# Read the document's PageMode entry from its catalog

The PageMode tells a PDF viewer how to display the document on open:
just the content, the outline panel beside it, the thumbnails panel,
full-screen, the optional-content panel, or the attachments panel. Wraps
`FPDFDoc_GetPageMode`.

## Usage

``` r
pdf_doc_page_mode(doc, password = NULL)
```

## Arguments

- doc:

  A `pdfium_doc` from
  [`pdf_doc_open()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_open.md),
  or a character path.

- password:

  Optional password for encrypted PDFs when `doc` is a path. Ignored
  when `doc` is already an open `pdfium_doc`.

## Value

Character scalar - one of `"use_none"`, `"use_outlines"`,
`"use_thumbs"`, `"full_screen"`, `"use_oc"` (optional-content panel),
`"use_attachments"`, or `"unknown"` (PDFium couldn't determine the
entry).
