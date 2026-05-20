# Delete a page from the document

Wraps `FPDFPage_Delete`. Removes the page at `page_num` from the
document. Subsequent page numbers shift down by one.

## Usage

``` r
pdf_page_delete(doc, page_num)
```

## Arguments

- doc:

  A read-write `pdfium_doc`.

- page_num:

  One-based page index to delete.

## Value

Invisibly returns `doc`.

## Details

Takes a `pdfium_doc` (not a `pdfium_page` — once you delete a page, any
loaded handle to it is invalid).
