# ADR-008 — CRAN-from-v0.1.0 targeting

- Status: Accepted
- Date: 2026-05-15

## Context

The operator's preference is for `pdfium` to ship to CRAN at its
first release (v0.1.0), not after an internal-only stabilization
period. The R PDF ecosystem survey (`docs/r-pdf-ecosystem-survey.md`)
confirmed there's a clean naming slot on CRAN. Targeting CRAN from
day one shapes several decisions:

- Binary distribution (ADR-003) had to choose a CRAN-acceptable
  pattern. Download-at-install via `configure` is precedented by
  `arrow` and `stringi`.
- Examples and tests can't make network calls during `R CMD check`.
- Source-tarball size must stay under the 5 MB CRAN limit.
- The example runtime budget is ~5 seconds per example.

## Decision

Every design choice in this repository preserves CRAN-cleanliness from
day one. Specifically:

- **Source tarball under 5 MB.** The bundled binary (10–15 MB per
  platform) is downloaded at install time, never vendored.
- **No internet during `R CMD check`.** Examples and tests use
  fixtures under `inst/extdata/fixtures/`. Conformance comparisons
  against pypdfium2 are opt-in (`KMEXTRACT_PATH` env var) and skipped
  on CRAN.
- **Examples under 5 seconds.** No example loads a multi-MB PDF;
  fixtures are minimal.
- **No writes outside `tempdir()`** during examples or tests.
  `withr::local_tempfile()` is the standard idiom.
- **No `\dontrun{}`** without justification. The current API has none
  — every example runs.
- **CRAN incoming-check matrix**: weekly `rhub::check_for_cran()` via
  `.github/workflows/cran-check.yaml` covers CRAN's reference
  platforms. Failures are triaged before they accumulate.
- **`cran-comments.md`** is added at the v0.1.0 release. It lists
  test platforms, expected NOTEs (specifically the installed binary
  size and the configure-time download), and prior-release context
  (none for the first release).
- **Failure modes**: if the configure-time download fails on a CRAN
  builder, the installation surfaces a clear actionable error and
  the override path (`PDFIUM_OFFLINE=1` + vendored tarball) is
  documented. We have no current evidence CRAN's farm blocks the
  download, but if they ever do, the override is the path forward.

## Consequences

- Cleanup work that internal-first releases get to defer is
  front-loaded here (vignettes, examples, lifecycle badge, NEWS
  discipline, `cran-comments.md`).
- We can't ship a "good enough for friends" v0.1.0; the first release
  is held to the same bar as the tenth. That's a feature, not a bug.
- Bumping PDFium (ADR-006) requires re-running the CRAN check
  matrix, not just our internal tests.
- If we ever discover a CRAN policy that's incompatible with
  download-at-install, we have the `PDFIUM_OFFLINE=1` fallback and
  a documented override.

## Alternatives considered

- **Internal-only v0.1.0, CRAN at v0.2.0.** Rejected per the
  operator's preference. The package's CRAN-readiness affects the
  configure script's design, the binary-distribution choice, the
  test-suite's CRAN-skip discipline, and the example budgets; baking
  these in from the start is cheaper than retrofitting.
- **Skip CRAN entirely** (GitHub-only forever). Rejected — most R
  users find packages on CRAN, and the project's goal includes
  serving non-niche audiences.

## References

- ADR-003 (binary distribution)
- ADR-006 (PDFium pin)
- [CRAN Repository Policy](https://cran.r-project.org/web/packages/policies.html)
- [Writing R Extensions §1.1.4 — `cran-comments.md`](https://cran.r-project.org/doc/manuals/R-exts.html#The-CRAN-incoming-feasibility-check)
