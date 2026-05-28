# pypdfium2 (Python) vs. rpdfium (R) — API comparison

## Provenance

- Compare date: 2026-05-28.
- pypdfium2 clone: shallow `main` at `/tmp/pypdfium2-compare`,
  source tree under `src/pypdfium2/_helpers/`.
- rpdfium reference: `NAMESPACE` and `_pkgdown.yml` at this worktree.
- Out-of-scope cross-reference: [`v0.1.0-api-gap-audit.md`](v0.1.0-api-gap-audit.md).
- Methodology: walk every public class / public method in
  `_helpers/*.py`, classify against the rpdfium exports.

pypdfium2 modules surveyed (all of `_helpers/`):

| File | Public classes | Notes |
|---|---|---|
| `document.py` | `PdfDocument`, `PdfFormEnv`, `PdfXObject`, `PdfBookmark`, `PdfDest` | doc + bookmark + dest + xobject |
| `page.py` | `PdfPage`, `PdfColorScheme` | page + render config |
| `textpage.py` | `PdfTextPage`, `PdfTextSearcher` | extraction + search |
| `pageobjects.py` | `PdfObject`, `PdfImage`, `PdfTextObj`, `PdfFont` | page-object hierarchy + font |
| `bitmap.py` | `PdfBitmap`, `PdfPosConv` | render output + coord translation |
| `matrix.py` | `PdfMatrix` | pure-Python 3×2 affine |
| `attachment.py` | `PdfAttachment` | embedded files |
| `sysfontinfo.py` | `PdfSysfontBase`, `PdfDefaultTTFMap` | sysfont callback plumbing |
| `unsupported.py` | `PdfUnspHandler` | feature-not-supported callback |
| `misc.py` | `PdfiumError`, `PdfiumWarning` | exception classes |

## Top-line summary

- **MISSED**: 4 items worth a closer look — `PdfDocument.get_version()`
  (file-version getter; in 0.1.0 it's a column on `pdf_doc_info()` but
  not exposed standalone), `PdfDocument.get_identifier(type=...)`
  (we already wrap permanent IDs; pypdfium2 also lets the caller ask
  for the changing ID — small parameter gap),
  `PdfTextSearcher.get_prev()` (we have forward search only),
  `PdfTextPage.get_textobj(index)` (resolve the `pdfium_obj` that owns
  a given char index — useful for char→obj round-trips).
- **DELIBERATELY OMITTED — to reconsider**: 4 items.
  `PdfBitmap.from_pil()` / `PdfImage.set_bitmap()`-style PNG embedding
  is already deferred per the v0.2.0 plan; the *audit
  rationale* should be updated to mention pypdfium2's working
  precedent. `PdfImage.extract()` (write-to-file, pick a format from
  the filter chain) is a genuinely useful convenience. `PdfDest`
  reader exists in pypdfium2 as a separate class — we surface the
  same data as columns on `pdf_doc_bookmarks()` / named-dests
  tibbles, which is fine but worth noting.
  `PdfUnspHandler` (the unsupported-feature callback) is not
  currently wrapped and is not in the audit list at all; adding it as
  a small `pdf_set_unsupported_handler(callback)` would be cheap
  diagnostic value.
- **Convenience helpers worth adapting**: 6. `PdfDocument` as an
  iterable / length-supporting object → rpdfium could expose a
  `length.pdfium_doc()` (already implicit via `pdf_page_count()`)
  and a tidyverse-friendly `pdfium_doc` accessor (not part of the
  CRAN scope but listed for v0.3+). The
  `PdfBitmap.to_pil()` / `to_numpy()` /
  `from_pil()` triad has direct R analogues
  (`as.raster.pdfium_bitmap`, `as.array.pdfium_bitmap`,
  `as.matrix.pdfium_bitmap`), so this is mostly *already* present;
  the missing piece is a `magick`-style adapter. The
  `PdfTextPage._get_active_text_range` machinery (skip
  inserted/excluded chars) is a subtle correctness fix worth
  porting into `pdf_text_chars()` if we don't already do it.
  `PdfDocument.METADATA_KEYS` exposed as a constant
  is mildly useful (we already return all keys from
  `pdf_doc_meta()` so this is minor).
  `PdfImage.extract()` is the same item flagged in the
  to-reconsider bucket above. `PdfBitmap.get_posconv()` →
  bitmap→page coord translator: we have `pdf_device_to_page()` /
  `pdf_page_to_device()` but the API requires the caller to remember
  the render's `start_x/start_y/size_x/size_y/rotate`; pypdfium2
  attaches them to the bitmap. Stashing render args on the
  `pdfium_bitmap` would let us provide a `pdf_bitmap_posconv()`
  that has the args already.
- **Idiomatic differences (not gaps)**: pypdfium2 returns iterators
  / generators where rpdfium returns tibbles; pypdfium2 uses
  context managers (`with PdfDocument(path):`) where rpdfium uses
  finalizers + explicit `pdf_doc_close()`. pypdfium2's `PdfMatrix`
  is a Python class with `.translate()` / `.scale()` / `.rotate()`
  / `.skew()` methods where rpdfium passes raw 3×2 numeric
  matrices and lets the user compose via base R. The whole reader
  shape (one row per annotation, one row per char, etc.) is much
  more discoverable in R than the iterator-of-handles approach
  pypdfium2 uses.

## MISSED functions

| pypdfium2 name | PDFium symbols it wraps | What an rpdfium R name might be | Use case |
|---|---|---|---|
| `PdfDocument.get_version()` ([`_helpers/document.py:265`](file:///tmp/pypdfium2-compare/src/pypdfium2/_helpers/document.py)) | `FPDF_GetFileVersion` | `pdf_doc_file_version(doc)` | Direct accessor for `15` / `17` etc. We already expose this as `pdf_doc_info()$file_version` — adding a standalone is one-liner symmetry with other `pdf_doc_*` accessors. Low priority; arguably already covered. |
| `PdfDocument.get_identifier(type=FILEIDTYPE_PERMANENT \| FILEIDTYPE_CHANGING)` ([`_helpers/document.py:248`](file:///tmp/pypdfium2-compare/src/pypdfium2/_helpers/document.py)) | `FPDF_GetFileIdentifier(type=...)` with the type enum | `pdf_doc_file_id(doc, which = c("permanent", "changing"))` | rpdfium's `pdf_doc_file_id()` exists but always returns the permanent ID. PDFium's enum has two values — the *changing* one is regenerated each time the PDF is incrementally saved, useful for revision tracking. Small parameter addition. |
| `PdfTextSearcher.get_prev()` ([`_helpers/textpage.py:329`](file:///tmp/pypdfium2-compare/src/pypdfium2/_helpers/textpage.py)) | `FPDFText_FindPrev` | rpdfium's `pdf_text_search()` only iterates forward via `FPDFText_FindNext` | `FPDFText_FindPrev` lets you walk backward from the latest hit. Niche but free if we already have the searcher handle plumbing in place. Worth a check before CRAN. |
| `PdfTextPage.get_textobj(index)` ([`_helpers/textpage.py:241`](file:///tmp/pypdfium2-compare/src/pypdfium2/_helpers/textpage.py)) | `FPDFText_GetTextObject` | `pdf_text_obj_at_char(page, char_index)` | Returns the `pdfium_obj` (TEXT type) that contains a given char index. We expose `pdf_text_char_obj_index()` to get the obj-index, but the caller then has to round-trip through `pdf_page_objects()` to materialize the handle. A direct handle-returning helper would shave a step for the layout-reconstruction use case. |

## DELIBERATELY OMITTED — to reconsider

| pypdfium2 name | Why pypdfium2 includes it | Why we excluded | Recommendation |
|---|---|---|---|
| `PdfBitmap.from_pil()` + `PdfImage.set_bitmap()` ([`_helpers/bitmap.py:281`](file:///tmp/pypdfium2-compare/src/pypdfium2/_helpers/bitmap.py), [`_helpers/pageobjects.py:415`](file:///tmp/pypdfium2-compare/src/pypdfium2/_helpers/pageobjects.py)) | Embed any-format raster (PNG, TIFF, in-memory pixel data) as an image page-object | Per [`v0.2.0-plan.md`](v0.2.0-plan.md) §1 non-goals, "PNG / TIFF / raw-bitmap image embedding" was deferred. Workaround: convert to JPEG with `magick::image_write()` and use `pdf_image_new()`. We *do* now wrap `FPDFBitmap_Create*` + `FPDFImageObj_SetBitmap` in v0.1.0 as `pdf_bitmap_*` / `pdf_image_set_bitmap`. | **Partial — already there, just not user-facing as a single call.** v0.1.0 ships every primitive needed (`pdf_bitmap_new`, `pdf_bitmap_set_buffer`, `pdf_image_set_bitmap`). A small `pdf_image_new_from_bitmap(doc, bitmap)` or `pdf_image_new_from_raster(doc, raster)` wrapper would close the gap without new symbols. Track for v0.2.x rather than v0.1.0. |
| `PdfImage.extract(dest, fb_format = ...)` ([`_helpers/pageobjects.py:542`](file:///tmp/pypdfium2-compare/src/pypdfium2/_helpers/pageobjects.py)) | One-call write-image-to-file: walks the filter chain, picks JPEG / JPEG2000 / PNG / TIFF based on what's in the stream, falls back to PIL re-encode for everything else | Not in the audit document. We expose `pdf_image_data()` (raw or simple-decoded bytes), `pdf_image_filters()` (filter names), and `pdf_image_bitmap()` (rasterize) — but the caller has to assemble these themselves to extract an image. | **Add — convenience win, low risk.** The "best-effort image extraction" pattern is widely used. R analogue: `pdf_image_extract(obj, path)` returning the on-disk format chosen. Can defer to v0.2.x; not blocking 0.1.0 CRAN. Note that pypdfium2's implementation depends on PIL for the fallback; rpdfium would use `magick` (already a soft dependency target for image embedding). |
| `PdfDest` reader class ([`_helpers/document.py:670`](file:///tmp/pypdfium2-compare/src/pypdfium2/_helpers/document.py), `get_index`, `get_view`) | Represent a `/Dest` action target as its own object with `get_index()` / `get_view()` accessors | rpdfium does not have a separate `pdfium_dest` class. Instead, every reader that surfaces destinations (`pdf_doc_bookmarks()`, `pdf_doc_named_dests()`, `pdf_page_links()`, `pdf_link_at_point()`, `pdf_page_actions()`) returns `dest_view` / `dest_x` / `dest_y` / `dest_zoom` columns directly. | **Skip — tibble-first design is the deliberate R idiom.** The shape difference is the right call for R. Keep the rationale documented somewhere (it's implicit in the `v0.2.0-plan.md` reader-writer contract); pypdfium2's class is the right call for an iterator-based Python API but would be friction in R. |
| `PdfUnspHandler` ([`_helpers/unsupported.py:15`](file:///tmp/pypdfium2-compare/src/pypdfium2/_helpers/unsupported.py)) | Register a callback that fires when PDFium hits an unsupported feature (XFA forms, encryption type, unimplemented annotation subtype, etc.); calls `FSDK_SetUnSpObjProcessHandler`. Lets the library *warn* about deficiencies before failing silently. | Not in the audit document. rpdfium today emits no diagnostics for unsupported-feature events. | **Add (small, optional) — diagnostic value for users debugging "why does my PDF not render right?"** Suggested R surface: `pdf_set_unsupported_handler(callback = warn)` plus a default `warning()`-based callback. The PDFium symbol involved (`FSDK_SetUnSpObjProcessHandler`) is process-global, not per-document, so it sits as a top-level utility. Defer to v0.2.0; document the gap in the audit. |

## Convenience helpers worth adapting

1. **`PdfDocument.__len__` / `__iter__` / `__getitem__`**
   ([`_helpers/document.py:121-132`](file:///tmp/pypdfium2-compare/src/pypdfium2/_helpers/document.py))
   — `len(pdf)` gives the page count, `pdf[i]` loads page `i`,
   `for page in pdf:` yields pages. R analogue: provide
   `length.pdfium_doc()` returning `pdf_page_count()` so
   `length(doc)` works. `[[` and iteration are less idiomatic in R
   but a method dispatch on `[[.pdfium_doc` returning
   `pdf_page_load(doc, i)` is feasible. Not blocking; nice for
   tidyverse-style chaining.

2. **Context manager (`with PdfDocument(path) as pdf:` →
   automatic close)**
   ([`_helpers/document.py:86-90`](file:///tmp/pypdfium2-compare/src/pypdfium2/_helpers/document.py))
   — R doesn't have native context managers, but
   `withr::with_(pdf_doc_open(path), { ... })` or a
   `pdf_with(path, function(doc) { ... })` higher-order function
   would mirror the pattern. Already trivially expressible with
   `withr::defer(pdf_doc_close(doc))`; arguably out of scope for
   CRAN 0.1.0 but worth mentioning in the architecture vignette.

3. **`PdfBitmap.to_pil()` / `from_pil()` / `to_numpy()`**
   ([`_helpers/bitmap.py:221-306`](file:///tmp/pypdfium2-compare/src/pypdfium2/_helpers/bitmap.py))
   — three first-class converters to / from the dominant imaging
   libraries. rpdfium already has `as.array.pdfium_bitmap`,
   `as.matrix.pdfium_bitmap`, `as.raster.pdfium_bitmap`,
   `plot.pdfium_bitmap`. The missing analogue is `magick::image_read`
   adapter — for users wanting to apply `magick` filters after
   render. Single-method `as_magick(bitmap)` would close the gap.
   Not a PDFium binding, so possibly out of CRAN scope; defer.

4. **`PdfTextPage._get_active_text_range` (skip inserted/excluded
   chars when extracting text by range)**
   ([`_helpers/textpage.py:88-101`](file:///tmp/pypdfium2-compare/src/pypdfium2/_helpers/textpage.py))
   — pypdfium2 has a subtle correctness fix that handles
   PDFium's `FPDFText_GetTextIndexFromCharIndex` returning -1 for
   chars that exist in the char list but are excluded from the
   text-flow representation (e.g. inserted line breaks). Worth
   verifying that rpdfium's `pdf_text_chars()` /
   `pdf_text_index_from_char()` family handles this case (it
   probably does — we wrap both `FPDFText_GetTextIndexFromCharIndex`
   and `FPDFText_GetCharIndexFromTextIndex` directly). If
   `pdf_text_bounded()` doesn't compensate, that's a bug to track.

5. **`PdfImage.extract()` — best-effort image extraction**
   (see also DELIBERATELY OMITTED table above) — combines
   `get_filters()` + `get_data(decode_simple=True)` + format
   inference; picks `.jpg` / `.jp2` / raw / PIL fallback automatically.
   Proposed R surface: `pdf_image_extract(obj, path)` returning
   the chosen format string.

6. **`PdfBitmap.get_posconv(page)` →
   `PdfPosConv.to_page(x, y)` / `to_bitmap(x, y)`**
   ([`_helpers/bitmap.py:309-325`](file:///tmp/pypdfium2-compare/src/pypdfium2/_helpers/bitmap.py),
   [`_helpers/bitmap.py:354-395`](file:///tmp/pypdfium2-compare/src/pypdfium2/_helpers/bitmap.py))
   — caches the render's `start_x/start_y/size_x/size_y/rotate`
   tuple on the bitmap, then provides a converter that
   pre-populates those args for `FPDF_DeviceToPage` /
   `FPDF_PageToDevice`. rpdfium exposes both PDFium symbols as
   `pdf_device_to_page()` / `pdf_page_to_device()`, but requires
   the user to remember the render args. Closing the gap: stash
   the render geometry on the `pdfium_bitmap` S3 object's attributes
   at render time, and offer `pdf_bitmap_to_page(bitmap, x, y)` /
   `pdf_bitmap_from_page(bitmap, x, y)` that consume those
   pre-stashed args. v0.2.x-grade convenience win.

## Idiomatic differences (not gaps)

- **Iterators vs. tibbles.** Where pypdfium2 returns a generator
  (`PdfPage.get_objects()`, `PdfDocument.get_toc()`,
  `PdfTextSearcher.get_next()` loop), rpdfium returns a tibble:
  `pdf_page_objects()` is one row per object, `pdf_doc_bookmarks()`
  is one row per bookmark (with `parent_index` / `level` columns for
  the tree), `pdf_text_search()` enumerates all matches in one
  call. R idiom; not a gap.
- **Context managers vs. finalizers.** `with PdfDocument(path) as
  pdf:` always closes promptly. rpdfium relies on the
  `R_RegisterCFinalizerEx` finalizer + optional explicit
  `pdf_doc_close()`. Already documented in the architecture
  vignette. Not a gap.
- **PdfMatrix class vs. plain 3×2 matrix.** pypdfium2's `PdfMatrix`
  has methods `.translate() / .scale() / .rotate() / .skew() /
  .mirror() / .on_point() / .on_rect()`. rpdfium passes raw 3×2
  numeric matrices; users compose with `%*%` and base R. Less
  discoverable but consistent with how R users think about
  matrices. Could provide convenience wrappers in v0.3+ if there's
  demand; not a gap for 0.1.0.
- **Box getters with fallback chain.** pypdfium2's
  `get_mediabox(fallback_ok=True)` returns ANSI A on missing
  MediaBox, `get_cropbox` falls back to MediaBox, `get_trimbox`
  falls back to CropBox, etc. rpdfium's `pdf_page_box(page, box)`
  returns `NA` (or empty) on absent boxes; the user controls
  fallback. Documenting which boxes inherit (and the
  https://crbug.com/pdfium/1786 quirk) is worth a sentence in the
  `pdf_page_box()` reference.
- **`render(scale, rotation, crop, color_scheme, ...)` 16+ keyword
  args.** pypdfium2's `PdfPage.render()` has a wide signature;
  rpdfium splits the same surface into `pdf_render_page()` (simple)
  and `pdf_render_page_with_matrix()` (matrix-driven). The
  intermediate flags (`no_smoothtext`, `force_halftone`, etc.) are
  available via `pdf_render_*` arguments. The
  `color_scheme` knob (`FPDF_COLORSCHEME`) is **not** currently
  wrapped — but the v0.1.0 audit doesn't list it. Likely intentional
  to skip; document explicitly.
- **PdfFont vs. `pdf_text_font()` / `pdf_text_font_metrics()`.**
  pypdfium2 returns a `PdfFont` handle for per-textobj lookups.
  rpdfium returns the font name + metrics directly as tibble
  columns (`font_family`, `font_weight`, `is_embedded`, plus
  ascent / descent / cap-height / x-height via
  `pdf_text_font_metrics()`). Not a gap; the columnar shape is the
  R idiom.
- **Sysfont callback class (`PdfSysfontBase`).** pypdfium2 lets
  you subclass and override `MapFont / GetFont / GetFontData /
  GetFaceName / GetFontCharset / DeleteFont` to plug in a custom
  system-font resolver. rpdfium exposes
  `pdf_system_fonts_default_ttf_map()` +
  `pdf_system_fonts_install_default()` and otherwise treats sysfonts
  as opaque. Implementing the full `FPDF_SYSFONTINFO` callback
  surface from R requires R callbacks called from C++, which is
  feasible but a research-grade undertaking. Document the gap;
  keep deferred.

## Out of scope — firmly skip

Confirming the audit-doc out-of-scope categories with reference to
pypdfium2:

| Audit category | pypdfium2 status | Confirmation |
|---|---|---|
| XFA forms (7 symbols) | Conditionally exposed in `PdfDocument.init_forms()` if PDFium was built with XFA | Same reasoning: the bundled bblanchon binary doesn't include XFA. **Skip.** |
| Progressive / streaming document loading (`fpdf_dataavail.h`, 8 symbols) | pypdfium2 does NOT wrap these in helpers — uses `_open_pdf` direct calls | Same scope conclusion as rpdfium. **Skip.** |
| Progressive rendering (`fpdf_progressive.h`, 5 symbols) | pypdfium2 uses `FPDF_RenderPageBitmapWithColorScheme_Start` *internally* for the color-scheme path ([`_helpers/page.py:486`](file:///tmp/pypdfium2-compare/src/pypdfium2/_helpers/page.py)), but the interactive-render API is not exposed as helpers | rpdfium uses the one-shot `FPDF_RenderPageBitmap`. **Skip** (with note that color-scheme rendering at minimum requires the `_Start` / `_Close` pair if we ever wrap `FPDF_COLORSCHEME`). |
| Skia backend (`FPDF_FFLDrawSkia`, `FPDF_RenderPageSkia`) | pypdfium2 does NOT wrap these | Confirmed skip. |
| Form-fill UI helpers (`FPDF_SetFormFieldHighlightColor` etc.) | pypdfium2 calls `FPDF_FFLDraw` internally during render ([`_helpers/page.py:492`](file:///tmp/pypdfium2-compare/src/pypdfium2/_helpers/page.py)) but does NOT expose the highlight color/alpha setters | rpdfium currently doesn't render forms during `pdf_render_page()`. If we ever add a `render_forms = TRUE` flag, we'd want `FPDF_FFLDraw` internally but probably still skip the highlight setters. **Skip for v0.1.0.** |
| V8 / JS sandbox (3 symbols) | pypdfium2 does NOT wrap these in helpers | Confirmed skip. |
| Annotation meta-validation (`FPDFAnnot_IsSupportedSubtype` etc.) | pypdfium2 does NOT wrap these | Confirmed skip. |
| Print backend setup (`FPDF_SetPrintMode`) | pypdfium2 does NOT wrap this | Confirmed skip. |
| Alternative entry points (older / narrower variants) | pypdfium2 uses the *older* `FPDF_LoadMemDocument` ([`_helpers/document.py:545`](file:///tmp/pypdfium2-compare/src/pypdfium2/_helpers/document.py)) where rpdfium uses `FPDF_LoadMemDocument64`. We made the right call: `xlen_t` PDFs > 2 GiB benefit from the 64-bit length. The `FPDFPageObj_TransformF` vs. `FPDFPageObj_Transform` split (pypdfium2 uses `_TransformF`, rpdfium uses `_Transform`) is purely a calling-convention choice. **Skip both pypdfium2 variants.** |

## Additional pypdfium2 features that *aren't gaps* but are worth knowing

- **PdfFormEnv lifetime.** pypdfium2's `PdfDocument.init_forms()`
  is the explicit form-fill-environment trigger. The v0.2.0 plan
  (ADR-011 proposed) already specifies lazy-cached form env. The
  pypdfium2 convention should be cross-referenced in the ADR when
  it lands — pypdfium2 chose *explicit* `init_forms()` whereas
  rpdfium plans *lazy*. Consider the tradeoffs.
- **PdfDocument._data_holder / _data_closer for byte-buffer keep-
  alive.** pypdfium2's `_open_pdf` holds source bytes alive on the
  document object so PDFium's "we don't copy your buffer" contract
  doesn't crash. rpdfium does the same via the `prot` slot on the
  external-pointer. Different mechanism, same outcome. Architectural
  parity confirmed; nothing to do.
- **`PdfBookmark.get_count()` semantics.** Returns a *signed* count
  where the sign indicates initial open / closed state. rpdfium's
  `pdf_bookmark_child_count()` returns the same. Parity confirmed.
- **TOC traversal with cycle detection.** pypdfium2's
  `PdfDocument.get_toc()` uses a `seen` set keyed by pointer
  address to break circular bookmarks ([`_helpers/document.py:512-527`](file:///tmp/pypdfium2-compare/src/pypdfium2/_helpers/document.py))
  — important because PDFium *will* loop infinitely on a
  malformed outline tree. Verify rpdfium's
  `cpp_doc_bookmarks` does the same cycle-detection (it should;
  worth a 30-second confirmation pass during the next code-review
  cycle).
- **PIL fallback paths.** pypdfium2 lazily imports PIL / numpy via
  the `Lazy` proxy. rpdfium doesn't have this — `magick` is the
  closest analogue but isn't currently a soft dependency for
  image extraction. Worth deciding before shipping the
  `pdf_image_extract()` helper proposed above.

## Action checklist

The triage actions falling out of this comparison (priority labels: H
= high, M = medium, L = low; phase: 0.1.0 = blocker, 0.2.x = nice-to-have,
v0.3+ = future):

| Priority | Phase | Item |
|---|---|---|
| L | 0.1.0 | Verify `pdf_text_chars()` and `pdf_text_bounded()` handle PDFium's excluded-char case the way `PdfTextPage._get_active_text_range` does. |
| L | 0.1.0 | Verify `cpp_doc_bookmarks` has cycle detection on malformed outline trees. |
| L | 0.1.0 | Document the `FPDF_COLORSCHEME` decision in the audit doc (currently absent from the deliberate-exclusion list). |
| M | 0.2.x | Add `pdf_image_extract(obj, path)` — best-effort image-to-file. |
| M | 0.2.x | Add `pdf_set_unsupported_handler(callback)` wrapping `FSDK_SetUnSpObjProcessHandler`. |
| L | 0.2.x | Add `pdf_doc_file_id(doc, which = c("permanent", "changing"))` parameter. |
| L | 0.2.x | Add `pdf_doc_file_version(doc)` (one-liner; already in `pdf_doc_info()`). |
| L | 0.2.x | Add `pdf_text_search_prev()` (or a `direction = "next"` / `"prev"` knob). |
| L | 0.2.x | Stash render geometry on `pdfium_bitmap` and add `pdf_bitmap_to_page()` / `pdf_bitmap_from_page()` (PdfPosConv equivalent). |
| L | 0.2.x | Add `pdf_text_obj_at_char(textpage, char_index)` returning the obj handle directly. |
| L | 0.2.x | Add `pdf_image_new_from_bitmap()` to close the PNG-embed gap (already-shipped primitives, missing wrapper). |
| L | v0.3+ | `length.pdfium_doc()` + S3 `[[.pdfium_doc` (pypdfium2 `__len__` / `__iter__` parity). |
| L | v0.3+ | `pdf_with(path, function(doc) { ... })` higher-order context manager. |
| L | v0.3+ | `as_magick(bitmap)` adapter for `magick::image_read`. |
| L | v0.3+ | PdfSysfontBase R-callback equivalent. |
