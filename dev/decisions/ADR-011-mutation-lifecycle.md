# ADR-011 — Mutation lifecycle: explicit `pdf_save()`

- Status: Accepted
- Date: 2026-05-19
- Deciders: Bill Denney

## Context

PDFium's mutation API mutates the in-memory `FPDF_DOCUMENT`; persisting
to disk requires `FPDF_SaveAsCopy` (or `FPDF_SaveWithVersion`) writing
through a `FPDF_FILEWRITE` callback. The R surface needs a convention
for how callers move from a mutated handle to a saved file.

Three shapes were considered:

| Shape | Example |
|---|---|
| A: explicit save | `pdf_open(path) → modify → pdf_save(doc, out)` |
| B: in-place edit | `pdf_edit(in, out, function(doc) ...)` |
| C: side-effect functions | `pdf_rotate_page(path, page, degrees, out = path)` |

## Decision

Adopt shape A. `pdf_save(doc, file, ...)` is its own export. The doc
handle remains the unit of work — open it, mutate it, save it. The
mutation API never overloads `pdf_close()` and never takes path-string
arguments in place of a doc handle.

## Consequences

- Matches the `pdftools` / `qpdf` convention R users already know.
- Each mutator function takes a `pdfium_doc` (or a `pdfium_page` /
  `pdfium_obj` that resolves to one) and returns it invisibly so
  edits can be chained with `|>`.
- Two doc handles in memory when saving to a path that differs from
  the open path; acceptable cost.
- `pdf_save()` writes atomically (tempfile in destination dir,
  rename on success). See the function reference and
  `dev/mutation-design.md` §3.

## Alternatives considered

- **Shape B** (`pdf_edit(in, out, fn)`): rejected — too opinionated;
  forces every edit into a callback closure even when the caller
  just wants to chain a couple of mutators.
- **Shape C** (`pdf_rotate_page(path, page, degrees, out = path)`):
  rejected — heavy per-call overhead; no editing graph; explodes the
  API surface (every mutator has a path-string overload).

## References

- `dev/mutation-design.md` §3.
- PDFium `FPDF_SaveAsCopy` / `FPDF_FILEWRITE` in `public/fpdf_save.h`.
