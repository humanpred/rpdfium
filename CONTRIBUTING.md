# Contributing to pdfium

Thanks for your interest in contributing.

## Quick start

```sh
git clone https://github.com/humanpred/rpdfium
cd rpdfium

# Install Python pre-commit (one-time, per clone)
pip install --user pre-commit
pre-commit install
pre-commit install --hook-type pre-push

# Install R dev dependencies
Rscript -e 'install.packages(c("devtools","testthat","covr","lintr","styler","withr","roxygen2"))'

# Configure the package (downloads the bblanchon PDFium binary)
R CMD INSTALL .

# Run the test suite (parallel, per worker)
Rscript -e 'devtools::test()'
```

## Workflow

1. Create a feature branch (`claude/...` for AI-authored, `feature/...`
   otherwise) off `main`. **Never** push to `main` directly.
2. Make your change. Add or update tests for every behavioural change.
3. Run `pre-commit run --all-files` until it passes.
4. Run `devtools::check()` (or `R CMD check --as-cran .`) and confirm
   zero errors / zero warnings.
5. Run `covr::package_coverage()` and confirm R coverage stays at 100%.
   Untestable code paths must be marked `# nocov start` / `# nocov end`
   with a comment explaining why.
6. Push your branch and open a pull request using the template at
   `.github/PULL_REQUEST_TEMPLATE.md`.

## Commit messages

We follow [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: short summary in imperative mood

Optional longer body. Reference issues with "Closes #N".
```

Allowed types: `feat`, `fix`, `docs`, `chore`, `test`, `refactor`,
`perf`, `ci`, `build`, `style`, `revert`. Subject line under 70 chars.

## Architectural decisions

Material decisions (API shape, dependencies, binary distribution,
memory model) are recorded as Architecture Decision Records under
`dev/decisions/`. Use the template at
`dev/decisions/ADR-000-template.md`. ADRs are immutable once accepted
— supersede with a new ADR that references the old.

## Pre-commit fast / slow stages

The `.pre-commit-config.yaml` splits hooks into two stages:

- **`pre-commit`** runs on every `git commit`. Fast checks: lintr,
  styler, parsable-R, spell-check, header sanity. Optimized for tight
  feedback.
- **`pre-push`** runs only when you `git push`. Slower checks: roxygen
  regeneration, full lint, parallel testthat run. Slow enough that we
  don't want it on every commit but cheap enough to run before the
  branch leaves your machine.

If a `pre-push` hook fails, fix the issue and create a **new** commit
— don't `--amend` (that complicates code review).

## CRAN cleanliness

`pdfium` targets CRAN at v0.1.0 and stays CRAN-clean. Before merging:

- `R CMD check --as-cran` is green.
- No new internet calls happen during `R CMD check` (only at
  install-time `configure`).
- Examples run in under 5 seconds each.
- Any new `\dontrun{}` is justified in the PR description.
