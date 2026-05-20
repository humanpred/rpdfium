# Reorder pages

Wraps `FPDF_MovePages`. Either passes a full permutation of
`seq_len(pdf_page_count(doc))` as `new_order` (the document is reordered
in place to that permutation), or moves a contiguous set of pages to a
new position via `move_pages` + `dest`.

## Usage

``` r
pdf_pages_reorder(doc, new_order = NULL, move_pages = NULL, dest = NULL)
```

## Arguments

- doc:

  A read-write `pdfium_doc`.

- new_order:

  Integer vector. A full permutation of `1:pdf_page_count(doc)`.

- move_pages:

  Integer vector of 1-based source page indices to move (ignored when
  `new_order` is supplied).

- dest:

  One-based destination index for the moved pages (ignored when
  `new_order` is supplied).

## Value

Invisibly returns `doc`.
