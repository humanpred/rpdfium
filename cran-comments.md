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
  downloading.** Selection order, on POSIX:

      1. PDFIUM_HOME env var pointing at a usable install
      2. pkg-config --exists libpdfium
      3. /usr/local, /usr, /opt/homebrew, /opt/local

  Only if none of those resolve does it fall back to the
  bblanchon binary download. `configure.win` honors
  PDFIUM_HOME similarly (Windows has no canonical system
  install location, so it does not guess).

## NOTE we cannot eliminate

* **"Found '\_exit' / 'abort' / 'exit'" in `pdfium.dll`** — the
  flagged DLL is the package's own compiled Rcpp library, not
  the upstream binary. Our C/C++ source contains zero direct
  calls to these functions (all error paths use `Rcpp::stop()`).
  They are imports of `api-ms-win-crt-runtime-l1-1-0.dll` (the
  Windows Universal CRT) pulled in by the MinGW-w64 startup
  machinery that Rtools links into every shared object:

      libmingw32.a   references abort  (CRT init,
                                        __cxa_terminate handler)
      libmingwex.a   references _exit
      libucrt.a      references _exit

  We added `-ffunction-sections -fdata-sections
  -Wl,--gc-sections` to strip dead code from our own
  compilation units, but the residual references survive
  because they are needed by Rtools' own static runtime, not
  by our code. Removing them would require rebuilding
  Rtools/MinGW itself. CRAN's own NOTE text acknowledges this
  case: *"The detected symbols are linked into the code but
  might come from libraries and not actually be called."*
