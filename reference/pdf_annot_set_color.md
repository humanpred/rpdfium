# Set the stroke / line color of an annotation

Wraps `FPDFAnnot_SetColor` with `type = FPDFANNOT_COLORTYPE_Color`.
Composite setter — pass `color = c(r, g, b)` (or `c(r, g, b, a)`) for a
full replacement, or individual `red` / `green` / `blue` / `alpha`
arguments for a partial overlay on the current color. 0-255 ints and 0-1
doubles are auto-detected per ADR-018 §5.

## Usage

``` r
pdf_annot_set_color(
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

[`pdf_annot_color()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_color.md),
[`pdf_annot_set_interior_color()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_set_interior_color.md).
