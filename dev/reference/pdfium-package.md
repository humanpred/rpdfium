# pdfium: Idiomatic R Bindings to the PDFium PDF Engine

Read PDF documents at the level of pages, page objects, and path
geometry using Google's PDFium engine. Surfaces path segments, stroke
and fill style, transformation matrices, text positions and content,
font metadata, image metadata, and page rendering.

## Where to start

Open a document with
[`pdf_doc_open()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_open.md)
and inspect basic facts with
[`pdf_page_count()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_count.md).
Higher-level helpers (path extraction, text runs, rendering) arrive in
subsequent releases.

## Binary distribution

The underlying `libpdfium` shared library is downloaded from
[bblanchon/pdfium-binaries](https://github.com/bblanchon/pdfium-binaries)
the first time the package is installed. The pinned version lives in
`tools/pdfium-version.txt`.

## See also

Useful links:

- <https://github.com/humanpred/rpdfium>

- <https://humanpred.github.io/rpdfium/>

- Report bugs at <https://github.com/humanpred/rpdfium/issues>

## Author

**Maintainer**: Bill Denney <wdenney@humanpredictions.com>
([ORCID](https://orcid.org/0000-0002-5759-428X))

Authors:

- Bill Denney <wdenney@humanpredictions.com>
  ([ORCID](https://orcid.org/0000-0002-5759-428X))

Other contributors:

- The PDFium Authors (Authors of bundled PDFium binaries (BSD-3-Clause))
  \[copyright holder\]
