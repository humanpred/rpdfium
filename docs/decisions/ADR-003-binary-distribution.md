# ADR-003 — Binary distribution

- Status: Accepted
- Date: 2026-05-15

## Context

The PDFium engine is ~10–15 MB per platform after linking. CRAN's
source-tarball limit is 5 MB and CRAN explicitly disallows binary
distribution inside source tarballs. We need a strategy that gives users
a working library on every platform without bloating the source.

The R ecosystem has precedent for this:

- [`arrow`](https://CRAN.R-project.org/package=arrow) downloads
  prebuilt Apache Arrow libraries via its `configure` script.
- [`stringi`](https://CRAN.R-project.org/package=stringi) downloads
  ICU data when system ICU is too old.
- [`pdftools`](https://CRAN.R-project.org/package=pdftools) relies on
  system-installed Poppler (`SystemRequirements: poppler`).

The "system-installed PDFium" path is unworkable for us: PDFium has no
distro packaging on Ubuntu/macOS/Windows, and Google does not publish
release tarballs. Our only realistic source of cross-platform binaries
is [`bblanchon/pdfium-binaries`](https://github.com/bblanchon/pdfium-binaries),
which automates the upstream build and publishes per-release tarballs.

## Decision

- `pdfium` downloads the `bblanchon/pdfium-binaries` archive at
  **install time** via `configure` (POSIX) / `configure.win` (Windows).
- The downloaded archive is extracted into `inst/include/` (headers)
  and `inst/lib/` (shared library, plus `inst/bin/pdfium.dll` on
  Windows).
- The pinned release tag lives in **`tools/pdfium-version.txt`**.
  Bumping this file = bumping PDFium (see ADR-006).
- Offline installs: setting `PDFIUM_OFFLINE=1` and providing the
  matching archive under `inst/pdfium-binaries/` skips the network
  call. Documented for corporate firewalls and CRAN's build farm if
  their policy ever changes.
- Linker integration:
  - POSIX: `configure` templates `src/Makevars` from
    `src/Makevars.in`, embedding an RPATH (`$ORIGIN/../lib` on Linux,
    `@loader_path/../lib` on macOS) so the installed `pdfium.so` finds
    `libpdfium` at load time without `LD_LIBRARY_PATH`.
  - Windows: `pdfium.dll` is placed in `inst/bin/` and loaded via
    `library.dynam()` from `R/zzz.R` before any FPDF call.
- A user-level cache directory (`tools::R_user_dir("pdfium",
  "cache")` by default; overridable via `PDFIUM_CACHE_DIR`) prevents
  repeated downloads across reinstalls.

## Consequences

- Users need internet at install time. We document the offline
  override and ship a clear error when both fail.
- We carry an implicit dependency on bblanchon's release cadence. If
  bblanchon stops publishing releases, we either vendor binaries
  ourselves or fall back to building PDFium from source (which is
  multi-hour and not feasible per-user). ADR-006 reviews this annually.
- CRAN's "downloads at install" precedent (`arrow`, `stringi`) means we
  expect this pattern to pass CRAN incoming. We will surface the
  network call in `cran-comments.md` at submission.
- Bug surface area: a corrupted download must fail cleanly with a
  reproducible error, not produce a half-installed package. The
  download script uses a sentinel filename and re-extracts atomically.

## Alternatives considered

- **Vendor binaries inside the source tarball.** Rejected — exceeds
  the CRAN 5 MB limit, requires shipping multiple architectures.
- **Build PDFium from source during install.** Rejected — PDFium's
  build system requires Chromium's `gn`+`ninja` toolchain plus a depot
  tools checkout; this would balloon install time from seconds to
  hours and is fragile across distros.
- **System dependency** (`SystemRequirements: libpdfium`). Rejected —
  no distro packages PDFium.
- **Two-package split** (`pdfium` data package + `pdfium` code
  package). Rejected — adds complexity for users with no upside;
  CRAN-friendly precedents already exist for download-at-install.

## References

- [bblanchon/pdfium-binaries](https://github.com/bblanchon/pdfium-binaries)
- [`arrow` `configure`](https://github.com/apache/arrow/blob/main/r/configure)
- [CRAN policies on system dependencies](https://cran.r-project.org/web/packages/policies.html)
