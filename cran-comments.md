# pdfium 0.1.0 — first CRAN submission

## Summary

`pdfium` provides idiomatic R bindings to Google's PDFium PDF
engine via Rcpp. It exposes more of a PDF's internals — vector-
path geometry, annotations, form fields, attachments,
signatures, structure tree, named destinations, viewer
preferences, and a focused mutation surface — than any other R
package on CRAN today.

## NOTEs we cannot eliminate

* **"Possibly misspelled words in DESCRIPTION: PDFium"** —
  "PDFium" is the proper name of the upstream Google library
  this package wraps. It is already listed in `inst/WORDLIST`.

* **"Found '\_exit' / 'abort' / 'exit'" in `pdfium.dll`** — the
  flagged DLL is the package's own compiled Rcpp library. Our
  C/C++ source contains zero calls to these functions (all
  error paths use `Rcpp::stop()`). The symbols are linked in by
  the C/C++ runtime that Rtools statically attaches to every
  shared library (`libgcc` / `libstdc++` reference `abort()`
  from the default terminate handler) and via the import table
  for the upstream `libpdfium.dll` we link against. CRAN's own
  NOTE acknowledges this case: *"The detected symbols are
  linked into the code but might come from libraries and not
  actually be called."*
