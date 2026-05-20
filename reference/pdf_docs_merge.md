# Merge documents into a new PDF

Concatenates the pages of one or more source documents into a fresh
`pdfium_doc`, then optionally saves to `file`. Wraps
`FPDF_CreateNewDocument` + `FPDF_ImportPagesByIndex` per source.

## Usage

``` r
pdf_docs_merge(docs, file = NULL)
```

## Arguments

- docs:

  A list of `pdfium_doc` objects, or a character vector of paths. Mixed
  lists are also accepted.

- file:

  Destination path. If `NULL` (default), the merged document is returned
  without saving.

## Value

When `file` is non-NULL, invisibly returns `file`. When `file` is NULL,
returns the merged `pdfium_doc`.

## Details

Source documents are not modified. The returned doc is read-write.
