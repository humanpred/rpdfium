# Create a new path page-object on a page

Wraps `FPDFPageObj_CreateNewPath` + `FPDFPage_InsertObject`. The new
path starts with an implicit MoveTo at `(x, y)`; build it up further
with
[`pdf_path_line_to()`](https://humanpred.github.io/rpdfium/reference/pdf_path_line_to.md)
/
[`pdf_path_bezier_to()`](https://humanpred.github.io/rpdfium/reference/pdf_path_bezier_to.md)
/
[`pdf_path_close()`](https://humanpred.github.io/rpdfium/reference/pdf_path_close.md),
then set styling via
[`pdf_path_set_stroke()`](https://humanpred.github.io/rpdfium/reference/pdf_path_set_stroke.md)
/
[`pdf_path_set_fill()`](https://humanpred.github.io/rpdfium/reference/pdf_path_set_fill.md)
/
[`pdf_path_set_draw_mode()`](https://humanpred.github.io/rpdfium/reference/pdf_path_set_draw_mode.md).

## Usage

``` r
pdf_path_new(page, x = 0, y = 0)
```

## Arguments

- page:

  A `pdfium_page` from
  [`pdf_page_load()`](https://humanpred.github.io/rpdfium/reference/pdf_page_load.md).
  Parent doc must be readwrite.

- x, y:

  Numeric scalars — starting point in PDF user-space points (origin at
  the page's bottom-left). Default `0, 0`.

## Value

The new `pdfium_obj` (type `"path"`), inserted on the page. The parent
page's dirty mark is set.

## See also

[`pdf_path_line_to()`](https://humanpred.github.io/rpdfium/reference/pdf_path_line_to.md),
[`pdf_rect_new()`](https://humanpred.github.io/rpdfium/reference/pdf_rect_new.md),
[`pdf_path_set_draw_mode()`](https://humanpred.github.io/rpdfium/reference/pdf_path_set_draw_mode.md).
