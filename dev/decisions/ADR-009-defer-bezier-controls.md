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

## Potential upstream resolution

If a future maintainer wants to push for control-point readout, the
groundwork is in place. The cross-language demand is documented and
the PDFium maintainers have not (as of 2026-05-15) opened or rejected
a public issue on the topic.

**Where to file:**

- Primary: the Chromium issue tracker, PDFium component
  ([component 1456102](https://issues.chromium.org/issues?q=componentid:1456102)).
  Open a new issue at `https://issues.chromium.org/issues/new?component=1456102`.
- Discuss first (optional, often helpful): the PDFium mailing list
  at `pdfium@googlegroups.com`
  ([thread archive](https://groups.google.com/g/pdfium)).
- Code review of any patch goes through Gerrit at
  `https://pdfium-review.googlesource.com`.

**Suggested title:**

```
[Feature] Expose Bezier control points via
FPDFPathSegment_GetBezierControlPoints
```

**Suggested body:**

```
PDFium's path segment readout exposes only the destination point
of each segment via FPDFPathSegment_GetPoint, even for
FPDF_SEGMENT_BEZIERTO. The two control points stored internally on
CFX_Path::Point are not retrievable through any public C API, so
embedders cannot reconstruct cubic Bezier curves read from existing
PDFs.

The constructor side already exposes all six floats via
FPDFPath_BezierTo, so the asymmetry is purely on the readout side.
Proposed addition, mirroring the existing shape:

  FPDF_EXPORT FPDF_BOOL FPDF_CALLCONV
  FPDFPathSegment_GetBezierControlPoints(FPDF_PATHSEGMENT segment,
                                          float* cp1_x, float* cp1_y,
                                          float* cp2_x, float* cp2_y);

Behavior:
  - Returns TRUE on success.
  - Returns FALSE without modifying out-params when segment type is
    not FPDF_SEGMENT_BEZIERTO.

Use case: every cross-language PDFium wrapper hits this limitation
when reading existing PDFs. pdfium-render's maintainer documented
the issue at https://github.com/ajrcarey/pdfium-render/issues/55
and the dedicated upstream-handoff issue
https://github.com/ajrcarey/pdfium-render/issues/99 was closed
2023-08-03 specifically asking for the upstream change. pypdfium2,
pdfium-rs, and an R binding (pdfium / github.com/humanpred/rpdfium)
all currently document the limitation and lose curve geometry on
the read path.

Alternatives considered:
  - Exposing the raw page content stream (e.g.
    `FPDFPage_GetRawContents`) would also unblock this, but is a
    much larger surface change with broader downstream impact.
  - Embedders cannot recover control points geometrically - many
    distinct curves share the same pair of endpoints.

Happy to draft the patch via Gerrit if there's interest.
```

**Tips for framing:**

1. Lead with the API gap (constructor exposes all six floats,
   readout exposes one point), not with the use case. PDFium
   maintainers respond better to "the read and write paths are
   asymmetric" than to "I want feature X."
2. Cite the existing cross-wrapper evidence. The pdfium-render
   issues are the only public documentation of multi-language
   demand; link them.
3. Offer to draft the patch. PDFium has limited maintainer
   bandwidth; the offer materially shifts the cost/benefit on the
   reviewer side.

**Triggers to revisit this ADR:**

- A new `FPDFPathSegment_GetBezierControlPoints` (or equivalent)
  symbol appears in PDFium upstream `public/`. Watch via
  bblanchon release notes; the bump procedure in
  `dev/architecture.md` already covers re-running the API survey
  on each pin bump.
- A new public PDFium API exposing raw page content streams
  (`FPDFPage_GetRawContents` or similar) lands. Either unblocks
  the same capability via parsing.
- An R-side consumer requires control points and is willing to
  fund either route (1) (vendoring a PDF parser) or (2) (qpdf
  dependency) from the original "Alternatives considered" section.

## References

- `dev/pdfium-api-review.md` — original survey, including the
  `FPDFPage_GetRawContents` note that did not pan out.
- `dev/upstream-feature-survey.md` — cross-wrapper feature matrix
  showing the same gap in pypdfium2 / pdfium-rs / pdfium-render.
- PDFium upstream `public/` headers, commit
  `9095044e26da35f3261df4365f51d6e74a3c8b24` (clone at
  `https://pdfium.googlesource.com/pdfium`, 2026-05-15).
- pdfium-render issue #99
  (<https://github.com/ajrcarey/pdfium-render/issues/99>) —
  explicit upstream-handoff ask, closed 2023-08-03 pointing at the
  PDFium project.
- pdfium-render issue #55, comment 2022-10-28 — original
  observation by the project maintainer: "Pdfium does not provide
  any way to retrieve the control points of the curve."
- Miklos Vajna's blog post describing the original
  FPDFPathSegment_* API contribution
  (<https://vmiklos.hu/blog/pdfium-pathsegment.html>) — confirms
  only basic segment readout was added; control points were never
  in scope.
