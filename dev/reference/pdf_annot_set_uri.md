# Set the URI of a link annotation

Wraps `FPDFAnnot_SetURI`. The annotation must be of subtype `"link"`;
the URI becomes the link's destination.

## Usage

``` r
pdf_annot_set_uri(annot, uri)
```

## Arguments

- annot:

  A `pdfium_annot` of subtype `"link"`.

- uri:

  Character scalar — the destination URI.

## Value

Invisibly returns the parent `pdfium_doc`.
