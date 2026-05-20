# Font metadata of a text page-object

Returns the font properties PDFium exposes for `obj`'s text: the base
font name (e.g. "Helvetica-Bold"), the family name (e.g. "Helvetica"),
weight (typographic weight integer, 400 = regular, 700 = bold), italic
angle in degrees (negative for italic slant), whether the font is
embedded in the PDF, and the PDF font-descriptor flags bitmask (see PDF
spec section "Font Descriptors", Table 123).

## Usage

``` r
pdf_text_font(obj)
```

## Arguments

- obj:

  A `pdfium_obj` of type `"text"` (from
  [`pdf_page_objects()`](https://humanpred.github.io/rpdfium/reference/pdf_page_objects.md)).

## Value

A named list with elements (matching the `font_*` columns that
[`pdf_text_runs()`](https://humanpred.github.io/rpdfium/reference/pdf_text_runs.md)
returns for the same text object, so either shape can feed directly into
a row of the other):

- `font_base_name` - character scalar, base font name; UTF-8

- `font_family` - character scalar, font family name; UTF-8

- `font_weight` - integer (e.g. 400, 500, 700)

- `font_italic_angle` - integer degrees; 0 for upright

- `font_is_embedded` - logical

- `font_flags` - integer bitmask

## Details

If the text object has no font set (rare; usually only for malformed
PDFs), every field is `NA`.

## See also

[`pdf_text_content()`](https://humanpred.github.io/rpdfium/reference/pdf_text_content.md),
[`pdf_text_runs()`](https://humanpred.github.io/rpdfium/reference/pdf_text_runs.md),
[`pdf_text_font_size()`](https://humanpred.github.io/rpdfium/reference/pdf_text_font_size.md)

## Examples

``` r
fixture <- system.file("extdata", "fixtures", "shapes.pdf",
  package = "pdfium"
)
if (nzchar(fixture)) {
  doc <- pdf_open(fixture)
  p <- pdf_load_page(doc, 1)
  text_obj <- Filter(\(o) o$type == "text", pdf_page_objects(p))[[1]]
  pdf_text_font(text_obj)
  pdf_close_page(p)
  pdf_close(doc)
}
```
