# Apply a transform to a page's content stream with an optional clip

Wraps `FPDFPage_TransFormWithClip`. The matrix is applied to the entire
page content; when `clip_rect` is supplied (length-4 numeric
`c(left, bottom, right, top)`), the page is clipped to that rectangle
after the transform.

## Usage

``` r
pdf_page_transform_with_clip(page, matrix, clip_rect = NULL, page_num = 1L)
```

## Arguments

- page:

  A `pdfium_page` or `pdfium_doc`.

- matrix:

  Numeric length-6 vector `c(a, b, c, d, e, f)`.

- clip_rect:

  Optional numeric length-4 vector `c(left, bottom, right, top)`. `NULL`
  means no clip.

- page_num:

  Used when `page` is a `pdfium_doc`.

## Value

Invisibly returns the parent `pdfium_doc`.
