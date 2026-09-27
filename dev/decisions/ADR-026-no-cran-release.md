# ADR-026 — No CRAN release; keep CRAN quality, distribute through r-universe

- Status: Supersedes ADR-008's release targeting (its quality constraints stay in force) and ADR-003's CRAN-submission wording
- Date: 2026-09-27
- Deciders: Bill Denney

## Context

ADR-008 decided that `pdfium` would ship to CRAN at v0.1.0 and derived
a set of quality constraints from that target. Version 0.1.0 was
submitted on 2026-05-31 (commit `e121bc9`, recorded in a
`CRAN-SUBMISSION` file) and never published on CRAN: CRAN has neither a
package page nor an archive entry for `pdfium`.

On 2026-09-27 the maintainer decided that `pdfium` is not likely ever
to go to CRAN, and that the package should still be held to CRAN
quality: "While we are not planning to target an actual CRAN release,
we do want to target CRAN quality, so many of the ADR-008 parts are
likely to be kept."

Users still need a way to install the package, preferably without a
compiler. `dev/r-universe-evaluation.md` evaluated r-universe for that
role and found it a fit. Its builders can run the configure-time
PDFium download that ADR-003 relies on, and the binary packages they
produce already carry `libpdfium`.

## Decision

1. **No CRAN release.** Release and submission material is removed:
   `CRAN-SUBMISSION` and `cran-comments.md` are deleted. User-facing
   and contributor docs no longer say the package ships to, or installs
   from, CRAN.

2. **The CRAN quality bar stays** as the package's own standard. These
   ADR-008 constraints remain in force:
   - `R CMD check --as-cran` is clean. This is gated in
     `R-CMD-check.yaml`, with a weekly check on CRAN's platforms
     (`cran-check.yaml`).
   - The source tarball stays small. The PDFium binary is downloaded at
     install time by `configure` and never vendored (ADR-003).
   - Tests and examples make no network calls. Conformance comparisons
     stay opt-in.
   - Examples run in 5 seconds or less.
   - Examples and tests write only inside `tempdir()`.
   - No `\dontrun{}` without a stated justification.
   - R coverage stays gated at 100% (ADR-007).
   - The `PDFIUM_OFFLINE=1` path, with a vendored archive, stays, now
     justified by offline and firewalled installs rather than by CRAN's
     build farm.

3. **Distribution.**
   - Source: from GitHub, `remotes::install_github("humanpred/rpdfium")`.
   - Binaries: from r-universe at `https://humanpred.r-universe.dev`,
     once the owner has set up the registry (the steps are in
     `dev/r-universe-evaluation.md`). r-universe builds each platform
     from the tracked Git ref with our own `configure`, so there is no
     separate binary release pipeline to maintain.
   - Releases are GitHub releases. Whether r-universe follows `main` or
     the latest release is the owner's choice (evaluation, step 1).

4. **Reading the accepted ADRs.** Accepted ADRs are not edited.
   - Where ADR-001, ADR-002, ADR-003, ADR-006, ADR-007, ADR-010 and
     ADR-020 cite CRAN policy, those citations still describe the
     quality bar.
   - Where they speak of a CRAN release or submission, CRAN reviewers,
     or `cran-comments.md`, read "release" instead: a GitHub release,
     built by r-universe. This covers ADR-003's Consequences, ADR-007's
     "before submission" and ADR-020 §8 and §11.
   - ADR-020 §8's release gate (every phase landed and the API gap
     audit clean) is otherwise unchanged. ADR-020 §11's deprecation
     cadence applies from the first published release.

## Consequences

- There is no submission overhead: no `cran-comments.md`, no reviewer
  round-trips, and no dependence on CRAN's view of configure-time
  downloads. We control the release cadence.
- The quality bar does not relax. Our CI stays the gate. r-universe
  runs its own `R CMD check` on every build, but not with `--as-cran`,
  and it publishes binaries whatever the check result.
- Users need an extra `repos` entry. `install.packages("pdfium")` on
  its own finds nothing.
- r-universe binary packages contain `libpdfium`, so we now
  redistribute PDFium in binary form. The installed package must carry
  PDFium's licence notices, and today it doesn't
  (`tools/download-pdfium.R` drops the archive's `LICENSE` and
  `licenses/`). That has to be fixed before the first binary is
  published.
- r-universe has known platform gaps. WebAssembly can't be built,
  because no PDFium build exists that a webR package can link. Windows
  arm64 will fail until `tools/download-pdfium.R` finds the aarch64
  `dlltool`.
- Packages on CRAN can list `pdfium` only in `Suggests`, together with
  `Additional_repositories`.
- If a CRAN release is ever reconsidered, the package is still held to
  CRAN's bar, so a new ADR superseding this one would be enough.

## Alternatives considered

- **Keep targeting CRAN (ADR-008 as written).** Rejected by the
  maintainer's decision.
- **Drop the CRAN quality bar along with the CRAN target.** Rejected:
  the maintainer wants CRAN quality. The constraints also keep r-universe
  builds reproducible, for example tests that never need the network.
- **GitHub source installs only.** Viable, and still offered for the
  development version. But every user then compiles the package and
  downloads PDFium at install time. r-universe adds binaries at no cost.
- **R-multiverse** (curated releases on r-universe infrastructure).
  Possible later; not needed to get binaries to users.
- **A self-hosted CRAN-like repository.** It would reproduce what
  r-universe provides, at our own maintenance cost.

## References

- ADR-003 (binary distribution), ADR-006 (PDFium pin), ADR-007 (CI and
  coverage), ADR-008 (CRAN-from-v0.1.0 hardening), ADR-020 §8 and §11
- [`dev/r-universe-evaluation.md`](../r-universe-evaluation.md)
- [Set up your own universe](https://docs.r-universe.dev/publish/set-up.html) (r-universe documentation)
- [CRAN Repository Policy](https://cran.r-project.org/web/packages/policies.html), still the reference for the quality bar
