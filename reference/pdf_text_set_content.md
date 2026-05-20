# Replace the text content of a text page object

Wraps `FPDFText_SetText`. Replaces whatever text the object carries with
`text` (UTF-8). PDFium re-encodes for the embedded font; characters the
font can't render fall back to the spec's substitution rules.

## Usage

``` r
pdf_text_set_content(obj, text)
```

## Arguments

- obj:

  A `pdfium_obj` of type `"text"`. Parent doc must be readwrite.

- text:

  Character scalar (UTF-8).

## Value

Invisibly returns the parent `pdfium_doc`.

## See also

[`pdf_text_content()`](https://humanpred.github.io/rpdfium/reference/pdf_text_content.md).
