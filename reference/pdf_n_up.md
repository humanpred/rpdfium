# Combine N pages of a document into one

Wraps `FPDF_ImportNPagesToOne` — N-up imposition. Pages are arranged
into a `cols x rows` grid on each output page; if the source has more
pages than fit on one output page, more output pages are created.

## Usage

``` r
pdf_n_up(doc, file, cols, rows, output_width = 612, output_height = 792)
```

## Arguments

- doc:

  A source `pdfium_doc` (does not need `readwrite`).

- file:

  Destination path.

- cols, rows:

  Grid dimensions per output page.

- output_width, output_height:

  Output page size in PDF points. Defaults to US Letter (612 x 792).

## Value

Invisibly returns `file`.
