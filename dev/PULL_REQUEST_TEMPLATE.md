# NA

## What changed

## Why

## Test coverage

Added or updated tests for every behavioural change.

R coverage remains 100% (verified locally with
[`covr::package_coverage()`](http://covr.r-lib.org/reference/package_coverage.md)).

If touching `src/`, the change runs cleanly under AddressSanitizer
(`.github/workflows/cpp-asan.yaml`) and valgrind
(`.github/workflows/valgrind.yaml`).

## API stability

No exported symbol was renamed or removed without a deprecation cycle.

If an exported function signature changed, an ADR was added or amended.

## Decision records

Linked an existing ADR if one applies.

Added a new ADR if this PR locks in a material architectural choice.

## Checklist

`pre-commit run --all-files` passes locally.

`R CMD check --as-cran` is clean (0 errors / 0 warnings).

Documentation regenerated with `devtools::document()`.

`NEWS.md` updated under “(development version)”.
