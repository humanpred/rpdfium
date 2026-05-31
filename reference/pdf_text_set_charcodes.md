# Populate a text object with explicit glyph charcodes

Wraps `FPDFText_SetCharcodes`. The standard
[`pdf_text_set_content()`](https://humanpred.github.io/rpdfium/reference/pdf_text_set_content.md)
maps UTF-8 text through the font's CMap to find glyph codes; this
lower-level setter takes the codes directly. Useful when the font's
encoding is non-standard or when the embedder already has the glyph
indices in hand (e.g. from a previous
[`pdf_text_runs()`](https://humanpred.github.io/rpdfium/reference/pdf_text_runs.md)
extraction).

## Usage

``` r
pdf_text_set_charcodes(obj, charcodes)
```

## Arguments

- obj:

  A `pdfium_obj` of `type = "text"`.

- charcodes:

  Integer vector of unsigned glyph codes. Negative values raise an
  error.

## Value

Invisibly returns the parent `pdfium_doc`.

## See also

[`pdf_text_set_content()`](https://humanpred.github.io/rpdfium/reference/pdf_text_set_content.md)
for the cmap-driven path.
