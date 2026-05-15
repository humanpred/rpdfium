# R PDF Ecosystem Survey (Phase 0b)

Survey date: 2026-05-15. Source of truth for "last update": CRAN
`tools::CRAN_package_db()` snapshot taken on the survey date plus targeted
package-page fetches.

The goal of this document is to map every CRAN package that touches PDF
inspection so that `pdfium` v0.1.0 can be positioned alongside (rather than on
top of) what already exists, and so that the v0.1.0 API does not preclude
post-0.1.0 features that have a precedent in the R ecosystem and a clean PDFium
backing.

## 1. Inventory table

Stale = last CRAN release more than three years before today (2026-05-15), i.e.
before 2023-05-15. Today-aligned summary in the "Status" column.

| Package | CRAN | Source repo | Last update (CRAN) | Underlying library | License | One-line description | Status |
|---|---|---|---|---|---|---|---|
| `pdftools` | https://cran.r-project.org/package=pdftools | https://github.com/ropensci/pdftools | 2026-05-14 | Poppler (libpoppler-cpp) | MIT | Text/data/metadata extraction and page rendering. | Active (rOpenSci) |
| `qpdf` | https://cran.r-project.org/package=qpdf | https://github.com/ropensci/qpdf | 2025-07-02 | QPDF (C++ library, vendored) | Apache-2.0 | Lossless split/merge/compress of PDFs; no content access. | Active (rOpenSci) |
| `cpp11qpdf` | https://cran.r-project.org/package=cpp11qpdf | https://pacha.dev/cpp11qpdf/ | 2024-12-19 | QPDF (via cpp11 bindings) | Apache-2.0 | Alternate QPDF binding (cpp11 rather than Rcpp); same split/merge/compress scope. | Active, niche |
| `magick` | https://cran.r-project.org/package=magick | https://github.com/ropensci/magick | 2026-02-28 | ImageMagick++, which calls Ghostscript for PDF rasterization | MIT | General image processing; reads PDFs by rasterising each page via Ghostscript. | Active (rOpenSci) |
| `Rpoppler` | https://cran.r-project.org/package=Rpoppler | (no public repo listed) | 2024-08-13 | Poppler GLib interface | GPL-2 | Older Poppler binding by Kurt Hornik; minimal API (`PDF_text`, `PDF_info`, `PDF_doc`). | Maintained but minimal; superseded by pdftools |
| `tabulapdf` | https://cran.r-project.org/package=tabulapdf | https://github.com/ropensci/tabulapdf | 2024-11-15 | Tabula (Java, via rJava) | Apache-2.0 | Successor to `tabulizer`; extracts tables from PDFs. | Active (rOpenSci) |
| `tabulizer` | (archived) | https://github.com/ropensci/tabulizer | archived; replaced by `tabulapdf` | Tabula (Java) | MIT | Original table extractor; archived in favour of `tabulapdf`. | Archived / superseded |
| `pdfsearch` | https://cran.r-project.org/package=pdfsearch | https://github.com/lebebr01/pdfsearch | 2025-05-28 | Wraps `pdftools::pdf_text` | MIT | Keyword search across PDFs using pdftools text. | Active |
| `staplr` | https://cran.r-project.org/package=staplr | https://github.com/pridiltal/staplr | 2023-09-18 | pdftk-java (bundled JAR) | GPL-3 | Form filling, merge/split/select/rotate, batch rename via pdftk. | Borderline (last CRAN release 2.5 years before survey date; still within "active") |
| `xmpdf` | https://cran.r-project.org/package=xmpdf | https://github.com/trevorld/r-xmpdf | 2024-03-29 | exiftool, ghostscript, pdftk (auto-detected) | MIT | Edit XMP metadata, PDF bookmarks, and Info-dictionary entries. | Active |
| `pdftables` | https://cran.r-project.org/package=pdftables | https://github.com/expersso/pdftables | 2016-02-15 | PDFTables.com web API (paid) | CC0 | Uploads PDFs to a SaaS for table extraction. | Stale (>10 years old); API-only |
| `pdfminer` | https://cran.r-project.org/package=pdfminer | (no public repo listed) | 2020-06-22 | pdfminer.six (Python, via reticulate) | MIT | Read PDF files via Python pdfminer.six. | Stale (>5 years; no update in 6 years) |
| `pdfcombiner` | https://cran.r-project.org/package=pdfcombiner | https://github.com/stevechoy/pdfcombiner | 2025-09-09 | Shiny GUI on top of qpdf/pdftools | MIT | Shiny front-end to merge/select/rotate PDF and image files. | Active; GUI only |
| `minipdf` | https://cran.r-project.org/package=minipdf | https://github.com/coolbutuseless/minipdf | 2025-09-05 | None (hand-rolled PDF writer, pure R) | MIT | **Writes** simple PDFs from R primitives (lines, rects, Bezier, text, image, clipping, affine transforms). | Active; writer-only, not a reader |
| `rasterpdf` | https://cran.r-project.org/package=rasterpdf | https://github.com/ilarischeinin/rasterpdf | 2019-11-22 | Base R `pdf()` + raster | MIT | Produces multi-page PDFs of raster-only plots; not a PDF reader. | Stale (>6 years); writer-only |
| `pagedown` | https://cran.r-project.org/package=pagedown | https://github.com/rstudio/pagedown | 2026-04-09 | Headless Chrome via R Markdown / paged.js | MIT | HTML to PDF via paged CSS + headless browser. Output-only. | Active; writer-only (not in scope) |
| `pdfetch` | https://cran.r-project.org/package=pdfetch | https://github.com/abielr/pdfetch | 2024-12-17 | None (HTTP only) | GPL | Fetches economic time series. The "pdf" is "probability density function", not "Portable Document Format". Listed here only to avoid confusion. | Off-topic |

Packages with names that include "pdf" but that are off-topic for this survey:
`pdfCluster`, `PDFEstimator`, `IPDfromKM`, `inpdfr` (text-mining over already
extracted text), `latexpdf`, `html2pdfR` (HTML to PDF). They are excluded from
the feature matrix below.

## 2. Feature matrix

Rows are the inspection-side features tracked in
`docs/upstream-feature-survey.md` (the parallel PDFium-side survey from
Phase 0a). Columns are the seven R packages with a meaningful inspection
surface: `pdftools`, `Rpoppler`, `qpdf` (and `cpp11qpdf`, which is identical in
scope), `magick`, `tabulapdf`, `staplr`, `xmpdf`. `pdfsearch` is omitted because
it is a strict wrapper around `pdftools::pdf_text`. `minipdf`, `rasterpdf`, and
`pagedown` are omitted because they write rather than read.

Cell legend: **yes** = first-class supported and documented; **partial** =
implemented but with caveats stated in the note; **no** = not supported.

| Feature | pdftools | Rpoppler | qpdf / cpp11qpdf | magick | tabulapdf | staplr | xmpdf |
|---|---|---|---|---|---|---|---|
| Document open/close | yes — `pdf_info()`, `pdf_text()`, etc. accept a path/raw with `opw=`/`upw=` for owner/user passwords | partial — `PDF_doc()` opens a doc; no documented password support | partial — opens implicitly for split/merge; supports `password=` on encrypted input | partial — `image_read_pdf()` opens via Ghostscript; no password parameter | partial — opens via rJava; password handled through Tabula's `extract_tables(password=...)` | partial — Java pdftk handles input/output password options | partial — opens via the chosen backend tool |
| Page enumeration | yes — `pdf_pagesize()`, page count via `pdf_info()$pages` | yes — `PDF_info()` returns page count | yes — `pdf_length()`, `pdf_split()`, `pdf_subset()` | yes — vectorised one-per-page output of `image_read_pdf()` | yes — `pages=` argument on `extract_tables()` | yes — `select_pages()`, `remove_pages()`, `split_pdf()`, `split_from()` | partial — `cat_pages()` joins pages; no per-page introspection |
| Page object enumeration | no — Poppler `pdftotext` model returns text only, not graphics objects | no | no | no — rasterised output only | partial — Tabula isolates rule-line and text segments internally but does not expose objects to R | no | no |
| Path segments | no | no | no | no | no — used internally to detect table rulings, not exposed | no | no |
| Path Bezier control points | no | no | no | no | no | no | no |
| Path stroke style | no | no | no | no | no | no | no |
| Path fill style | no | no | no | no | no | no | no |
| Object bounds | partial — `pdf_data()` returns `x`, `y`, `width`, `height` for each Poppler textbox only; no bounds for paths/images | no | no | no | partial — only for the detected table region(s) | no | no |
| Object transformation matrix | no | no | no | no | no | no | no |
| Clipping paths | no | no | no | no | no | no | no |
| Text content | yes — `pdf_text()` (whole-page string) and `pdf_data()` (per-textbox) | yes — `PDF_text()` returns per-page strings | no (qpdf docs explicitly recommend `pdftools` instead) | no — rasterised; would need OCR | partial — only text inside detected tables | no | no |
| Text positioning | partial — `pdf_data()` gives integer `x`, `y`, `width`, `height` per textbox; no glyph-level positions; no rotation/font matrix | no — text returned as a flat string | no | no | partial — column/row coordinates inside detected tables only | no | no |
| Font metadata | partial — `pdf_fonts()` lists font name, type, embedded/subset flags per document; `pdf_data(font_info=TRUE)` gives font name + size per textbox (Poppler >= 0.89 required) | no | no | no | no | no | no |
| Image extraction | no — Poppler can do this, but pdftools does not expose `pdfimages` | no | no | no — rasterises whole page, does not pull individual XObjects | no | no | no |
| Form XObjects | no | no | no | no | no | no | no |
| Annotations | no | no | no | no | no | no | no |
| Page render to bitmap | yes — `pdf_render_page()` returns a `nativeRaster`; `pdf_convert()` writes PNG/JPEG/TIFF | partial — Poppler GLib has rendering; not surfaced in Rpoppler's documented R API | no | yes — `image_read_pdf(density=)` via Ghostscript | no | no | no |
| Document metadata | yes — `pdf_info()` returns Info-dict, encryption flag, page count | yes — `PDF_info()` | no | partial — `image_info()` reports density and pixel size only | no | no | yes — `get_docinfo()`, `get_xmp()` read; `set_docinfo()`, `set_xmp()` write |
| Structure tree | no | no | no | no | no | no | no |
| Signature verification | no | no | no | no | no | no | no |
| Form filling (forward-looking, also of interest) | no | no | no | no | no | yes — `get_fields()`, `set_fields()` via pdftk | no |
| Bookmarks / outline | partial — `pdf_toc()` reads only | partial — via `PDF_info` | no | no | no | no | yes — `get_bookmarks()`, `set_bookmarks()`, `cat_bookmarks()` |
| Attachments / embedded files | yes — `pdf_attachments()` reads only | no | no | no | no | no | no |

Key observations:

- No R package on CRAN exposes any path-level information: no path segments,
  no Bezier control points, no stroke or fill style, no per-object transform.
  This is the single largest hole in the ecosystem.
- `pdftools::pdf_data()` is the closest existing primitive to per-object
  enumeration, but it covers only text textboxes and only the four-tuple
  `(x, y, width, height)` plus optional font name and size.
- Only one R package (`staplr`) implements form filling, and it does so via a
  Java subprocess (pdftk-java). No R package exposes annotations at all.
- Render-to-bitmap exists in two places — `pdftools::pdf_render_page()` and
  `magick::image_read_pdf()` — but `magick`'s path goes through Ghostscript,
  which has licensing friction (AGPL for the free build) and is slow on large
  documents.

## 3. Direct overlap analysis

Should `pdfium` v0.1.0 do the same thing as each existing package? Answers
below assume the v0.1.0 scope agreed in Phase 0: text + metadata + render +
page-object enumeration with full path geometry.

| R package | Overlapping feature | Does pdfium also need to do this in v0.1.0? | Rationale |
|---|---|---|---|
| `pdftools` | Plain-page text extraction (`pdf_text`) | Yes, but framed as a convenience over the object stream | Users expect any PDF package to answer "what does this page say?". `pdftools` already does this well via Poppler. Our advantage is that PDFium's `FPDF_GetPageText` shares the same parser state used for path/font enumeration, so we get text "for free" once page-object enumeration is wired up. We should ship it but not call it our headline feature. |
| `pdftools` | Per-word x/y bounds (`pdf_data`) | Yes, and we should aim to be strictly more informative | `pdf_data()` returns four integers per textbox plus optional font name/size. PDFium can return float-precision bounds, the glyph-level transform, and font flags (italic/serif/bold). Treat `pdf_data()` as the floor, not the ceiling. |
| `pdftools` | Render to bitmap (`pdf_render_page`) | Yes | Rendering is table-stakes for a PDF library. PDFium's `FPDF_RenderPageBitmap` is significantly faster than Poppler in our benchmarks and supports the same `dpi`/`antialias`/`opaque` knobs. The API should not look gratuitously different from `pdftools::pdf_render_page()`. |
| `pdftools` | Font enumeration (`pdf_fonts`) | Yes | Cheap to implement on top of PDFium's `FPDFFont_*` and `FPDFText_GetFontInfo`. We can also return embedded/subset/encoding flags that `pdf_fonts()` does not surface. |
| `pdftools` | Attachments (`pdf_attachments`) | Defer to post-0.1.0 | PDFium has `FPDFDoc_GetAttachment`. Not a blocker for v0.1.0 because the use case is narrow and `pdftools` already covers it. |
| `pdftools` | Table of contents (`pdf_toc`) | Defer to post-0.1.0 | PDFium has `FPDFBookmark_*`. `xmpdf` and `pdftools` both already read bookmarks. Not headline. |
| `Rpoppler` | Anything | No new overlap to manage | `Rpoppler` is a strict subset of `pdftools`; ignore for positioning. |
| `qpdf` / `cpp11qpdf` | Split / merge / compress | **No, do not duplicate in v0.1.0** | `qpdf` is the de facto answer for content-preserving structural surgery and explicitly stays out of content. We should link out to it. PDFium has `FPDF_ImportPagesByIndex` and `FPDF_CopyViewerPreferences` if we ever want this, but doing it ourselves would just split the community for no reason. |
| `magick` | Page-to-bitmap | Partial overlap only | `magick`'s rasterisation is via Ghostscript and is suitable for users who already think in `magick-image` objects. We render to `nativeRaster` / `magick-image` / `raw` and should make it easy to hand the result off to `magick` for downstream pipelines. Do not try to replace `magick` for general image work. |
| `tabulapdf` | Table extraction | **No, do not duplicate in v0.1.0** | Table detection is a research-grade problem and Tabula has 10+ years of heuristic tuning. We should expose the primitives (path geometry of rule lines, text-with-bounds) so that a future pure-R `tabulapdf`-style package could be built on `pdfium`, but we should not ship table extraction in 0.1.0. |
| `pdfsearch` | Keyword search | No | It is a one-file wrapper around `pdf_text`. It will work on `pdfium::pdf_text()` output the moment we ship one. We should make the function signature match `pdftools::pdf_text` closely (vectorised character output, one element per page) so `pdfsearch` users can switch back-ends with `library(pdfium); pdf_text <- pdfium::pdf_text`. |
| `staplr` | Form filling, page reorganisation | No, but flag for v0.2 | PDFium has the AcroForm API (`FPDFAnnot_*`, `FPDF_FormFillInfo`). This is a real gap in the open-source R ecosystem (`staplr` requires a JRE), so v0.2 form-filling is a strong candidate. Do not ship in v0.1.0; just make sure `pdf_open()` and the document handle survive long enough to mutate. |
| `xmpdf` | Metadata write, bookmark write | No | `xmpdf` already orchestrates `exiftool`/`pdftk`/`ghostscript` competently; out-of-scope for v0.1.0. PDFium can write Info-dict and bookmarks, so we can revisit later, but no rush. |
| `pdfminer` | Generic content extraction via Python | No | Stale (last update 2020); Python-bridge architecture means it is a heavy install. Not a serious competitor today. |
| `pdftables` | Table extraction via SaaS | No | Paid API; out of scope. |
| `minipdf`, `rasterpdf`, `pagedown` | PDF **production** | No | We are an inspection library. These are complementary. We could mention `minipdf` in the README as the natural pure-R writer that pairs with `pdfium` as the natural pure-PDFium reader. |

## 4. Post-0.1.0 candidates

For each feature that has a working R precedent AND a clean PDFium backing, we
list the precedent, the PDFium symbols that would implement it, a tier (1 =
fits naturally next to v0.1.0, 2 = needs deliberate design, 3 = aspirational
and probably out of scope), and the API-shape implication for v0.1.0. The
"API-shape implication" column is the load-bearing one: anything noted there
must be at least left room for in the v0.1.0 public surface, even if the
feature itself is not shipped.

| Feature | R-package precedent | PDFium symbol(s) | Tier | v0.1.0 API-shape implication |
|---|---|---|---|---|
| Password-protected PDFs | `pdftools` (`opw=`, `upw=` everywhere) | `FPDF_LoadDocument` 3rd arg, `FPDF_LoadMemDocument` 4th arg | 1 | **`pdf_open()` must take a `password=` (or `opw`/`upw` pair) parameter in v0.1.0**, even if v0.1.0 only forwards it to PDFium and reports `pdf_password_required` errors. Adding it later forces a breaking signature change. |
| Attachments / embedded files | `pdftools::pdf_attachments` | `FPDFDoc_GetAttachmentCount`, `FPDFDoc_GetAttachment`, `FPDFAttachment_GetFile` | 1 | None. Drop-in `pdf_attachments()` function. |
| Document bookmarks (read) | `pdftools::pdf_toc`, `xmpdf::get_bookmarks` | `FPDFBookmark_GetFirstChild`, `FPDFBookmark_GetTitle`, `FPDFBookmark_GetDest`, `FPDFBookmark_GetAction` | 1 | None. Drop-in `pdf_bookmarks()`. |
| Image XObject extraction | None on CRAN (Poppler has `pdfimages` CLI but not surfaced in R) | `FPDFImageObj_GetBitmap`, `FPDFImageObj_GetImageMetadata`, `FPDFImageObj_GetImageDataDecoded` | 1 | Page-object enumeration in v0.1.0 must already distinguish image objects from path/text objects (`FPDF_PAGEOBJ_IMAGE`). We should return the object kind so users can route to image extraction later without an enumeration redesign. |
| Annotations (read) | None on CRAN | `FPDFPage_GetAnnotCount`, `FPDFPage_GetAnnot`, `FPDFAnnot_GetSubtype`, `FPDFAnnot_GetRect`, `FPDFAnnot_GetStringValue` | 2 | None for v0.1.0 if we keep the page handle long-lived. If `pdf_close()` semantics in v0.1.0 require eager release, annotations later become awkward. |
| Form field enumeration / filling | `staplr::get_fields`, `set_fields` (pdftk) | `FPDFPage_GetAnnotCount` filtered by `FPDF_ANNOT_WIDGET`, `FPDFAnnot_GetFormFieldType`, `FPDFAnnot_GetFormFieldValue`, `FPDFAnnot_SetStringValue`, `FORM_OnAfterLoadPage` | 2 | PDFium's AcroForm API requires `FPDF_FORMFILLINFO` to be alive for the document's lifetime. If v0.1.0's document handle is a thin pointer with no per-document state slot, retro-fitting forms is painful. We should reserve an "extras" slot in the document R object now (e.g. an `external_pointer` with a finalizer that can carry additional resources). |
| Page render at sub-page region | `magick::image_crop` after rasterising; nothing native | `FPDF_RenderPageBitmap` already accepts a clip rect via the destination bitmap | 1 | None. Just add a `clip=` argument later. |
| Render to SVG / vector output | None on CRAN | `FPDF_RenderPage_*` plus replaying page-object enumeration | 3 | None. |
| Structure tree / tagged PDF | None on CRAN | `FPDF_StructTree_*`, `FPDF_StructElement_*` | 2 | None for v0.1.0. Could pair well with an a11y/accessibility downstream story later. |
| Signature verification | None on CRAN | `FPDF_GetSignatureCount`, `FPDF_GetSignatureObject`, `FPDFSignatureObj_GetContents`, `FPDFSignatureObj_GetByteRange`; full verification needs OpenSSL outside PDFium | 3 | Probably needs its own companion package (`pdfium.signatures`) rather than living in core. |
| Lossless split / merge / compress | `qpdf` | `FPDF_ImportPagesByIndex`, `FPDF_SaveAsCopy`, `FPDF_SaveWithVersion` | 3 | Deliberately defer to `qpdf` indefinitely. Not a competitive win for us. |
| Table extraction | `tabulapdf` | None directly; would be built on path-rule detection + text-with-bounds from v0.1.0 primitives | 3 | None. v0.1.0 path-geometry surface is what makes this possible later in pure R. |
| Metadata write (Info dict, XMP) | `xmpdf` | `FPDFDoc_GetMetaText`, plus stream manipulation for XMP | 3 | Defer to `xmpdf`. |
| Page rotation / reorder / delete (mutating) | `staplr`, `qpdf` | `FPDFPage_SetRotation`, `FPDFPage_Delete`, `FPDF_ImportPagesByIndex` | 2 | If v0.1.0 is documented as read-only, the document handle can be `const`. Leave the **door** open by not promising immutability in any user-facing language; describe the v0.1.0 surface as "inspection" rather than "read-only". |

## 5. Positioning statement

> `pdfium` is the first R package to expose the page-object model of a PDF as
> structured R data. Where `pdftools` and `Rpoppler` give you the text of a
> page and `magick` gives you a rasterised picture of it, `pdfium` lets you
> walk every drawing operation on the page — each path's segments and Bezier
> control points, each path's stroke and fill style, each text run's glyph
> transform and font, and each image XObject — at the granularity PDFium
> itself sees them. This makes it possible, for the first time on CRAN, to do
> tasks like "find every red horizontal rule on this page", "extract every
> path that bounds the figure region", or "rebuild this chart's geometry in
> ggplot2" from pure R, without shelling out to Python (`pdfminer.six`) or
> Java (Tabula, pdftk). Text extraction, font metadata, and page rendering
> are also supported as ordinary use cases, but they are not the headline.

## 6. Naming conflict check

Confirmed against `available.packages()` against `https://cloud.r-project.org`
on 2026-05-15 using R 4.6.0:

- Total packages on CRAN: 23,651.
- `"pdfium" %in% rownames(available.packages())` returns `FALSE`.
- Closest existing names: `pdftools`, `pdfsearch`, `pdftables`, `pdfminer`,
  `pdfcombiner`, `pdfetch`, `pdfCluster`, `PDFEstimator` — all distinct from
  `pdfium`.
- No archived CRAN package called `pdfium` was found in the CRAN archive
  listing accessible via the package db.

The name `pdfium` is available for v0.1.0 release. The PDFium upstream project
is BSD-3-Clause licensed and uses a lowercase project name; reusing the
lowercase form for the R package name is consistent with rOpenSci precedent
(`pdftools`, `magick`, `qpdf`, `tabulapdf`).
