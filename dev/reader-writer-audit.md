# Reader / writer symmetry audit

This document audits every reader the `pdfium` package exposes today
against the eventual writer/mutation surface planned for v0.2.0
(`dev/v0.2.0-plan.md`). The aim is to ensure that — for every reader
that emits a tibble or list — a user can:

1. Read it.
2. Edit a single cell.
3. Hand the edited row (or whole frame) back to the corresponding
   writer.
4. Save the PDF and see the change persist.

That round-trip is the contract this audit tries to lock in *before*
0.1.0 ships, so 0.2.0 writers don't force a reader-API break.

## Provenance

- Audit date: 2026-05-18.
- pdfium pin: `tools/pdfium-version.txt` -> `chromium/7202`.
- Reader inventory generated from `R/*.R` on commit `e3e8359`.
- Source of writer surface: a walk of `inst/include/fpdf_edit.h` +
  `fpdf_annot.h` + `fpdf_save.h` + `fpdf_ppo.h` + the `Set*` / `New*` /
  `*Insert*` / `*Remove*` / `*Append*` / `*Update*` exports across
  all 22 PDFium public headers.
- This file should be regenerated when any reader's tibble schema
  changes or a new PDFium pin lands.

## Principles

The audit enforces six principles. Every "finding" below is justified
in terms of one or more of these.

1. **Identity present.** Every readered row must contain enough
   information for a writer to locate the same object. For
   page-scoped lists, that means an `xxx_index` *and* the implicit
   `page` reference the caller passes in. For doc-scoped lists, an
   `xxx_index` alone (with the implicit `doc`). When PDFium hands us a
   live handle (page objects), the handle *is* the identity and an
   index is redundant.

2. **PDF coordinate space.** All geometry is in PDF user-space
   points, origin at the page's bottom-left, y growing upwards. Rect
   columns are `bounds_left / bounds_bottom / bounds_right /
   bounds_top` in that order. Writers consume the same convention.
   (PDFium's internal `FS_RECTF` is `left/top/right/bottom`; the
   shim layer handles the swap.)

3. **List-columns for variable-length geometry.** Quad points,
   vertices, ink-paths, dash arrays, control points — anything that
   varies per row — is a `list`-column of numeric matrices /
   vectors / tibbles. Writers accept the same shape. No "flatten and
   re-shape on the way back in" pattern.

4. **Codes and names coexist where roundtripping benefits.** PDFium
   enums (action types, annotation subtypes, form-field types,
   render modes, line caps / joins) come back as readable strings
   ("uri", "highlight", "round"). For writers that need codes, we
   provide internal bidirectional helpers
   (`pdfium_action_type_code()` etc.) — and writers accept either
   the string or the integer code.

5. **Normalized numeric ranges.** Colors are 0..1 doubles in R (not
   0..255 integers), matrices are 3x2 doubles (not raw float
   arrays), opacities are 0..1. Writers do the denormalization on
   their side. (Rationale: R idioms beat PDF idioms at the API
   boundary; the C layer is where conversions happen.)

6. **Reader output is self-describing.** Tibble column names exactly
   match the writer parameter names where the writer takes
   scalars. A user who reads `field_flags` and wants to set them
   passes `field_flags = ...` to the setter — no rename needed.

## Findings

### `pdf_doc_open` / `pdf_doc_close` / `pdf_page_close` / `pdf_page_load`

Lifecycle, not data. No tibble involved. Writers: `pdf_save()` and
`pdf_save_as_copy()` will be peers. **No change needed.**

### `pdf_doc_info` / `pdf_doc_meta` / `pdf_parse_date`

Doc-level metadata strings + a parsed POSIXct date.

* Writer counterpart: `pdf_doc_set_meta(doc, key, value)` calls
  `FPDF_SetMetaText`. Takes the same keys we already accept on
  the read side (`Title`, `Author`, ...).
* `pdf_parse_date` is read-only; the inverse is
  `pdf_format_date(time)` which would emit a PDF date string for
  writers that want to set `CreationDate` / `ModDate`.

**Audit finding:** ensure `pdf_doc_info()` returns the exact key
names PDFium expects (`Title`, `Author`, ...) — not lowercased or
prettified. Today it does. Status: **OK as is.**

### `pdf_doc_permissions`

Returns a named `logical` vector with eight permission flags.

* Writer counterpart: PDFium doesn't expose a `Set` for permission
  bits at the public API level; permission flags belong to the
  encryption layer, which we do not plan to mutate in 0.2.0.
* **No change needed** (read-only by design).

### `pdf_doc_is_tagged` / `pdf_doc_page_mode` / `pdf_doc_javascript` / `pdf_doc_viewer_preferences` / `pdf_doc_named_dests` / `pdf_doc_file_id`

Scalar / small-tibble readouts. No writer counterparts planned (PDFium
exposes only `FPDF_CopyViewerPreferences` and a small set of catalog
mutators that aren't on the 0.2.0 roadmap).

**Status:** **OK as is.**

### `pdf_doc_fonts`

Doc-wide font inventory (font name, type, embedded flag, etc.).

* Writer counterpart: `pdf_text_obj_set_font(obj, font_name, ...)`
  uses `FPDFText_LoadFont` (load a custom TTF) or
  `FPDFPageObj_NewTextObj(doc, font_name, font_size)`.
  Built-in font names ("Helvetica", "Times-Roman", etc.) round-trip
  cleanly.

**Audit finding:** the `is_embedded`, `is_tagged_pdf_compliant`,
and `weight` columns we return are reader-only; writers consume
font *names* and font *handles*, not metadata. No reshape required
because the writer API operates by handle/name lookup. Status:
**OK as is.**

### `pdf_doc_bookmarks`

Pre-order tibble: `bookmark_index`, `parent_index`, `level`, `title`,
`page_num`, `action_type`, `uri`, `filepath`.

* Writer counterpart: PDFium does **not** expose direct
  `FPDFBookmark_Set*` mutators. Bookmark trees can only be
  modified by manipulating the underlying PDF dictionary tree,
  which is below the public API surface. Realistically, 0.2.0 will
  not ship bookmark mutation.
* **However**, we may want a `pdf_bookmarks_replace(doc, df)` that
  rebuilds `/Outlines` from a tibble (using only the public
  read/write surface PDFium provides — `FPDF_SaveAsCopy` + manual
  outline reconstruction). For that path, the tibble needs to be
  self-sufficient.

**Audit finding:** the current tibble is round-trippable. The
`parent_index` column encodes hierarchy via row references; an
implementation of `pdf_bookmarks_replace()` can walk the rows in
order, build elements, and link them. Status: **OK as is.**

### `pdf_page_label` / `pdf_page_labels`

Logical page labels. Writer counterpart: `pdf_page_label_set()` would
need direct catalog manipulation, not in 0.2.0 scope. Status:
**OK as is.**

### `pdf_page_size` / `pdf_page_rotation` / `pdf_page_box`

Page geometry.

* Writer counterparts: `pdf_page_set_rotation(page, rotation)` (wraps
  `FPDFPage_SetRotation`), `pdf_page_set_box(page, box, rect)`
  (wraps `FPDFPage_Set*Box`). MediaBox isn't directly settable via
  the public API; CropBox / BleedBox / TrimBox / ArtBox are.
* The `rotation` value goes in as an integer in `{0, 90, 180, 270}` —
  both reader and writer agree.

**Audit finding:** the `pdf_page_box()` output is a named numeric
vector `c(left, bottom, right, top)`. The writer would take exactly
that vector. Status: **OK as is.**

### `pdf_page_links`

Tibble: `link_index`, `bounds_*`, `action_type`, `uri`, `filepath`,
`dest_page_num`.

* Writer counterparts:
  - `pdf_link_set_action(page, link_index, action)` — uses
    `FPDFLink_*` + `FPDFAction_*` setters (PDFium does NOT expose
    these directly — links are immutable through the public API
    except via the annotation surface, since links *are* annotations
    of subtype `link`).
  - In practice link mutation goes through `pdf_annotations` (see
    below).

**Audit finding:** `pdf_page_links` is convenience; writers go through
the annotation surface. Reader API doesn't need a parallel structure.
Status: **OK as is, but add `quad_points` list-column** when we
land `FPDFLink_GetQuadPoints` (Tier 1) so multi-line links round-trip.

### `pdf_link_at_point`

Single-row tibble. Same notes as `pdf_page_links`. Writer goes
through annotations.

### `pdf_page_actions`

Up to two rows (open / close additional-actions). Writer counterpart
not on 0.2.0 roadmap. Status: **OK as is.**

### `pdf_page_thumbnail`

Raw vector of bytes. Writer counterpart: there is **no** PDFium API
for setting a page's `/Thumb` stream. Reader is informational.
Status: **OK as is.**

### `pdf_text_weblinks`

Detected URL spans. Reader-only (URL detection runs over extracted
text). Status: **OK as is.**

### `pdf_annotations`

The biggest writer-symmetry target. Today's tibble:

| column | type | notes |
|---|---|---|
| `annotation_index` | integer | identity, page-scoped 1-based |
| `subtype` | character | name; needs `pdfium_annot_subtype_code()` for writers |
| `flags` | integer | raw bitmask; writers accept this |
| `is_invisible` / `_hidden` / ... | logical | decoded bits 1, 2, 3, 6, 7, 8 |
| `bounds_*` | numeric | maps directly to `FS_RECTF` (left/bottom/right/top in PDF space) |
| `contents` | character | `/Contents`; settable via `FPDFAnnot_SetStringValue("Contents", ...)` |
| `title` | character | `/T`; ditto |
| `subject` | character | `/Subj`; ditto |
| `color_red` / `_green` / `_blue` / `_alpha` | numeric 0..1 | `FPDFAnnot_SetColor` takes 0..255 ints |
| `interior_red` / ... | numeric 0..1 | same as above for `/IC` |
| `border_width` | numeric | `FPDFAnnot_GetBorder`; setter is `FPDFAnnot_SetBorder` |

**Audit findings:**

1. **`subtype_code` should also be exposed** as an integer column so
   writers that take an `FPDF_ANNOTATION_SUBTYPE` enum don't have to
   bidirectionally map. The string `subtype` stays as the primary
   user-facing field. (Implemented as part of Tier 1 alongside the
   geometry additions.)

2. **Quad-points, vertices, ink-lists are missing.** A highlight that
   wraps over five lines has five quad-points but `pdf_annotations()`
   only surfaces the union bounding rect. We must add list-columns:
   - `quad_points`: list of 4x2 numeric matrices (x1,y1, x2,y2,
     x3,y3, x4,y4) per row. `NULL` when the annotation has no
     `/QuadPoints`.
   - `vertices`: list of N x 2 numeric matrices for line / polygon /
     polyline annotations. `NULL` otherwise.
   - `ink_paths`: list of list-of-N x 2 numeric matrices (one matrix
     per ink stroke). `NULL` otherwise.

   These are all Tier 1 additions and the writer accepts the same
   shape (a list of matrices) when constructing or mutating the
   annotation.

3. **`linked_index`** column — the annotation that this one is linked
   to (e.g. a Popup parent). Surfaces `FPDFAnnot_GetLinkedAnnot`.
   Tier 2 addition.

4. **`font_color_*` / `font_size`** for FreeText and Stamp annotations
   — Tier 2.

5. **`appearance_stream`** (the `/AP` stream bytes, optional) —
   conceptually round-trippable but bulky. Defer: writers can set
   `/AP` via `FPDFAnnot_SetAP` but most users will rely on PDFium's
   auto-regeneration via `FPDFPage_GenerateContent`. We will expose
   `pdf_annot_appearance(annot, mode = "N"|"R"|"D")` separately
   rather than baking it into `pdf_annotations()`.

### `pdf_form_fields`

| column | type | writer correspondence |
|---|---|---|
| `field_index` | integer | identity |
| `page_num` | integer | derivable but useful |
| `field_type` | character | intrinsic; writers can't change it |
| `field_flags` | integer | raw mask, settable |
| `is_readonly` / `_required` / `_no_export` | logical | decoded; writer accepts these or raw |
| `is_checked` | logical | set via `FPDFAnnot_SetFormFieldValue` + appearance state |
| `name` | character | intrinsic |
| `alternate_name` | character | settable |
| `value` | character | settable |
| `bounds_*` | numeric | settable via `FPDFAnnot_SetRect` |
| `options` | list-column | intrinsic |

**Audit findings:**

1. **Missing:** `is_option_selected` (per option, for combo/listbox)
   and `export_value` (for buttons). Tier 1 additions.

2. **Missing:** `control_index` for radio-button groups (which
   widget within a multi-widget field is this row). Tier 1.

3. **Missing:** `additional_actions_javascript` (read-only; per-field
   JS triggers). Tier 1.

4. **Audit note:** `value` for choice fields returns the selected
   *label*, not the *export value*. PDF distinguishes the two. For
   round-tripping, the writer needs the export value too. The new
   `export_value` column closes this.

### `pdf_page_objects`

Returns a `list` of `pdfium_obj` S3 objects, each carrying a live
`FPDF_PAGEOBJECT` handle. **The handle is the identity** — writers
take an `obj` directly.

* No tibble: this is the right shape for write-friendliness. Page
  objects are first-class handles, not rows.
* Status: **OK as is.**

### `pdf_obj_type` / `pdf_obj_bounds` / `pdf_obj_rotated_bounds` / `pdf_obj_has_transparency` / `pdf_obj_is_active` / `pdf_obj_matrix`

Per-object scalar accessors. Each has a counterpart setter
(`pdf_obj_set_matrix`, `pdf_obj_set_active`, ...). Reader return
shapes match writer arg shapes:

* `pdf_obj_matrix(obj)` returns a 3x2 numeric matrix; writer accepts
  the same.
* `pdf_obj_bounds(obj)` returns `c(left, bottom, right, top)`; writer
  for moving an object is `pdf_obj_set_matrix()`, not a direct
  set-bounds (PDFium-API constraint).

**Status:** **OK as is.**

### `pdf_path_segments`

Tibble of segment_type / x / y / is_close.

* Writer counterpart: `pdf_path_new()` + per-segment
  `pdf_path_move_to(path, x, y)` / `_line_to` / `_bezier_to` /
  `_close`.
* The tibble's `segment_type` ∈ `{"moveto", "lineto", "bezierto",
  "close"}` maps directly to PDFium's MOVETO / LINETO / BEZIERTO /
  the CLOSE flag.

**Audit findings:**

1. **Missing Bezier control points.** Today `pdf_path_segments()`
   reports a single `(x, y)` per row. For a `"bezierto"` segment,
   that's the end-point — the two control points are *not* exposed
   (PDFium's `FPDFPathSegment_GetPoint()` returns only one point per
   segment, and the spec models a Bezier as three consecutive
   segments in the segment list). The current tibble *does* expose
   each of those three rows, so this is already correct. **No
   change needed; documentation should clarify.**

2. **Future-proof:** add a `point_role` column ("anchor",
   "control1", "control2") so writers can disambiguate. Actually,
   PDFium already orders the segments so the three Bezier rows are
   sequential; a writer can re-assemble them. The reader's job is to
   report what PDFium reports.

   Decision: **defer** the `point_role` column; current shape is
   sufficient for round-tripping.

### `pdf_path_stroke` / `pdf_path_fill` / `pdf_path_dash` / `pdf_path_line_cap` / `pdf_path_line_join`

All return small lists / vectors. Each has a corresponding setter on
the writer side. The shapes match.

**Audit finding:** the `dash` field is a `list(count, array, phase)`
already. The writer takes `array` as a numeric vector and `phase` as
a numeric scalar — exact symmetry. Status: **OK as is.**

### `pdf_text_runs`

| column | writer correspondence |
|---|---|
| `run_index` | identity |
| `text` | settable via `FPDFText_SetText` |
| `font_size` | settable via `FPDFTextObj_SetFontSize` |
| `font_name` | settable via setting the font handle |
| `render_mode` | settable via `FPDFTextObj_SetTextRenderMode` |
| `bounds_*` | derived; writers set the position matrix |
| `matrix` | list-column of 3x2 matrices |

**Audit findings:** writers operate on the underlying text object
handle. The tibble's `run_index` indexes into `pdf_page_objects()`
filtered to text objects. **Need:** add an `obj_index` column so the
mapping is explicit. Tier 1 audit fix.

### `pdf_text_chars`

Per-character readout. No direct writer (PDFium has no per-character
edit API). Status: **OK as is, read-only.**

### `pdf_text_colors`

Per-character fill + stroke RGBA. Read-only at the character level;
mutation goes through the parent text object (`pdf_obj_set_fill_color`).
Status: **OK as is.**

### `pdf_text_search`

Match results. Read-only. Status: **OK as is.**

### `pdf_image_info` / `pdf_image_size` / `pdf_image_bitmap` / `pdf_image_rendered` / `pdf_image_data` / `pdf_image_filters`

Per-image-object readers. Writers operate on the page object handle
directly (`pdf_image_obj_set_bitmap`, `pdf_image_obj_set_matrix`).
Already write-symmetric. Status: **OK as is.**

### `pdf_form_objects`

Form XObject enumeration. Mutation = `FPDFFormObj_RemoveObject` +
`FPDFFormObj_AppendObject` on the sub-objects. The reader already
returns object handles. Status: **OK as is.**

### `pdf_obj_clip_path` / `pdf_clip_path_count` / `pdf_clip_path_segments`

Clip-path readers. Writers add clipping via
`FPDFPageObj_TransformClipPath` + path construction. The current
reader output is structurally compatible with writer inputs.
Status: **OK as is.**

### `pdf_signatures` / `pdf_signature_contents` / `pdf_signature_byte_range`

Signature metadata. PDFium does **not** expose signature creation
through the public API. Read-only by upstream constraint. Status:
**OK as is.**

### `pdf_attachments` / `pdf_attachment_data`

| reader output | writer counterpart |
|---|---|
| `attachment_index` | identity for setters |
| `name` | settable via `FPDFAttachment_SetStringValue("UF", ...)` |
| `description` | settable |
| `subtype` | settable |
| `size` / `creation_date` / `modification_date` | settable via dict mutation |
| `data` (raw bytes) | settable via `FPDFAttachment_SetFile` |

Writers go through `pdf_attachment_new()` / `pdf_attachment_delete()`
/ `pdf_attachment_set_*()`. **Status: OK as is.**

### `pdf_structure_tree`

Tagged-PDF structure tree readout.

* Writer counterpart: PDFium does **not** expose direct mutation of
  the `/StructTreeRoot`. 0.2.0 will not ship structure mutation.
* Status: **OK as is, read-only.**

**Audit finding:** add `attributes` list-column (Tier 2) so the
`FPDF_StructElement_GetAttribute*` family is surfaced. Read-only
addition.

### `pdf_render_page` / `pdf_render_to_png` / `plot.pdfium_bitmap`

Rendering pipeline. The output is a bitmap, not a writer input;
asymmetric by nature. Status: **OK as is.**

### `pdf_extract_paths`

One-call helper that wraps `pdf_page_objects()` + `pdf_path_*()` for
the kmextract use case. Already a thin layer over composable
readers. Status: **OK as is.**

## Action items rolled up

The audit produces a short list of reader-API adjustments needed
for write-symmetry. All are additive (no breaking change to existing
column types or row counts):

| Reader | Change | Tier | Status |
|---|---|---|---|
| `pdf_annotations` | add `subtype_code` integer column | Tier 1 | TODO |
| `pdf_annotations` | add `quad_points` list-column | Tier 1 | TODO |
| `pdf_annotations` | add `vertices` list-column | Tier 1 | TODO |
| `pdf_annotations` | add `ink_paths` list-column | Tier 1 | TODO |
| `pdf_annotations` | add `linked_index` integer column | Tier 2 | TODO |
| `pdf_annotations` | add `font_color_*` + `font_size` columns | Tier 2 | TODO |
| `pdf_form_fields` | add `is_option_selected` list-column | Tier 1 | TODO |
| `pdf_form_fields` | add `export_value` column | Tier 1 | TODO |
| `pdf_form_fields` | add `control_index` integer | Tier 1 | TODO |
| `pdf_form_fields` | add `additional_actions_js` list-column | Tier 1 | TODO |
| `pdf_form_fields` | document the value/export distinction | Tier 1 | TODO |
| `pdf_page_links` | add `quad_points` list-column | Tier 1 | TODO |
| `pdf_text_runs` | add `obj_index` integer column | Tier 1 | TODO |
| `pdf_structure_tree` | add `attributes` list-column | Tier 2 | TODO |
| `pdf_path_segments` | clarify Bezier triple in docs | Tier 1 | TODO |

All other readers pass the audit unchanged.

## Tier 3 readers landed in 0.1.0

The "Tier 3" section originally documented several PDFium readers
as deferred to v0.2.0. After a refresh pass driven by the
"reconstructing challenging character mappings" use case, all but a
small genuinely-niche residue have landed in v0.1.0:

| Reader added | Wraps | Use case |
|---|---|---|
| `pdf_glyph_path()` | `FPDFFont_GetGlyphPath` + glyph-segment walk | Glyph outline reconstruction for ToUnicode-CMap auditing |
| `pdf_glyph_width()` | `FPDFFont_GetGlyphWidth` | Layout / advance-width spot-checks |
| `pdf_text_font_metrics()` | `FPDFFont_GetAscent` / `GetDescent` | Font ascent + descent at a given size |
| `pdf_text_chars()$char_font_name`, `$char_font_flags` | `FPDFText_GetFontInfo` | Per-character font info (catches PDFs that switch fonts within a run) |
| `pdf_render_page_with_matrix()` | `FPDF_RenderPageBitmapWithMatrix` | Crop-and-zoom rendering, shear, custom projections |
| `pdf_annot_dict_value()` | `FPDFAnnot_HasKey` + `GetValueType` + `GetStringValue` + `GetNumberValue` | Generic by-key annotation-dict probe |
| `pdf_annot_appearance()` | `FPDFAnnot_GetAP` | Annotation `/AP` appearance-stream content per appearance mode |
| `pdf_link_annot_at_point()` | `FPDFLink_GetLinkAtPoint` + `FPDFLink_GetAnnot` | Hit-test that returns the underlying annotation_index |
| `pdf_obj_marked_content_id()` | `FPDFPageObj_GetMarkedContentID` | Fast-path single-int direct MCID for a page object |
| `pdf_doc_focusable_subtypes()` | `FPDFAnnot_GetFocusableSubtypes*` | Tab-focus annotation subtypes for round-tripping the writer setter |
| `pdf_structure_tree()$attributes` recurses arrays | `FPDF_StructElement_Attr_CountChildren` + `GetChildAtIndex` | Nested arrays (`/BBox`, `/RowSpan`, ...) come back as R lists |

### Still deferred — and why

These reader symbols intentionally do NOT land in v0.1.0:

| Deferred symbol | Reason |
|---|---|
| `FPDFAnnot_GetObject` | Returns an embedded page-object handle from a stamp / FreeText annotation. Useful in principle, but requires wrapping the handle as a child object whose parent is the annotation — a small S3-class change that fits the v0.2.0 mutation work better. |
| `FPDFAnnot_IsSupportedSubtype` / `IsObjectSupportedSubtype` | Viewer-UI capability checks. Returns whether PDFium's reference viewer can render this subtype; not useful for tabular workflows. |
| `FPDFAvail_*` (streaming) | Incremental loading from network sources. The `pdfium` package's "open a local file" core workflow doesn't benefit; the streaming API would only matter for an HTTP-backed wrapper, which is out of scope. |
| `FPDF_GetDefaultTTFMapEntry`, `FPDF_FreeDefaultSystemFontInfo` | Internal font-resolution tables that PDFium uses for fallback glyph rendering. Not interpretable at the R level without exposing PDFium's full font-substitution machinery. |
| `FPDF_RenderPageBitmapWithColorScheme_Start` | Progressive rendering with a custom palette (used for "dark mode" PDF viewers). Niche; users wanting custom colours can post-process the bitmap from `pdf_render_page()` array-wise. |
| `FPDFPage_TransFormWithClip` | Mutation — fits the v0.2.0 plan. |
| `FPDF_StructElement_GetParent` | Already addressable via `pdf_structure_tree()$parent_index`. |
| `FPDF_StructElement_GetStringAttribute` | Already addressable via filtering `pdf_structure_tree()$attributes` on the desired key. |
| `FPDF_StructElement_GetChildMarkedContentID` | Per-child MCID detail. The element-level `mcid` / `mcid_count` columns already aggregate; the per-K-child distinction is rarely meaningful for downstream consumers. |

Everything else PDFium exposes as a reader is wrapped.

## Helpers the writer layer will need

* `pdfium_annot_subtype_code(name)` / `pdfium_annot_subtype_name(code)`
* `pdfium_action_type_code(name)` / already have `_name()`
* `pdfium_field_flag_encode(named_logical_vec)` / `_decode()`
* `pdfium_annot_flag_encode(named_logical_vec)` / `_decode()`
* `pdf_format_date(time)` to emit `D:YYYYMMDDHHMMSS+HH'MM'` strings
  matching what `pdf_parse_date()` consumes.

These ship with 0.1.0 (read-side has the `_decode()` already; we
add `_encode()` and `_code()` peers).
