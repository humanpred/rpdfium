# Look up a `/ViewerPreferences` name-typed entry by key

PDFium's structured
[`pdf_doc_viewer_preferences()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_viewer_preferences.md)
surfaces the commonly-used entries (print scaling, copies, duplex, page
ranges). For other keys whose value is a `/Name` (e.g. `Direction` =
`"L2R"`/`"R2L"`, `ViewArea` = `"MediaBox"`/`"CropBox"`, or arbitrary
author-defined entries), use this by-key lookup. Wraps
`FPDF_VIEWERREF_GetName`.

## Usage

``` r
pdf_doc_viewer_preference_by_name(doc, key, password = NULL)
```

## Arguments

- doc:

  A `pdfium_doc` from
  [`pdf_doc_open()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_open.md),
  or a character path.

- key:

  The viewer-preferences dictionary key as a single non-empty character
  string (ASCII PDF name, e.g. `"Direction"`).

- password:

  Optional password for encrypted PDFs when `doc` is a path. Ignored
  when `doc` is already an open `pdfium_doc`.

## Value

Character scalar — the entry's name value (without the leading slash),
or `NA_character_` when the key is absent or the value is not a `/Name`.

## See also

[`pdf_doc_viewer_preferences()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_viewer_preferences.md).
