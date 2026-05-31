# Set the appearance stream content for an annotation

Wraps `FPDFAnnot_SetAP`. Replaces the annotation's `/AP`
appearance-stream entry for the named mode with the given content
string. Pass `""` to clear the entry.

## Usage

``` r
pdf_annot_set_appearance(annot, mode = "normal", value = "")
```

## Arguments

- annot:

  A `pdfium_annot`.

- mode:

  Character scalar — one of `"normal"`, `"rollover"`, or `"down"`.

- value:

  Character scalar — the appearance-stream content. The empty string
  clears the entry.

## Value

Invisibly returns the parent `pdfium_doc`.

## See also

[`pdf_annot_appearance()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_appearance.md)
for the reader counterpart.
