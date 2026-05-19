# ADR-014 — Structural mutation set: in-scope vs. defer to qpdf

- Status: Accepted
- Date: 2026-05-19
- Deciders: Bill Denney

## Context

PDFium exposes a small but useful set of structural mutators
(`FPDFPage_SetRotation`, `_Delete`, `FPDF_MovePages`,
`FPDF_ImportPagesByIndex`, etc.). `qpdf` already covers the same
ground on CRAN (split / merge / rotate) plus more
(compress / linearise / encrypt) that PDFium does not expose. The
question is which subset to expose in `pdfium`.

## Decision

Expose the structural mutators PDFium's public API supports directly:

| R function | PDFium symbol |
|---|---|
| `pdf_set_page_rotation(doc, page_num, degrees)` | `FPDFPage_SetRotation` |
| `pdf_delete_page(doc, page_num)` | `FPDFPage_Delete` |
| `pdf_reorder_pages(doc, new_order)` | `FPDF_MovePages` |
| `pdf_merge(docs, file, ...)` | `FPDF_ImportPagesByIndex` |
| `pdf_n_up(doc, file, cols, rows)` | `FPDF_ImportNPagesToOne` |
| `pdf_set_page_box(page, box, c(l, b, r, t))` | `FPDFPage_Set{Media,Crop,Bleed,Trim,Art}Box` |
| `pdf_set_doc_language(doc, lang)` | `FPDFCatalog_SetLanguage` |
| `pdf_new_doc()` | `FPDF_CreateNewDocument` |
| `pdf_new_page(doc, page_num, width, height)` | `FPDFPage_New` |

Do **not** expose compress / linearise / encrypt / decrypt /
optimize — PDFium does not provide them; `qpdf` is the right tool.
Document the relationship in `README.md` so users know which
package solves which problem.

## Consequences

- `pdfium` becomes a self-contained tool for the common
  read-modify-save flow (rotate, delete, reorder, merge) without
  forcing users to also install `qpdf`.
- `qpdf` remains the right choice for compression, linearisation,
  optimization, and password-based encryption.
- `pdf_n_up` and `pdf_merge` need round-trip tests that verify the
  handle lifetime issue (see `dev/mutation-design.md` §8) is not
  hit; document the order callers must close handles in.

## Alternatives considered

- **Defer all structural mutation to qpdf**: rejected — the
  open / modify / save flow is the most common user demand, and
  forcing two packages for that is a poor user experience.
- **Mirror qpdf's full surface in `pdfium`**: rejected — PDFium
  doesn't expose compress / encrypt / linearise, so we'd need to
  re-implement them; out of scope and a maintenance burden.

## References

- `dev/mutation-design.md` §2 Phase 2.
- `qpdf` package on CRAN: <https://CRAN.R-project.org/package=qpdf>.
- `dev/r-pdf-ecosystem-survey.md` § Post-0.1.0 candidates.
