# Set the font size of a text page object

Wraps `FPDFTextObj_SetFontSize`: rewrites the size operand of the
object's `Tf` operator, so
[`pdf_text_font_size()`](https://humanpred.github.io/rpdfium/reference/pdf_text_font_size.md)
reads the new value back and the object renders at the new size. This is
distinct from scaling the object's matrix with
[`pdf_obj_set_matrix()`](https://humanpred.github.io/rpdfium/reference/pdf_obj_set_matrix.md),
which changes the rendered size but leaves the font size unchanged.

## Usage

``` r
pdf_text_set_font_size(obj, size)
```

## Arguments

- obj:

  A `pdfium_obj` of type `"text"`. Parent doc must be readwrite.

- size:

  Numeric scalar, the new font size in PDF points (1/72 inch). Must be
  non-negative; `0` is allowed, matching
  [`pdf_text_new()`](https://humanpred.github.io/rpdfium/reference/pdf_text_new.md).

## Value

Invisibly returns the parent `pdfium_doc`.

## See also

[`pdf_text_font_size()`](https://humanpred.github.io/rpdfium/reference/pdf_text_font_size.md).
