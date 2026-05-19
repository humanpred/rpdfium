# ADR-012 — Read-write flag on `pdfium_doc`

- Status: Accepted
- Date: 2026-05-19
- Deciders: Bill Denney

## Context

PDFium itself has no read/write distinction — every loaded
`FPDF_DOCUMENT` is mutable. The R wrapper, however, has both
read-only and write-capable users and wants to protect read-only
users from accidental edits (a common class of bug: pass `doc` to a
mutator deep in a pipeline, save it, lose data).

## Decision

`pdf_open(path, source = NULL, password = NULL, readwrite = FALSE)`
defaults to read-only. The flag is stored on the `pdfium_doc` S3
object as `doc$readwrite` and is checked by an internal
`assert_readwrite(doc)` helper that every mutator calls first. If
the doc is read-only, the helper raises:

> Document opened read-only; reopen with `pdf_open(..., readwrite = TRUE)`.

`pdf_new_doc()` (creates an empty document via
`FPDF_CreateNewDocument`) returns a doc with `readwrite = TRUE`
unconditionally — you cannot usefully create a document you cannot
write.

## Consequences

- One-line cost at the top of every mutator function.
- Read-only users see no change to existing reader behaviour.
- The flag is R-side only; the underlying PDFium handle is the same
  in both modes.
- Round-trip tests need to explicitly open `readwrite = TRUE` to
  exercise the writer surface.
- An open doc cannot be promoted from read-only to read-write
  without a re-open. Acceptable: discourages accidental late-stage
  mutation, and the re-open cost is negligible.

## Alternatives considered

- **No flag, always writable**: rejected — too easy to corrupt
  upstream files via a stray mutator in the middle of a long
  pipeline.
- **Flag at the function level** (e.g. `pdf_set_page_rotation(..., overwrite = TRUE)`):
  rejected — pushes the safety check onto every mutator call site;
  the doc-level flag scopes safety to "this handle, for its life".

## References

- `dev/mutation-design.md` §4.
