# ADR-029 — A handle is refused once any of its owners is closed

- Status: Accepted (extends ADR-020 §4 and ADR-025)
- Date: 2026-09-27
- Deciders: Bill Denney

## Context

ADR-020 §4 made every C++ shim validate a handle before using it:
`validate_handle()` refuses a handle whose own externalptr is cleared,
or whose `prot` slot holds a cleared externalptr. That checks one
level of ownership. ADR-025 made closing a document clear its pages,
and every handle below a page pinned the page or, for the objects of
an annotation's appearance stream, the annotation. Clip paths from
`pdf_obj_clip_path()` pinned the page, and the objects
`pdf_form_objects()` returns pinned the form's page or annotation.

PDFium frees page-objects in more ways than closing their page.
`FPDFPageObj_GetClipPath()` returns a pointer into the object, and a
form object owns its nested objects, so both go with the object.
`pdf_obj_delete()` and `pdf_form_obj_remove_object()` destroy an
object, `pdf_annot_delete()` frees the objects of the annotation's
appearance stream, and `pdf_annot_append_object()` moves an object
into an annotation, which frees it when the annotation is deleted. A
handle derived from such an object passed validation, because what it
pinned, the page or the annotation, was still open. Under valgrind on
the ADR-025 branch, seven paths through exported functions read freed
memory (0 invalid writes, 0 invalid frees):

- a clip path of an annotation's object after `pdf_annot_delete()`
  (2 invalid reads; `pdf_clip_path_count()` segfaults without
  valgrind);
- a clip path after `pdf_obj_delete()` of its object (2);
- the objects of a form after `pdf_obj_delete()` of the form (5; they
  returned garbage bounds);
- a clip path after `pdf_form_obj_remove_object()` of its object (1);
- a clip path after `pdf_annot_remove_object()` of its object (1);
- the objects of a form moved into an annotation, after
  `pdf_annot_delete()` (1);
- a clip path of an object moved into an annotation, after
  `pdf_annot_delete()` (1).

In R, `is_open()` checked an object's own handle and its page only.
Objects of a deleted annotation printed as open and were refused only
by the C++ check, with its internal message; children of a deleted
form passed both.

## Decision

1. Every handle pins its immediate owner in `prot`. Two change: a clip
   path from `pdf_obj_clip_path()` pins its page-object, not the page,
   and an object from `pdf_form_objects()` pins its form object, not
   the form's page or annotation. The rest stand: a page pins its
   document, an annotation its page, a page-object its page or
   annotation, and fonts, XObjects, attachments, signatures and
   bookmarks their document.
2. `validate_handle(..., require_prot_alive = true)` walks the `prot`
   chain until the first `prot` that is not an externalptr, and refuses
   the handle when any externalptr on the way is cleared. The walk
   allocates nothing. It is capped at 64 links: PDFium parses Form
   XObjects 40 deep, so the longest real chain, from a clip path
   through its object, 40 forms, the page and the document to the
   document's memory buffer, is 44. A chain cannot loop, because
   `prot` is fixed when a handle is made; a longer chain is an error.
3. `is_open()` follows the same chain in R. A page-object is open when
   its own handle is and its owner is: `parent_form`, else
   `parent_annot`, else its page. A clip path is open when its handle
   and its page-object are. The closed-handle messages name the
   outermost owner that is closed: the document, the annotation
   ("deleted with pdf_annot_delete()"), a form object ("deleted,
   removed from its form or moved into an annotation"), else the
   existing page-closed text.
4. `pdf_annot_update_object()` and `pdf_form_obj_remove_object()`
   validate their page-object argument like the other page-object
   functions (`check_pdfium_obj()`).

## Consequences

- A handle is refused as soon as anything it depends on is closed,
  deleted or moved: by the R wrappers with a message naming the cause,
  and by the C++ shims for direct `cpp_*` calls. Six of the seven paths
  above read no freed memory any more.
- The refusal is conservative. After `pdf_annot_append_object(annot,
  form)`, the objects read through the form's handle, now closed, are
  refused although they still exist inside the annotation; they are
  read again through `pdf_annot_objects()` and `pdf_form_objects()`.
- The seventh path stays open: `pdf_annot_remove_object()` destroys an
  object by position and cannot find the handles made to it earlier,
  so those handles and what is read through them remain stale, as
  documented. The same holds for a second handle to one object, from a
  second `pdf_page_objects()` or `pdf_form_objects()` call, after the
  object is deleted through the first. Registering the page-object
  handles of an annotation under it in the ADR-025 registry would let
  `pdf_annot_remove_object()` clear them; that is left for a later
  decision.
- Validation reads one pointer per level of ownership, at most 44.
- `cpp_obj_get_clip_path()` and `cpp_form_get_object()` no longer take
  a page or owner externalptr; the handle they are given is the owner.

## Alternatives considered

- **Pin the page or annotation that owns the object**, as the objects
  of `pdf_form_objects()` did: catches a deleted annotation, but not a
  deleted, removed or moved object or form.
- **Register page-objects in the ADR-025 registry**: an object can have
  any number of handles, from separate calls, and pages have many
  objects, none of which PDFium closes; it would be a far larger change
  for the one case the owner chain cannot reach.
- **Check the chain only in R**: direct `cpp_*` calls would still read
  freed memory, against ADR-020 §4.
- **A small cap, such as 8 links**: stops before the page and document
  for objects nested in a few forms, which would then pass unchecked.

## References

- ADR-020 §4 (C-side validation), ADR-023 (annotation page-objects),
  ADR-025 (handles close with their document).
- `src/handle_validation.h`, `src/clip.cpp`, `src/forms.cpp`,
  `R/classes.R` (`is_open()`, `obj_owner()`), `R/obj_extras.R`
  (`obj_closed_cause()`).
- PDFium `public/fpdf_edit.h` (`FPDFPageObj_GetClipPath`,
  `FPDFPageObj_Destroy`, `FPDFFormObj_GetObject`), `public/fpdf_annot.h`
  (`FPDFAnnot_AppendObject`, `FPDFAnnot_RemoveObject`).
- `tests/testthat/test-clip.R`, section "Clip paths close with their
  page-object (ADR-029)"; `tests/testthat/test-forms.R`, section "Nested
  objects close with their form (ADR-029)".
