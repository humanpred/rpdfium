# Resolve a named destination by name

Looks up a `/Dest` by its name string and returns the same kind of row
[`pdf_named_dests()`](https://humanpred.github.io/rpdfium/reference/pdf_named_dests.md)
surfaces — page, view, x, y, zoom. Useful for following cross-document
references such as `RemoteGoTo` actions that carry a destination name
rather than a page index.

## Usage

``` r
pdf_named_dest_by_name(doc, name, password = NULL)
```

## Arguments

- doc:

  A `pdfium_doc` from
  [`pdf_open()`](https://humanpred.github.io/rpdfium/reference/pdf_open.md),
  or a character path.

- name:

  Single non-empty character string.

- password:

  Optional password for encrypted PDFs when `doc` is a path. Ignored
  when `doc` is already an open `pdfium_doc`.

## Value

A list with `found` (logical), `page` (integer, 1-based, `NA` when not
resolvable), and `dest_view` / `dest_x` / `dest_y` / `dest_zoom` (same
shape as the corresponding columns on
[`pdf_named_dests()`](https://humanpred.github.io/rpdfium/reference/pdf_named_dests.md)).
`found = FALSE` and all other fields `NA` when the name is not in the
destination table.

## Details

Wraps `FPDF_GetNamedDestByName` plus `FPDFDest_GetDestPageIndex` /
`FPDFDest_GetView` / `FPDFDest_GetLocationInPage`.

## See also

[`pdf_named_dests()`](https://humanpred.github.io/rpdfium/reference/pdf_named_dests.md).
