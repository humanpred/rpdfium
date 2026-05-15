# ADR-001 — Language stack and framework

- Status: Accepted
- Date: 2026-05-15

## Context

`pdfium` exposes Google's PDFium C ABI to R users. PDFium ships as a C++
library with a flat C public header surface (`public/fpdfview.h` and
siblings). We need an R↔C++ glue layer. Two practical options exist:
[Rcpp](https://www.rcpp.org/) and
[cpp11](https://cpp11.r-lib.org/). The R community uses both; Rcpp has
broader installed base and tooling familiarity. We also need a minimum
R version that balances modern features against installed-base
compatibility.

## Decision

- **R framework:** R ≥ 4.2. Rationale: R 4.2 introduced `\\` lambda
  syntax and stabilized native pipe semantics. As of 2026-05-15, every
  CRAN-supported R release is ≥ 4.4, and R 4.2 covers ~98% of installed
  R sessions.
- **R↔C++ glue:** Rcpp. Rationale: matches the maintainer's familiarity,
  has well-trodden patterns for `externalptr` lifetimes that the
  `cpp11` ecosystem only recently developed, and unblocks reuse of
  existing PDFium R explorations.
- **C++ standard:** C++17. Rcpp 1.0.13+ supports it cleanly. PDFium's
  public headers compile under C++17. We use `CXX_STD = CXX17` in
  `Makevars` so the build system honors it.
- **Object model:** S3. The handle hierarchy (`pdfium_doc`,
  `pdfium_page`, `pdfium_obj`) is shallow and the dispatch needs are
  minimal. S4 / R6 would buy nothing here.

## Consequences

- Users on R < 4.2 must upgrade. Documented in `DESCRIPTION` and the
  README.
- Rcpp ABI changes (rare but possible) require us to bump `LinkingTo:`
  and re-run `R CMD check` against the new version.
- C++17 support is universal on the CRAN platforms we target (Ubuntu
  22.04+ / GCC 11+, macOS Big Sur+ / Apple Clang 12+, Rtools43+ on
  Windows).
- S3 means we cannot rely on multiple dispatch. If we ever need
  per-handle-class behavior for a generic, we'll route through
  `inherits()` rather than method tables.

## Alternatives considered

- **cpp11 instead of Rcpp.** Cleaner allocator semantics and a smaller
  installed footprint. Rejected because the project benefits more from
  Rcpp's mature `externalptr` patterns. If cpp11's `external_pointer`
  proves materially better for our memory model later, a follow-up ADR
  can revisit.
- **C ABI directly via `.Call`.** Possible but would require us to
  hand-roll all the `SEXP` wrangling Rcpp already does. Not worth it.
- **R6 instead of S3.** Would give us method dispatch and reference
  semantics. Rejected because PDFium handles are *not* mutable objects
  from R's perspective — they're opaque pointers we expose ergonomic
  accessors over.
- **R ≥ 4.4 (more aggressive floor).** Rejected because the installed
  base for 4.2 is still meaningful. We can raise the floor later when
  CRAN itself does.

## References

- [Rcpp](https://www.rcpp.org/)
- [cpp11 vs Rcpp](https://cpp11.r-lib.org/articles/motivations.html)
- [Writing R Extensions, External Pointers and weak references](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#External-pointers-and-weak-references)
