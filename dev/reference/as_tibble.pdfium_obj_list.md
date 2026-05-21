# Tibble view of a `pdfium_obj_list`

Walks each page-object handle and reads its type, axis-aligned bounds,
transparency / active flags, and (for nested objects) parent-form index
into a tibble. Adds `handle` and `source` list-columns (ADR-017).

## Usage

``` r
# S3 method for class 'pdfium_obj_list'
as_tibble(x, ...)
```

## Arguments

- x:

  A `pdfium_obj_list` from
  [`pdf_page_objects()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_objects.md).

- ...:

  Unused (S3 generic compatibility).

## Value

A tibble with columns `object_index`, `type`, `bbox_left`,
`bbox_bottom`, `bbox_right`, `bbox_top`, `has_transparency`,
`is_active`, `parent_form_index`, `handle`, `source`.
