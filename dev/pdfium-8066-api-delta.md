# PDFium API delta — `chromium/7857` → `chromium/8066`

Audit of the `pdfium` R package against the newest bblanchon PDFium
release. The pin moves from `chromium/7857` (Chromium M150) to
`chromium/8066` (Chromium M156), about four months of upstream change.
This document is the evidence base for what the bump changed in PDFium
— public API *and* behaviour — and what the package does about it.
It follows the method of
[`dev/pdfium-7857-api-delta.md`](pdfium-7857-api-delta.md) and adds an
empirical behaviour-diff pass, because this delta's most consequential
changes are invisible in the headers.

## Provenance

- **Audit date:** 2026-09-26.
- **Old pin:** `chromium/7857` — bblanchon build of 2026-05-25,
  `VERSION` 150.0.7857.0.
- **New pin:** `chromium/8066` — bblanchon build of 2026-09-21,
  `VERSION` 156.0.8066.0. It is the newest `chromium/*` tag in
  `bblanchon/pdfium-binaries` as of the audit date
  (`git ls-remote --tags`).
- **Header sources diffed:** `include/` of `pdfium-linux-x64.tgz` from
  both releases. Both builds use identical `args.gn` (no XFA, no V8,
  no Skia, `pdf_is_standalone = true`).
- **Exports diffed:** `nm -D --defined-only lib/libpdfium.so` of both
  builds — 456 → 468 exported functions.
- **Upstream commits:** PDFium `6308a8b36d17..fc46361ce750`, i.e. every
  commit rolled into Chromium between the trunk `VERSION` bumps that
  bracket the two branch points (7856→7857, Chromium `240877342`,
  2026-05-24; 8065→8066, Chromium `70bb45607`, 2026-09-17). No PDFium
  roll landed inside either branch window, so both ends are exact. The
  subjects come from the 73 "Roll PDFium from … to …" commits in the
  `chromium/chromium` GitHub mirror (`pdfium.googlesource.com` was not
  reachable from the audit environment, and the `chromium/pdfium`
  GitHub mirror stops at 2025-11-19): **495 commits**, 425 after
  dropping dependency / toolchain rolls. Commits cherry-picked onto the
  release branches after the branch point are not covered.
- **Behaviour diff:** the package was built against each binary
  (R 4.3.3, Rcpp 1.1.2) and the same probes run under both
  (§D). The unmodified package passed its full suite on both builds
  (891 tests, 0 failures, 1 skip — the missing encrypted fixture).
- The exact commands are in the appendix.

## TL;DR

- **12 functions added, 0 removed, 0 signatures changed.** Nothing the
  package calls went away; the unmodified package builds and passes its
  suite against 8066.
- **10 of the 12 are wrapped** (§C, Bucket 1). Two of them are this
  package's own upstream proposals landing:
  `FPDFPath_GetBezierControlPoints` (→ `cx1`/`cy1`/`cx2`/`cy2` columns,
  ADR-021 supersedes ADR-009) and `FPDFTextObj_SetFontSize`
  (→ `pdf_text_set_font_size()`).
- **2 are out of scope by existing policy:** `FORM_GetTextDirection` /
  `FORM_SetTextDirection` are in-memory interactive form-fill state
  (§C, Bucket 2).
- **Five behaviour changes affect the package** (§D):
  1. `FPDFAttachment_SetStringValue` now stores Unicode correctly
     (was mojibake for non-ASCII) — docs and tests that encoded the old
     bug are updated.
  2. `FPDFAnnot_SetRect` no longer rewrites the appearance `/BBox`.
     This exposed that `pdf_render_page()`'s "AP refresh" (ADR-020 §7)
     never refreshed anything: on 7857 its only effect was to corrupt
     `/BBox` entries during rendering. **Removed** (ADR-022), with a
     regression test.
  3. `FPDFPage_Flatten` now removes flattened fields from `/AcroForm`
     (and the `/AcroForm` itself once empty).
  4. New documents get a `/CreationDate` with a time-zone offset —
     but PDFium writes `+00'00'` whatever the local zone (upstream bug;
     documented, parsed value unchanged for R users).
  5. The appearance of an annotation is now scaled, not re-boxed, when
     its rect grows (consequence of 2; documented on
     `pdf_annot_set_bounds()`).
- **Pre-existing issues surfaced by the review** (§E): a wrong
  "control points are lost" claim in the path docs (fixed), a false
  "rebuilds the widget appearance" claim on
  `pdf_form_field_set_value()` (fixed), a stale Rd file (regenerated),
  and three items left as follow-ups — a double-ownership segfault in
  `pdf_annot_append_object()`, form widgets never being rendered, and
  an undeclared Rcpp ≥ 1.1.0 requirement.

---

## A. API diff

### Added in 8066 (12)

All are marked `// Experimental API.` upstream.

| # | Symbol | Header | Signature | Upstream commit |
|---|---|---|---|---|
| 1 | `FPDFAttachment_GetDescription` | `fpdf_attachment.h` | `unsigned long (FPDF_ATTACHMENT, FPDF_WCHAR* buffer, unsigned long buflen)` | "Add APIs to read and write attachment descriptions" (2026-07-13) |
| 2 | `FPDFAttachment_SetDescription` | `fpdf_attachment.h` | `FPDF_BOOL (FPDF_ATTACHMENT, FPDF_WIDESTRING value)` | same |
| 3 | `FPDFAttachment_GetAFRelationship` | `fpdf_attachment.h` | `unsigned long (FPDF_ATTACHMENT, FPDF_WCHAR* buffer, unsigned long buflen)` | "Add FPDFAttachment_GetAFRelationship() API" (2026-09-12) |
| 4 | `FPDFBookmark_GetColor` | `fpdf_doc.h` | `FPDF_BOOL (FPDF_BOOKMARK, float* R, float* G, float* B)` | "Add FPDFBookmark_GetColor public API" (2026-06-24) |
| 5 | `FPDFBookmark_GetStyle` | `fpdf_doc.h` | `int (FPDF_BOOKMARK)` | "Add FPDFBookmark_GetStyle() API" (2026-08-28) |
| 6 | `FPDFPageObj_AddExistingMark` | `fpdf_edit.h` | `FPDF_BOOL (FPDF_PAGEOBJECT, FPDF_PAGEOBJECTMARK)` | "Create FDPFPageObj_AddExistingMark()" (2026-05-29) |
| 7 | `FPDFPageObj_GetRenderedStrokePattern` | `fpdf_edit.h` | `FPDF_BITMAP (FPDF_DOCUMENT, FPDF_PAGEOBJECT)` | "Add FPDFPageObj_GetRenderedStrokePattern() API" (2026-09-08) |
| 8 | `FPDFPageObj_GetRenderedFillPattern` | `fpdf_edit.h` | `FPDF_BITMAP (FPDF_DOCUMENT, FPDF_PAGEOBJECT)` | "Add FPDFPageObj_GetRenderedFillPattern() API" (2026-09-17) |
| 9 | `FPDFPath_GetBezierControlPoints` | `fpdf_edit.h` | `FPDF_BOOL (FPDF_PAGEOBJECT path, size_t index, FS_POINTF* first_control_point, FS_POINTF* second_control_point)` | "Add FPDFPath_GetBezierControlPoints() API" (2026-08-20) |
| 10 | `FPDFTextObj_SetFontSize` | `fpdf_edit.h` | `FPDF_BOOL (FPDF_PAGEOBJECT text, float size)` | "Add FPDFTextObj_SetFontSize() public API" (2026-05-27, authored by this package's maintainer) |
| 11 | `FORM_GetTextDirection` | `fpdf_formfill.h` | `FPDF_TEXT_DIRECTION (FPDF_FORMHANDLE, FPDF_ANNOTATION)` | "Expose SetTextDirection through public FPDF FormFill API" (2026-07-30) |
| 12 | `FORM_SetTextDirection` | `fpdf_formfill.h` | `FPDF_BOOL (FPDF_FORMHANDLE, FPDF_ANNOTATION, FPDF_TEXT_DIRECTION)` | same |

Runtime semantics, probed with a C++ harness against the 8066 binary
(the header comments leave several of these open):

- `FPDFPath_GetBezierControlPoints` succeeds only at the *endpoint*
  index of a cubic segment. The segment enumeration already lists every
  cubic as three `FPDF_SEGMENT_BEZIERTO` points (control 1, control 2,
  endpoint); the control-point indices, `moveto` / `lineto` indices,
  out-of-range indices and `NULL` outputs all return `FALSE`. For a
  path `m, c, c, l, c` the endpoints are indices 3, 6 and 10.
- `FPDFTextObj_SetFontSize` rejects negative sizes (leaving the size
  unchanged), non-text objects and `NULL`; `0` is accepted.
- `FPDFPageObj_AddExistingMark` **shares** the mark: both objects then
  return the same `FPDF_PAGEOBJECTMARK`, so parameters written through
  either are visible from both. Adding the same mark twice duplicates
  it. PDFium does **not** enforce the header's "same document" rule
  for page objects created in another document.
- `FPDFPageObj_GetRendered{Fill,Stroke}Pattern` return a BGRA bitmap
  of one tile at one pixel per unit of the pattern `/BBox`, or `NULL`
  when the colour is not a tiling pattern. The tile is rendered in
  pattern space and comes back **bottom-up** (first row = the cell's
  bottom edge), unlike every other PDFium bitmap; the pattern
  `/Matrix` is not applied (a rotated pattern is clipped into the
  unrotated cell box). The stroke variant reports the stroke colour's
  pattern even for an object that isn't stroked. The document argument
  is used for resources only — passing an unrelated document still
  returns a tile.
- `FPDFBookmark_GetColor` fails (all outputs untouched) when `/C` is
  absent or not three numbers in `[0, 1]`; `FPDFBookmark_GetStyle`
  returns the raw `/F` integer, including reserved bits (`/F 7` → 7).
- `FPDFAttachment_GetDescription` / `GetAFRelationship` read the *file
  specification* dictionary (not `/Params`); a wrong-typed entry
  (`/Desc 42`, `/AFRelationship (Source)` as a string) reads as the
  empty string (return 2). `SetDescription` works before
  `FPDFAttachment_SetFile` and its value survives a later `SetFile`
  (which rebuilds only the stream and `/Params`).
- `FORM_GetTextDirection` reports `FPDF_TEXTDIR_AUTO` until
  `FORM_SetTextDirection` changes it; `FPDF_TEXTDIR_UNKNOWN` is
  rejected. Nothing is written to the document.

### Removed in 8066 (0)

`comm -23 old.exports new.exports` is empty, and every one of the 363
distinct `FPDF*` / `FORM_*` identifiers referenced from `src/*.cpp`
resolves in the 8066 export table.

### Signature-changed (0)

No prototype of an existing function changed. Two doc comments changed
in ways that describe behaviour (§D-2, §D-5).

### Constants, enums, structs

| Change | Where | Impact |
|---|---|---|
| New enum `FPDF_TEXT_DIRECTION` (`UNKNOWN`=0, `AUTO`, `LTR`, `RTL`) | `fpdf_formfill.h` | Only used by the two `FORM_*` additions. |
| `FPDF_LIBRARY_CONFIG` v6 field `m_BrotliEnabled` | `fpdfview.h` | Enables the experimental PDF 2.0 `/BrotliDecode` filter — only in builds with `PDF_ENABLE_BROTLI`, which the bblanchon build is not (no Brotli code in `libpdfium.so`). |
| `FPDF_LIBRARY_CONFIG` v7 field `m_IsolatePerDocument` | `fpdfview.h` | V8 only; the bblanchon build has no V8. |
| `m_FontLibraryType` (v5) comment no longer says "Skia only" | `fpdfview.h` | None. |

`src/init.cpp` zero-initialises the config and sets `version = 2`, so
PDFium reads none of the v5–v7 fields. No change needed.

### Bundled third-party components

`licenses/libtiff.txt` is gone from the 8066 archive: TIFF decoding is
only used by XFA, which the bblanchon build omits (upstream "Remove
per-codec pdf_enable_xfa_<codec> GN arguments and macros",
2026-08-10). The top-level `LICENSE` and every other license file are
byte-identical. `LICENSE.md` names no individual third-party
component, so it needs no change.

---

## B. What the package calls

- 363 distinct `FPDF*` / `FORM_*` / `FSDK_*` identifiers in
  `src/*.cpp` before this change; all resolve in 8066.
- Still **zero** `FORM_*` calls — form filling goes through
  `FPDFAnnot_*` + `FPDFDOC_InitFormFillEnvironment`, per
  `dev/v0.1.0-api-gap-audit.md` §5.

---

## C. The buckets

### Bucket 1 — new symbols wrapped

| Symbol | R surface | Notes |
|---|---|---|
| `FPDFPath_GetBezierControlPoints` | `cx1`, `cy1`, `cx2`, `cy2` columns of `pdf_path_segments()` and `pdf_extract_paths()` | Filled on each cubic's endpoint row, `NA` elsewhere; triplet rows kept so `pdf_path_append()` round-trips. **ADR-021** (supersedes ADR-009). Tests cover `c` / `v` / `y` operators parsed from a content stream and `pdf_path_bezier_to()`-authored curves. |
| `FPDFTextObj_SetFontSize` | `pdf_text_set_font_size(obj, size)` | Reader/writer pair with `pdf_text_font_size()`; persists through save/reload. |
| `FPDFPageObj_AddExistingMark` | `pdf_obj_add_existing_mark(obj, src, mark_index)` | Shared (not copied) mark, documented; the R wrapper enforces the same-document rule PDFium doesn't. |
| `FPDFPageObj_GetRenderedFillPattern` / `…StrokePattern` | `pdf_obj_rendered_fill_pattern(obj)` / `pdf_obj_rendered_stroke_pattern(obj)` | `pdfium_bitmap` or `NULL`. Rows are flipped to the package's top-down bitmap contract; a test ties the tile to the page render so an upstream orientation change is caught. |
| `FPDFBookmark_GetColor` / `GetStyle` | `pdf_bookmark_color(bm)`, `pdf_bookmark_style(bm)`; `color_red` / `color_green` / `color_blue` / `italic` / `bold` columns of `as_tibble(pdf_doc_bookmarks())` | Colour on the 0..1 scale of `pdf_annot_color()`; style decodes the two defined `/F` bits. |
| `FPDFAttachment_GetDescription` / `SetDescription` / `GetAFRelationship` | `pdf_attachment_description()`, `pdf_attachment_set_description()`, `pdf_attachment_af_relationship()`; `description` / `af_relationship` columns of `as_tibble(pdf_attachments())` | These are the file-spec entries `pdf_attachment_set_dict_value()`'s docs used to (wrongly) list as `/Params` keys; those docs are corrected. |

### Bucket 2 — new symbols not wrapped

- **`FORM_GetTextDirection` / `FORM_SetTextDirection`.** They read and
  set the text direction of the interactive editing widget PDFium
  creates for a focused form field ("only alters the in-memory state of
  the form field and does not modify the PDF document"). The package
  neither drives PDFium's interactive form-fill layer nor draws widgets
  (§E-5), so the setting could be read back but would never affect a
  render or a saved file. They join the 31 `FORM_*` symbols excluded by
  `dev/v0.1.0-api-gap-audit.md` §5. Revisit together with widget
  rendering (`FPDF_FFLDraw`) if that is ever taken on.
- **`FPDF_LIBRARY_CONFIG` v6 / v7** — inert in this build (see §A).

### Bucket 3 — deprecated / removed

None. The 7857 deferrals (`FPDFPageObjMark_GetParamFloatValue` /
`SetFloatParam`, `FPDFPage_InsertObjectAtIndex`,
`FPDFText_SetPositions`) are unchanged upstream and stay deferred for
the reasons in [`dev/pdfium-7857-api-delta.md`](pdfium-7857-api-delta.md).

---

## D. Behaviour changes (empirical)

Each item was reproduced by building the package against both binaries
and running the same probe; "7857 → 8066" shows the observed outputs.

**D-1. `FPDFAttachment_SetStringValue` now round-trips Unicode.**
Upstream "Fix FPDFAttachment_SetStringValue() encoding problem"
(2026-07-13). Writing `"café"` / `"日本語"` through
`pdf_attachment_set_dict_value()` read back as `"cafÃ©"` /
`"æŠ¥æœ¬èªž"` on 7857 (the raw UTF-8 bytes decoded as
PDFDocEncoding); on 8066 both read back exactly as written, also
after save/reload. `pdf_attachment_set_dict_value()`'s "restrict to ASCII
until upstream is fixed" advice and the matching test comment are
replaced by a Unicode round-trip regression test. This was the second
half of the attachment gap noted in `dev/upstream-patches/README.md`.

**D-2. `FPDFAnnot_SetRect` no longer rewrites the appearance `/BBox`.**
The header dropped "…then update the bounding box too if the new
rectangle defines a bigger one". Enlarging a square annotation's rect
from `[10 10 50 50]` to `[5 5 150 150]` left its `/BBox` at
`[5 5 150 150]` on 7857 and `[10 10 50 50]` on 8066. Two consequences:

- *ADR-020 §7's "AP refresh" was a bug, not a feature.* Every render
  called `FPDFAnnot_SetRect(rect)` on every annotation, believing it
  flipped an "AP-dirty flag". PDFium has no such flag; the call's only
  effect on 7857 was the `/BBox` rewrite. For an appearance whose
  `/BBox` (`[12 12 48 48]`) sits inside its `/Rect` (`[10 10 50 50]`),
  `pdf_render_page()` drew it at 36 × 36 px instead of the
  spec-correct 40 × 40 px (a direct `FPDF_RenderPageBitmap` gave 40 ×
  40 on both builds), and a later `pdf_save()` wrote the corrupted
  `/BBox`. On 8066 the walk is a pure no-op (identical bitmaps and
  saved bytes with or without it). **ADR-022 removes it** (and the
  single-annotation variant in `pdf_form_field_set_value()`); the
  regression test "rendering leaves annotation appearance streams
  untouched" pins both the rendered size and the saved `/BBox`.
- *Resizing an annotation now scales its existing appearance.*
  Documented on `pdf_annot_set_bounds()`, with a test that the saved
  `/BBox` survives.

**D-3. Flattening removes the flattened fields from `/AcroForm`.**
Upstream "Remove flattened fields from AcroForm" (2026-06-18). After
flattening every field of `annotated.pdf`, `pdf_doc_form_type()` stayed
`"acro_form"` on 7857 (with a `/Fields` array of dangling references)
and is `"none"` on 8066 — in memory and after save/reload. A partial
flatten (fields on two pages, one page flattened) keeps the other
page's field. Documented on `pdf_page_flatten()`; tested.

**D-4. New documents' `/CreationDate` carries a time-zone offset — the
wrong one.** Upstream "Add timezone offset to new document creation
date" (2026-06-26). `pdf_doc_new()` gives `D:20260926205600` on 7857
and `D:20260926205600+00'00'` on 8066. The timestamp is local
wall-clock time, but the offset is `+00'00'` under every zone tried
(`TZ` = `America/New_York`, `Asia/Kolkata`, `Australia/Adelaide`,
`EST5EDT`): e.g. under `Asia/Kolkata` 8066 writes
`D:20260927022603+00'00'` at 20:56 UTC. `pdf_parse_date()` already
read the offset-less 7857 string as UTC, so the parsed value R users
see is unchanged — only the raw string now asserts the wrong offset.
The package cannot fix it (there is no public `/Info` setter; see
`dev/upstream-patches/pdfium-FPDF_SetMetaText.patch`). Documented on
`pdf_doc_new()`; the test pins only "has a parseable offset", so an
upstream fix will not break it. **Worth reporting upstream.**

**D-5. `FPDF_GetMetaText` documents its return codes** (0 for a
`NULL` argument or a missing `/Info`, 2 for a missing key). The
behaviour itself is unchanged, and `src/document.cpp` already maps
both 0 and 2 to `""`.

**D-6. Checked, no impact on the package or its fixtures:**

- Content-stream numbers are formatted with Dragonbox (shortest
  round-trip, 2026-08-18). Saved bytes differ; coordinates read back
  after save/reload are identical at float precision.
- `FPDFFont_GetWeight` honours a font descriptor's `/FontWeight`
  (2026-07-22); every fixture font reports 400 on both builds.
- Later `ToUnicode` entries supersede earlier ones (2026-09-12);
  `/ActualText` characters get their own internal char type
  (2026-07-31); "Fix mixed-direction line extraction" landed and was
  reverted inside the window. Text of every fixture is identical.
- Rendering: reduced-size JPEG decoding (`scale_denom`), transfer
  function fixes, 1-bpp horizontal stretching, colour-key masking for
  > 8-bit images. Page 1 of every fixture renders identically at 72
  dpi.
- Name-tree logic fix, `FPDF_ImportPages` hang on circular page trees,
  a crash on invalid xref object numbers, an OpenJPEG double free, JPX
  and fax-decoder bounds — robustness fixes on paths the package calls;
  named destinations and attachments of every fixture are unchanged.

---

## E. Pre-existing issues found during the review

Not caused by the bump, but found while checking the package's
assumptions against it.

- **E-1 (fixed). The path docs said Bezier control points are lost.**
  `pdf_path_segments()`, `pdf_extract_paths()` and `src/paths.cpp`
  repeated ADR-009's premise, but the segment enumeration has always
  included both control points (the path-setter tests and the
  `extracting-paths` vignette relied on it). Corrected with ADR-021.
- **E-2 (fixed). `pdf_form_field_set_value()` promised the widget's
  appearance is rebuilt** on the next render / save. Neither build
  rebuilds it (checked: the saved `/AP` stream is byte-identical after
  a value change). Corrected with ADR-022.
- **E-3 (fixed). `man/plot.pdfium_bitmap.Rd` was stale** — the roxygen
  source in `R/render.R` changed in the nativeRaster fix, the Rd
  didn't. Regenerated.
- **E-4 (follow-up). `pdf_annot_append_object()` double-frees.** Every
  object creator inserts the new object into the page, so the object
  handed to `FPDFAnnot_AppendObject` is owned by both the page and the
  annotation; `pdf_page_close()` then crashes (reproduced on both
  builds with `MALLOC_CHECK_=3`, even without a later
  `pdf_annot_remove_object()`). The "success path crashes at teardown"
  notes on `pdf_annot_remove_object()` point at the same root cause,
  while the equivalent note on `pdf_form_obj_remove_object()` does not
  reproduce on either build. Needs a design decision (detach the
  object from the page first, or refuse page-owned objects) — out of
  scope for a pin bump.
- **E-5 (follow-up). Form fields are never drawn by
  `pdf_render_page(annotations = TRUE)`.** PDFium's
  `FPDF_RenderPageBitmap` hard-codes widget annotations as hidden; they
  are drawn only by `FPDF_FFLDraw` with a form handle, which the
  package does not call. Worth at least a documentation note.
- **E-6 (follow-up). Rcpp ≥ 1.1.0 is required but not declared.**
  `src/annotations.cpp` builds a 28-element `List::create()`; before
  Rcpp 1.1.0 (variadic `create()` made unconditional) this fails to
  compile (reproduced with Rcpp 1.0.12). `LinkingTo: Rcpp (>= 1.1.0)`
  would state it.

---

## F. Verification

- `R CMD INSTALL` against 7857 and 8066: clean compile (`-Wall`).
- Unmodified package on 8066: 891 tests, 0 failures, 1 skip.
- With this change, on 8066 (R 4.3.3, Linux x86-64, UTF-8 locale):
  - test suite: **912 tests, 0 failures**, 1 skip (the pre-existing
    encrypted-fixture skip);
  - `covr::package_coverage(type = "tests")`: **100 %** of `R/` lines;
  - `R CMD check --as-cran --no-manual` on a tarball built from a clean
    export: 0 errors. The 2 warnings and 5 notes are all artefacts of
    the audit environment — no `checkbashisms` / `qpdf` binaries, URL
    checks blocked by the sandbox proxy, no time server, and the
    Ubuntu R build's `-g` / `-mno-omit-leaf-frame-pointer` flags
    (installed size, non-portable flag). Tests, examples, vignettes
    and Rd checks are OK;
  - valgrind memcheck over a script calling every new function:
    0 bytes definitely / indirectly lost (the CI gate); all reported
    errors are `Mismatched free()` inside `libpdfium.so`, none in
    package code;
  - `lintr::lint_package()`, `spelling::spell_check_package()`,
    `tools/check-pkgdown-reference.R` and `tools/check-rd-xrefs.R`:
    no new findings.

---

## G. Recommendations

| # | Action | Status |
|---|---|---|
| 1 | Bump the pin to `chromium/8066` | **Done** |
| 2 | Wrap the 10 in-scope additions (Bucket 1) | **Done** |
| 3 | Drop the render-time `SetRect` walk (ADR-022) + regression test | **Done** |
| 4 | Update docs/tests for D-1..D-4 | **Done** |
| 5 | Report D-4 (`+00'00'` offset on local time) upstream | Suggested — maintainer (has a Gerrit/CLA setup) |
| 6 | Fix E-4 (annotation append double ownership) | Follow-up PR; needs a small ADR |
| 7 | Document or implement widget rendering (E-5) | Follow-up |
| 8 | Declare `Rcpp (>= 1.1.0)` in `LinkingTo` (E-6) | Follow-up |
| 9 | Refresh `dev/upstream-patches/` for the two landed patches | **Done** (status notes) |

---

## Appendix — reproducer

```sh
# 1. Both header sets and export tables
base=https://github.com/bblanchon/pdfium-binaries/releases/download/chromium
mkdir -p old new
curl -sL $base/7857/pdfium-linux-x64.tgz | tar xz -C old
curl -sL $base/8066/pdfium-linux-x64.tgz | tar xz -C new
diff -ru old/include new/include
nm -D --defined-only old/lib/libpdfium.so | awk '$2=="T"{print $3}' | sort > old.exports
nm -D --defined-only new/lib/libpdfium.so | awk '$2=="T"{print $3}' | sort > new.exports
comm -13 old.exports new.exports          # added
comm -23 old.exports new.exports          # removed

# 2. Upstream commit subjects between the branch points, from the
#    Chromium autoroller messages (commits only; no trees / blobs)
git clone --filter=tree:0 --no-checkout --single-branch --branch main \
  --shallow-since=2026-04-01 https://github.com/chromium/chromium
cd chromium
git log --format='%h %cd %s' --grep='Updating trunk VERSION from \(7856\|8065\)\.0'
git log --reverse --format='%B' 240877342..70bb45607 --grep='^Roll PDFium' |
  grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2} [^ ]+@[^ ]+ '

# 3. What the package calls
grep -rhoE '\b(FPDF|FORM_|FSDK)[A-Za-z_0-9]*\(' src/*.cpp src/*.h | tr -d '(' | sort -u

# 4. Build + test against each pin
echo chromium/8066 > tools/pdfium-version.txt
R CMD INSTALL --library=/tmp/lib-8066 .
LANG=C.UTF-8 Rscript -e 'testthat::test_dir("tests/testthat",
  package = "pdfium", load_package = "installed")'
```
