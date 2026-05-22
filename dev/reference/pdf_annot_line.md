# Line endpoints of a line annotation

Wraps `FPDFAnnot_GetLine`. PDF line annotations carry their start and
end points in `/L` rather than `/Rect`; this helper exposes those
endpoints as a named numeric vector.

## Usage

``` r
pdf_annot_line(annot)
```

## Arguments

- annot:

  A `pdfium_annot` of subtype `"line"` (PDFium also returns endpoints
  for annotations with a `/L` entry).

## Value

Named numeric vector `c(start_x, start_y, end_x, end_y)`. All-`NA` when
the annotation has no line entry.
