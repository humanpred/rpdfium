# Create a clip path covering a rectangle

Wraps `FPDF_CreateClipPath`. Returns a `pdfium_clip_box` handle that can
be inserted into a page via
[`pdf_page_insert_clip_path()`](https://humanpred.github.io/rpdfium/reference/pdf_page_insert_clip_path.md)
to restrict the page's rendered output to the given rectangle.

## Usage

``` r
pdf_clip_path_new(bounds)
```

## Arguments

- bounds:

  Numeric length-4 vector `c(left, bottom, right, top)` in PDF
  user-space points.

## Value

A `pdfium_clip_box` handle. The handle carries an `FPDF_DestroyClipPath`
finalizer; explicit
[`pdf_clip_path_close()`](https://humanpred.github.io/rpdfium/reference/pdf_clip_path_close.md)
is optional but useful for deterministic release.

## See also

[`pdf_page_insert_clip_path()`](https://humanpred.github.io/rpdfium/reference/pdf_page_insert_clip_path.md),
[`pdf_obj_transform_clip_path()`](https://humanpred.github.io/rpdfium/reference/pdf_obj_transform_clip_path.md),
[`pdf_page_transform_with_clip()`](https://humanpred.github.io/rpdfium/reference/pdf_page_transform_with_clip.md).

## Examples

``` r
if (FALSE) { # \dontrun{
doc <- pdf_doc_new()
page <- pdf_page_new(doc, width = 612, height = 792)
cp <- pdf_clip_path_new(c(72, 72, 540, 720))
pdf_page_insert_clip_path(page, cp)
pdf_save(doc, tempfile(fileext = ".pdf"))
} # }
```
