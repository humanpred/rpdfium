# Read the document's file identifier from its trailer

Returns the raw bytes of the PDF trailer's `/ID` entry. The identifier
is a two-element array `[permanent, changing]`: `permanent` is a hash
that should stay constant across saves of the same logical document;
`changing` is updated each time the file is rewritten. Use
`id_type = "permanent"` (the default) to track document identity, or
`"changing"` to detect that the file has been re-saved.

## Usage

``` r
pdf_file_id(doc, id_type = c("permanent", "changing"), password = NULL)
```

## Arguments

- doc:

  A `pdfium_doc` from
  [`pdf_open()`](https://humanpred.github.io/rpdfium/reference/pdf_open.md),
  or a character path.

- id_type:

  One of `"permanent"` (default) or `"changing"`.

- password:

  Optional password for encrypted PDFs when `doc` is a path. Ignored
  when `doc` is already an open `pdfium_doc`.

## Value

A raw vector. Zero-length when the document has no `/ID` entry.

## Details

Wraps `FPDF_GetFileIdentifier`. The identifier is binary; PDF writers
conventionally produce 16-byte MD5 hashes but the length is unspecified
and PDFs from non-standard writers may return any byte string (or none
at all).

## Examples

``` r
fixture <- system.file("extdata", "fixtures", "shapes.pdf",
                       package = "pdfium")
if (nzchar(fixture)) pdf_file_id(fixture)
#> raw(0)
```
