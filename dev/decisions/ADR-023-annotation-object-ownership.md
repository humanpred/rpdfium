# ADR-023 — Annotation page-objects: appending moves the object off its page

- Status: Accepted
- Date: 2026-09-26
- Deciders: Bill Denney

## Context

`FPDFAnnot_AppendObject(annot, obj)` takes ownership of `obj` and
expects a free-standing object: PDFium wraps the pointer in a
`std::unique_ptr` in the page-object list of the annotation's
appearance form, and `FPDFPage_CloseAnnot` deletes it together with
the annotation context.

Every page-object creator in the package (`pdf_path_new()`,
`pdf_rect_new()`, `pdf_text_new()`, `pdf_image_new()`, ...) creates
the object *and* inserts it into a page with `FPDFPage_InsertObject`,
so the R side never has to manage a detached object's lifetime.
`pdf_annot_append_object()` passed such an object straight to
`FPDFAnnot_AppendObject`, leaving it in both the page's object list
and the annotation's form. Whichever of `FPDF_ClosePage` and
`FPDFPage_CloseAnnot` ran second freed it again.
`dev/pdfium-8066-api-delta.md` §E-4 reproduced the crash under
`MALLOC_CHECK_=3` on chromium/7857 and chromium/8066, and the default
Windows heap turned it into a segfault in every run tried.

Two workarounds had grown around the double free and hidden it:

- The annotation finalizer skipped `FPDFPage_CloseAnnot` once the page
  had been closed, attributing the crash to PDFium's destructor. That
  avoided the second free in the usual "page closed first" teardown
  order, and leaked every annotation context whose page closed before
  its handle was collected.
- `pdf_annot_remove_object()` and `pdf_form_obj_remove_object()` marked
  their success paths `# nocov` as crashing at teardown. For the
  annotation the crash was the same double ownership (the removed
  object was still in the page's list). For the form XObject nothing
  crashed, but `FPDFFormObj_RemoveObject` hands the removed child to
  the caller, and the package never freed it.

## Decision

1. `pdf_annot_append_object(annot, obj)` **moves** a top-level
   page-object of the annotation's page into the annotation. The shim
   checks `FPDFAnnot_IsObjectSupportedSubtype`, finds `obj` among the
   page's top-level objects, detaches it with `FPDFPage_RemoveObject`
   and appends it. Should `FPDFAnnot_AppendObject` still refuse the
   detached object, the object goes back to its original index
   (`FPDFPage_InsertObjectAtIndex`). On success the `obj` handle is
   cleared, since the annotation owns the object; `pdf_annot_objects()`
   reaches it from then on.
2. Every other input is refused with an R error before any state
   changes: annotation subtypes that cannot hold objects (only ink and
   stamp can), objects on another page or on another handle of the
   same page, objects nested in a form XObject, and objects already
   inside an annotation. PDFium itself accepts the last case and would
   create the same double ownership between two annotations.
3. The annotation finalizer closes the annotation context while its
   page handle or its document is still open, so a page closed first
   no longer leaks the context. The context keeps only an unowned page
   pointer, which its destructor never reads
   (`pdf_use_partition_alloc = false` in the bblanchon builds, so
   `UnownedPtr` is a plain pointer). Destroying the fonts and images of
   its page-objects calls back into the document only while it is
   alive: `CPDF_DocPageData`'s destructor marks every cached font and
   image, generated images included, so that releasing them later
   skips the callback. Valgrind on Linux found no invalid access when
   closing after `pdf_doc_close()` with path, text, image, shading and
   form objects in the appearance stream. Once the page and the
   document are both closed, the close is still skipped: that teardown
   order is unexercised, and a leak is the safer failure.
4. `pdf_form_obj_remove_object()` destroys the child that
   `FPDFFormObj_RemoveObject` hands back and clears its handle, the
   contract `pdf_obj_delete()` already has.

## Consequences

- Appending no longer double-frees. Append, remove and update run
  under test with explicit `gc()` in each teardown order (annotation,
  page or document first), and the success paths lose their `# nocov`
  markers.
- The move is visible to callers: after `pdf_annot_append_object()`
  the object is no longer on the page, and the page-scoped indices of
  later page-objects shift down by one, as after `pdf_obj_delete()`.
- Only the handle passed in is cleared. Other handles to a moved or
  destroyed object (from a second `pdf_page_objects()` call, or an
  earlier `pdf_annot_objects()` / `pdf_form_objects()` list) are not
  invalidated. `pdf_obj_delete()` has the same limitation; each
  function documents it.
- Two annotation-context leaks are outside this decision: the context
  of a handle collected after both its page and its document were
  closed (decision 3 skips the close), and the context behind
  `pdf_annot_delete()` (`FPDFPage_RemoveAnnot` leaves it alive, and the
  handle was cleared without `FPDFPage_CloseAnnot`). Neither is part of
  the double free.
- `pdf_form_obj_remove_object()` changes the page in memory only.
  PDFium regenerates a modified form XObject through
  `CPDF_PageContentManager`, which writes the new content to a
  `/Contents` key of the form's dictionary as if the form were a page;
  readers ignore that key, so a saved file still draws the removed
  child. The function documents this, a test pins it, and the fix
  belongs upstream.

## Alternatives considered

- **Detached creators** (e.g. a `page = NULL` mode for the
  `pdf_*_new()` creators): matches PDFium's intended call sequence, but
  needs a finalizer that destroys a detached object unless ownership
  moves, plus a second creator surface. Worth revisiting if users need
  to build annotation content without a page round-trip; moving covers
  today's use.
- **Refuse page-owned objects**: safe, but every object the package can
  create is page-owned, so `pdf_annot_append_object()` would have no
  valid input left.
- **Keep skipping `FPDFPage_CloseAnnot` after the page closes**: leaks
  every annotation context in the page-first teardown order and keeps a
  regression of the double free invisible in that order.
- **Close only while the document is open**: stops closing contexts
  after an explicit `pdf_doc_close()` while the page handle is still
  open, which the finalizer always did without any observed invalid
  access; the test suite's valgrind leak totals roughly double.

## References

- ADR-005 (memory model), ADR-015 (annotation authoring), ADR-016
  (page-object creation).
- PDFium `fpdfsdk/fpdf_annot.cpp` (`FPDFAnnot_AppendObject`,
  `FPDFAnnot_RemoveObject`, `FPDFAnnot_IsObjectSupportedSubtype`),
  `fpdfsdk/fpdf_editpage.cpp` (`FPDFPage_RemoveObject`,
  `FPDFFormObj_RemoveObject`), `core/fpdfapi/page/cpdf_annotcontext.h`,
  `core/fpdfapi/page/cpdf_docpagedata.cpp` (`~CPDF_DocPageData`),
  `core/fpdfapi/edit/cpdf_pagecontentgenerator.cpp` (`ProcessForm`,
  `ProcessImage`).
- `tests/testthat/test-api-completion.R`, section "Annotation
  page-objects: ownership (ADR-023)".
