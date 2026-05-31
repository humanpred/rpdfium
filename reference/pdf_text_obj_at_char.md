# Look up the text page-object owning a given char by direct accessor

Wraps `FPDFText_GetTextObject`. Returns a `pdfium_obj` of type `"text"`
for the page-object that contains the character at the given 1-based
`char_index` on the page's text page (matching the `char_index` column
of
[`pdf_text_chars()`](https://humanpred.github.io/rpdfium/reference/pdf_text_chars.md)).
Returns `NULL` when the char has no associated page-object (e.g.
PDFium-synthesised whitespace).

## Usage

``` r
pdf_text_obj_at_char(page, char_index, page_num = 1L)
```

## Arguments

- page:

  A `pdfium_page` from
  [`pdf_page_load()`](https://humanpred.github.io/rpdfium/reference/pdf_page_load.md),
  or a `pdfium_doc`.

- char_index:

  One-based character index (matches `pdf_text_chars()$char_index`).

- page_num:

  One-based page index. Only used when `page` is a `pdfium_doc`. Ignored
  otherwise.

## Value

A `pdfium_obj` of type `"text"`, or `NULL` when the char has no
associated page-object.

## Details

Functionally equivalent to chaining
`pdf_text_char_obj_index() -> pdf_page_objects()[[i]]`, but
short-circuited through PDFium's direct accessor so callers don't have
to enumerate every page-object.

## See also

[`pdf_text_char_obj_index()`](https://humanpred.github.io/rpdfium/reference/pdf_text_char_obj_index.md)
for the index-only version,
[`pdf_text_chars()`](https://humanpred.github.io/rpdfium/reference/pdf_text_chars.md)
for per-character readouts.

## Examples

``` r
fixture <- system.file("extdata", "fixtures", "shapes.pdf",
  package = "pdfium"
)
if (nzchar(fixture)) {
  doc <- pdf_doc_open(fixture)
  page <- pdf_page_load(doc, 1L)
  # Text page-object owning the first character on the page.
  obj <- pdf_text_obj_at_char(page, char_index = 1L)
  if (!is.null(obj)) pdf_obj_bounds(obj)
  pdf_page_close(page)
  pdf_doc_close(doc)
}
```
