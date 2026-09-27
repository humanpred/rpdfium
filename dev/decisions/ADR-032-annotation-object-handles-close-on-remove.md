# ADR-032 — Removing an annotation's page-object closes its handles

- Status: Accepted (extends ADR-029)
- Date: 2026-09-27
- Deciders: Bill Denney

## Context

ADR-029 refuses a handle once any of its owners is closed, but left
one path open: `pdf_annot_remove_object()` destroys an object of an
annotation's appearance stream by position (`FPDFAnnot_RemoveObject`),
and nothing could find the handles made to that object earlier. They
still pinned an open annotation, so they, and the clip paths and nested
objects read through them, passed every check and read the freed
object. Under valgrind on the ADR-029 branch:

- the removed object's own handle, and a second handle to it from
  another `pdf_annot_objects()` call: 4 invalid reads;
- a clip path read from the object: 1 invalid read;
- an object nested in a form removed from its annotation: 5 invalid
  reads.

Each annotation handle has its own annotation context, which parses the
appearance stream into its own objects: objects read through another
handle to the same annotation are separate copies, at other addresses,
and the removal does not touch them.

## Decision

1. The handles `pdf_annot_objects()` returns are registered in the
   ADR-025 registry, under the annotation's document, as a new kind
   whose release only clears the handle: the annotation owns the
   object. `make_annot_object_handle()` mints them; like every other
   registered handle they are released by their finalizer and by their
   document's close.
2. After `FPDFAnnot_RemoveObject` succeeds, `cpp_annot_remove_object()`
   releases every handle of that kind registered under the document
   whose address is the removed object's, with
   `release_annot_object_handles()`. Only addresses are compared, so
   the object being freed already does not matter; a removal PDFium
   refuses leaves the handles open. The clip paths and nested objects
   read through the released handles are then refused by the ADR-029
   chain.
3. As with annotation handles (ADR-024), the shims take the document
   from R: `cpp_annot_get_object()` and `cpp_annot_remove_object()`
   gain a document argument.
4. The closed-handle messages name the cause: "The object was removed
   from its annotation by pdf_annot_remove_object()."

## Consequences

- No handle reachable from `pdf_annot_objects()` outlives the object it
  points to.
- Every annotation page-object handle carries a finalizer, which only
  deregisters it.
- A second handle to one page-object of a page or form, from a separate
  `pdf_page_objects()` or `pdf_form_objects()` call, still stays stale
  after the object is deleted through the first. Those objects have no
  registry entry; registering them the same way would close that gap
  too.
- `cpp_annot_object_handle_count()` reports the registered annotation
  page-object handles of a document, for tests;
  `cpp_doc_handle_counts()` is unchanged.

## Alternatives considered

- **Document the handles as stale**, as ADR-029 did: leaves a
  use-after-free one call away from an exported function.
- **Register the handles under their annotation handle** instead of the
  document: the registry is keyed by document, and the address already
  tells the removed object's handles apart from those of other
  annotation contexts.
- **Release the handles before the removal**: a removal PDFium refuses,
  for an annotation subtype that cannot hold objects, would close
  handles to an object that still exists.

## References

- ADR-024, ADR-025, ADR-029.
- `src/handle_registry.h`, `src/handle_registry.cpp`,
  `src/api_completion.cpp` (`cpp_annot_get_object`,
  `cpp_annot_remove_object`).
- PDFium `public/fpdf_annot.h` (`FPDFAnnot_GetObject`,
  `FPDFAnnot_RemoveObject`).
- `tests/testthat/test-api-completion.R`, section
  "pdf_annot_remove_object() closes the removed object's handles
  (ADR-032)".
