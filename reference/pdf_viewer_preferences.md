# Read the document's viewer preferences

Returns the print-related preferences encoded in the PDF's
ViewerPreferences dictionary: whether the viewer should honor the
author's print scaling, the suggested number of copies, the
paper-handling (duplex) option, and the print-page-range specification.
Wraps the `FPDF_VIEWERREF_*` family.

## Usage

``` r
pdf_viewer_preferences(doc, password = NULL)
```

## Arguments

- doc:

  A `pdfium_doc` from
  [`pdf_open()`](https://humanpred.github.io/rpdfium/reference/pdf_open.md),
  or a character path.

- password:

  Optional password for encrypted PDFs when `doc` is a path. Ignored
  when `doc` is already an open `pdfium_doc`.

## Value

A named list with:

- `print_scaling` (logical) — TRUE if the author wants the viewer's
  print dialog to use its default scaling.

- `num_copies` (integer) — suggested copies; 1 if not set.

- `duplex` (character) — one of `"none"`, `"simplex"`,
  `"duplex_flip_short_edge"`, `"duplex_flip_long_edge"`.

- `print_page_ranges` (integer) — 1-based page numbers the author
  suggests printing; empty when unspecified.

## Details

Most PDFs don't set these; the returned defaults are PDFium's "no
preference" sentinels: `print_scaling = TRUE`, `num_copies = 1`,
`duplex = "none"`, `print_page_ranges` empty.
