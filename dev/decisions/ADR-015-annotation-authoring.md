# ADR-015 — Annotation authoring scope

- Status: Accepted
- Date: 2026-05-19
- Deciders: Bill Denney

## Context

The v0.1.0 reader surface enumerates 28 annotation subtypes and
every structural property PDFium exposes (rect, color, interior
color, flags, contents, title, subject, quad_points, vertices,
ink_paths, font_color, font_size, popup_index, irt_index,
file_attachment_name, border). The writer half mirrors all of
those plus annotation creation + removal.

The earlier v0.2.0 plan scoped the writer to "highlight, text note,
link only". With the full v0.2.0 surface folding into v0.1.0, we
have the headroom to ship the entire mirror.

## Decision

Ship the full writer mirror:

* `pdf_annot_new(page, subtype, rect)` — `FPDFPage_CreateAnnot`.
  Subtype accepted as name (string) or integer code; gated by
  `FPDFAnnot_IsSupportedSubtype` so unsupported subtypes error
  early with a clear message.
* `pdf_annot_remove(page, annotation_index)` —
  `FPDFPage_RemoveAnnot`.
* `pdf_annot_set_rect()`, `_set_contents()`, `_set_title()`,
  `_set_subject()`, `_set_color()`, `_set_interior_color()`,
  `_set_flags()`, `_set_border()`, `_set_font_color()`,
  `_set_font_size()`.
* `pdf_annot_set_quad_points(annot, matrix)` — clears + re-appends
  via `FPDFAnnot_AppendAttachmentPoints` (PDFium's only writer
  shape for the quad list).
* `pdf_annot_add_ink_stroke(annot, points)` and
  `_remove_ink_list(annot)` — `FPDFAnnot_AddInkStroke` /
  `_RemoveInkList`.
* `pdf_annot_set_uri(annot, uri)` — `FPDFAnnot_SetURI` for Link
  subtype.
* `pdf_annot_set_string_value(annot, key, value)` — generic
  dict-key set via `FPDFAnnot_SetStringValue`. Matches the reader's
  `pdf_annot_dict_value()` shape.
* `pdf_annot_set_ap(annot, mode, appearance_obj)` —
  `FPDFAnnot_SetAP`. Mode is `"normal"` / `"rollover"` / `"down"`.
* `pdf_annot_append_object(annot, obj)`,
  `pdf_annot_update_object(annot, obj)`,
  `pdf_annot_remove_object(annot, index)` —
  `FPDFAnnot_AppendObject` / `_UpdateObject` / `_RemoveObject` for
  Stamp / Ink subtypes that carry inner page objects.

`pdf_annot_set_vertices()` (line / polygon / polyline) is **not**
exposed: PDFium has no public setter. Documented as a known gap in
the function reference; a v0.2.0 release may add raw-dict access if
demand materialises.

## Consequences

- The annotation writer surface is the largest writer module
  (~25 exported functions). Each maps to one PDFium symbol; the
  R-side complexity is in coercing R-natural shapes (matrices for
  quad points, list-of-matrices for ink paths, named logicals for
  flags) back into the C ABI.
- `pdfium_annot_subtype_code()` (the inverse of
  `annotation_subtype_name()`) ships in Phase 9.
- Appearance-stream regeneration (`FPDFAnnot_SetAP`) needs
  documentation: setting structural properties does NOT
  automatically regenerate AP for viewers that respect AP
  strictly. Document the workflow.

## Alternatives considered

- **Highlight / text note / link only** (the original v0.2.0
  scope): rejected — once we have the foundation (Phase 1) and
  the obj-styling setters (Phase 3), every other annotation
  setter is a one-liner. The maintenance burden of "everything"
  is barely higher than "three subtypes".
- **Defer to v0.3+**: rejected per user decision to fold
  v0.2.0 into v0.1.0.

## References

- `dev/mutation-design.md` §2 Phase 6.
- PDFium `fpdf_annot.h`.
