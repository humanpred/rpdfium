# Direct marked-content ID for a page object

Fast-path single-integer accessor that wraps
`FPDFPageObj_GetMarkedContentID`. Equivalent to taking
[`pdf_obj_marks()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_obj_marks.md)
and pulling out the first integer `MCID` parameter, but avoids the
tibble materialisation when the caller only needs the ID.

## Usage

``` r
pdf_obj_marked_content_id(obj)
```

## Arguments

- obj:

  A `pdfium_obj` from
  [`pdf_page_objects()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_objects.md).

## Value

Integer scalar — the 0-based marked-content ID, or `NA_integer_` when
the object has no direct MCID.

## See also

[`pdf_obj_marks()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_obj_marks.md),
[`pdf_structure_tree()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_structure_tree.md).
