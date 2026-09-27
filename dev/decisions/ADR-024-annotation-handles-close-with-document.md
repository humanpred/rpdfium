# ADR-024 — Annotation handles are closed with their document

- Status: Supersedes ADR-023 decision 3 (when the annotation finalizer closes the context)
- Date: 2026-09-27
- Deciders: Bill Denney

## Context

A `pdfium_annot` handle, including a form-field handle, owns a PDFium
annotation context (`CPDF_AnnotContext`). `FPDFPage_CloseAnnot` frees
the context together with the page-objects of the annotation's
appearance stream. Until then the context holds a reference to the
annotation's dictionary, so a context that is never closed leaks that
dictionary as well once `FPDF_CloseDocument` drops the document's own
reference.

The weekly valgrind job (`.github/workflows/valgrind.yaml`) failed its
leak gate on every run from at least 2026-05-25. Almost every
definitely-lost record was an annotation context that was never closed,
minted by `pdf_annotations()`, `pdf_annot_at()`, `pdf_annot_new()`,
`pdf_form_fields()` and the other functions that return annotation
handles. Two paths left contexts open:

- `pdf_annot_delete()` cleared the handle without closing the context.
  It now closes it.
- The finalizer skipped the close in some teardown orders. Until
  ADR-023 it skipped it whenever the page handle had been closed;
  ADR-023 decision 3 narrowed that to "page handle and document both
  closed". That is still the usual order in scripts and in the test
  suite: a page closed and then its document closed, typically through
  `on.exit()`, with annotation handles still bound.

ADR-023 argues from PDFium's source that closing a context after its
document has been freed is safe, and valgrind runs found no invalid
access in that order. The argument rests on PDFium internals that no
public header promises, though, and ADR-023 still leaves the "both
closed" order unclosed.

The finalizer also cannot always tell which document a handle belongs
to. PDFium has no page-to-document call, and the page handles that
`pdf_form_fields()` makes do not pin their document in `prot`.

## Decision

1. Every annotation handle is registered under its `FPDF_DOCUMENT` in
   a per-document registry in C++ (`src/annot_registry.{h,cpp}`).
   `make_annot_handle()` is the only function that creates an
   annotation externalptr, and it attaches the finalizer and registers
   the handle together. The four places that mint handles call it:
   `cpp_annot_get`, `cpp_annot_new`, `cpp_annot_linked_handle` and
   `cpp_form_field_handles`. The first three take the document
   externalptr from the R layer (`page$doc$ptr`) and refuse a closed
   document before calling PDFium.
2. A document releases its registered handles before it closes: each
   context is closed with `FPDFPage_CloseAnnot` and its handle cleared.
   Every `FPDF_CloseDocument` call in the package goes through
   `close_document_handle()` (`src/document_handle.h`), which does
   this. That covers `pdf_doc_close()`, the document finalizer, and
   the finalizer of the documents `pdf_n_up()` makes.
3. The registry holds its handles weakly. It keeps the externalptr
   `SEXP`s in C++ containers that R does not scan, and never protects
   them. `release_annot_handle()` removes a handle from the registry
   first, whether or not its address is still set, and it is the only
   code that clears an annotation handle: the finalizer,
   `pdf_annot_delete()` and document close all call it. The registry
   therefore never holds a handle R has freed, and an unreachable
   handle is still collected as soon as R finds it, not kept alive
   until its document closes.
4. The finalizer closes the context whenever the handle's address is
   still set. ADR-023's liveness test (`annot_close_is_safe()`) is
   removed. Under the registry, a handle whose address is set always
   belongs to an open document, so the test would always pass. For a
   form-field handle whose page handle had already been closed, it
   also skipped the close while the document was still open, because
   that page handle does not lead to the document.

## Consequences

- No annotation context outlives its document, in any teardown order,
  so whether closing one after its document is safe no longer matters.
- `pdf_doc_close()` changes what a caller sees: annotation and
  form-field handles still open on the document print as closed
  afterwards, and `pdf_annot_*()` calls on them raise an error. Before,
  they printed as open while pointing into a closed document.
- The document holds no R reference to its annotation handles, so a
  `pdf_annotations()` loop over a long document still frees each page's
  handles once they become unreachable.
- Minting an annotation handle needs the document externalptr as well
  as the page's. Internal callers pass `page$doc$ptr`.
- Page handles are unchanged. `pdf_doc_close()` does not close them, a
  page handle collected after its document closed still runs
  `FPDF_ClosePage` then, and form-field page handles still do not pin
  their document. None of these leaks, and they are outside this
  decision.

## Alternatives considered

- **Defer `FPDF_CloseDocument` until the last child is collected**:
  breaks the documented contract that `pdf_doc_close()` releases the
  document at once, which Windows needs before the file can be deleted.
- **Track the handles in R** (a list in `doc$state`, or the document
  externalptr's tag or prot slot): a strong reference, so every handle
  would live until its document closes, and a `pdf_annotations()` loop
  over a long document would pile them up.
- **Fix only the tests** (collect annotation handles before closing the
  document): users would hit the same leak with the same code.
- **Keep ADR-023's liveness test as a fallback**: it guards no case the
  registry leaves open, and it leaks form-field contexts whose page
  handle was closed first.
- **Read the document from the page handle's prot slot**: works for
  pages from `pdf_page_load()` and `pdf_page_new()`, but not for the
  page handles of `pdf_form_fields()`. Making those pin their document
  is a separate change; once it is made, the minting shims could take
  the document from the page again.

## References

- ADR-005 (memory model), ADR-023 (annotation page-objects).
- `src/annot_registry.h`, `src/annot_registry.cpp`,
  `src/document_handle.h`, `src/init.cpp`.
- PDFium `public/fpdf_annot.h` (`FPDFPage_CloseAnnot`),
  `core/fpdfapi/page/cpdf_annotcontext.h`.
- `tests/testthat/test-annot-handles.R`, section "pdf_doc_close() and
  live annotation handles (ADR-024)".
