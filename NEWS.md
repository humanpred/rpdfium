# pdfium 0.0.0.9000

## Phase 0 — package skeleton

* Initial scaffolding: R package layout, Rcpp toolchain, GitHub CI matrix,
  `pre-commit` configuration, decision records, architecture documentation.
* Binary distribution: PDFium is downloaded from
  [bblanchon/pdfium-binaries](https://github.com/bblanchon/pdfium-binaries) at
  install time. See `docs/decisions/ADR-003-binary-distribution.md`.
* Smoke test: `pdf_page_count(path)` proves the end-to-end Rcpp toolchain
  against a fixture PDF.

This release is not yet feature complete. See the project plan for the
roadmap to v0.1.0.
