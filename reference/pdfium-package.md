# pdfium: Idiomatic R Bindings to the PDFium PDF Engine

Read PDF documents at the level of pages, page objects, and path
geometry using Google's PDFium engine. Surfaces path segments, stroke
and fill style, transformation matrices, text positions and content,
font metadata, image metadata, and page rendering.

## Where to start

Open a document with
[`pdf_doc_open()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_open.md)
and inspect basic facts with
[`pdf_page_count()`](https://humanpred.github.io/rpdfium/reference/pdf_page_count.md).
Higher-level helpers (path extraction, text runs, rendering) arrive in
subsequent releases.

## Binary distribution

At install time, the `configure` script picks a `libpdfium` to build
against, in this order:

1.  The `PDFIUM_HOME` environment variable, if it points at a directory
    containing `include/fpdfview.h` and a `libpdfium` shared library
    (`lib/libpdfium.{so,dylib}` on POSIX, or `lib/libpdfium.dll.a` +
    `bin/libpdfium.dll` on Windows).

2.  `pkg-config --exists libpdfium` (POSIX only).

3.  Standard system prefixes: `/usr/local`, `/usr`, `/opt/homebrew`,
    `/opt/local` (POSIX only).

4.  Download from
    [bblanchon/pdfium-binaries](https://github.com/bblanchon/pdfium-binaries).
    The pinned release lives in `tools/pdfium-version.txt`. Set
    `PDFIUM_OFFLINE=1` and stage the tarball under
    `inst/pdfium-binaries/` for offline installs.

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
