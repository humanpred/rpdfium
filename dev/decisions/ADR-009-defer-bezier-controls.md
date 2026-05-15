# ADR-009 — Defer Bezier control points to a post-0.1.0 release

- Status: Accepted
- Date: 2026-05-15

## Context

PDFium's public C API exposes path segments via `FPDFPath_CountSegments`
+ `FPDFPath_GetPathSegment` + the `FPDFPathSegment_*` accessors. For a
`FPDF_SEGMENT_BEZIERTO` segment, `FPDFPathSegment_GetPoint` returns only
the curve's *endpoint*. The two control points needed to reconstruct
the cubic Bézier curve are not exposed by any public PDFium function.

The Phase 0c API review (`dev/pdfium-api-review.md`) anticipated this
gap and recorded `FPDFPage_GetRawContents` as a path forward —
parse the raw page content stream to recover `c`, `v`, `y` operands.
On verification:

- `FPDFPage_GetRawContents` is **not** in the bblanchon `chromium/7202`
  build we pin (see `tools/pdfium-version.txt`).
- It is **not** in upstream PDFium's `public/` headers at all (verified
  against `pdfium.googlesource.com/pdfium`, HEAD `9095044` as of
  2026-05-15).
- The Phase 0a upstream-wrapper survey
  (`dev/upstream-feature-survey.md`) shows pypdfium2, pdfium-rs, and
  pdfium-render all report the same limitation: control points are
  not retrievable from the FPDFPath_* read API.

The only currently-feasible routes to control points all require
substantial additional work:

1. **Build a PDF parser inside this package.** Open the file as bytes,
   walk the cross-reference table, locate the page's `/Contents`
   stream object, decompress (Flate / LZW / ASCII85), tokenize PDF
   operators, and track path-construction state per page object.
   Multi-week effort with a large correctness surface area to test.
2. **Take a runtime dependency on qpdf.** libqpdf does parse content
   streams. Adds a heavy native dependency to the package and a
   runtime coupling we cannot easily unwind.
3. **Wait for upstream PDFium.** No public signal that a content
   stream / control point API is being added.

## Decision

Ship `pdfium` v0.1.0 with the documented limitation: `bezierto`
segments return only their endpoints, control points are not
exposed. This affects `pdf_path_segments()` and the columns of
`pdf_extract_paths()` (no `cx1/cy1/cx2/cy2` columns).

Re-evaluate when one of the following becomes true:

- Upstream PDFium publishes a content-stream or per-segment
  control-point API (track via the bblanchon release notes).
- A user's concrete need crosses a clear cost/benefit line that
  justifies route (1) or (2).

## Consequences

- v0.1.0 supports the geometry needs of `kmextract` (which extracts
  lineto-heavy survival-curve and Kaplan-Meier plots) without control
  points. Most R-generated PDF figures (`graphics::plot.default`,
  `ggplot2::ggplot()`, etc.) emit linetos, not Béziers, so the
  practical impact on the target workflow is small.
- Documentation in `pdf_path_segments()` (`R/paths.R`) already states
  the limitation and points to this ADR. `pdf_extract_paths()`'s
  Known Limitations section reflects the same.
- The Phase 2 plan item "Bezier + dash + CTM" is reduced to "dash +
  CTM" for v0.1.0; the matrix and dash work shipped on
  `claude/phase-2-matrix`. Bezier moves to Tier 2 / post-0.1.0.

## Alternatives considered

- **Reconstruct control points geometrically from endpoints.**
  Impossible in general: many distinct Bézier curves share the same
  pair of endpoints. Even for the special case of circular arcs
  (most common producer of `c` operators in R-generated PDFs), the
  reconstruction is ambiguous without additional context.
- **Use `qpdf` as a Suggests dep with graceful fallback.** Adds an
  opt-in path to control points if the user has qpdf installed. The
  cost — a second parsing path to maintain, plus CI complexity, plus
  user-visible inconsistency — outweighs the value for v0.1.0. Open
  to revisit if user demand materializes.
- **Vendor a minimal PDF parser.** Reusing an existing one (e.g.
  PDFBox, MuPDF) brings in a different non-trivial dependency.
  Writing one from scratch is the multi-week effort flagged above.

## References

- `dev/pdfium-api-review.md` — original survey, including the
  `FPDFPage_GetRawContents` note that did not pan out.
- `dev/upstream-feature-survey.md` — cross-wrapper feature matrix
  showing the same gap in pypdfium2 / pdfium-rs / pdfium-render.
- PDFium upstream `public/` headers, commit
  `9095044e26da35f3261df4365f51d6e74a3c8b24` (clone at
  `https://pdfium.googlesource.com/pdfium`, 2026-05-15).
