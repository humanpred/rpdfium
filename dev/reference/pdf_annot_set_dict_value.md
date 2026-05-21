# Set an arbitrary string-valued entry on an annotation dict

Wraps `FPDFAnnot_SetStringValue` for callers that want to write a
specific `/key value` pair beyond the common `/Contents` / `/T` /
`/Subj` shortcuts. Symmetric with
[`pdf_annot_dict_value()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_dict_value.md)
for reading.

## Usage

``` r
pdf_annot_set_dict_value(annot, key, text)
```

## Arguments

- annot:

  A `pdfium_annot` handle. Parent doc must be readwrite.

- key:

  Character scalar — the PDF dictionary key (e.g. `"CreationDate"`,
  `"NM"`, `"M"`).

- text:

  Character scalar (UTF-8).

## Value

Invisibly returns the parent `pdfium_doc`.

## See also

[`pdf_annot_dict_value()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_dict_value.md),
[`pdf_annot_set_contents()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_set_contents.md).
