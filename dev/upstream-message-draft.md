# Draft message for `pdfium@googlegroups.com`

A consolidated "things we'd like to see in the public C API" message
from the R-bindings perspective. Drafted 2026-05-21 after closing
out the v0.1.0 release of the `pdfium` R package
(<https://github.com/humanpred/rpdfium>) — a Rcpp wrapper that
covers the full read surface plus a focused mutation surface
(structural page edits, page-object styling + geometry, page-object
creation, annotation authoring, form filling, attachment authoring).

The list below is the residue we couldn't ship cleanly because the
public C API is missing a symbol whose internal implementation
already exists. Six patches are drafted in our repo under
`dev/upstream-patches/` and are ready for upload from a CLA-signed
account; the other six are described with enough detail to map
directly onto an internal `CPDF_*` class method.

Suggested subject line:
> **API: 12 small writer additions to round out reader/writer
> symmetry (R-bindings perspective)**

---

## Suggested message body

Hi pdfium@,

I maintain the `pdfium` R package
(<https://github.com/humanpred/rpdfium>), which is the first
comprehensive R binding for PDFium. We just closed v0.1.0, which
ships ~70% of the public C API — every PDFium symbol that maps
cleanly to an R-side concept. While doing that we kept a careful
log of public-API gaps where PDFium has the internal implementation
but no `FPDF_EXPORT` symbol for embedders to call. I'm writing to
ask whether the project would welcome a consolidated batch of small
writer-side additions to close these gaps.

Background on why these specifically: most R-side workflows are
"open a PDF, inspect it, change one or two things, save". The
read side is well-covered already (path geometry, text, annotations,
form fields, attachments, signatures, structure tree). The write
side has comprehensive coverage too — page rotation, page-object
matrix / colors / dash patterns, path geometry rebuild, page-object
creation (paths, rects, text, JPEG images), annotation authoring,
form field value writers, attachment authoring. But there's a
consistent pattern of "we have `_GetX()` but no `_SetX()`" where
the internal class already supports the write, and that's the gap
we'd like to discuss.

### What's already in flight (no action needed from us)

* `FPDFPath_GetBezierControlPoints` — CL 147810, ps2, uploaded
  2026-05-15.
* `FPDFTextObj_SetFontSize` — drafted in our repo, ready for
  upload from a CLA-signed account.
* `FPDFAnnot_AppendOption` + `FPDFAnnot_RemoveOptions` — drafted
  in our repo, ready for upload.

### What we have drafted patches for (need a CLA-signed reviewer)

These six patches live in our repo under `dev/upstream-patches/`.
Each is a thin C-shim mirror of an existing internal method (~10-30
LOC of implementation, plus `fpdf_view_c_api_test.c` `CHK` entries
and a 3-block `embeddertests` test); none introduces new core
algorithms. They follow the precedent shape already established by
the in-flight patches above.

1. **`FPDF_SetMetaText(doc, key, value)`** — the missing setter for
   `/Info` dictionary entries. PDFium already mutates `/Info` for
   `/Producer` and `/CreationDate` on save; the public symbol just
   needs to call the same path with the embedder's key + UTF-16
   value.

2. **`FPDFAttachment_SetSubtype(attachment, subtype)`** — pairs
   with the existing `FPDFAttachment_GetSubtype` reader. Without
   it the embedder has to use the generic `SetStringValue("Subtype")`
   shape, which works but bypasses subtype-name normalisation.

3. **`FPDFAnnot_SetNumberValue(annot, key, value)`** — the float
   complement to `FPDFAnnot_SetStringValue`. Used by `/CA`
   (constant opacity), `/IT` (free-text rotation), `/BS/W` (border
   width), and custom-namespace floats. Existing internal method:
   `pdf_dict->SetNewFor<CPDF_Number>(key, value)`.

### What we'd like to add (no patches yet — looking for sign-off
### on scope before writing them)

Each entry lists the proposed signature, the existing internal
support, and the embedder workflow that motivates it.

4. **Bookmark / outline authoring (4 symbols)**

   ```c
   FPDF_BOOKMARK FPDFBookmark_New(FPDF_DOCUMENT doc,
                                  FPDF_BOOKMARK parent_or_null,
                                  FPDF_WIDESTRING title);
   FPDF_BOOL FPDFBookmark_SetTitle(FPDF_BOOKMARK bm,
                                    FPDF_WIDESTRING title);
   FPDF_BOOL FPDFBookmark_SetDest(FPDF_BOOKMARK bm,
                                    FPDF_DEST dest);
   FPDF_BOOL FPDFBookmark_Delete(FPDF_BOOKMARK bm);
   ```

   The reader side (`FPDFBookmark_Get*`, `FPDFAction_*`,
   `FPDFDest_*`) is complete and very widely used by viewers and
   doc-organizing tools. PDFium internally has full outline-tree
   mutation in `CPDF_BookmarkTree`; only the public shim is
   missing. The R-side workflow is "open a PDF, programmatically
   add a per-section TOC", which has no current path.

5. **`FPDFAnnot_SetFormFieldValue` / `_SetFormFieldExportValue`**
   — the embedder-side complement to the existing
   `FPDFAnnot_GetFormFieldValue` /  `_GetFormFieldExportValue`
   readers. Today the R wrapper writes form-field values through
   `FPDFAnnot_SetStringValue("V", ...)` plus `_AS` mirroring,
   which works but bypasses field-type-aware coercion. PDFium
   has the type-aware path internally
   (`CPDF_InteractiveForm::SetField*Value`); just no public shim.

6. **`FPDF_SetEncryption` / `FPDF_RemoveEncryption`** — paired with
   the existing `FPDF_GetSecurityHandlerRevision` /  `_GetDocPermissions`
   /  `_GetDocUserPermissions` readers. PDFium can read every
   encryption variant and supports writing in
   `CPDF_SecurityHandler::OnCreate`; the public shim would unblock
   on-save password protection for embedders that currently have
   to post-process through qpdf.

7. **`FPDFAnnot_SetGoToAction` / `_SetLaunchAction` / `_SetNamedAction`**
   — paired with the existing `FPDFAction_*` readers. Useful for
   embedders that programmatically build link annotations pointing
   to in-document destinations. Internal action-dict mutation is
   already supported via the existing `CPDF_Dictionary::SetNewFor`
   path; the C shim is missing.

8. **`FPDFAnnot_SetVertices` / `_SetLine`** — paired with the
   existing `FPDFAnnot_CountVertices` / `_GetVertex` /
   `_GetLine` readers. Used for polygon / polyline / line
   annotations. Without the writer side, embedders can create
   line / polygon annots but can't author their geometry.

9. **`FPDFFormObj_AppendObject`** — the embedder-side complement to
   the existing `FPDFFormObj_*Get*` readers + the recently-added
   `FPDFFormObj_RemoveObject`. Lets embedders construct form
   XObjects programmatically rather than only via
   `FPDF_NewXObjectFromPage`. PDFium internally already supports
   appending objects to a form XObject's stream; the public shim
   is missing.

10. **Color-space introspection on page objects** — five readers
    are missing on the read side, which forces embedders that need
    full colorspace info to parse raw content streams. The set:

    ```c
    FPDF_COLORSPACE FPDFPageObj_GetFillColorSpace(FPDF_PAGEOBJECT);
    FPDF_COLORSPACE FPDFPageObj_GetStrokeColorSpace(FPDF_PAGEOBJECT);
    FPDF_BOOL FPDFPageObj_GetFillColorRaw(FPDF_PAGEOBJECT, ...);
    FPDF_BOOL FPDFPageObj_GetStrokeColorRaw(FPDF_PAGEOBJECT, ...);
    // plus a CPDF_ColorSpace handle accessor + name getter
    ```

    Today the public surface only returns RGBA byte tuples; the
    raw colorspace path (DeviceN, ICCBased, Indexed) is
    inaccessible. Internally `CPDF_PageObject::m_ColorState`
    exposes the full info.

11. **`FPDFAnnot_SetFont` / `SetFontColor`** taking an `FPDF_FONT`
    handle — the existing `FPDFAnnot_SetFontColor(form, annot, R,
    G, B)` requires a form-fill environment and only sets the color.
    The proposed handle-taking variants would let embedders pair
    `pdf_font_load()` with annotation authoring directly. (Note:
    we observed a likely-our-side crash with the existing
    `FPDFAnnot_SetFontColor` from R that we couldn't reproduce
    in pure C++ — separate issue, not asking for upstream help on
    that yet.)

12. **`FPDF_CreateClipPathFromPath` / `FPDFClipPath_AppendPath`** —
    pair with the existing `FPDF_CreateClipPath(left, bottom,
    right, top)`. The current public API only creates rectangular
    clip boxes; full path-based clipping (which PDF supports per
    spec) requires writing raw content-stream operators today.

### Cross-cutting questions for the list

* **Batching:** do you prefer one large meta-CL or one CL per
  symbol? Our six drafted patches are split per-symbol, but we're
  happy to combine related ones if that's the project's preference.

* **Testing layout:** the in-flight patches we've followed use a
  three-block embedder-test layout (round-trip, rejection,
  persistence-via-save-and-reopen) — is that the preferred shape?

* **`Experimental` annotation:** PDFium's convention is that
  newly-introduced symbols carry an `// Experimental API.` line in
  the header. None of these 12 would need to leave experimental
  immediately — happy to follow whatever timeline the project
  uses for promoting symbols.

* **Lower-priority observations:** we also catalogued a handful of
  smaller asymmetries (no `FPDF_SetFileIdentifier`, no
  `FPDFPageObj_SetMark*` writer family, no `FPDF_StructElement_Set*`
  family) where the internal hook either doesn't exist or is large
  enough to warrant a separate discussion. We're not asking for
  them now; mentioning them only so future audits don't re-discover
  them as novelties.

Full per-CL detail (signatures, internal-method pointers, R-side
consumers) lives at
<https://github.com/humanpred/rpdfium/blob/main/dev/upstream-api-gaps.md>.
Drafted patches are at
<https://github.com/humanpred/rpdfium/tree/main/dev/upstream-patches>.

Happy to upload any of the drafted patches via a contributor with a
signed CLA, refactor them per project conventions, write the
remaining six, or rework any of the proposals based on feedback.

Thanks for PDFium — the public C API has been a pleasure to wrap.

— Bill Denney, on behalf of the `pdfium` R-package maintainers

---

## Notes on tone and audience

* Tone is "embedder reporting back what we found while shipping a
  comprehensive binding", not "you have a bug, fix it". PDFium's
  maintainers are responsive to well-scoped requests but the list
  gets churn-y if every embedder shows up with a unilateral list.

* We deliberately do NOT ask the list to chase the segfault we
  observed in `FPDFAnnot_SetFontColor` / `_SetFormFieldFlags` /
  `_SetFocusableSubtypes` from R — we can't reproduce it from
  pure C++ (see `dev/reprex/`), so until we can, the right framing
  is "probably ours, not yours".

* The "cross-cutting questions" block is the actual call to
  action: it asks for sign-off on scope + conventions before we
  invest time writing the remaining six patches.

* If the response is "this is too much for one thread", suggested
  follow-up is to split into three threads: (a) Info-dict /
  attachment / annotation-number writers (drafted; ask for review
  pointers); (b) Bookmark + form-field-value + encryption + action
  writers (need scope sign-off before drafting); (c) Color-space
  introspection (probably its own larger discussion since it
  exposes `CPDF_ColorSpace` to the public surface).
