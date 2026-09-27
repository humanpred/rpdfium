# ADR-025 — Pages, fonts and XObjects are closed with their document

- Status: Accepted (extends ADR-024)
- Date: 2026-09-27
- Deciders: Bill Denney

## Context

PDFium expects a page to be closed before its document. ADR-024
enforced that order for annotation contexts only. `pdf_doc_close()`
closed the document at once and left its page handles open, and every
page shim validated only the page handle's own address. A page used
after its document's close therefore handed PDFium a page whose
`CPDF_Document` had been freed. Under valgrind, `pdf_render_page()`
and `pdf_text_runs()` on such a page read freed document memory, and
text extraction also *wrote* into it: resolving a font's `/ToUnicode`
stream inserts into the freed document's indirect-object map. The
results still looked right, so nothing noticed. On Windows, whose heap
reuses freed blocks differently, this is a plausible source of
unexplained crashes. A page collected after its document was closed
also ran `FPDF_ClosePage` after `FPDF_CloseDocument`.

Page-objects read from such a page passed their own check too: their
`prot` slot pins the page, and the page's address was still set.

The page handles that `pdf_form_fields()` makes had `R_NilValue` in
`prot`, so they did not pin their document.

The same class reached two other handle types:

- Font handles (`FPDFText_LoadFont` and the other loaders) and XObject
  handles (`FPDF_NewXObjectFromPage`) outlived their document, and
  their finalizers called `FPDFFont_Close` / `FPDF_CloseXObject`
  afterwards. PDFium's source suggests both touch no document memory
  then, but no public header promises it: the argument ADR-024
  declined to rely on for annotation contexts.
- An XObject handle validated only its own address, so
  `pdf_obj_form_from_xobject()` after its destination document closed
  built a form object from the freed document. A loaded font or an
  XObject could also be combined with a page of *another* document:
  the resulting text or form object refers into the first document, is
  written out wrongly by `pdf_save()`, and reads freed memory once that
  document closes.

## Decision

1. The ADR-024 registry holds every handle PDFium closes on the
   document's behalf: annotation contexts, pages, fonts and XObjects.
   `src/annot_registry.{h,cpp}` becomes `src/handle_registry.{h,cpp}`:
   one per-document registry whose entries carry their kind, keeping
   ADR-024's weak entries, reverse map and unconditional
   deregistration in the finalizer.
2. Each kind has one minting and one releasing function.
   `make_page_handle()` mints every page handle (`cpp_load_page`,
   `cpp_page_new`, `cpp_form_field_handles`) and pins the document in
   `prot`, the form-field pages included. `make_font_handle()` mints
   the handles of `cpp_font_load_standard`, `cpp_font_load_truetype`
   and `cpp_font_load_cidtype2`, and `make_xobject_handle()` the one of
   `cpp_xobject_from_page`. The matching `release_*_handle()` is the
   only code that clears a handle: the finalizer, `pdf_page_close()`,
   `pdf_font_close()`, `pdf_xobject_close()` and document close all
   call it.
3. `close_document_handle()` releases the document's registered
   handles before `FPDF_CloseDocument`, in this order: annotation
   contexts (each refers to its page), pages, then fonts and XObjects.
4. A page whose document closed reads as closed, so the existing
   closed-page checks refuse it: the R wrappers with "Page has been
   closed: its document was closed.", the C++ shims with their NULL
   checks. Page-objects are refused through `prot`, which pins the
   cleared page, or, for `pdf_annot_objects()`, the cleared annotation.
   The XObject shims also require the pinned document to be open.
5. A font or XObject is used only with pages of its own document:
   `pdf_text_new(font = )` and `pdf_obj_form_from_xobject()` refuse one
   from another document, as `pdf_obj_add_existing_mark()` already does
   for marks.
6. The form object `pdf_obj_form_from_xobject()` inserts pins its page,
   not the XObject, like the objects of every other creator. It stays
   usable after `pdf_xobject_close()`, as documented, and is refused
   once its page closes.

## Consequences

- No page, annotation context, font or XObject outlives its document,
  in any teardown order. A finalizer that runs after its document
  closed only deregisters the handle.
- `pdf_doc_close()` changes what a caller sees: pages, page-objects,
  fonts and XObjects of the document print as closed afterwards, and
  calls on them raise an error. Code that closed a document and then
  kept reading one of its pages used to appear to work while reading
  freed memory; it now fails at the first call on the page.
- Handles outside the registry, and why each is safe after its
  document closes:
  - page-objects (including those of `pdf_form_objects()` and
    `pdf_annot_objects()`) and the clip paths of `pdf_obj_clip_path()`
    have no close of their own and pin their page or annotation, which
    the document's close clears;
  - attachments, signatures and bookmarks have no close of their own
    and pin the document, and their shims require it open;
  - clip paths from `pdf_clip_path_new()` and bitmaps from
    `pdf_bitmap_new()` do not belong to a document;
  - text pages, structure trees, web links, search handles and
    form-fill environments are opened and closed within one call.
- The R-level `doc$state$open_pages` list keeps the externalptr of the
  last page loaded per index. It still holds the cleared externalptrs
  of pages a document's close closed; its only reader, the flush in
  `pdf_save()`, skips cleared externalptrs, and `pdf_save()` refuses a
  closed document anyway.
- The annotation-minting shims keep taking the document from R, the
  ADR-024 interface, although every page handle now pins its document.
- `cpp_doc_handle_counts()` reports a document's registered handles
  per kind, for tests.

## Alternatives considered

- **A parallel page registry next to ADR-024's annotation registry**
  (and later font and XObject ones): duplicates the maps and the
  release code per kind, and spreads the release order over the
  callers of each. One registry keyed by kind keeps the order in one
  place.
- **Refuse pages whose document closed instead of closing them** (a
  document-liveness check in every page shim): needs dozens of shims
  changed, and still runs `FPDF_ClosePage` after `FPDF_CloseDocument`
  for pages collected later.
- **Defer `FPDF_CloseDocument` until the last page is collected**:
  breaks the contract that `pdf_doc_close()` releases the document at
  once, which Windows needs before the file can be deleted (as in
  ADR-024).
- **Track pages in R**: `doc$state$open_pages` holds only the last page
  per index, holds it strongly, and is out of reach of the document's
  finalizer.
- **Register pages only**: fonts and XObjects would keep calling
  PDFium after their document closed, and XObjects could still reach
  it through `pdf_obj_form_from_xobject()`.

## References

- ADR-005 (memory model), ADR-020 §4 (C-side validation), ADR-024.
- `src/handle_registry.h`, `src/handle_registry.cpp`,
  `src/document_handle.h`, `src/init.cpp`.
- PDFium `public/fpdfview.h` (`FPDF_ClosePage`, `FPDF_CloseDocument`),
  `public/fpdf_edit.h` (`FPDFFont_Close`), `public/fpdf_ppo.h`
  (`FPDF_CloseXObject`).
- `tests/testthat/test-document.R`, section "pdf_doc_close() and the
  document's pages (ADR-025)".
