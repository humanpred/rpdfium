# pdfium 0.1.0 — first CRAN submission

## Summary

`pdfium` provides idiomatic R bindings to Google's 'PDFium' PDF
engine via Rcpp. It exposes more of a PDF's internals — vector-
path geometry, annotations, form fields, attachments,
signatures, structure tree, named destinations, viewer
preferences, and a focused mutation surface — than any other R
package on CRAN today.

## Resubmission — addressing prior reviewer feedback

* **Single-quoted 'PDFium'** in the Title and Description
  fields of DESCRIPTION.

* **`configure` prefers an existing system libpdfium before
  downloading.** On POSIX, the selection order is:

      1. PDFIUM_HOME env var pointing at a usable install
      2. pkg-config --exists libpdfium
      3. /usr/local, /usr, /opt/homebrew, /opt/local

  Only if none of those resolve does it fall back to the
  bblanchon binary download. `configure.win` honors
  PDFIUM_HOME similarly (Windows has no canonical system
  install location, so it does not guess).

* **`_exit` / `abort` / `exit` symbols** — root cause
  identified and fixed. `tools::check_compiled_code()` on
  Windows reads `libs/<arch>/symbols.rds` (an R-generated
  per-`.o`-file symbol table) when `_R_SHLIB_BUILD_OBJECTS_SYMBOL_TABLES_=TRUE`
  (which CRAN sets). Without that file installed alongside
  the package's DLL, the check falls back to scanning the
  DLL's import table — which on every Rtools/MinGW-built
  Windows shared library imports `_exit`/`abort`/`exit` from
  the Universal CRT (libgcc / libstdc++ / libmingw32.a all
  reference them from their runtime/terminate machinery,
  whether or not the user's code calls them). The package's
  own compiled `.o` files contain zero references to these
  symbols (verified with `nm --undefined-only` on a
  production build).

  This package ships an `install.libs.R` script that replaces
  R's default install logic for `src/*.so/.dll`. The previous
  version did not propagate `src/symbols.rds` into the
  installed `libs/<arch>/`. The fix in this submission copies
  `symbols.rds` when present, restoring the behaviour R
  performs by default for packages without a custom
  `install.libs.R`. With `symbols.rds` in place,
  `tools::check_compiled_code()` returns no findings on the
  installed package.
