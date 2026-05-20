# Enumerate document-level JavaScript actions

Returns one row per JavaScript action attached to the document
(typically OpenAction or Document JS). Useful for static analysis of
PDFs that may contain executable JavaScript. PDFium never executes the
script; this is a passive readout. Wraps `FPDFDoc_GetJavaScriptAction*`
/ `FPDFJavaScriptAction_GetName` / `_GetScript`.

## Usage

``` r
pdf_doc_javascript(doc, password = NULL)
```

## Arguments

- doc:

  A `pdfium_doc` from
  [`pdf_open()`](https://humanpred.github.io/rpdfium/reference/pdf_open.md),
  or a character path.

- password:

  Optional password for encrypted PDFs when `doc` is a path. Ignored
  when `doc` is already an open `pdfium_doc`.

## Value

A tibble with columns `name` (UTF-8 action name, often empty for the
top-level OpenAction) and `script` (the JavaScript source, UTF-8). Empty
tibble when no JS actions are present.
