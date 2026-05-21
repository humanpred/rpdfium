# Create a closed rectangle path on a page

Wraps `FPDFPageObj_CreateNewRect` + `FPDFPage_InsertObject`. The new
path describes the rectangle `(x, y, x + width, y + height)` with an
explicit close — it renders as a stroked / filled rectangle once you set
its draw mode and colors.

## Usage

``` r
pdf_rect_new(page, x, y, width, height)
```

## Arguments

- page:

  A `pdfium_page` from
  [`pdf_page_load()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_load.md).
  Parent doc must be readwrite.

- x, y:

  Numeric scalars — bottom-left corner in PDF user-space points.

- width, height:

  Numeric scalars — rectangle dimensions.

## Value

The new `pdfium_obj` (type `"path"`), inserted on the page.

## See also

[`pdf_path_new()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_new.md),
[`pdf_path_set_draw_mode()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_set_draw_mode.md),
[`pdf_path_set_fill()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_set_fill.md).
