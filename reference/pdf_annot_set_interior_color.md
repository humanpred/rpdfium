# Set the interior / fill color of an annotation

Wraps `FPDFAnnot_SetColor` with
`type = FPDFANNOT_COLORTYPE_InteriorColor`. Same composite shape as
[`pdf_annot_set_color()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_set_color.md);
auto-detects 0-255 vs 0-1 color form.

## Usage

``` r
pdf_annot_set_interior_color(
  annot,
  color = NULL,
  red = NULL,
  green = NULL,
  blue = NULL,
  alpha = NULL
)
```

## Arguments

- annot:

  A `pdfium_annot` handle. Parent doc must be readwrite.

- color:

  Length-3 (RGB) or length-4 (RGBA) numeric vector, or `NULL` to keep
  the current color and rely on the per-channel overrides.

- red, green, blue, alpha:

  Individual channel overrides.

## Value

Invisibly returns the parent `pdfium_doc`.

## See also

[`pdf_annot_interior_color()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_interior_color.md),
[`pdf_annot_set_color()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_set_color.md).
