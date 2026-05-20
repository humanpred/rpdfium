# Read the logical page label of a PDF page

PDFs distinguish "physical" page numbers (1, 2, 3, ...) from "logical"
labels (e.g. "i", "ii", "iii" for front-matter then "1", "2", "3" for
the body, or "A-1", "A-2" for an appendix). Wraps `FPDF_GetPageLabel`.

## Usage

``` r
pdf_page_label(doc, page_num = 1L)
```

## Arguments

- doc:

  A `pdfium_doc` from
  [`pdf_doc_open()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_open.md),
  or a character path.

- page_num:

  One-based physical page index (default `1`).

## Value

Character scalar - the page's logical label, UTF-8 encoded. Empty string
when the PDF doesn't carry a labels table for this page (PDFium falls
back to the physical number's string form in some cases, but the
contract is "may be empty").

## See also

[`pdf_page_labels()`](https://humanpred.github.io/rpdfium/reference/pdf_page_labels.md)
for every page's label at once,
[`pdf_doc_bookmarks()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_bookmarks.md).
