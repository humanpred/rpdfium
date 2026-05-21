# Font size of a text page-object

Returns the typographic ("em") font size, in PDF points, set on the text
object. This is the raw size stored in the PDF; it is NOT scaled by the
object's transformation matrix. PDF producers often emit text at em-size
`1` and let the CTM do the scaling (Cairo's PDF backend works that way).
To recover the on-page rendered size, multiply this value by the y-scale
of the object's matrix (the matrix accessor lands in a later phase).

## Usage

``` r
pdf_text_font_size(obj)
```

## Arguments

- obj:

  A `pdfium_obj` of type `"text"` (from
  [`pdf_page_objects()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_objects.md)).

## Value

Numeric scalar in PDF points, or `NA_real_` if PDFium reports no font
size (rare; usually only for malformed PDFs).

## See also

[`pdf_page_objects()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_objects.md)

## Examples

``` r
fixture <- system.file("extdata", "fixtures", "shapes.pdf",
  package = "pdfium"
)
if (nzchar(fixture)) {
  doc <- pdf_doc_open(fixture)
  p <- pdf_page_load(doc, 1)
  text_obj <- Filter(\(o) o$type == "text", pdf_page_objects(p))[[1]]
  pdf_text_font_size(text_obj)
  pdf_page_close(p)
  pdf_doc_close(doc)
}
```
