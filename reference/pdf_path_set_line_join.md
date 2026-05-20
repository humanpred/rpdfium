# Set the line join style of a path stroke

Wraps `FPDFPageObj_SetLineJoin`. Allowed values: `"miter"`, `"round"`,
`"bevel"`.

## Usage

``` r
pdf_path_set_line_join(obj, join)
```

## Arguments

- obj:

  A `pdfium_obj` of type `"path"`. Parent doc must be readwrite.

- join:

  Character scalar; one of `"miter"`, `"round"`, `"bevel"`.

## Value

Invisibly returns the parent `pdfium_doc`.

## See also

[`pdf_path_line_join()`](https://humanpred.github.io/rpdfium/reference/pdf_path_line_join.md).
