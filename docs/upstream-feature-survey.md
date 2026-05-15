# Upstream wrapper feature survey (Phase 0a)

Survey of six existing language bindings around Google's PDFium C API, plus
notes on what the underlying C API itself exposes. Findings here will inform
ADR-003 (binary distribution), ADR-004 (R-side API style), and ADR-005
(memory / handle lifetime model), and the Tier 1/2/3 feature prioritization.

## Provenance

This survey was conducted on **2026-05-15**. The six upstream repositories
were cloned shallow into `/tmp/pdfium-upstream-survey/`; the findings below
reflect the exact commits in the table. Re-running the survey against a
more recent state may surface features or patterns added since.

| Repo                          | Branch   | Commit         | Commit date | Latest tag at HEAD       |
|---|---|---|---|---|
| `pypdfium2-team/pypdfium2`    | `main`   | `65641ce442a5` | 2026-05-15  | (untagged on main)       |
| `newinnovations/pdfium-rs`    | `main`   | `4056e0031ec8` | 2026-02-28  | (untagged)               |
| `ajrcarey/pdfium-render`      | `master` | `b63a034b7ffe` | 2026-05-02  | (untagged)               |
| `hyzyla/pdfium`               | `main`   | `274cac6e238b` | 2026-05-13  | `v2.1.13`                |
| `barteksc/PdfiumAndroid`      | `master` | `103d5855f797` | 2018-06-29  | `pdfium-android-1.9.0`   |
| `pvginkel/PdfiumViewer`       | `master` | `b253afcfa00b` | 2019-08-01  | (untagged; repo archived)|

PdfiumAndroid and PdfiumViewer have not received commits in years and are
included as historical baselines. The three actively-maintained wrappers
(pypdfium2, pdfium-rs, pdfium-render) are where post-survey drift is most
likely; refresh those clones first when revisiting this document.

To refresh this survey:

```sh
for d in /tmp/pdfium-upstream-survey/*/; do (cd "$d" && git pull); done
# then re-grep the trees, update the provenance table above, and note any
# material deltas in NEWS.md or a new ADR if architectural implications follow.
```

## Wrappers covered (column order in the matrix)

| Short label | Language | Repo |
| --- | --- | --- |
| **pypdfium2** | Python (ctypes, ABI-level) | https://github.com/pypdfium2-team/pypdfium2 |
| **pdfium-rs** | Rust (libloading, full C-API surface) | https://github.com/newinnovations/pdfium-rs |
| **pdfium-render** | Rust (idiomatic, also supports WASM) | https://github.com/ajrcarey/pdfium-render |
| **hyzyla** | TypeScript / WebAssembly | https://github.com/hyzyla/pdfium |
| **PdfiumAndroid** | Java / JNI on Android | https://github.com/barteksc/PdfiumAndroid |
| **PdfiumViewer** | C# / WinForms (archived) | https://github.com/pvginkel/PdfiumViewer |

PDFium itself is treated as the upstream reference for what the C API exposes;
specific upstream cells say "C-API:" where the table column would otherwise
be repetitive.

Two repos draw a clear line between a low-level binding layer and a
"helper" / idiomatic layer. Where that matters for feature coverage, the
cell text says "raw only" — meaning the function exists in the
ctypes/FFI bindings but no convenience wrapper sits on top of it.

---

## 1. Feature matrix

Cells use **yes** / **partial** / **no**. "Raw only" means the underlying
C entry point is exposed but no idiomatic wrapper exists. Notes are
deliberately specific so we can reuse function names verbatim.

| Capability                                | pypdfium2                                                                | pdfium-rs                                                                  | pdfium-render                                                       | hyzyla (WASM)                                          | PdfiumAndroid                                              | PdfiumViewer (.NET)                                       |
|-------------------------------------------|--------------------------------------------------------------------------|-----------------------------------------------------------------------------|---------------------------------------------------------------------|--------------------------------------------------------|------------------------------------------------------------|-----------------------------------------------------------|
| Document open / close                     | yes — `PdfDocument(input, password)`, accepts path/bytes/IO              | yes — `PdfiumDocument::new_from_path`, `_from_reader`, `_from_bytes`        | yes — `Pdfium::load_pdf_from_file`, `_byte_slice`, `_reader`, `_blob`, `_fetch` | yes — `library.loadDocument(buff, password)`           | yes — `newDocument(fd | byte[], password?)`                | yes — `PdfDocument.Load(path | stream, password?)`        |
| Page enumeration & metadata               | yes — `pdf.get_page(i)`, `len(pdf)`, mediabox/crop/bleed/trim/art        | yes — `doc.page(i)`, `pages()`, `boundaries()`, rotation, has_transparency | yes — `document.pages()`, `page.boundaries()`, `paper_size`, `label` | partial — width/height + count only                    | partial — count, width/height, size in points              | partial — `PageCount`, `PageSizes`, `RotatePage`          |
| Page object enumeration                   | yes — `page.get_objects(filter, max_depth)` (recursive into FormXObjects)| yes — `page.objects()` / `page.object(i)`                                  | yes — `page.objects()` returns typed `PdfPageObject` enum           | yes — `page.objects()` generator, factory dispatches type | no                                                         | no                                                        |
| Path segments (linear)                    | raw only — `FPDFPath_CountSegments` / `FPDFPath_GetPathSegment` in `raw` | yes — `lib().FPDFPath_CountSegments`, `_GetPathSegment` on `Pdfium`          | yes — `path.segments()`, iterator yields `PdfPathSegment`           | no — only object-type tag, no segment iteration         | no                                                         | no                                                        |
| Path Bezier control points                | raw only — `FPDFPathSegment_GetPoint` + segment type enum                | yes via raw `FPDFPathSegment_GetType`/`_GetPoint`/`_GetClose`              | yes — `segment.segment_type()` returns enum incl. `BezierTo`        | no                                                     | no                                                         | no                                                        |
| Path stroke style (color, width, dash)    | raw only                                                                 | yes — `get_stroke_color/_width/_dash_array/_dash_count/_dash_phase/_line_cap/_line_join` | yes — trait methods `stroke_color`, `stroke_width`, `dash_array`, `dash_phase`, `line_cap`, `line_join` | no                                                     | no                                                         | no                                                        |
| Path fill style (color, rule, opacity)    | raw only                                                                 | yes — `get_fill_color`, fill mode via `FPDFPath_GetDrawMode`               | yes — `fill_color`, `fill_mode()` returns `PdfPathFillMode`         | no                                                     | no                                                         | no                                                        |
| Object bounds                             | yes — `obj.get_bounds()`, `get_quad_points()`                            | yes — `get_bounds(...)`, `get_rotated_bounds` (quad)                       | yes — trait `bounds()` returns `PdfQuadPoints` + `width/height`     | no                                                     | no                                                         | no                                                        |
| Object transformation matrix (CTM)        | yes — `obj.get_matrix()`, `set_matrix()`, `transform()`                  | yes — `get_matrix(&mut FS_MATRIX)`, `set_matrix`, `transform_f`            | yes — applied via `transform(matrix)`; `PdfMatrix` is first-class   | no                                                     | no                                                         | partial — `FPDFPageObj_Transform` is bound, no wrapper    |
| Clipping paths                            | raw only — `FPDFPageObj_GetClipPath`, `FPDFClipPath_CountPaths`          | yes — `obj.get_clip_path()` → `PdfiumClipPath`; iterate via `FPDFClipPath_CountPathSegments` | yes — `obj.get_clip_path()` → `PdfClipPath` with `segments()` iterator | no                                                     | no                                                         | no                                                        |
| Text content                              | yes — `PdfTextPage.get_text_range`, `get_text_bounded`                   | yes — `text().full()`, `extract()`, `get_bounded_text`                     | yes — `page.text()` then `.text()` / `.chars()`                     | yes — `page.getText()` (returns full UTF-16 string)    | no                                                         | yes — `GetPdfText(page)`, `Search`, `PdfTextSpan`         |
| Text positioning (per-glyph bbox)         | yes — `textpage.get_charbox(i, loose=)`, `get_rect(i)`                   | yes — `get_char_box`, `get_loose_char_box`, `get_char_origin`              | yes — `PdfPageTextChar` exposes `tight_bounds`, `loose_bounds`, `origin`, `angle_degrees` | no                                                     | no                                                         | yes — `FPDFText_GetCharBox` bound, `GetTextBounds`        |
| Font metadata (name, weight, embedded)    | yes — `PdfFont.get_family_name`, `get_weight`, `is_embedded`             | yes — at-char level: `get_font_info`, `get_font_size`, `get_font_weight`   | yes — `PdfFont::name/family/weight/italic_angle/ascent/descent/is_embedded/data` | no                                                     | no                                                         | no                                                        |
| Image objects + bitmap extraction         | yes — `PdfImage.get_bitmap(render=)`, `extract(...)`, `get_metadata`, `get_filters` (decode chain) | yes — image object methods + JPEG load/save via `FPDFImageObj_*`           | yes — `PdfPageImageObject::get_raw_image/_processed_image`, `filters()`, DPI, color_space, bpp | yes — `imageObj.getImageDataRaw()` returns `{width,height,data,filters}`; also `render()` does RGBA conversion in JS | no                                                         | no                                                        |
| Form XObjects                             | yes — `PdfXObject.as_pageobject()`, `pdf.page_as_xobject()`, recursed in `get_objects()` | partial — exposed as `xobject` type with handle wrapper                    | yes — `as_x_object_form_object()` variant, transparent recursion    | partial — `PDFiumFormObject` type tag, no contents API | no                                                         | no                                                        |
| Annotations                               | raw only — full `FPDFAnnot_*` available in `raw` but no helper           | yes via C-API — `FPDFAnnot_*` on `Pdfium`; handle wrapper exists but few high-level methods | yes — fully typed: 16+ annotation subtypes via `as_*_annotation()` accessors | no — but render flag `ANNOT` is on in render           | no — only renderAnnot bool in render                       | no                                                        |
| Page render to bitmap                     | yes — `page.render(...)` returns `PdfBitmap`, multiple format options    | yes — `page.render(&PdfiumRenderConfig::new())` returns `PdfiumBitmap`     | yes — `page.render_with_config()` + `PdfRenderConfig` builder       | yes — async `page.render({scale, render fn})`         | yes — `renderPageBitmap` to Android `Bitmap`, also Surface | yes — `Render(page, ...)` returns `Image`, also DC variant|
| Document metadata (title, author, ...)    | yes — `pdf.get_metadata_dict()`, `get_metadata_value(key)`               | yes — `metadata_dict(skip_empty)`, `metadata_value(key)`                   | yes — `document.metadata()` returns typed `PdfMetadata`             | no                                                     | yes — `getDocumentMeta(doc)` returns `PdfDocument.Meta`    | yes — `GetInformation()` returns `PdfInformation` (8 fields)|
| Structure tree / tagged PDF               | partial — `pdf.is_tagged()` only; full `FPDF_StructTree_*` is raw-only   | yes via C-API — full `FPDF_StructTree_*` + `FPDF_StructElement_*` + attribute introspection on `Pdfium` | no — `is_tagged` available on document, no struct tree wrapper      | no                                                     | no                                                         | no                                                        |
| Signature verification                    | raw only — `FPDF_GetSignatureCount`, `FPDFSignatureObj_*` in raw         | yes — `FPDFSignatureObj_GetByteRange/Contents/SubFilter/Reason/Time/DocMDP` on `Pdfium` | partial — `document.signatures()` exposes bytes/reason/signing_date/MDP perms, but no PKI verification | no                                                     | no                                                         | no                                                        |

Notes on what "raw only" buys you (pypdfium2): every `FPDF*` function we
might want for path/clip/annot/struct/signature work is callable from the
`pypdfium2.raw` module, so the wrapper is fully capable — it just hasn't
chosen to wrap them. The 460-function-count in `autorelease/bindings.py`
covers the entire 5x10+ family of `FPDFAnnot_*` calls, `FPDFPath*`,
`FPDF_StructTree*`, etc.

---

## 2. Patterns worth borrowing

Each entry names a wrapper, points at a concrete file path, and notes how
the pattern translates to R/Rcpp.

1. **Two-tier API: raw bindings + idiomatic helpers, both shipped together (pypdfium2).**
   `src/pypdfium2/raw.py` re-exports the entire ctypesgen output as
   `pypdfium2.raw`, while `_helpers/document.py` etc. provide the
   ergonomic surface. Users who hit a missing helper can drop down without
   leaving the package.
   *Applicability to R:* mirror with two namespaces inside the same
   package — `pdfium::*` (S7/S4 classes around what we have wrapped) and
   `pdfium::raw_*` (thin functions exported via Rcpp that pass through
   PDFium handles as `externalptr`). This avoids the "I need one more
   function, time to fork the package" cliff.

2. **`AutoCloseable` base class with weak-reference finalizer and explicit close (pypdfium2).**
   `src/pypdfium2/internal/bases.py` (~line 105 onward) attaches a
   `weakref.finalize` to every PDFium-handle-holder so GC eventually closes
   them, but `close()` is also callable explicitly. The finalizer
   captures only the handle and parent, not the live object — so the
   reference graph stays cycle-free.
   *Applicability to R:* register an `externalptr` finalizer with
   `R_RegisterCFinalizerEx(..., onexit = TRUE)` so handles are freed on
   GC and at session shutdown, and expose `close.pdfium_document()`
   (S3) for users who want determinism. Be careful with parent-child
   handle ordering — pypdfium2 tracks `kids` for that reason.

3. **Lifetime-free handles via internal Arc/refcount (pdfium-rs).**
   `src/c_api/pdfium.rs` and the `Handle` type in `src/pdfium_types.rs`
   keep an internal reference count so a `PdfiumPage` can outlive the
   `PdfiumDocument` it was created from; the document is only really
   closed when the last derived handle drops. README example explicitly
   demonstrates `drop(document); ... page.render(...)`.
   *Applicability to R:* in R the typical user has `doc <- pdfium_open(...)`
   then `page <- doc$page(1)`. If `doc` goes out of scope but `page`
   is still alive, naive finalizer ordering will segfault. pypdfium2's
   weakref-with-parent and pdfium-rs's Arc both solve this — pick one
   and document it in ADR-005.

4. **Typed object enum with `as_*` downcasts (pdfium-render).**
   `src/pdf/document/page/object.rs` returns a `PdfPageObject` enum, and
   the high-level type provides `as_text_object()`, `as_path_object()`,
   `as_image_object()`, etc. that return `Option<&Concrete>`. Same
   pattern is repeated for annotations (16 subtypes).
   *Applicability to R:* mimic with an S7 union or `vctrs`-style class
   list. We could return a generic `pdfium_object` and provide
   `as_path()`, `as_text()`, `as_image()` that return `NULL` if the
   object isn't of that type — friendlier than a single fat list with
   `type` field that callers have to test.

5. **Recursive page-object enumeration with depth limit and FormXObject descent (pypdfium2).**
   `src/pypdfium2/_helpers/page.py:get_objects(filter=None, max_depth=15, form=None, level=0)`
   iterates `FPDFPage_GetObject` and recurses into FormXObjects with a
   depth guard. The `filter` argument prunes by `FPDFPageObj_GetType` early.
   *Applicability to R:* `page_objects(page, types = c("path","text"), max_depth = 15)`
   is a much friendlier R surface than forcing users to recurse
   themselves. Recursion into XObjects matters for many real PDFs
   (logos in headers, scientific figures embedded as forms).

6. **Render config as a builder (pdfium-render, pdfium-rs).**
   `pdfium-render`'s `PdfRenderConfig::new().set_target_width(2000).rotate_if_landscape(...)`
   and `pdfium-rs`'s `PdfiumRenderConfig::new().with_height(1080)` both
   chain options, then a single `page.render_with_config(&config)` call
   does the work.
   *Applicability to R:* `pdfium_render_opts()` returning a list with
   sane defaults, passed to `render_page(page, opts)`. Avoids the
   12-argument `render()` signature that pypdfium2's `page.render(...)`
   has grown into (`src/pypdfium2/_helpers/page.py`, ~line 280).

7. **Loose vs tight character bounding boxes (pypdfium2, pdfium-render).**
   pypdfium2's `textpage.get_charbox(index, loose=False)` and
   pdfium-render's `char.tight_bounds()` vs `char.loose_bounds()` both
   expose the PDFium distinction between the glyph ink box and the
   advance/line-height box. This matters for figure-text alignment.
   *Applicability to R:* expose both. For regulatory-filing diff work,
   we want tight bounds; for layout reconstruction, loose. Default to
   tight.

8. **Single-tree binary download with build-attestation verification (pypdfium2).**
   `src/pypdfium2/setup.py` and `setupsrc/` pull a pre-built pdfium
   shared library from `https://github.com/bblanchon/pdfium-binaries/`
   at install time, and the README explicitly recommends installing
   `gh` so the GitHub build attestation is verified before use.
   *Applicability to R:* this is the cleanest model for our Tier-A
   binary-distribution decision (see ADR-003). We can vendor a
   download-on-configure script in `tools/` that uses `curl` /
   `R.utils::download.file` and verifies a checksum. The attestation
   step would be optional but worth documenting.

9. **Convert-on-output bitmap adapters (pypdfium2).**
   `_helpers/bitmap.py` exposes `to_numpy()` and `to_pil()` plus
   `from_pil()` so the same `PdfBitmap` can flow into the two
   dominant Python imaging libraries with one method call each.
   *Applicability to R:* expose `as.raster()`, `as.nativeRaster()` (for
   the `grid` package), and optionally a `magick::image_read` adapter.
   Users will want to feed these into ggplot/grid/magick without
   re-allocating.

10. **WASM-aware byte-source loader (pdfium-render, hyzyla).**
    Both pdfium-render's `load_pdf_from_byte_vec` / `load_pdf_from_blob`
    and hyzyla's `library.loadDocument(buff)` keep ownership of the
    PDF source bytes alive for as long as the document is open, because
    PDFium does not copy. pdfium-render encodes this in lifetimes;
    hyzyla allocates inside WASM heap with `malloc` and frees on
    `document.destroy()`.
    *Applicability to R:* if we accept a `raw` vector source, we must
    `R_PreserveObject(src)` (or hold an `Rcpp::RawVector` member) for
    the document's lifetime. Don't trust users to keep their `raw`
    around. Document this in ADR-005 alongside the handle model.

---

## 3. Features we didn't realize we needed

Items spotted in upstream wrappers that look genuinely useful for the
scientific-figure / regulatory-filing / PDF-normalization workloads
`pdfium` is aiming at, but weren't in the original Tier 1/2/3 scope.

- **Loose vs tight character bbox** (pypdfium2, pdfium-render).
  Tight is the inked glyph; loose includes leading/ascent/descent. We
  want both for line-reconstruction and gap detection.
- **`FPDFFont_GetGlyphPath` — vector outline of a glyph** (pdfium-render
  exposes via `PdfFontGlyphs`). Lets us redraw text as path geometry,
  useful for vector-output normalization (e.g., turning a figure
  caption into Bezier curves so it renders identically without the
  font).
- **`is_generated` / `is_hyphen` per-char flags** (pdfium-rs
  `get_text_index_from_char_index` / `is_generated` / `is_hyphen`).
  PDFium synthesizes characters at line boundaries; flagging them
  lets us avoid double-counting.
- **Marked content + Marked-Content ID** (pdfium-rs `get_marked_content_id`,
  `add_mark`, `count_marks` on page objects). Tagged-PDF accessibility
  relies on this. For regulatory work we may want to read and preserve
  marks during a round-trip.
- **DocMDP / signature permission level** (pdfium-rs
  `FPDFSignatureObj_GetDocMDPPermission`, pdfium-render
  `modification_detection_permission`). This is the PDF "this
  signature locks the document at level N" flag — important for
  knowing whether a normalization step would invalidate a sig.
- **Page label (i, ii, iii, ...) vs page index** (pdfium-render
  `page.label()`, pdfium-rs `metadata_value`). Regulatory filings
  use roman-numeral front matter — the index is not what users cite.
- **Per-object `is_active` / `set_inactive` flag** (pdfium-rs and
  pdfium-render). Lets you mark page objects as hidden without
  removing them — useful for redaction workflows.
- **Embedded thumbnails** (pdfium-render `page.embedded_thumbnail()`).
  Some PDFs ship pre-rendered thumbnails; for indexing large filing
  archives that's a huge speed-up vs re-rendering.
- **Object filter on enumeration** (pypdfium2 `get_objects(filter=...)`).
  If a user only wants paths, don't make them iterate text and
  images. Small ergonomics win that saves real time in large PDFs.
- **Text bounding-rect coalescing** (`FPDFText_CountRects` +
  `FPDFText_GetRect`, exposed by pypdfium2 `count_rects` /
  `get_rect`, pdfium-rs `count_rects`, pdfium-render via `chars()`).
  Returns merged rectangles per text run instead of per-glyph. Better
  for "highlight this passage" or "where on the page is this text".
- **PosConv: bitmap pixel <-> page coords** (pypdfium2 `PdfPosConv`,
  PdfiumAndroid `mapPageCoordsToDevice`, PdfiumViewer `PointToPdf`).
  Round-trip between rendered pixel coordinates and PDF user-space
  points. Required for click-handling and for overlaying analysis
  results on a rendered figure.
- **File-id / permanent identifier** (pypdfium2 `get_identifier`,
  pdfium-rs `identifier`). The `/ID` array in the PDF trailer is
  what regulatory systems use for "is this the same document".
- **Page boundary boxes beyond just /MediaBox** (pypdfium2 / pdfium-rs /
  pdfium-render all expose crop/bleed/trim/art). For figure
  extraction the trim/art box is often what you actually want.

---

## 4. Memory-management approaches

| Wrapper | Approach | Key code location |
| --- | --- | --- |
| **pypdfium2** | Weakref finalizer with explicit `close()` and parent/child tracking. `AutoCloseable` base class attaches `weakref.finalize` at construction; finalizer captures only handle + parent (no strong refs). Manual `.close()` works too, and `__exit__` is supported for context-manager use. Parent objects warn if kids are not yet closed. | `src/pypdfium2/internal/bases.py` lines ~105-180 |
| **pdfium-rs** | Internal refcounted `Handle<T>` via `parking_lot::ReentrantMutex`. The wrapper structs (`PdfiumDocument`, `PdfiumPage`, ...) are `Clone` and have no Rust lifetime parameter; the underlying C handle is freed only when the last `Handle` drops. README explicitly demonstrates `drop(document); page.render(...)` working. | `src/pdfium_types.rs`, `src/c_api/pdfium.rs`, lib readme line ~80 |
| **pdfium-render** | RAII via `impl Drop` on each wrapper plus explicit Rust lifetimes (`PdfPage<'a>`). The `<'a>` lifetime ties pages to their parent document; borrow checker enforces order. As of 0.9 wrappers also implement `Send + Sync`. | `impl<'a> Drop for PdfDocument` in `src/pdf/document.rs`, ditto in `page.rs`, `bitmap.rs` |
| **hyzyla** | Manual `destroy()` calls — no GC integration. The user *must* call `document.destroy()` and `library.destroy()` (README warns "you'll be fired for causing a memory leak"). WASM malloc/free pairs are tracked inside `PDFiumDocument` constructor. | `src/document.ts`, `src/library.ts` |
| **PdfiumAndroid** | Explicit `closeDocument` plus a static `Object lock` so all native calls are serialized — PDFium is not thread-safe so the wrapper enforces single-threaded access globally. No finalizer; Java GC won't help. | `PdfiumCore.java` line ~95 (`private static final Object lock`) |
| **PdfiumViewer** | `IDisposable` pattern (`PdfDocument.Dispose()`); native `FPDF_AddRef` / `FPDF_Release` on `PdfLibrary` so initialization happens at most once across multiple documents. | `PdfDocument.cs`, `PdfLibrary.cs`, `NativeMethods.Pdfium.cs:FPDF_AddRef/_Release` |

For R, the closest existing R analogue to pypdfium2's pattern is the
classic `R_RegisterCFinalizerEx` on an `externalptr`. The pdfium-render
borrow-checker lifetime model has no direct R equivalent — R has no
compile-time lifetime tracking, so we must either:

- Track parents explicitly (pypdfium2 style: page holds a reference to
  its document so the document can't be finalized before the page); or
- Use the pdfium-rs Arc-style approach: each handle holds an internal
  refcount and is closed only on the last release. This adds C++
  bookkeeping but is the most foolproof.

ADR-005 should pick one. The pypdfium2 approach is simpler to implement
in Rcpp; the pdfium-rs approach is more user-forgiving.

---

## 5. Binary-distribution approaches

| Wrapper | How pdfium is shipped / located |
| --- | --- |
| **pypdfium2** | Vendored at install time. `setup.py` downloads pre-built shared libs from `https://github.com/bblanchon/pdfium-binaries/releases` and bundles them into the wheel. Pre-built wheels exist for all major platforms; fallback is system-pdfium or source build. `setup.py` will verify GitHub build attestations if `gh` CLI is present. README explicitly recommends this. |
| **pdfium-rs** | User obtains it themselves. Crate does not include pdfium. README directs to `bblanchon/pdfium-binaries/releases` and tells users where to put `libpdfium.so` / `pdfium.dll` / `libpdfium.dylib` (system path, exe dir, or custom via `set_library_location("...")`). Uses `libloading` to open at runtime. |
| **pdfium-render** | Like pdfium-rs but more flexible. Supports dynamic linking via `libloading`, static linking via `feature = "static"` and `PDFIUM_STATIC_LIB_PATH`, or WASM module side-loading. README links to two binary sources (`bblanchon/pdfium-binaries` and `paulocoutinhox/pdfium-lib`). Multi-version support: features `pdfium_6996`, `pdfium_7543`, `pdfium_7763`, `pdfium_latest` pin to specific PDFium ABI versions. |
| **hyzyla** | Vendored in the npm package. The WASM blob is built from `paulocoutinhox/pdfium-lib` and shipped as part of `@hyzyla/pdfium`. README says "zero dependencies". For browsers, user must pass `wasmUrl` or `wasmBinary` to `PDFiumLibrary.init()`. |
| **PdfiumAndroid** | Vendored as `.so` files per ABI in `src/main/jni/lib/{arm64-v8a,armeabi-v7a,x86,x86_64,mips,mips64}/`. The build also bundles a custom JNI shim (`mainJNILib.cpp`). Loaded with `System.loadLibrary("modpdfium")`. |
| **PdfiumViewer** | Not vendored. README is explicit: "PdfiumViewer control requires native PDFium libraries. These are not included in the PdfiumViewer NuGet package" and links to a wiki installation page. Native lookup goes through `PdfiumResolver` so the host app can supply the .dll path. |

Summary for ADR-003:

- The clear precedent is to vendor binaries from
  `bblanchon/pdfium-binaries` (used by pypdfium2 wheels, recommended by
  pdfium-rs and pdfium-render). It's MIT-licensed, GitHub-Actions-built,
  attestation-signed, covers all platforms CRAN cares about, and tracks
  Chromium's pdfium release cadence.
- Pure runtime lookup (pdfium-rs / pdfium-render / PdfiumViewer style)
  pushes the install problem onto users — fine for Rust/C# audiences
  used to that, harder for R users who expect `install.packages()` to
  Just Work.
- Vendoring inside the package tarball (PdfiumAndroid style) would
  exceed CRAN size limits for the typical pdfium shared lib (~10 MB
  compressed, ~30 MB unpacked per platform).
- The realistic R-package shape is: download-on-configure (similar to
  `arrow`, `duckdb`, `cmdstanr`'s approach to large native deps) with
  a cached binary in `tools/`, and a fallback to system pdfium if a
  user sets a `PDFIUM_LIB` env var. That matches the pdfium-render
  flexibility model with the pypdfium2 default ergonomics.
