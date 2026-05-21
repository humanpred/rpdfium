# Stroke line-cap style of a path page-object

Returns the PDF line-cap style applied to a path's stroke. Maps to the
`LC` operand in the page content stream and corresponds to PDFium's
`FPDFPageObj_GetLineCap`.

## Usage

``` r
pdf_path_line_cap(obj)
```

## Arguments

- obj:

  A `pdfium_obj` of type `"path"` from
  [`pdf_page_objects()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_objects.md).

## Value

Character scalar; one of `"butt"` (square cap aligned with the stroke
endpoint, the PDF default), `"round"` (semicircular extension past the
endpoint), or `"projecting_square"` (square cap extending one
half-line-width past the endpoint).

## See also

[`pdf_path_line_join()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_line_join.md),
[`pdf_path_stroke()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_stroke.md).

## Examples

``` r
fixture <- system.file("extdata", "fixtures", "shapes.pdf",
  package = "pdfium"
)
if (nzchar(fixture)) {
  doc <- pdf_doc_open(fixture)
  p <- pdf_page_load(doc, 1)
  path_obj <- Filter(\(o) o$type == "path", pdf_page_objects(p))[[1]]
  pdf_path_line_cap(path_obj)
  pdf_page_close(p)
  pdf_doc_close(doc)
}
```
