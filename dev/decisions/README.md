# Architecture Decision Records

This directory records every material design decision in `pdfium` as a
Markdown ADR following the
[MADR template](https://adr.github.io/madr/).

## Index

| # | Status   | Title |
|---|----------|---|
| [001](ADR-001-language-stack.md) | Accepted | Language and framework: R ≥ 4.2 + Rcpp + C++17 + S3 |
| [002](ADR-002-license.md)        | Accepted | License: MIT for the R package, BSD-3-Clause for the bundled PDFium |
| [003](ADR-003-binary-distribution.md) | Accepted | Binary distribution: bblanchon pdfium-binaries downloaded at install |
| [004](ADR-004-api-style.md)      | Accepted | API style: snake_case `pdf_*`, S3 classes, tibble outputs |
| [005](ADR-005-memory-model.md)   | Accepted | Memory model: `externalptr` + finalizers + idempotent explicit close |
| [006](ADR-006-pdfium-pin.md)     | Accepted | PDFium version pinning policy |
| [007](ADR-007-ci-and-coverage.md) | Accepted | CI: GitHub Actions matrix, 100% R coverage gate, valgrind, ASan |
| [008](ADR-008-cran-targeting.md) | Accepted | CRAN-from-v0.1.0 hardening |
| [009](ADR-009-defer-bezier-controls.md) | Accepted | Defer Bezier control points to a post-0.1.0 release (no public PDFium API) |

## Policy

- One ADR per material choice. Material choices include: dependency
  changes, API-shape changes, distribution model changes, memory-model
  changes, CI gating policy changes, license changes.
- ADRs are **immutable once accepted**. Update by writing a new ADR with
  status `Supersedes ADR-NNN`, and amend the index above.
- The template lives at [`ADR-000-template.md`](ADR-000-template.md).
- New ADRs increment the number monotonically.

## When to write an ADR

Yes:

- "We will use [framework X] for [layer Y]."
- "We will distribute binaries via [mechanism Z]."
- "We will name the public function `pdf_foo()` (not `pdfium_foo()`)
  because [reason]."

No:

- Bug fixes.
- Implementation details that don't constrain other choices.
- Renaming a private helper.
