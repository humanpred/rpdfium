# ADR-007 — CI and coverage policy

- Status: Accepted
- Date: 2026-05-15

## Context

`pdfium` mixes R, C++, and an external binary. Standard `usethis` CI
templates cover R-only packages; we need a richer matrix that catches:

- Cross-platform R CMD check failures (Linux / macOS / Windows × R
  release / devel / oldrel).
- Coverage regressions (the package targets 100% R coverage).
- C++ memory bugs the test suite alone won't catch (valgrind, ASan).
- Style and lint drift (lintr).
- CRAN-policy surprises before submission (rhub weekly).

Two operator preferences also shaped this: GitHub-only (no GitLab
mirror), and "fail fast on lint" — issues caught locally via
`pre-commit` are cheap; the same issues at CI cost minutes.

## Decision

Eight workflows under `.github/workflows/`:

| Workflow | Purpose | Gate? |
|---|---|---|
| `R-CMD-check.yaml`  | CRAN-style check on 5 OS/R combinations | Yes (0 errors / 0 warnings) |
| `coverage.yaml`     | `covr` → codecov; R lines only | Yes (project + patch 100%) |
| `lint.yaml`         | `lintr::lint_package()` mirror of pre-commit | Yes |
| `pre-commit.yaml`   | Full `pre-commit run --all-files` | Yes |
| `pkgdown.yaml`      | Build & deploy docs to `gh-pages` | No (deploy only on tag) |
| `cran-check.yaml`   | Weekly `rhub::check_for_cran()` | Yes (cron) |
| `valgrind.yaml`     | Weekly leak / memory-error check on Linux | Yes (cron) |
| `cpp-asan.yaml`     | AddressSanitizer + UBSan advisory build | No (continue-on-error) |

Configuration:

- **Coverage gate** is enforced via `codecov.yml` (`project.default` and
  `patch.default` both `target: 100%`). The `src/**` tree is
  `ignored` — C++ is tracked best-effort separately.
- **testthat parallelism** is on by default
  (`Config/testthat/parallel: true` in `DESCRIPTION`). The `valgrind`
  and `cpp-asan` workflows override this via `TESTTHAT_PARALLEL=false`
  because instrumented tests don't compose with parallel workers.
- **Branch protection**: `main` requires `R-CMD-check`, `coverage`,
  `lint`, and `pre-commit` to pass; expects approvals from one
  reviewer. (Configured outside-of-tree on the GitHub project itself
  since branch protection rules live in repo settings.)
- **C++ coverage** is captured by gcov and uploaded as a second
  codecov flag (`cpp`). It is *not* gated — best-effort tracking
  while we build it out.
- **Dependabot** runs weekly to upgrade GitHub Action versions; it
  does not touch CRAN deps.

## Consequences

- Six gates means we must keep workflow times reasonable. R CMD
  check takes the longest (~5 min per cell); parallel testthat keeps
  the inner loop fast.
- 100% R coverage requires every error branch to be tested. This is
  intentional — error handling is the most-bug-prone code and the
  most-skipped tests. Use `# nocov start` / `# nocov end` only with a
  comment explaining why.
- Coverage on `R/zzz.R` is tricky (it runs at package load before any
  test). We mark it `# nocov` and accept that the load itself is the
  test.
- Weekly rhub catches CRAN-platform surprises (Solaris, M1, devel)
  before submission. If a bump breaks one of those, we know early.

## Alternatives considered

- **A single mega-workflow.** Rejected — slow inner loop, harder to
  re-run a single failing check.
- **No coverage gate (advisory only).** Rejected — without the gate,
  coverage decays. The 100% target is enforced precisely so it
  doesn't.
- **Allow C++ coverage to gate too.** Rejected for v0.1.0 — gcov +
  Rcpp + downloaded library has rough edges; we don't want to block
  PRs on a moving target. Revisit when the C++ surface stabilizes.
- **GitLab mirror.** Rejected — the operator chose GitHub-only.
  Workflows reference `github.actions` / `gh-pages` directly without
  GitLab equivalents.

## References

- `codecov.yml` and `.pre-commit-config.yaml`
- [r-lib/actions](https://github.com/r-lib/actions) — the action suite
  used by every workflow.
- ADR-005 (memory model) — explains why valgrind matters.
