# PDFium public-API gap list (for a consolidated upstream request)

A tracking document for missing-symmetry and missing-feature gaps in
the PDFium public C API. The goal is a single, well-scoped batch of
proposed changes to take to the `pdfium-reviews@googlegroups.com`
mailing list once we've talked them over internally — not a
torrent of independent CLs. Quality and self-containment matter more
than coverage breadth.

Each entry is structured so that, if we choose to pursue it, the
proposal text below can become the cover-letter description of an
actual Gerrit CL.

## Provenance

- Date: 2026-05-21.
- Upstream HEAD walked: `e30fc3988` (immediately before the
  in-flight `FPDFAnnot_AppendOption` patch lands in
  `/home/bill/src/pdfium`). Bundled headers in
  `inst/include/fpdf_*.h` track `chromium/7202`; the structural
  gap analysis below is stable across the small delta between the
  two.
- Method:
  1. Grep `FPDF_EXPORT` declarations across all 22 public headers
     in `public/fpdf_*.h` to enumerate every exposed symbol.
  2. Pair every `_Get*` symbol with the corresponding `_Set*` and
     list the unpaired getters. 173 getters / 41 setters across
     the headers means most exported symbols are reader-only; that's
     fine, since many are intrinsically read-only (parser internals,
     bitmap rasterizations, signature data). The interesting list
     is the smaller set of getters whose write side would clearly
     unblock embedder workflows.
  3. Cross-reference each gap with the `pdfium` R package's
     reader-writer audit
     (`/home/bill/github/rpdfium/dev/reader-writer-audit.md`) to
     pin every entry to a real R-side consumer that would gain a
     non-hacky writer path.
  4. Walk the internal `CPDF_*` classes under
     `core/fpdfdoc/`, `core/fpdfapi/page/`, and
     `core/fpdfapi/parser/` to find utility methods that look
     useful but aren't exposed.

## In flight (don't re-request)

These have working drafts in
`dev/upstream-patches/` or are uploaded to Gerrit already. The
consolidated mailing-list request should mention them as existing
prior art rather than repeating their motivation.

- `FPDFPath_GetBezierControlPoints` — CL 147810, patchset 2,
  uploaded 2026-05-15.
- `FPDFTextObj_SetFontSize` — patch drafted 2026-05-20, ready to
  upload from a CLA-signed account.
- `FPDFAnnot_AppendOption` + `FPDFAnnot_RemoveOptions` — patch
  drafted 2026-05-20, ready to upload.
- `FPDF_SetMetaText` — patch drafted 2026-05-21 (CL 1 below); see
  `dev/upstream-patches/pdfium-FPDF_SetMetaText.patch`.
- `FPDFAttachment_SetSubtype` — patch drafted 2026-05-21 (CL 6
  below); see
  `dev/upstream-patches/pdfium-FPDFAttachment_SetSubtype.patch`.

## Proposed CLs

Each entry below is self-contained: signature, motivation,
internal-implementation pointer, R-side consumer, and an estimate of
how independent it is from the others. Order is rough priority for
the consolidated request: gaps that unblock the most user-visible R
functionality first, geometry / authoring writers next,
deeper-structural items last.

### CL 1: Document Info dictionary writers — **drafted**

**Symbols proposed:**

```c
FPDF_EXPORT FPDF_BOOL FPDF_CALLCONV
FPDF_SetMetaText(FPDF_DOCUMENT document,
                 FPDF_BYTESTRING tag,
                 FPDF_WIDESTRING value);
```

**Rationale:** `FPDF_GetMetaText` is one of the oldest reader
symbols in `fpdf_doc.h` and is wrapped by every binding we
surveyed (pypdfium2, pdfium-rs, pdfium-render, hyzyla,
PdfiumAndroid, PdfiumViewer). There is no public way to set
`/Info/Title`, `/Info/Author`, `/Info/Subject`, `/Info/Keywords`,
`/Info/Creator`, `/Info/Producer`, `/Info/CreationDate`, or
`/Info/ModDate`. The only workaround embedders have today is to
re-parse the saved PDF, mutate the trailer dictionary, and re-save
with `FPDF_SaveAsCopy` — which fails on incremental saves and
loses any in-memory mutations not yet flushed. Setting `/Info`
fields at PDF-generation time is also impossible: `FPDF_CreateNewDocument`
returns a doc with an empty Info dict that the embedder can't fill.

The doc-comment should make clear that:

- Empty string deletes the entry (matches PDFium's
  `FPDFCatalog_SetLanguage` precedent).
- Date keys (`CreationDate`, `ModDate`) take a PDF date string
  (`D:YYYYMMDDHHMMSS+HH'MM'`); the caller is responsible for
  formatting. We considered a `FPDF_SetMetaDate` helper but the
  string-formatting boundary is the same as what
  `FPDF_GetMetaText` already returns, so symmetry argues for a
  single setter.

**Internal implementation pointer:** `CPDF_Document::GetInfo()`
in `core/fpdfapi/parser/cpdf_document.h` already returns a mutable
`RetainPtr<CPDF_Dictionary>`. The C-shim
`FPDF_GetMetaText` (in `fpdfsdk/fpdf_doc.cpp` around line 539)
reads from that dict via `GetUnicodeTextFor(tag)`. A setter is a
trivial `SetNewFor<CPDF_String>(tag, value, /*as_hex=*/false)`
mirror, gated on `tag != nullptr` and `document != nullptr`.

**R-side consumer:** `pdf_doc_set_meta(doc, key, value)` —
identified as the single most-requested writer in the v0.1.0 user
survey
(see `dev/v0.1.0-api-gap-audit.md` §"Document metadata writers").
The reader (`pdf_doc_info()`) has shipped since 0.1.0; the writer
is on the v0.2.0 roadmap pending this CL.

**Self-contained?** yes.

### CL 2: Bookmark / outline authoring (4 symbols)

**Symbols proposed:**

```c
FPDF_EXPORT FPDF_BOOKMARK FPDF_CALLCONV
FPDFBookmark_New(FPDF_DOCUMENT document,
                 FPDF_BOOKMARK parent,
                 FPDF_BOOKMARK insert_after);

FPDF_EXPORT FPDF_BOOL FPDF_CALLCONV
FPDFBookmark_SetTitle(FPDF_BOOKMARK bookmark,
                      FPDF_WIDESTRING title);

FPDF_EXPORT FPDF_BOOL FPDF_CALLCONV
FPDFBookmark_SetDest(FPDF_DOCUMENT document,
                     FPDF_BOOKMARK bookmark,
                     FPDF_DEST dest);

FPDF_EXPORT FPDF_BOOL FPDF_CALLCONV
FPDFBookmark_Delete(FPDF_DOCUMENT document, FPDF_BOOKMARK bookmark);
```

**Rationale:** The reader half is comprehensive
(`FPDFBookmark_GetFirstChild`, `GetNextSibling`, `GetTitle`,
`GetCount`, `Find`, `GetDest`, `GetAction`), but there's no path
to write a `/Outlines` tree. Embedders that generate reports
programmatically — academic toolchains, scientific report
generators, batch-PDF assemblers — want to emit a clickable TOC
with one bookmark per section. Today they have to drop down to a
different PDF library (HummusPDF, PDFKit, Reportlab) for this
single operation.

`FPDFBookmark_New` takes a parent (`NULL` ⇒ root) and an insert
position (`NULL` ⇒ append last child). `SetTitle` and `SetDest`
mirror the existing getters; `Delete` removes the bookmark from
its parent's child list and the document's bookmark tree, but does
not free child bookmarks (they get re-parented to the deleted
bookmark's parent, matching the `/Outlines` PDF spec's
behavior for an `OpenAction` removal).

Action setters (`FPDFBookmark_SetAction`) are intentionally
deferred: a follow-up CL adds them once the destination setter
has shaken out the lifecycle questions about `FPDF_DEST`
ownership.

**Internal implementation pointer:** `CPDF_Bookmark` in
`core/fpdfdoc/cpdf_bookmark.h` is currently
immutable — it wraps a `RetainPtr<const CPDF_Dictionary>`. The
internal class would need either a mutable variant or — cleaner —
a `CPDF_BookmarkTree` mutator
(`core/fpdfdoc/cpdf_bookmarktree.h` is already
the natural home; today it only enumerates).

Writes operate on the `/Outlines` root dict on the document, which
is reachable via `doc->GetMutableRoot()->GetMutableDictFor("Outlines")`.
The bookmark-tree walker (`CPDF_BookmarkTree::GetFirstChild`) shows
how to traverse; insertion is the same walk plus pointer
re-wiring on `Prev`/`Next`/`First`/`Last`/`Parent` entries per
PDF spec §12.3.3.

**R-side consumer:** `pdf_bookmark_new()`, `pdf_bookmark_set_title()`,
`pdf_bookmark_set_dest()`, `pdf_bookmark_delete()` — currently
v0.2.0 roadmap, blocked on these symbols.
The `pdf_doc_bookmarks()` reader has shipped since 0.1.0.

**Self-contained?** yes. This is a "closely related cluster"
(per the task brief), packaged as one CL.

### CL 3: Action and destination introspection completers

**Symbols proposed:**

```c
FPDF_EXPORT FPDF_BOOL FPDF_CALLCONV
FPDFAnnot_SetURI(FPDF_ANNOTATION annot, const char* uri);
/* Already exists — listed here only to clarify scope. */

FPDF_EXPORT FPDF_BOOL FPDF_CALLCONV
FPDFAnnot_SetGoToAction(FPDF_DOCUMENT document,
                        FPDF_ANNOTATION annot,
                        int dest_page_index,
                        const FS_FLOAT* view_params,
                        unsigned long num_view_params,
                        unsigned long view_type);

FPDF_EXPORT FPDF_BOOL FPDF_CALLCONV
FPDFAnnot_SetLaunchAction(FPDF_ANNOTATION annot,
                          FPDF_BYTESTRING file_path);

FPDF_EXPORT FPDF_BOOL FPDF_CALLCONV
FPDFAnnot_SetNamedAction(FPDF_ANNOTATION annot,
                         FPDF_BYTESTRING action_name);
```

**Rationale:** `FPDFAnnot_SetURI` exists for link annotations,
but it only handles the URI action subtype. Embedders that
generate cross-document or intra-document hyperlinks programmatically
need `/GoTo`, `/Launch`, or `/Named` actions and have no public
path to set them. The current workaround is to mutate the
annotation dict via PDFium's private surface — not a stable choice.

The signature for `FPDFAnnot_SetGoToAction` mirrors
`FPDFDest_GetView`'s parameter layout (a fit-type code plus up to
4 view-state floats), so caller code that round-trips through
`FPDFDest_GetView` can pass the same shape back. The intra- vs.
inter-document distinction is encoded via the `dest_page_index`
sign: non-negative ⇒ local page, `-1` ⇒ caller has separately
established a remote-goto via `FPDFAnnot_SetLaunchAction` chained
with a follow-up dest.

**Internal implementation pointer:** Each new entry maps to
`annot_dict->GetMutableDict()->SetNewFor<CPDF_Dictionary>("A", ...)`
where the inner dict gets `Type=Action`, `S=GoTo|Launch|Named`,
and the per-type parameters. The shape mirrors what
`FPDFAction_GetType` (in `fpdfsdk/fpdf_doc.cpp`) reads back from
`/A/S`; reuse of those constants keeps the symmetry tight.

**R-side consumer:** `pdf_link_annot_set_action()` —
v0.2.0 roadmap. Today, `pdf_page_links()` reports `action_type`
strings ("uri", "goto", "launch", "named", "remotegoto") in a
read-only column; round-tripping requires this writer to exist.

**Self-contained?** yes, but pairs naturally with CL 4 if the
mailing list pushes for a single coherent "action-authoring"
batch.

### CL 4: Form-field value writer (single annot, single value)

**Symbols proposed:**

```c
FPDF_EXPORT FPDF_BOOL FPDF_CALLCONV
FPDFAnnot_SetFormFieldValue(FPDF_FORMHANDLE hHandle,
                            FPDF_ANNOTATION annot,
                            FPDF_WIDESTRING value);

FPDF_EXPORT FPDF_BOOL FPDF_CALLCONV
FPDFAnnot_SetFormFieldExportValue(FPDF_FORMHANDLE hHandle,
                                  FPDF_ANNOTATION annot,
                                  FPDF_WIDESTRING export_value);
```

**Rationale:** `FPDFAnnot_GetFormFieldValue` and
`FPDFAnnot_GetFormFieldExportValue` exist (the latter for radio
buttons and checkboxes), but only the *interactive* forms surface
exposes value setters: `FORM_ReplaceSelection` and
`FORM_SetIndexSelected` both require an interactive
`FPDF_FORMHANDLE` plus user-event simulation (selection ranges,
focus events). For embedders that just want to programmatically
populate a form — the classic "fill PDF from database" pipeline —
this is the wrong API. They want to write `/V` on the field dict
and let PDFium regenerate the appearance via
`FPDFPage_GenerateContent`.

`FPDFAnnot_SetStringValue("V", ...)` is a partial workaround for
text fields but doesn't update the field's appearance state for
checkboxes/radios (the `/AS` entry on widget annots), so the form
ends up visually wrong while the dictionary says the right
thing. The proposed setter routes through
`CPDF_FormField::SetValue` like the interactive path does, but
without requiring the form-fill environment to be in an
"interactive" state.

The export-value setter is the symmetric companion for radio
button groups: setting `/V` to a non-existent `/AP/N/<name>` key
leaves the field in a broken state, so the setter must also
update `/Kids/N/AS` to match. The two-symbol shape mirrors the
two-getter shape already in the header.

**Internal implementation pointer:**
`CPDF_FormField::SetValue` (in `core/fpdfdoc/cpdf_formfield.h`
around line 109) and `SetCheckValue` (line 165) and
`SetItemSelectionSelected` (line 168) are the three internal
hooks. A new `FPDFAnnot_SetFormFieldValue` would route based on
`GetFormFieldType()` to the right one of those three.

**R-side consumer:** `pdf_form_field_set_value()` and
`pdf_form_field_set_export_value()` — currently v0.2.0 roadmap.
The `pdf_form_fields()` reader has shipped since 0.1.0.

**Self-contained?** yes. Distinct from CL 1's
`FPDFAnnot_AppendOption` (already in-flight) which writes the
`/Opt` array — that's the field's *options*, not its *selected
value*.

### CL 5: Encryption / password-protect on write

**Symbols proposed:**

```c
typedef struct {
  int revision;             /* 0 (legacy), 2, 3, 4, or 5 (AES-256) */
  const char* user_password;
  const char* owner_password;
  uint32_t permissions;     /* PDF spec §7.6.3 permission flags */
  FPDF_BOOL encrypt_metadata;
} FPDF_ENCRYPTION_PARAMS;

FPDF_EXPORT FPDF_BOOL FPDF_CALLCONV
FPDF_SetEncryption(FPDF_DOCUMENT document,
                   const FPDF_ENCRYPTION_PARAMS* params);

FPDF_EXPORT FPDF_BOOL FPDF_CALLCONV
FPDF_RemoveEncryption(FPDF_DOCUMENT document);
```

**Rationale:** PDFium can *read* encrypted PDFs
(`FPDF_LoadDocument` accepts a password argument and
`FPDFCatalog_*` introspects), and `FPDF_SaveAsCopy` accepts a
`FPDF_REMOVE_SECURITY` flag to strip encryption when saving. But
there's no path to *add* encryption: a document created with
`FPDF_CreateNewDocument` and saved with `FPDF_SaveAsCopy` is
always unencrypted. The single most common request in
PDF-generation issue trackers (pypdfium2 #283, pdfium-rs #94,
pdfium-render #186) is "produce a password-protected PDF",
and every binding redirects it upstream.

The proposed API stays narrow — a single struct with the
parameters the PDF spec mandates — to avoid an N-overload
explosion. AES-256 (revision 6) is intentionally left
out for v1; it can ship as a follow-up that extends the struct
with a new field, because `FPDF_ENCRYPTION_PARAMS` is opaque to
callers and the struct can grow.

**Internal implementation pointer:**
`CPDF_SecurityHandler::OnCreate` in
`core/fpdfapi/parser/cpdf_security_handler.h` line 30 is the hook.
It takes an `EncryptDict` (which we'd allocate fresh on the
document), the file-ID array (which `FPDF_CreateNewDocument`
already produces and `CPDF_Document::GetFileIdentifier` exposes),
and the password. The encryption-dict gets wired into the
trailer via `CPDF_Parser::SetEncryptionDict` (which would need
to become public-callable, or — better — `CPDF_Document` would
grow a `SetEncryption` method that wraps the wiring step).

`FPDF_RemoveEncryption` is the inverse — it walks the document
clearing `/Encrypt` and dropping the security handler. The
existing `FPDF_REMOVE_SECURITY` save flag already does this at
save time; the proposed symbol does it at write-prep time, so
subsequent operations (further metadata writes, structural
edits) operate on an unencrypted in-memory model.

**R-side consumer:** `pdf_doc_set_encryption()` and
`pdf_doc_remove_encryption()` — not currently on the v0.2.0
roadmap (the package's `pdf_doc_permissions()` reader is marked
read-only by design in the audit), but a known v0.3.0 request:
the kmextract pipeline produces PDFs that need clinical-trial
compliance encryption.

**Self-contained?** yes. Largest single CL in this list by both
public surface and internal touch. If we want to lead with a
"big ticket" item to seed the conversation, this is the one.

### CL 6: Attachment Subtype writer — **drafted**

**Symbols proposed:**

```c
FPDF_EXPORT FPDF_BOOL FPDF_CALLCONV
FPDFAttachment_SetSubtype(FPDF_ATTACHMENT attachment,
                          FPDF_WIDESTRING subtype);
```

**Rationale:** `FPDFAttachment_GetSubtype` reads the embedded
file's MIME type from the *file-stream dict* (`/EF/F/Subtype`),
not the params dict (`/Params/Subtype`). The existing
`FPDFAttachment_SetStringValue("Subtype", ...)` writes to the
params dict, so it does NOT round-trip through the existing
getter — you set `Subtype` on params, then `GetSubtype` reads
the file-stream version and finds no value.

The proposed setter explicitly writes the file-stream-dict
version, so reader/writer round-trip works. Doc comment makes
the file-stream-vs-params distinction explicit, and notes that
`FPDFAttachment_SetFile` resets the file-stream dict (so
`SetSubtype` should be called *after* `SetFile`, not before).

**Internal implementation pointer:** the getter at
`fpdfsdk/fpdf_attachment.cpp` line 308 reaches into
`CPDF_FileSpec::GetFileStream()->GetDict()->GetNameFor("Subtype")`.
The setter is the trivial mirror via `GetMutableDict()` and
`SetNewFor<CPDF_Name>` — the existing
`FPDFAttachment_SetStringValue` body (line 156) provides the
template, just operating on a different dict.

**R-side consumer:** `pdf_attachment_set_subtype()` —
v0.2.0 roadmap. Currently `pdf_attachments()$subtype` is
read-only.

**Self-contained?** yes.

### CL 7: Annotation Number / numeric-key writers

**Symbols proposed:**

```c
FPDF_EXPORT FPDF_BOOL FPDF_CALLCONV
FPDFAnnot_SetNumberValue(FPDF_ANNOTATION annot,
                         FPDF_BYTESTRING key,
                         float value);
```

**Rationale:** `FPDFAnnot_GetNumberValue` (in `fpdf_annot.h`
line 600) reads a float from an annotation's dictionary by key.
There's no setter. This blocks writing common annotation fields
like `/CA` (constant opacity, 0..1), `/F` (custom flags as float),
`/IT` (rotation in degrees on free-text annots), or arbitrary
custom keys some viewers use. `FPDFAnnot_SetStringValue` works
for string-typed entries, `FPDFAnnot_SetColor` covers the
specific RGBA case, but there's no general numeric setter.

Doc comment should clarify that the value type after the call
is `FPDF_OBJECT_NUMBER` regardless of what was there before
(consistent with `FPDFAnnot_SetStringValue`'s contract).

**Internal implementation pointer:** the getter at
`fpdfsdk/fpdf_annot.cpp` line ~750 walks
`GetAnnotDictFromFPDFAnnotation(annot)->GetNumberFor(key)`. The
setter is `GetMutableAnnotDict->SetNewFor<CPDF_Number>(key, value)`
exactly mirroring `FPDFAnnot_SetStringValue`'s body.

**R-side consumer:** generic `pdf_annot_set_dict_value(annot, key,
value)` — already exposed read-only via `pdf_annot_dict_value()`
in v0.1.0. Tier 3 plan calls for this writer at v0.2.0.

**Self-contained?** yes.

### CL 8: Annotation geometry writers (vertices, line, ink)

**Symbols proposed:**

```c
FPDF_EXPORT FPDF_BOOL FPDF_CALLCONV
FPDFAnnot_SetVertices(FPDF_ANNOTATION annot,
                      const FS_POINTF* points,
                      unsigned long count);

FPDF_EXPORT FPDF_BOOL FPDF_CALLCONV
FPDFAnnot_SetLine(FPDF_ANNOTATION annot,
                  const FS_POINTF* start,
                  const FS_POINTF* end);
```

**Rationale:** `FPDFAnnot_GetVertices` (polygon/polyline) and
`FPDFAnnot_GetLine` (line) are pure-readers today. The existing
`FPDFAnnot_AddInkStroke` + `FPDFAnnot_RemoveInkList` precedent
covers the ink subtype's similar shape, but polygon, polyline,
and line have no symmetric writer. Embedders that generate
markup overlays from extracted data (highlighting tables,
boxing chart axes, drawing redaction borders) need these.

`SetVertices` replaces the entire `/Vertices` array; the
two-argument shape (no append, no remove) keeps the API
flat. For polyline subtypes, `count >= 2` is enforced; for
polygons, `count >= 3`. Wrong-subtype calls return `false`.

`SetLine` writes `/L = [x1 y1 x2 y2]`, matching the existing
getter's read shape exactly.

**Internal implementation pointer:** the getters at
`fpdfsdk/fpdf_annot.cpp` line 955 (`GetVertices`) and 1023
(`GetLine`) read `annot_dict->GetArrayFor(...)`. The setters
allocate a fresh `CPDF_Array`, push points, and call
`annot_dict->GetMutableDict()->SetFor("Vertices"|"L",
std::move(array))`.

**R-side consumer:** `pdf_annot_set_vertices()`,
`pdf_annot_set_line()` — v0.2.0 roadmap. Today
`pdf_annotations()` exposes `vertices` and `line` as read-only
list-columns.

**Self-contained?** yes.

### CL 9: `FPDFFormObj_AppendObject` (form-XObject child writer)

**Symbols proposed:**

```c
FPDF_EXPORT FPDF_BOOL FPDF_CALLCONV
FPDFFormObj_AppendObject(FPDF_PAGEOBJECT form_object,
                         FPDF_PAGEOBJECT page_object);
```

**Rationale:** `FPDFFormObj_GetObject`, `FPDFFormObj_CountObjects`,
and `FPDFFormObj_RemoveObject` exist — but there is no way to
add a new page object to an existing form XObject. The reader
and remover are there but the appender is missing. This breaks
the otherwise-symmetric "form objects are page-object-like
containers" model. Embedders that want to assemble reusable
form XObjects programmatically (logo stamps, watermarks,
repeat-on-every-page glyph sets) have to construct the form
XObject from scratch via private surface.

The signature mirrors `FPDFAnnot_AppendObject` (which is the
established precedent for "append a page-object child"):
ownership of `page_object` transfers to `form_object`, and the
caller MUST NOT subsequently call `FPDFPageObj_Destroy` on it.

**Internal implementation pointer:** `CPDF_FormObject` in
`core/fpdfapi/page/cpdf_formobject.h` wraps a `CPDF_Form` whose
`m_pPageObjectHolder` member is a `std::unique_ptr<CPDF_PageObjectHolder>`.
The `Holder` already has an `AppendPageObject` method (used by
the page-level constructor). The C-shim implementation matches
`fpdfsdk/fpdf_editpage.cpp::FPDFPage_InsertObject`'s pattern
applied to the form-object's holder instead of the page's
holder.

**R-side consumer:** `pdf_form_obj_append_object()` —
v0.2.0 roadmap. `pdf_form_objects()` reader has shipped since
0.1.0.

**Self-contained?** yes.

### CL 10: Color-space introspection on page objects

**Symbols proposed:**

```c
FPDF_EXPORT int FPDF_CALLCONV
FPDFPageObj_GetFillColorSpace(FPDF_PAGEOBJECT page_object);

FPDF_EXPORT int FPDF_CALLCONV
FPDFPageObj_GetStrokeColorSpace(FPDF_PAGEOBJECT page_object);

FPDF_EXPORT FPDF_BOOL FPDF_CALLCONV
FPDFPageObj_GetFillColorRaw(FPDF_PAGEOBJECT page_object,
                            float* components,
                            unsigned long* num_components,
                            unsigned long max_components);

FPDF_EXPORT FPDF_BOOL FPDF_CALLCONV
FPDFPageObj_GetStrokeColorRaw(FPDF_PAGEOBJECT page_object,
                              float* components,
                              unsigned long* num_components,
                              unsigned long max_components);
```

**Rationale:** `FPDFPageObj_GetFillColor` and
`FPDFPageObj_GetStrokeColor` return RGBA tuples in `0..255`
integers. If the underlying PDF uses `/DeviceCMYK`,
`/DeviceGray`, `/CalRGB`, `/Lab`, or a custom `/ICCBased`
color space, the API silently converts to RGB — *lossy*. For
embedders that extract color information to feed back into a
prepress pipeline, document-fidelity audit, or color-profile
preservation workflow, this is the wrong shape.

`GetFillColorSpace` / `GetStrokeColorSpace` return an integer
from a new `FPDF_COLORSPACE_*` enum mirroring
`CPDF_ColorSpace::Family` (kDeviceGray=1, kDeviceRGB=2,
kDeviceCMYK=3, kCalGray=4, kCalRGB=5, kLab=6, kICCBased=7,
kIndexed=8, kPattern=9, kSeparation=10, kDeviceN=11). `-1` on
error.

`GetFillColorRaw` / `GetStrokeColorRaw` return the raw color
components in their native color space (3 floats for RGB,
4 for CMYK, 1 for Gray, etc.), with `num_components` reporting
the count actually filled. Callers pass a `max_components` cap
to size the buffer (32 covers `/DeviceN` color spaces with
spot-color counts realistic in practice).

**Internal implementation pointer:**
`CPDF_PageObject::GetGeneralState().GetFillColor()` returns a
`CPDF_Color*` whose `GetColorSpace()->GetFamily()` is the enum
we want (defined in `core/fpdfapi/page/cpdf_colorspace.h`
line 96), and whose `GetValue()` returns a `pdfium::span<const
float>` of the raw components. Both are already cheap-O(1) reads;
the wrappers are mechanical.

**R-side consumer:** `pdf_obj_fill_color_space()`,
`pdf_obj_stroke_color_space()`,
`pdf_obj_fill_color_raw()`, `pdf_obj_stroke_color_raw()` —
not yet on the v0.2.0 roadmap, but flagged in the kmextract
conformance harness as a known fidelity gap. CRAN-acceptance
unlikely to block on this; CRAN doesn't audit PDF color-space
fidelity.

**Self-contained?** yes. Lowest priority of the list for the
R package, but the highest-leverage symbol for any other binding
that does color-managed prepress.

### CL 11: Annotation `SetFont` for FreeText

**Symbols proposed:**

```c
FPDF_EXPORT FPDF_BOOL FPDF_CALLCONV
FPDFAnnot_SetFont(FPDF_FORMHANDLE hHandle,
                  FPDF_ANNOTATION annot,
                  FPDF_FONT font,
                  float size);

FPDF_EXPORT FPDF_BOOL FPDF_CALLCONV
FPDFAnnot_SetFontColor(FPDF_FORMHANDLE hHandle,
                       FPDF_ANNOTATION annot,
                       unsigned int R,
                       unsigned int G,
                       unsigned int B);
```

**Rationale:** FreeText annotations carry their own appearance
state — font, size, color — via the `/DA` (default appearance)
string. PDFium already exposes `FPDFAnnot_GetFontSize` and
`FPDFAnnot_GetFontColor`, plus the C-shim helper
`CFFL_InteractiveFormFiller` knows how to *parse* `/DA`. But
there's no public setter for either. Embedders that generate
FreeText annotations programmatically have to use the appearance-
stream override (`FPDFAnnot_SetAP`), bypassing PDFium's
auto-regeneration entirely and putting them on the hook for
glyph layout.

`SetFont` accepts an `FPDF_FONT` loaded via `FPDFText_LoadFont`
(or one of the built-in font names). `SetFontColor` is a
three-byte RGB setter; alpha is intentionally omitted because
`/DA` doesn't support per-color opacity (the annotation's overall
`/CA` controls that).

**Internal implementation pointer:**
`CFFL_FormField::SetDefaultAppearance` in
`fpdfsdk/formfiller/cffl_formfield.cpp` is the internal hook;
it parses and rewrites the `/DA` string. A public wrapper builds
a `/DA` string of the form
`"/<font-resource-name> <size> Tf <r> <g> <b> rg"` and writes it
via `annot_dict->GetMutableDict()->SetNewFor<CPDF_String>("DA",
...)`. Font-resource registration on the page's `/Resources`
follows `CPDF_TextObject`'s pattern via `CPDF_PageObjectHolder`.

**R-side consumer:** `pdf_annot_set_font()`,
`pdf_annot_set_font_color()` — Tier 2 in the reader/writer audit
(`dev/reader-writer-audit.md` §"Annotation surface gaps,
font_color_* / font_size"). The reader columns
`font_color_red/green/blue` and `font_size` on
`pdf_annotations()` are Tier 2, blocked partly on this CL.

**Self-contained?** yes.

### CL 12: Path-based clip path constructor

**Symbols proposed:**

```c
FPDF_EXPORT FPDF_CLIPPATH FPDF_CALLCONV
FPDF_CreateClipPathFromPath(FPDF_PAGEOBJECT path_object);

FPDF_EXPORT FPDF_BOOL FPDF_CALLCONV
FPDFClipPath_AppendPath(FPDF_CLIPPATH clip_path,
                        FPDF_PAGEOBJECT path_object);
```

**Rationale:** `FPDF_CreateClipPath(left, bottom, right, top)`
creates a *rectangular* clip path. Real-world clipping
(text-cutout effects, irregular masks, curve-bounded crops) needs
arbitrary path geometry. The reader side exposes
`FPDFClipPath_CountPaths`, `FPDFClipPath_CountPathSegments`, and
`FPDFClipPath_GetPathSegment` — so you can read out a
multi-segment clip path — but you can't *create* one outside the
single-rectangle case.

`CreateClipPathFromPath` takes an existing path page object
(already built via `FPDFPath_MoveTo`/`LineTo`/`BezierTo`/`Close`)
and extracts its geometry into a clip path. `AppendPath`
extends an existing clip path with a second sub-path (for
even-odd or non-zero winding multi-path clips). Together they
cover the full reader surface symmetrically.

**Internal implementation pointer:** `CPDF_ClipPath` in
`core/fpdfapi/page/cpdf_clippath.h` already has
`AppendPath(CFX_Path, FillType)` for internal use. The shim
extracts the path's `CFX_Path` from the path page object's
`CPDF_PathObject` (already accessible via the existing path
getters) and threads it through.

**R-side consumer:** `pdf_clip_path_new_from_path()`,
`pdf_clip_path_append_path()` — v0.2.0 roadmap. The
`pdf_clip_path_segments()` reader has shipped since 0.1.0.

**Self-contained?** yes, but pairs naturally with CL 8 for a
combined "annotation + clipping geometry-writer" batch if the
mailing list pushes for fewer, larger CLs.

## Lower-priority gaps observed but not proposed

These are real asymmetries that we noticed but don't currently have
a strong R-side workflow demanding them. Catalogued for
completeness so future audits don't re-discover them as novelties.

- `FPDF_SetFileIdentifier` — no setter for the trailer's
  `/ID` array. PDFium auto-generates one on `FPDF_SaveAsCopy`;
  embedders that want deterministic IDs for content-addressable
  storage would benefit.
- `FPDFPageObj_SetMark*` family — `FPDFPageObj_GetMark*` reads
  marked-content properties but there's no public writer beyond
  `FPDFPageObj_AddMark`. The internal hook
  (`CPDF_ContentMarks::AddMark` with full param dict) is private.
- `FPDF_StructElement_Set*` family — entire structure-tree
  mutation surface absent. Useful for tagged-PDF authoring but
  the surface is large (kid-list management, role-map management,
  attribute-class management) and a single CL would be too big.
- `FPDFSignatureObj_*` — read-only by design upstream. Signing
  is intentionally out of scope (signing requires a crypto
  identity store that PDFium doesn't ship).
- `FORM_OnLButtonDown` etc. — interactive event callbacks,
  intentionally out of scope for non-interactive bindings.
- `FPDF_GetDefaultTTFMapEntry`, `FPDF_FreeDefaultSystemFontInfo` —
  internal font-substitution machinery; users wanting custom
  font lookup should override via `FPDF_SetSystemFontInfo`.
- `FPDFAvail_*` (8 symbols) — progressive / streaming
  document loading. Useful for HTTP-backed viewers, not for
  batch-mode bindings.

## Cross-cutting notes for the consolidated request

A few things to call out in the cover letter once we send this
upstream:

1. **All 12 proposed CLs are R-package-blocked first, but
   embedder-agnostic in shape.** Every one of them has been
   requested at least once in another binding's issue tracker
   (pypdfium2, pdfium-rs, pdfium-render, hyzyla). Where possible
   we should cite the cross-binding issues in the per-CL
   commit messages.

2. **Internal hooks already exist for all 12.** Each CL is a
   thin C-shim mirror of an existing internal method (or in the
   case of CL 2's bookmarks and CL 5's encryption, exposes a
   class that already mutates internally). No new core
   algorithms are involved.

3. **The existing in-flight CLs (`FPDFPath_GetBezierControlPoints`,
   `FPDFTextObj_SetFontSize`, `FPDFAnnot_AppendOption /
   RemoveOptions`) establish three precedent patterns** that the
   12 proposed CLs reuse: thin reader/writer mirror,
   `Append + Remove` for array-typed attributes, and per-
   subtype validation in the C shim. The mailing-list cover
   letter should anchor on those precedents rather than
   re-arguing the patterns from first principles.

4. **Test layout follows the existing fpdfsdk embedder-test
   pattern.** Each CL's tests use the three-block layout
   (round-trip, rejection, persistence) introduced by the
   `FPDFTextObj_SetFontSize` patch — a multi-block test makes
   reviewing easier without bloating any single block.

5. **None of the 12 proposed CLs requires a new
   `experimental` annotation.** PDFium's convention is that any
   newly-introduced symbol gets an `// Experimental API.` line in
   its header doc comment until the API stabilizes; all 12
   should carry it. The PDFium contribution guide doesn't
   require deprecating the experimental tag on any particular
   timeline.
