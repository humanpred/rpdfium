# pdfium 0.1.0 — first CRAN submission

## Summary

`pdfium` is a new R package providing idiomatic bindings to Google's
PDFium PDF engine via Rcpp. It complements `pdftools` (Poppler) and
`qpdf` (QPDF), filling two gaps no other CRAN package fills:

* **Vector-path geometry on read** — segment kinds, control points,
  stroke / fill style, transformation matrices, clip paths, blend
  modes — alongside text, fonts, images, annotations, form fields,
  attachments, signatures, structure tree, bookmarks, named
  destinations, and rendering. `pdf_extract_paths()` returns a
  tibble matching the schema kmextract's pypdfium2 backend ships
  today.
* **A focused mutation surface** opt-in via `readwrite = TRUE` on
  `pdf_doc_open()` (or `pdf_doc_new()` for fresh documents):
  structural mutation (page rotate / delete / reorder / merge /
  box / language), page-object styling setters, path-geometry
  rebuild, page-object creation (paths, rectangles, text, JPEG
  images), annotation authoring (14 supported subtypes), form
  filling + flattening, attachment authoring, plus standard-font
  and custom-font (TrueType / Type1) embedding. `pdf_save()`
  writes atomically.

Both halves are documented in pkgdown
(<https://humanpred.github.io/rpdfium/>) and exercised at 100% R
coverage in CI.

## Test environments

The R-CMD-check matrix in `.github/workflows/R-CMD-check.yaml`
covers:

* Ubuntu 24.04, R-release / R-devel / R-oldrel-1
* macOS-latest, R-release
* Windows-latest, R-release

`R CMD check --as-cran` locally on Ubuntu 24.04 with R 4.6.0:
0 ERRORs, 0 WARNINGs when `checkbashisms` is installed, 1 NOTE
(detailed below). The cross-platform CI matrix
(<https://github.com/humanpred/rpdfium/actions/workflows/R-CMD-check.yaml>)
is green on every cell on the head of `main`.

## Expected NOTEs

* **"Compilation used the following non-portable flag(s):
  '-mno-omit-leaf-frame-pointer'"** — inherited from the Debian /
  Ubuntu `r-base` package's default `CXX17FLAGS`. The pdfium
  package itself does not pass this flag in its `Makevars`; it
  appears only when R itself was built on Debian-family systems
  with that flag set in `etc/Makeconf`. No NOTE seen on
  macOS-latest or Windows-latest CI cells.

* **"Installed package size … Mb"** — *may appear* on systems
  where `inst/lib/libpdfium` ends up at 10–15 MB (the bundled
  libpdfium shared library). We download it at install time
  rather than shipping it in the source tarball, so the tarball
  itself is well under CRAN's 5 MB limit (~1 MB).

* **"GNU make is a SystemRequirements"** — *may appear* on
  platforms where the `configure` script triggers a GNU-make
  feature. The package declares `SystemRequirements: C++17,
  libpdfium (downloaded automatically at install time)` to make
  this explicit; the `configure` script downloads the matching
  bblanchon binary on demand and `cleanup` removes intermediate
  artefacts.

## Network access at install time

The `configure` (POSIX) and `configure.win` (Windows) scripts
fetch the bblanchon `libpdfium` binary on first install. The
script:

* Honors `CRAN_PDFIUM_OFFLINE=1` as a hard opt-out for the CRAN
  build farm.
* Falls back to a prepopulated `inst/pdfium-binaries/` directory
  when one is present.
* Errors with a clear message — and a `configure` exit code that
  surfaces in `install.packages()` — when the network is
  unavailable and no fallback is present.

The pinned release URL and SHA-256 live in
`tools/pdfium-version.txt`; any change to the pin requires a new
ADR entry under `dev/decisions/`. The download URL points at
GitHub releases (`https://github.com/bblanchon/pdfium-binaries/...`)
which is in CRAN's allowlist of acceptable fetch sources for
`arrow`, `duckdb`, and other binary-heavy packages.

No network access is required to run the package after install.
Tests use only the bundled fixtures under `inst/extdata/fixtures/`;
examples either use those fixtures or are wrapped in
`if (nzchar(fixture)) { ... }` so they no-op when the package is
not yet installed.

## Reverse dependencies

This is a first submission; there are no reverse dependencies
yet.

## Examples runtime

Every documented function has a runnable example. The longest
single example runs in under 200 ms on a 2024 Linux laptop;
the full `R CMD check` example pass completes in well under
60 seconds. No example uses `\dontrun{}`; all use
`if (nzchar(system.file(...))) { ... }` to no-op when the
fixture is missing.

## CRAN policy compliance checklist

* [x] No writes outside `tempdir()` and the package install
      directory.
* [x] No network access during `R CMD check` (download is at
      install time only; tests use bundled fixtures).
* [x] No `\dontrun{}` examples.
* [x] Examples runtime < 5 s each; full pass < 60 s.
* [x] No `<<-` writes to `.GlobalEnv` or anywhere outside the
      package namespace.
* [x] No interactive prompts at install or load time.
* [x] All Suggests packages are on CRAN and used via
      `requireNamespace()` / `skip_if_not_installed()` where
      appropriate.
* [x] Mutators require an explicit `readwrite = TRUE` opt-in on
      `pdf_doc_open()` so accidental edits inside a read-only
      pipeline raise a clear error rather than silently mutating
      the document.

## Licence

Package code: MIT (with file LICENSE).
Bundled `libpdfium` binary: BSD-3-Clause. The combined provenance
and per-file attribution live in `LICENSE.md`.
