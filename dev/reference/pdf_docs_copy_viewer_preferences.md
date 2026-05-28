# Copy `/ViewerPreferences` from one document to another

Wraps `FPDF_CopyViewerPreferences`. Copies the source document's
`/ViewerPreferences` dictionary (PageLayout, PageMode,
NonFullScreenPageMode, Direction, ViewArea, ViewClip, PrintArea,
PrintClip, PrintScaling, Duplex, PickTrayByPDFSize, PrintPageRange,
NumCopies, etc.) into the destination document. PDFium creates the entry
on `dest_doc` if absent, replaces it otherwise.

## Usage

``` r
pdf_docs_copy_viewer_preferences(dest_doc, src_doc)
```

## Arguments

- dest_doc:

  A `pdfium_doc` opened with `readwrite = TRUE`.

- src_doc:

  Source `pdfium_doc` whose viewer preferences are read.

## Value

Invisibly returns `dest_doc`.

## Details

Useful when assembling a derived document — concatenation, n-up, page
reordering — that should inherit the display and print hints the
publisher set on the original.
