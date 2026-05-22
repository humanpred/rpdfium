# Load a CID Type 2 (composite TrueType) font with explicit mappings

Wraps `FPDFText_LoadCidType2Font`. The CID Type 2 path is a
specialisation of
[`pdf_font_load()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_font_load.md)
that takes explicit ToUnicode CMap and CID-to-GID mapping tables —
useful for embedding fonts whose glyph indexing differs from the default
CID identity mapping (e.g. East Asian fonts with custom GID lookups).

## Usage

``` r
pdf_font_load_cidtype2(
  doc,
  font_data,
  to_unicode_cmap = "",
  cid_to_gid = raw(0)
)
```

## Arguments

- doc:

  A `pdfium_doc` opened with `readwrite = TRUE`.

- font_data:

  Either a raw vector of TTF bytes or a path to a TTF file on disk.

- to_unicode_cmap:

  Character scalar — the CMap content as a PostScript-style CMap string.
  Empty string `""` uses PDFium's default.

- cid_to_gid:

  Raw vector — the CID-to-GID mapping table (big-endian uint16 pairs).
  `raw(0)` uses the identity mapping.

## Value

A `pdfium_font` handle.

## Details

For ordinary TTF embedding,
[`pdf_font_load()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_font_load.md)
with `cid = TRUE` is usually all you need.

## See also

[`pdf_font_load()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_font_load.md)
for the simpler TTF path.
