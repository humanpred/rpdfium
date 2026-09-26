# ADR-021 — Bezier control points as endpoint-row columns

- Status: Supersedes ADR-009
- Date: 2026-09-26
- Deciders: Bill Denney

## Context

ADR-009 deferred Bezier control points because "`FPDFPathSegment_GetPoint`
returns only the curve's endpoint" and no public PDFium function exposed
the control points. Two things changed:

1. **The premise was wrong.** PDFium stores a cubic curve (`c`, `v`, `y`
   operators, or `FPDFPath_BezierTo`) as three consecutive
   `FPDF_SEGMENT_BEZIERTO` points — control point 1, control point 2,
   endpoint — and `FPDFPath_CountSegments` / `FPDFPath_GetPathSegment`
   enumerate all three. `pdf_path_segments()` has therefore always
   returned the control points, as the first two rows of each
   `"bezierto"` triplet; `pdf_path_append()` and its tests already rely
   on that shape (`tests/testthat/test-path-setters.R`,
   `vignettes/extracting-paths.Rmd`). Only the roxygen docs of
   `pdf_path_segments()` / `pdf_extract_paths()` and the comments in
   `src/paths.cpp` repeated the ADR-009 claim. What *was* missing is an
   authoritative way to tell a triplet's endpoint from its control
   points without counting rows.
2. **PDFium chromium/8066 ships `FPDFPath_GetBezierControlPoints(path,
   index, &cp1, &cp2)`** (upstream commit "Add
   FPDFPath_GetBezierControlPoints() API", 2026-08-20 — the path-level
   form of the proposal tracked in ADR-009 / pdfium-review CL 147810).
   It returns `TRUE` only when `index` is the endpoint of a cubic
   segment (it walks back through consecutive Bezier points to find
   the triplet boundary) and then reports that curve's two control
   points.

## Decision

Add four numeric columns, `cx1`, `cy1`, `cx2`, `cy2`, to
`pdf_path_segments()` and `pdf_extract_paths()` (placed after
`close_figure`). They hold the curve's control points on the endpoint
row of each cubic segment, filled from `FPDFPath_GetBezierControlPoints`,
and `NA` on every other row — including the two control-point rows of
each triplet.

Keep one row per PDFium point (the triplet shape). Do not collapse a
curve into a single row, and do not add a separate
`pdf_path_bezier_controls()` accessor.

## Consequences

- `subset(segs, !is.na(cx1))` yields one row per curve with its control
  points; the triplet rows keep `pdf_path_append()` round-trips
  lossless, and `pdf_path_append()` ignores the new columns.
- `pdf_extract_paths()` gains four columns in the geometry group, so
  code that addresses its style / bounds columns by position must
  re-index; code that uses column names is unaffected.
- Clip-path (`pdf_clip_path_segments()`) and glyph-path
  (`pdf_glyph_path()`) segments keep their current shape:
  `FPDFPath_GetBezierControlPoints` takes a path *page object*, and
  neither a clip path nor a glyph path is one. Their `"bezierto"` rows
  still follow the same triplet convention.
- ADR-009's "revisit" trigger has fired; its upstream-issue text is
  kept as the historical record of the request.

## Alternatives considered

- **One row per curve** (drop the control-point rows, keep `x`/`y` as
  the endpoint plus `cx1`..`cy2`): tidier for curve-level analysis, but
  it breaks the one-row-per-PDFium-segment contract, the
  `pdf_path_append()` round-trip, and every existing consumer of the
  triplet rows.
- **A role column** (`"control1"` / `"control2"` / `"end"`): derivable
  from the `NA` pattern of `cx1`; not worth a fifth column.
- **Computing roles by counting consecutive `"bezierto"` rows** in R:
  that is what the new PDFium function does internally; calling it
  keeps the package on PDFium's definition, including malformed runs
  whose length is not a multiple of three.

## References

- ADR-009 — the deferral this supersedes.
- `dev/pdfium-8066-api-delta.md` — the chromium/7857 → chromium/8066
  audit that introduced the symbol.
- `dev/upstream-patches/pdfium-FPDFPath_GetBezierControlPoints.patch` —
  the package's own upstream proposal.
- ISO 32000-1:2008, section 8.5.2.2 (cubic Bezier curves; `c`, `v`, `y`).
