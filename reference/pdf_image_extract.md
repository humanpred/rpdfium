# Extract an embedded image to a file, picking a sensible format

Convenience helper over
[`pdf_image_filters()`](https://humanpred.github.io/rpdfium/reference/pdf_image_filters.md),
[`pdf_image_data()`](https://humanpred.github.io/rpdfium/reference/pdf_image_data.md),
and
[`pdf_image_bitmap()`](https://humanpred.github.io/rpdfium/reference/pdf_image_bitmap.md).
Inspects the image's filter chain and picks an on-disk format:

## Usage

``` r
pdf_image_extract(obj, path)
```

## Arguments

- obj:

  A `pdfium_obj` of type `"image"`.

- path:

  Output file path. If the extension is supplied it's ignored — the
  function appends `.jpg`, `.jp2`, or `.png` according to the chosen
  format and returns the actual path used.

## Value

Invisibly returns the path written, with the chosen extension applied.
The output format can be retrieved by inspecting the file extension on
the returned string.

## Details

- `DCTDecode` → write the raw embedded bytes as `.jpg`.

- `JPXDecode` → write the raw embedded bytes as `.jp2`.

- `CCITTFaxDecode` / `JBIG2Decode` / `RunLengthDecode` / `FlateDecode` /
  `LZWDecode` / `ASCII85Decode` / `ASCIIHexDecode` chains, or no filter
  → rasterize via
  [`pdf_image_bitmap()`](https://humanpred.github.io/rpdfium/reference/pdf_image_bitmap.md)
  and write as a PNG using
  [`png::writePNG()`](https://rdrr.io/pkg/png/man/writePNG.html). PNG
  round-trips the alpha channel when present.

Mirrors pypdfium2's `PdfImage.extract()` convenience.

## See also

[`pdf_image_data()`](https://humanpred.github.io/rpdfium/reference/pdf_image_data.md)
to get the raw bytes directly,
[`pdf_image_bitmap()`](https://humanpred.github.io/rpdfium/reference/pdf_image_bitmap.md)
for the decoded pixel matrix.

## Examples

``` r
fixture <- system.file("extdata", "fixtures", "image.pdf",
  package = "pdfium"
)
if (nzchar(fixture)) {
  doc <- pdf_doc_open(fixture)
  page <- pdf_page_load(doc, 1L)
  imgs <- Filter(function(o) o$type == "image", pdf_page_objects(page))
  if (length(imgs) > 0L) {
    # The extension is chosen from the filter chain; pass a stem.
    out <- pdf_image_extract(imgs[[1L]], tempfile())
    basename(out)
  }
  pdf_page_close(page)
  pdf_doc_close(doc)
}
```
