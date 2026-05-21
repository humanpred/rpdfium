# pdfium 0.1.0

Initial CRAN release. This is the first public version of `pdfium`,
an R wrapper for Google's PDFium C API. The package surface is split
into a comprehensive **read** layer (parse and inspect any PDF) and
a focused **mutation** layer (open with `readwrite = TRUE` to enable;
PDFs created with `pdf_doc_new()` are also writable).

## Documents and pages

* `pdf_doc_open()` / `pdf_doc_close()`, `pdf_doc_new()`,
  `pdf_save()` / `pdf_save_to_raw()` — open existing PDFs (optionally
  with `readwrite = TRUE`), build new ones in memory, and persist
  the result. The `path =` argument of `pdf_doc_open()` accepts
  either a local filesystem path or a URL (any scheme `base::url()`
  recognises — typically `http://` / `https://` / `ftp://` /
  `file://`); URL input is fetched into raw bytes via `url()` +
  `readBin()` and loaded through PDFium's `FPDF_LoadMemDocument64`,
  with no temporary file on disk.
* `pdf_doc_info()`, `pdf_doc_meta()`, `pdf_doc_text()`,
  `pdf_doc_fonts()`, `pdf_doc_file_id()`, `pdf_doc_page_mode()`,
  `pdf_doc_viewer_preferences()`, `pdf_doc_viewer_preference_by_name()`,
  `pdf_doc_permissions()`, `pdf_doc_user_permissions()`,
  `pdf_doc_security()`, `pdf_doc_xref_valid()`,
  `pdf_doc_trailer_ends()`, `pdf_doc_is_tagged()`,
  `pdf_doc_javascript()`, `pdf_doc_focusable_subtypes()` — document-
  level inspection.
* `pdf_doc_named_dests()`, `pdf_doc_named_dest_by_name()`,
  `pdf_doc_bookmarks()`, `pdf_doc_bookmark_find()`,
  `pdf_page_label()`, `pdf_page_labels()` — outlines and named
  destinations.
* `pdf_page_load()` / `pdf_page_close()`, `pdf_page_size()`,
  `pdf_page_rotation()`, `pdf_page_box()`, `pdf_page_thumbnail()` —
  per-page handles and metadata.
* `pdf_doc_summary()` and `pdf_pages_summary()` — one-call triage
  helpers. `pdf_doc_summary()` returns a single-row tibble
  aggregating the most-asked-for facts about a PDF (path, page
  count, Info-dictionary metadata, feature flags, per-feature
  counts, file-ID tuple); `pdf_pages_summary()` is the per-page
  sibling (width / height / rotation / label, all via the fast
  by-index PDFium readers). `summary(doc)` and `summary(page)`
  dispatch to the matching tibble — `summary(page)` adds the
  page-loaded counts (annotation count, page-object count,
  text-run count, link count) since the page is already loaded.
* `summary()` S3 methods for every `pdfium_*_list` class:
  `pdfium_obj_list`, `pdfium_annot_list`, `pdfium_attachment_list`,
  `pdfium_signature_list`, `pdfium_bookmark_list`, and
  `pdfium_form_field_list`. Each dispatches to the matching
  `as_tibble.*` method so `summary(x)` returns the same tibble
  view `tibble::as_tibble(x)` would — matching the R idiom of
  `print()` for the one-line summary and `summary()` for the deep
  dive.

## Scope retraction

Two functions added during 0.1.0 development were retracted before
release on scope grounds (see `CLAUDE.md` §"Scope"):

* **`pdf_doc_open_url()`** — folded into `pdf_doc_open(path = ...)`.
  The URL-fetching layer is just `base::url()` + `readBin()` ahead
  of PDFium's existing in-memory path, so a separate exported
  symbol added surface for no PDFium-specific behaviour.
* **`pdf_dir_summary()`** — removed. Its body was `list.files()`
  + `lapply(pdf_doc_summary)`; users with bulk-triage needs can
  write the loop themselves in three lines. Keeping it set a
  precedent for "convenience over a base R loop" creep that the
  package's PDFium-wrapper mandate doesn't want.

## Page objects, paths, and text

* `pdf_page_objects()` returns a `pdfium_obj_list`; per-handle
  accessors `pdf_obj_type()`, `pdf_obj_bounds()`,
  `pdf_obj_rotated_bounds()`, `pdf_obj_matrix()`,
  `pdf_obj_has_transparency()`, `pdf_obj_is_active()`,
  `pdf_obj_marks()`, `pdf_obj_marked_content_id()`,
  `pdf_obj_clip_path()` cover every column.
* `pdf_path_segments()`, `pdf_path_stroke()`, `pdf_path_fill()`,
  `pdf_path_dash()`, `pdf_path_line_cap()`, `pdf_path_line_join()`,
  `pdf_path_draw_mode()` — path geometry + style.
* `pdf_text_runs()`, `pdf_text_content()`, `pdf_text_font()`,
  `pdf_text_font_metrics()`, `pdf_text_chars()`, `pdf_text_colors()`,
  `pdf_text_render_mode()`, `pdf_text_search()`,
  `pdf_text_char_at_point()`, `pdf_text_index_from_char()`,
  `pdf_text_char_from_text_index()`, `pdf_text_char_obj_index()`,
  `pdf_text_obj_rendered_bitmap()`, `pdf_glyph_path()`,
  `pdf_glyph_width()` — text inspection at every granularity.
* `pdf_image_info()`, `pdf_image_size()`, `pdf_image_bitmap()`,
  `pdf_image_rendered()`, `pdf_image_data()`, `pdf_image_filters()`,
  `pdf_image_icc_profile()` — image-object readouts.
* `pdf_clip_path_count()`, `pdf_clip_path_segments()` — clip-path
  geometry.
* `pdf_form_objects()` — Form XObject child enumeration.
* `pdf_extract_paths()` — one-call helper for the path-extraction
  workflow that motivated the package.
* `pdf_structure_tree()` — tagged-PDF / accessibility structure tree
  walk.

## Annotations and form fields

* `pdf_annotations()` returns a `pdfium_annot_list`;
  `pdf_annot_subtype()`, `pdf_annot_flags()`,
  `pdf_annot_flags_decoded()`, `pdf_annot_bounds()`,
  `pdf_annot_contents()`, `pdf_annot_title()`, `pdf_annot_subject()`,
  `pdf_annot_color()`, `pdf_annot_interior_color()`,
  `pdf_annot_border_width()`, `pdf_annot_font_size()`,
  `pdf_annot_font_color()`, `pdf_annot_dict_value()`,
  `pdf_annot_appearance()`, `pdf_annot_quad_points()`,
  `pdf_annot_vertices()`, `pdf_annot_ink_paths()`,
  `pdf_annot_popup()`, `pdf_annot_in_reply_to()`,
  `pdf_annot_file_attachment_name()`, `pdf_annot_at()` cover the
  full read surface.
* `pdf_form_fields()` returns a `pdfium_form_field_list`;
  `pdf_form_field_type()`, `pdf_form_field_name()`,
  `pdf_form_field_value()`, `pdf_form_field_export_value()`,
  `pdf_form_field_flags()`, `pdf_form_field_flags_decoded()`,
  `pdf_form_field_is_checked()`, `pdf_form_field_control_count()`,
  `pdf_form_field_control_index()`, `pdf_form_field_options()`,
  `pdf_form_field_is_option_selected()`,
  `pdf_form_field_additional_actions_js()`,
  `pdf_form_field_at_point()` cover form-fill inspection.
* `pdf_page_links()`, `pdf_link_at_point()`,
  `pdf_link_annot_at_point()`, `pdf_page_actions()` — link and
  action introspection.

## Attachments and signatures

* `pdf_attachments()` returns a `pdfium_attachment_list`;
  `pdf_attachment_name()`, `pdf_attachment_mime_type()`,
  `pdf_attachment_size_bytes()`, `pdf_attachment_data()`,
  `pdf_attachment_dict_value()` cover the read side.
* `pdf_signatures()` returns a `pdfium_signature_list`;
  `pdf_signature_sub_filter()`, `pdf_signature_reason()`,
  `pdf_signature_time()`, `pdf_signature_doc_mdp_permission()`,
  `pdf_signature_contents()`, `pdf_signature_byte_range()` — digital
  signature metadata.

## Rendering

* `pdf_render_page()`, `pdf_render_page_with_matrix()`,
  `pdf_render_to_png()` — page-to-bitmap and page-to-file
  rendering, with full `FPDF_RenderPageBitmap*` flag coverage.
* `plot()`, `as.raster()`, `as.array()`, `as.matrix()` methods for
  `pdfium_bitmap` — interoperate with the existing R graphics stack.

## Structural mutation (open with `readwrite = TRUE`)

* `pdf_page_new()`, `pdf_page_delete()`, `pdf_pages_reorder()`,
  `pdf_docs_merge()`, `pdf_n_up()`, `pdf_page_set_rotation()`,
  `pdf_page_set_box()`, `pdf_doc_set_language()`, `pdf_page_flush()`
  — add, remove, reorder, and reshape pages.

## v0.1.0 "complete the relevant PDFium surface" pass

A late v0.1.0 pass closes the remaining wrapping gaps so that every
PDFium public symbol that maps cleanly to an R-side concept now has
a wrapper. New exports broken out by topic:

### Text low-level geometry

* `pdf_text_rects()` — `FPDFText_CountRects` + `FPDFText_GetRect`.
  Returns a tibble of axis-aligned rectangles for a character range.
* `pdf_text_bounded()` — `FPDFText_GetBoundedText`. Extracts Unicode
  text inside a bounding rectangle on the page.
* `pdf_text_char_geometry()` — `FPDFText_GetMatrix` +
  `FPDFText_GetCharAngle` + `FPDFText_GetFontWeight`. Returns a
  per-character tibble (`char_index`, `matrix`, `angle_deg`,
  `font_weight`); the matrix column is a list-column of length-6
  numeric vectors.

### Page + document probes

* `pdf_doc_form_type()` — `FPDF_GetFormType` (none / acro_form /
  xfa_full / xfa_foreground).
* `pdf_page_has_transparency()` — `FPDFPage_HasTransparency`.
* `pdf_page_bounding_box()` — `FPDF_GetPageBoundingBox`.
* `pdf_page_transform_annots()` — `FPDFPage_TransformAnnots`.
* `pdf_annot_index()` — `FPDFPage_GetAnnotIndex`.
* `pdf_device_to_page()` / `pdf_page_to_device()` — `FPDF_DeviceToPage`
  / `FPDF_PageToDevice` coordinate conversion.
* `pdf_bookmark_child_count()` — `FPDFBookmark_GetCount`.

### Page-object setters

* `pdf_path_set_dash_phase()` — `FPDFPageObj_SetDashPhase`. Fine-
  grained complement to `pdf_path_set_dash()`.
* `pdf_obj_mark_set_blob()` / `pdf_obj_mark_remove_param()` —
  `FPDFPageObjMark_SetBlobParam` / `RemoveParam`.

### Font extras

* `pdf_font_data()` — `FPDFFont_GetFontData`. Extracts the bytes
  of an embedded font (raw vector).
* `pdf_font_load_cidtype2()` — `FPDFText_LoadCidType2Font`. Loads
  a CID Type 2 (composite TrueType) font with explicit ToUnicode
  CMap and CID-to-GID mapping.
* `pdf_text_set_charcodes()` — `FPDFText_SetCharcodes`. Sets
  explicit glyph charcodes on a text object (bypasses the font's
  cmap; lower-level than `pdf_text_set_content()`).

### Annotation authoring completers

* `pdf_annot_add_ink_stroke()` / `pdf_annot_remove_ink_list()` —
  `FPDFAnnot_AddInkStroke` / `RemoveInkList`. Build / clear the
  ink-list of an ink annotation.
* `pdf_annot_object_count()`, `pdf_annot_objects()`,
  `pdf_annot_append_object()`, `pdf_annot_remove_object()`,
  `pdf_annot_update_object()` — `FPDFAnnot_GetObjectCount` /
  `GetObject` / `AppendObject` / `RemoveObject` / `UpdateObject`.
  Manage the embedded page-objects inside stamp / freetext
  annotations.
* `pdf_annot_set_uri()` — `FPDFAnnot_SetURI`.
* `pdf_annot_set_appearance()` — `FPDFAnnot_SetAP` (modes: `normal`,
  `rollover`, `down`).
* `pdf_annot_add_file_attachment()` — `FPDFAnnot_AddFileAttachment`.
* `pdf_annot_line()` — `FPDFAnnot_GetLine`. Endpoints of a line
  annotation.
* `pdf_annot_link()` — `FPDFAnnot_GetLink` + action / dest
  classifier. Returns a 1-row tibble (action_type, uri, filepath,
  dest_page, dest_view, dest_x, dest_y, dest_zoom).
* `pdf_annot_set_border()` — `FPDFAnnot_SetBorder` (corner radii +
  width).

* `pdf_annot_set_font_color()`, `pdf_form_field_set_flags()`,
  `pdf_doc_set_focusable_subtypes()` — `FPDFAnnot_SetFontColor` /
  `_SetFormFieldFlags` / `_SetFocusableSubtypes`. These three
  setters route through a transient form-fill environment; our
  RAII wrapper around `FPDFDOC_InitFormFillEnvironment` /
  `_ExitFormFillEnvironment` originally stored the
  `FPDF_FORMFILLINFO` struct as a constructor-local, which went
  out of scope before Exit ran and segfaulted PDFium when it
  dereferenced its retained pointer. Root-caused via gdb and
  documented in `dev/reprex/README.md`; fixed by moving the
  `FORMFILLINFO` to a struct member.

### Clip-path authoring

* `pdf_clip_path_new()` — `FPDF_CreateClipPath`. Returns a new
  `pdfium_clip_box` S3 class (named `_clip_box` to avoid colliding
  with the existing read-side `pdfium_clip_path` class returned by
  `pdf_obj_clip_path()`).
* `pdf_clip_path_close()` — `FPDF_DestroyClipPath` (idempotent).
* `pdf_page_insert_clip_path()` — `FPDFPage_InsertClipPath`.
  Transfers ownership of the clip box to the page.
* `pdf_obj_transform_clip_path()` — `FPDFPageObj_TransformClipPath`.
* `pdf_page_transform_with_clip()` — `FPDFPage_TransFormWithClip`.

### Form-XObject + page-merge extras

* `pdf_xobject_from_page()` — `FPDF_NewXObjectFromPage`. Copies a
  page's visual content from a source doc into the destination doc
  as a reusable form XObject. Returns the new `pdfium_xobject` S3
  class.
* `pdf_xobject_close()` — `FPDF_CloseXObject`.
* `pdf_obj_form_from_xobject()` — `FPDF_NewFormObjectFromXObject` +
  `FPDFPage_InsertObject`. Instantiates an XObject on a page as a
  form page-object.
* `pdf_form_obj_remove_object()` — `FPDFFormObj_RemoveObject`.
  Removes a child page-object from a form XObject.
* `pdf_docs_import_pages()` — `FPDF_ImportPages` (string-range
  variant of `pdf_docs_merge()`, e.g. `"1-3,5,7-10"`).

### Image-bitmap embedding

* `pdf_bitmap_new()` / `pdf_bitmap_close()` — `FPDFBitmap_Create` /
  `Destroy`. New `pdfium_image_buffer` S3 class wrapping
  `FPDF_BITMAP` handles. Named `_image_buffer` to avoid colliding
  with the existing read-side `pdfium_bitmap` class (the integer
  matrix returned by `pdf_render_page()`).
* `pdf_bitmap_info()` — width / height / stride / format.
* `pdf_bitmap_fill_rect()` — `FPDFBitmap_FillRect` (color encoded
  as `0xAARRGGBB`).
* `pdf_bitmap_buffer()` / `pdf_bitmap_set_buffer()` —
  `FPDFBitmap_GetBuffer` + setter. Read or write raw pixel bytes
  as a length-checked raw vector.
* `pdf_image_set_bitmap()` — `FPDFImageObj_SetBitmap`. The v0.1.0
  PNG / raw-bitmap embedding path; pair with `pdf_image_new()` for
  the JPEG path.

### System font integration

* `pdf_system_fonts_default_ttf_map()` —
  `FPDF_GetDefaultTTFMap[Count|Entry]`. Returns a tibble of
  (`charset`, `fontname`) — PDFium's built-in substitution table.
* `pdf_system_fonts_install_default()` —
  `FPDF_SetSystemFontInfo(FPDF_GetDefaultSystemFontInfo())`. Enables
  the platform's default sys-font-info provider so PDFium can
  resolve missing glyphs against installed system fonts.

  Custom-provider registration (`FPDF_SetSystemFontInfo` with an
  R-defined `FPDF_SYSFONTINFO` struct + R-side callbacks) is
  deferred — it requires marshalling PDFium's font-resolution
  callback table into R closures, which is non-trivial.

## Page-object mutation

* `pdf_obj_set_matrix()`, `pdf_obj_set_active()`,
  `pdf_obj_set_blend_mode()`, `pdf_path_set_stroke()`,
  `pdf_path_set_fill()`, `pdf_path_set_line_cap()`,
  `pdf_path_set_line_join()`, `pdf_path_set_dash()`,
  `pdf_path_set_draw_mode()`, `pdf_text_set_content()`,
  `pdf_text_set_render_mode()`, `pdf_obj_add_mark()`,
  `pdf_obj_remove_mark()` — styling and metadata setters.
* `pdf_path_move_to()`, `pdf_path_line_to()`, `pdf_path_bezier_to()`,
  `pdf_path_close()`, `pdf_path_append()` — append path geometry to
  an existing path object.
* `pdf_path_new()`, `pdf_rect_new()`, `pdf_text_new()`,
  `pdf_image_new()`, `pdf_obj_delete()` — create fresh paths,
  rectangles, text objects, or JPEG images, or remove an existing
  object. `pdf_text_new()` accepts either a standard-font name or
  a `pdfium_font` handle from `pdf_font_load_standard()` /
  `pdf_font_load()`; `pdf_image_new()` embeds JPEG bytes inline
  via `FPDFImageObj_LoadJpegFileInline` and lets you place the
  image into an explicit `bounds = c(left, bottom, right, top)`
  rectangle.
* `pdf_font_load_standard()`, `pdf_font_load()`, `pdf_font_close()`
  — load one of the 14 PDF standard fonts (no embedding) or
  embed an arbitrary TrueType / Type1 font's bytes into the
  document. Returned `pdfium_font` handles plug straight into
  `pdf_text_new()` for custom-typeface text.

## Annotation authoring

* `pdf_annot_new()`, `pdf_annot_delete()`, `pdf_annot_set_bounds()`,
  `pdf_annot_set_color()`, `pdf_annot_set_interior_color()`,
  `pdf_annot_set_flags()`, `pdf_annot_set_contents()`,
  `pdf_annot_set_title()`, `pdf_annot_set_subject()`,
  `pdf_annot_set_dict_value()`, `pdf_annot_append_quad()` — create,
  remove, and mutate annotations of the supported subtypes
  (circle, fileattachment, freetext, highlight, ink, link, popup,
  square, squiggly, stamp, strikeout, text, underline).

## Form filling

* `pdf_form_field_set_value()` — polymorphic per-field writer.
  Dispatches by field type: character for text / choice fields,
  logical or character for checkable fields. Mirrors `/V` into
  `/AS` for checkable widgets so PDFium picks the correct appearance.
* `pdf_form_field_clear()` — restore to `/DV` (or empty / `"Off"`).
* `pdf_form_reset()` — doc-wide loop over `pdf_form_field_clear()`.
* `pdf_page_flatten()` — bake form widgets and annotations into the
  page content stream (one-way; intended as the final step before
  saving a non-editable copy).

## Attachment authoring

* `pdf_attachment_new()`, `pdf_attachment_delete()`,
  `pdf_attachment_set_data()`, `pdf_attachment_set_dict_value()` —
  add embedded files, populate their bytes, and write `/Params`
  metadata.

## Enum code <-> name helpers

* `pdfium_annot_subtype_name()` / `_code()`,
  `pdfium_obj_type_name()` / `_code()`,
  `pdfium_segment_type_name()` / `_code()`,
  `pdfium_form_field_type_name()` / `_code()`,
  `pdfium_action_type_name()` / `_code()`,
  `pdfium_dest_view_name()` / `_code()` — bidirectional converters
  between PDFium's integer enum codes and short string names. Both
  vectorised; case-insensitive on input.

## Coercion helpers

Every `pdfium_*_list` class round-trips through `as_tibble()` and a
matching `as_pdfium_*_list()`. The tibble carries `handle` and
`source` list-columns; the inverse reads them back. See `?ADR-017`
in `dev/decisions/` for the rationale.

## Bundled PDFium binary

The package downloads a pinned PDFium binary from
[bblanchon/pdfium-binaries](https://github.com/bblanchon/pdfium-binaries)
at install time (configure-time on POSIX, `configure.win` on
Windows). The pin lives in `tools/pdfium-version.txt`. CRAN's
network-at-configure-time policy permits this; the offline
fallback is documented in `configure`.
