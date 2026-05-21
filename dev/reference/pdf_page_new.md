# Add a new blank page

Wraps `FPDFPage_New`. Inserts a new blank page of the given dimensions
at `page_num` (1-based). Existing pages at or above `page_num` shift
down by one.

## Usage

``` r
pdf_page_new(doc, page_num, width, height)
```

## Arguments

- doc:

  A read-write `pdfium_doc`.

- page_num:

  Insertion index, 1-based. Must satisfy
  `1 <= page_num <= pdf_page_count(doc) + 1`.

- width, height:

  Page size in PDF points (1 pt = 1/72 in). US Letter is `612, 792`; A4
  is `595, 842`.

## Value

A `pdfium_page` handle for the new page. (Unlike most mutators this
returns a page rather than the doc, because callers typically want to
add content to the page immediately.)
