# ADR-010 — Use `checkmate` for argument validation

- Status: Accepted
- Date: 2026-05-19
- Deciders: Bill Denney

## Context

`pdfium`'s public R API is wide (≈ 90 exported functions in v0.1.0)
and each one validates its arguments before calling into the Rcpp /
PDFium layer. The validation surface is consequential because:

1. The C++ layer assumes its inputs are pre-validated. A
   value-shape mismatch that reaches Rcpp risks a segfault rather
   than a friendly R error.
2. Error messages are part of the public API; CRAN reviewers and
   downstream consumers expect consistent phrasing.
3. The package is CRAN-target from v0.1.0; lintr's
   `cyclocomp_linter(20L)` gate triggers on the long chained
   `is.numeric(x) && length(x) == 1L && !is.na(x) && ...` patterns
   that crop up everywhere on the read surface.

The PR-23 read-completion pass produced a first generation of
small ad-hoc validators in `R/utils.R`
(`validate_positive_int`, `validate_nonempty_char`,
`validate_finite_numeric`, plus four module-local
`validate_*` helpers). They worked but:

- Each one is bespoke; the error messages and the failure shapes
  are not consistent across the package.
- They cover the common cases (single positive integer, single
  non-empty character, finite numeric) and stop there; richer
  predicates (numeric ranges, named-list shape, S3-class
  assertion, vectorised checks for list-columns) would each be
  another hand-rolled helper.
- They don't compose. There's no clean way to express "x must be
  either a `pdfium_page` OR a `pdfium_doc`" without re-writing the
  branch logic per wrapper.
- They duplicate functionality from a well-established CRAN
  package (`checkmate`, ~2.5M downloads/year, maintained since
  2014, used by 800+ reverse-dependencies including `mlr3`,
  `data.table`, `parallelly`).

## Decision

Adopt `checkmate` as the canonical argument-validation library
for the entire `pdfium` R API surface. New code uses checkmate
from the first line; existing wrappers are migrated incrementally
under a single follow-up PR.

Concretely:

1. Move `checkmate` from `Suggests` (or no listing at all) to a
   first-class `Imports:` entry in `DESCRIPTION`.
2. Replace hand-rolled `validate_*` helpers in `R/utils.R` with
   direct `checkmate::assert_*` calls at each call site.
3. The shared helper file `R/utils.R` keeps small pdfium-specific
   wrappers only for assertions that have no clean checkmate
   single-call equivalent (e.g. "must be `pdfium_page` OR
   `pdfium_doc`", "must be an open page handle"). Those wrappers
   internally call `checkmate::assert_*` for the shape parts.
4. New code uses `checkmate::assert_*` (not `test_*` or `check_*`)
   so the failure mode is `stop()`-style and matches the rest of
   the R-side error contract.
5. `cyclocomp_linter` warnings on validation-heavy wrappers
   disappear, because each `assert_*` call is one branch instead
   of three or four chained boolean checks.

The migration is done in **one separate PR** after PR-23 lands.
That PR's scope is purely "refactor validation":

- Single commit per module group (e.g. `R/glyph_paths.R` +
  `R/annot_probes.R` + `R/tier3_extras.R`, `R/render.R` + `R/page.R`
  + `R/page_extras.R`, etc.).
- No public-API changes, no test behavior changes (error messages
  may shift slightly; existing `expect_error(..., regexp = ...)`
  patterns get re-targeted onto checkmate's standardised
  wording).
- Drops the hand-rolled `validate_*` helpers from `R/utils.R`
  (they'd become trivial one-line wrappers over `checkmate`, so we
  inline at the call site).

## Consequences

**Pros:**

- One CRAN dependency for argument validation across the package.
  Familiar to most R contributors; documented at
  <https://mllg.github.io/checkmate/>.
- Error messages are uniform: `assert_count(x, positive = TRUE)`
  produces `` "Assertion on 'x' failed: Must be a positive
  integerish value..." `` regardless of where it's called from.
- Composability via `assert_multi_class`, `assert_named`,
  `assert_subset`, and friends covers the patterns we kept
  hand-rolling.
- Tested at scale (the `mlr3` ecosystem leans on it). Fewer
  package-local bugs around the validation boundary.
- Vectorised assertions land naturally — important for the v0.2.0
  writer surface where setters may accept whole tibble columns.

**Cons:**

- One more `Imports:` entry. checkmate has no compiled code and
  no transitive deps beyond `backports`, so the install-time cost
  is negligible (<200 KB) and CRAN-policy-clean.
- One-time test-suite churn to update `expect_error(regexp = ...)`
  matchers to checkmate's wording. Bounded — every error message
  the package emits via the old `validate_*` helpers will need a
  one-line `regexp` update.
- A small philosophy shift in the C++ comments: instead of
  "R wrapper validated with `validate_positive_int`", they say
  "R wrapper validated with `checkmate::assert_count`".

**Operational guidance** (added to CLAUDE.md):

- All new R-side validation **must** use `checkmate::assert_*`
  unless explicitly justified in the function's roxygen.
- Error-message regexes in tests should match on the
  argument-name portion of the checkmate message (e.g.
  `"Assertion on 'x' failed"`) rather than the exact phrasing,
  so checkmate updates don't churn the test suite.
- The C++ layer's comment contract is unchanged: "arguments
  already validated upstream; raise only on invariants."

## Alternatives considered

- **`assertthat`** — also widely used, but less actively
  maintained, and missing some of checkmate's richer assertions
  (named-list shape, subset / membership without piping). The
  tidyverse itself has moved away from `assertthat` for new code.
- **`rlang::abort()` with hand-rolled checks per file** —
  what we have today. Cyclocomp issues recur; error messages
  drift. Status quo doesn't scale to the v0.2.0 writer surface
  (which adds ≈ 30 setter functions, each with its own argument
  validation).
- **A pdfium-internal validation DSL** — over-engineering.
  checkmate already provides what we'd build, with a more mature
  user base.
- **No validation library, just inline `stopifnot()`** — too
  terse for CRAN-grade error messages and doesn't compose for
  the multi-condition cases. Was rejected during ADR-004
  (API style).

## References

- checkmate package: <https://mllg.github.io/checkmate/>
- CRAN page: <https://cran.r-project.org/package=checkmate>
- Source: <https://github.com/mllg/checkmate>
- The pre-checkmate utilities this ADR retires:
  `R/utils.R::validate_positive_int` /
  `validate_nonempty_char` / `validate_finite_numeric`.
- Migration tracking: a follow-up PR (titled
  `refactor(validation): adopt checkmate package-wide`) lands
  after PR-23.
