# Set the line cap style of a path stroke

Wraps `FPDFPageObj_SetLineCap`. Allowed values: `"butt"`, `"round"`,
`"projecting_square"`.

## Usage

``` r
pdf_path_set_line_cap(obj, cap)
```

## Arguments

- obj:

  A `pdfium_obj` of type `"path"`. Parent doc must be readwrite.

- cap:

  Character scalar; one of `"butt"`, `"round"`, `"projecting_square"`.

## Value

Invisibly returns the parent `pdfium_doc`.

## See also

[`pdf_path_line_cap()`](https://humanpred.github.io/rpdfium/reference/pdf_path_line_cap.md).
