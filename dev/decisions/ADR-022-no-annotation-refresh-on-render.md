# ADR-022 — Rendering does not touch annotations

- Status: Supersedes ADR-020 §7
- Date: 2026-09-26
- Deciders: Bill Denney

## Context

ADR-020 §7 made `pdf_render_page()` and `pdf_render_page_with_matrix()`
walk every annotation on the page before rendering and call
`FPDFAnnot_SetRect()` with the annotation's current rect
(`cpp_page_refresh_annot_aps`), on the premise that this "flips
PDFium's AP-dirty flag so the next render rebuilds the stream from the
live dict". `pdf_form_field_set_value()` used the same trick on the
edited widget (`cpp_annot_touch_ap`).

The chromium/7857 → chromium/8066 bump changed `FPDFAnnot_SetRect()`,
which prompted a re-check of that premise against both builds
(`dev/pdfium-8066-api-delta.md`, §D):

- PDFium has no AP-dirty flag reachable through `FPDFAnnot_SetRect()`.
  Rendering already reads annotation dictionaries afresh on every call
  (`FPDF_RenderPageBitmap` builds a new annotation list per render), and
  it never regenerates an existing `/AP` stream.
- Up to chromium/7857, `FPDFAnnot_SetRect()` had one side effect: when
  the annotation had a normal appearance stream and the new rect
  contained its `/BBox`, it overwrote the `/BBox` with the rect. The
  "refresh" therefore rewrote the `/BBox` of any appearance whose
  bounding box sat inside its annotation rect, on every render — even
  on read-only documents. That drew the appearance at the wrong scale
  (a `/BBox` inside the `/Rect` must be stretched onto the `/Rect`, ISO
  32000-1:2008 section 12.5.5) and leaked into later `pdf_save()` output.
- From chromium/8066 `FPDFAnnot_SetRect()` no longer touches the
  appearance stream at all, so the walk is a pure no-op: rendering with
  and without it produces identical bitmaps and identical saved bytes.
- Form-field widgets are not drawn by `FPDF_RenderPageBitmap` at all,
  and the widget's `/AP` is not rebuilt after a `/V` change on either
  build, so `cpp_annot_touch_ap` never did what its documentation said.

## Decision

Remove the annotation walk from both render paths and the touch from
`pdf_form_field_set_value()`, and delete `cpp_page_refresh_annot_aps`
and `cpp_annot_touch_ap`. Rendering only flushes pending page-content
edits (`FPDFPage_GenerateContent` via `flush_page_if_dirty()`), which
remains necessary for page-object mutations. The form-field setter
documents that PDFium's public API offers no non-interactive
appearance regeneration.

## Consequences

- Rendering has no side effects on the document; a regression test pins
  that an appearance whose `/BBox` sits inside its `/Rect` renders at
  full size and that its `/BBox` survives rendering unchanged.
- One fewer O(annotations) pass per render.
- `pdf_form_field_set_value()` on a text or choice field still leaves
  the field's old appearance in place. Fixing that needs either
  PDFium's interactive form-fill layer (`FORM_*` / `FPDF_FFLDraw`,
  excluded in `dev/v0.1.0-api-gap-audit.md` §5) or an upstream
  non-interactive regeneration API; it is out of scope here.

## Alternatives considered

- **Keep the walk as a harmless no-op on chromium/8066**: it would keep
  a per-render annotation walk, and documentation of a mechanism that
  never existed.
- **Replace it with a real regeneration step**: PDFium's public API has
  none outside the interactive form-fill environment.

## References

- ADR-020 §7 — the decision this supersedes; the rest of ADR-020 stands.
- `dev/pdfium-8066-api-delta.md` — the empirical before/after checks.
- `tests/testthat/test-mut-save.R` — "rendering leaves annotation
  appearance streams untouched".
