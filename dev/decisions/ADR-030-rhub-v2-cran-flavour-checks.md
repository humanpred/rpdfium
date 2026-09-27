# ADR-030 — Weekly CRAN-flavour checks with rhub v2

- Status: Supersedes ADR-007's `cran-check.yaml` row (weekly `rhub::check_for_cran()`)
- Date: 2026-09-27
- Deciders: Bill Denney

## Context

ADR-007 made a weekly `rhub::check_for_cran()` run, in
`.github/workflows/cran-check.yaml`, the check against CRAN's platforms.
rhub v2 made that function defunct. Every scheduled run failed with
"This function is deprecated and defunct since rhub v2" and then
"attempt to apply non-function": 19 of 19 runs up to 2026-09-21. The
job never checked anything.

`pdfium` is not released to CRAN (ADR-026) but keeps CRAN's quality
bar. CRAN checks packages on more than its main platforms: it also runs
sanitizer builds, rchk and a check without suggested packages.

rhub v2 runs these checks as a GitHub Actions workflow in the package's
own repository (`r-hub/actions`). It uses R-hub's containers for CRAN's
extra check flavours and GitHub's Windows and macOS runners for the
rest.

Our other CI already covers the following:

- `R-CMD-check.yaml` runs `--as-cran` and fails on warnings, on macOS
  arm64 R-release, Windows R-release, and Ubuntu R-devel, R-release and
  R-oldrel.
- `valgrind.yaml` gates leaks weekly and on pull requests that touch
  code.
- `cpp-asan.yaml` is advisory.

## Decision

1. **Replace `cran-check.yaml`** with R-hub's canonical
   `.github/workflows/rhub.yaml`, changed in three ways:
   - a weekly schedule, Mondays 04:17 UTC (the old job's slot);
   - `RHUB_WEEKLY_PLATFORMS`, the platform set used by scheduled runs
     and by manual runs whose `config` is empty;
   - `permissions: contents: read`.

   The file's header lists these changes, because `rhub::rhub_setup()`
   would overwrite them.

2. **The weekly platforms:**

   | Platform | CRAN check flavour | Why |
   |---|---|---|
   | `windows` | r-devel-windows-x86_64 | Our CI checks Windows on R-release only. |
   | `macos-arm64` | macOS arm64, R-devel | Our CI checks macOS on R-release only. |
   | `gcc-asan` | gcc-ASAN, gcc-UBSAN | R and the package built with gcc's AddressSanitizer and UBSan. Our own ASan job is advisory. |
   | `clang-asan` | clang-ASAN | clang's sanitizers, with CRAN's `ASAN_OPTIONS`. |
   | `rchk` | rchk | PROTECT bugs in our C++ glue around R objects. |
   | `nosuggests` | noSuggests | Tests and examples must run without suggested packages. |

3. **Other platforms are not in the weekly set.**
   - `valgrind`: `valgrind.yaml` already covers it.
   - `linux`, `ubuntu-release`, `ubuntu-gcc12`: `R-CMD-check.yaml`
     covers Ubuntu.
   - The per-compiler containers (`clang16`–`clang22`, `gcc13`–`gcc16`),
     `lto`, `intel`, `atlas`, `mkl`, `nold`, `noremap`, `c23`,
     `donttest` and `vnu` test concerns this package lacks: it has no C
     or Fortran code, no BLAS use and no `\donttest` examples. They
     remain available for manual runs.

4. **What fails the job.** R-hub's `run-check` action:
   - runs `R CMD check --as-cran` through
     `r-lib/actions/check-r-package`, which fails on any WARNING or
     ERROR;
   - on the sanitizer platforms, also fails on any UBSan
     `runtime error:`;
   - on `rchk`, fails on any `bcheck` error outside R-hub's short list
     of ignored messages.

## Consequences

- Six CRAN check flavours run every week, on free runner time for a
  public repository.
- The weekly set was checked locally in R-hub's containers on
  2026-09-27, against the code of `origin/main` at `b58fd55`:
  - `gcc-asan`: 0 test failures, no sanitizer reports, NOTEs only.
  - `clang-asan`: the same.
  - `rchk`: no errors after R-hub's filter.
  - `nosuggests`: an ERROR. The `pdf_image_extract()` example needs
    `png`, a suggested package, and does not check for it. That is the
    kind of issue this ADR is for, and the job stays red until the
    example is fixed.
  - `windows` and `macos-arm64` were not run locally. The first
    scheduled or manual run checks them.
- Every `--as-cran` run reports the "New submission" NOTE, because the
  package is not on CRAN. NOTEs do not fail the job.
- Ad hoc runs: use "Run workflow" on the Actions page (an empty
  `config` gives the weekly set) or `rhub::rhub_check()` from R. The
  latter needs a GitHub personal access token in the git credential
  store; `rhub::rhub_doctor()` checks the setup.
- `rhub::rhub_setup()` rewrites the file. Re-apply the three changes
  listed in its header after updating it.

## Alternatives considered

- **Keep `rhub::check_for_cran()`.** It is defunct.
- **Drop the weekly job and rely on `R-CMD-check.yaml` and r-universe.**
  Rejected: neither runs sanitizers, rchk or a no-Suggests check, and
  r-universe's check is not `--as-cran`.
- **Run these containers on every pull request.** Deferred. The
  sanitizer and rchk jobs are the slowest, and a weekly run is enough
  to catch regressions before a release. Revisit if a regression slips
  through between weekly runs.
- **Include `valgrind`.** It would duplicate `valgrind.yaml`, which
  already has a leak policy tuned to PDFium's known mismatched frees.

## References

- ADR-007 (CI and coverage), ADR-026 (no CRAN release; CRAN-quality
  bar)
- [R-hub v2 actions](https://github.com/r-hub/actions) and
  [containers](https://r-hub.github.io/containers/)
- CRAN's additional check flavours: <https://cran.r-project.org/web/checks/check_issue_kinds.html>
