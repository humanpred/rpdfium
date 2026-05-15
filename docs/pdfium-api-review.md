# PDFium Public C API Review (Phase 0c Deliverable)

This document catalogs the complete public C API of Google's PDFium library.
The objective is to verify that the planned Tier 1/2/3 feature set for the R
`pdfium` package maps to real PDFium symbols, to identify post-0.1.0
capabilities so the 0.1.0 R API does not paint us into a corner, and to
provide a definitive reference for implementation.

## Provenance

Survey conducted on **2026-05-15**. PDFium source cloned from
`https://pdfium.googlesource.com/pdfium` to `/tmp/pdfium-upstream`:

| Field | Value |
|---|---|
| Branch | `main` |
| Commit | `9095044e26da35f3261df4365f51d6e74a3c8b24` |
| Commit date | 2026-05-14 |
| Scope | every file under `public/` except `public/cpp/` (C++ RAII helpers — `fpdf_deleters.h`, `fpdf_scopers.h` — not relevant to the Rcpp C-ABI binding) |

The bblanchon binary pinned in `tools/pdfium-version.txt` (currently
`chromium/7202`) corresponds to a tagged PDFium release, *not* this `main`
HEAD. Upstream `main` typically runs days to weeks ahead of any tagged
release; if a future bump pulls in API surface that wasn't present at this
survey's commit, regenerate the symbol inventory and capability buckets.

To refresh this survey:

```sh
cd /tmp/pdfium-upstream && git pull origin main
# then re-walk public/ and update the symbol inventory + provenance block.
```

## 1. Header Summary

| Header | One-line description | `FPDF_EXPORT` count |
|---|---|---|
| `fpdfview.h` | Library lifecycle, document/page lifecycle, bitmap creation, rendering, viewer prefs, named dests, XFA packets | 66 |
| `fpdf_edit.h` | Creating/editing documents, pages, page objects (path/text/image/form), fonts, page-object marks | 117 |
| `fpdf_text.h` | Text page extraction, character-level metadata, find/search, weblinks | 36 |
| `fpdf_doc.h` | Bookmarks/outline, actions, destinations, link annotations, metadata (`FPDF_GetMetaText`), page labels, file identifier | 27 |
| `fpdf_save.h` | Saving documents via `FPDF_FILEWRITE` callback | 2 |
| `fpdf_ppo.h` | Page import/merge, N-up imposition, XObject creation | 7 |
| `fpdf_annot.h` | Annotation enumeration/creation/properties, form-field annotation access | 66 |
| `fpdf_attachment.h` | Embedded file attachments (add, get, delete, params dictionary) | 12 |
| `fpdf_formfill.h` | Form-fill environment (`FORM_*` event handlers, `FPDF_FFLDraw`, AcroForm/XFA) | 42 |
| `fpdf_searchex.h` | Text-page char-index <-> text-index conversion | 2 |
| `fpdf_signature.h` | Digital signature object access (contents, byte range, reason, time, DocMDP) | 8 |
| `fpdf_structtree.h` | Tagged-PDF / structure tree traversal | 32 |
| `fpdf_thumbnail.h` | Page thumbnail extraction (raw, decoded, bitmap) | 3 |
| `fpdf_transformpage.h` | MediaBox/CropBox/BleedBox/TrimBox/ArtBox, page transform with clip, clip paths | 19 |
| `fpdf_dataavail.h` | Linearized PDF/progressive availability checks (`FPDF_AVAIL`) | 8 |
| `fpdf_progressive.h` | Progressive (interruptible) rendering with `IFSDK_PAUSE` | 4 |
| `fpdf_javascript.h` | Document-level JavaScript action enumeration | 5 |
| `fpdf_flatten.h` | Flatten annotations/form fields into page contents | 1 |
| `fpdf_catalog.h` | Document catalog: tagged-PDF flag, `/Lang` get/set | 3 |
| `fpdf_ext.h` | Unsupported-feature notifications, `PAGEMODE_*`, time/localtime overrides | 4 |
| `fpdf_sysfontinfo.h` | System font enumeration callback interface, default TTF map | 7 |
| `fpdf_fwlevent.h` | Constants only: keyboard/mouse event flags for `FORM_*` calls | 0 |

Total: 471 exported symbols across 22 headers. The `fpdf_fwlevent.h` header
contributes zero exports because it only defines enums/macros that the form-fill
event handlers consume.

## 2. Capability Buckets

The bucket organization below cuts across headers and groups functions by what
they let the embedder do.

### 2.1 Library Lifecycle

| Symbol | Header | Signature | Description |
|---|---|---|---|
| `FPDF_InitLibrary` | `fpdfview.h` | `void FPDF_InitLibrary()` | Convenience init using defaults (deprecated path) |
| `FPDF_InitLibraryWithConfig` | `fpdfview.h` | `void FPDF_InitLibraryWithConfig(const FPDF_LIBRARY_CONFIG* config)` | Init with versioned `FPDF_LIBRARY_CONFIG` (font paths, v8 isolate, renderer choice AGG/Skia, font backend FreeType/Fontations) |
| `FPDF_DestroyLibrary` | `fpdfview.h` | `void FPDF_DestroyLibrary()` | Release global resources |
| `FPDF_SetSandBoxPolicy` | `fpdfview.h` | `void FPDF_SetSandBoxPolicy(FPDF_DWORD policy, FPDF_BOOL enable)` | Toggle policies, e.g. `FPDF_POLICY_MACHINETIME_ACCESS` |
| `FPDF_SetPrintMode` | `fpdfview.h` | `FPDF_BOOL FPDF_SetPrintMode(int mode)` | Windows-only EMF/PostScript print mode |
| `FPDF_GetRecommendedV8Flags` | `fpdfview.h` | `const char* FPDF_GetRecommendedV8Flags()` | v8-enabled builds only |
| `FPDF_GetArrayBufferAllocatorSharedInstance` | `fpdfview.h` | `void* FPDF_GetArrayBufferAllocatorSharedInstance()` | v8-enabled builds only |
| `FSDK_SetUnSpObjProcessHandler` | `fpdf_ext.h` | `FPDF_BOOL FSDK_SetUnSpObjProcessHandler(UNSUPPORT_INFO*)` | Register callback for unsupported PDF features |
| `FSDK_SetTimeFunction` | `fpdf_ext.h` | `void FSDK_SetTimeFunction(time_t (*func)())` | Override `time()` (testing) |
| `FSDK_SetLocaltimeFunction` | `fpdf_ext.h` | `void FSDK_SetLocaltimeFunction(struct tm* (*func)(const time_t*))` | Override `localtime()` (testing) |

### 2.2 Document Lifecycle (open / close / save / password)

| Symbol | Header | Signature | Description |
|---|---|---|---|
| `FPDF_LoadDocument` | `fpdfview.h` | `FPDF_DOCUMENT FPDF_LoadDocument(FPDF_STRING file_path, FPDF_BYTESTRING password)` | Open from path (UTF-8) with optional password |
| `FPDF_LoadMemDocument` | `fpdfview.h` | `FPDF_DOCUMENT FPDF_LoadMemDocument(const void* data_buf, int size, FPDF_BYTESTRING password)` | Open from in-memory buffer |
| `FPDF_LoadMemDocument64` | `fpdfview.h` | `FPDF_DOCUMENT FPDF_LoadMemDocument64(const void* data_buf, size_t size, FPDF_BYTESTRING password)` | 64-bit size variant of `FPDF_LoadMemDocument` |
| `FPDF_LoadCustomDocument` | `fpdfview.h` | `FPDF_DOCUMENT FPDF_LoadCustomDocument(FPDF_FILEACCESS* pFileAccess, FPDF_BYTESTRING password)` | Open via custom `FPDF_FILEACCESS` callback (random-access reads) |
| `FPDF_CreateNewDocument` | `fpdf_edit.h` | `FPDF_DOCUMENT FPDF_CreateNewDocument()` | Make an empty document |
| `FPDF_CloseDocument` | `fpdfview.h` | `void FPDF_CloseDocument(FPDF_DOCUMENT document)` | Release document |
| `FPDF_GetLastError` | `fpdfview.h` | `unsigned long FPDF_GetLastError()` | One of `FPDF_ERR_SUCCESS`, `_UNKNOWN`, `_FILE`, `_FORMAT`, `_PASSWORD`, `_SECURITY`, `_PAGE` (and `_XFALOAD`/`_XFALAYOUT` in XFA builds) |
| `FPDF_GetFileVersion` | `fpdfview.h` | `FPDF_BOOL FPDF_GetFileVersion(FPDF_DOCUMENT doc, int* fileVersion)` | Returns e.g. 14 for PDF 1.4 |
| `FPDF_DocumentHasValidCrossReferenceTable` | `fpdfview.h` | `FPDF_BOOL FPDF_DocumentHasValidCrossReferenceTable(FPDF_DOCUMENT document)` | True when xref was not rebuilt |
| `FPDF_GetTrailerEnds` | `fpdfview.h` | `unsigned long FPDF_GetTrailerEnds(FPDF_DOCUMENT, unsigned int* buffer, unsigned long length)` | Byte offsets of trailer ends |
| `FPDF_GetDocPermissions` | `fpdfview.h` | `unsigned long FPDF_GetDocPermissions(FPDF_DOCUMENT)` | Returns 32-bit permission bits; `0xffffffff` if unprotected or unlocked by owner |
| `FPDF_GetDocUserPermissions` | `fpdfview.h` | `unsigned long FPDF_GetDocUserPermissions(FPDF_DOCUMENT)` | User-only permissions even when owner-unlocked |
| `FPDF_GetSecurityHandlerRevision` | `fpdfview.h` | `int FPDF_GetSecurityHandlerRevision(FPDF_DOCUMENT)` | -1 if unprotected |
| `FPDF_SaveAsCopy` | `fpdf_save.h` | `FPDF_BOOL FPDF_SaveAsCopy(FPDF_DOCUMENT, FPDF_FILEWRITE*, FPDF_DWORD flags)` | Save via callback. Flags: `FPDF_INCREMENTAL`, `FPDF_NO_INCREMENTAL`, `FPDF_REMOVE_SECURITY`, `FPDF_SUBSET_NEW_FONTS` |
| `FPDF_SaveWithVersion` | `fpdf_save.h` | `FPDF_BOOL FPDF_SaveWithVersion(FPDF_DOCUMENT, FPDF_FILEWRITE*, FPDF_DWORD flags, int file_version)` | Save with explicit version |
| `FPDFAvail_Create` | `fpdf_dataavail.h` | `FPDF_AVAIL FPDFAvail_Create(FX_FILEAVAIL*, FPDF_FILEACCESS*)` | Linearized/progressive availability provider |
| `FPDFAvail_Destroy` | `fpdf_dataavail.h` | `void FPDFAvail_Destroy(FPDF_AVAIL)` | |
| `FPDFAvail_IsDocAvail` | `fpdf_dataavail.h` | `int FPDFAvail_IsDocAvail(FPDF_AVAIL, FX_DOWNLOADHINTS*)` | Returns `PDF_DATA_ERROR`/`_NOTAVAIL`/`_AVAIL` |
| `FPDFAvail_GetDocument` | `fpdf_dataavail.h` | `FPDF_DOCUMENT FPDFAvail_GetDocument(FPDF_AVAIL, FPDF_BYTESTRING password)` | Get document handle after avail check (note: also takes password) |
| `FPDFAvail_GetFirstPageNum` | `fpdf_dataavail.h` | `int FPDFAvail_GetFirstPageNum(FPDF_DOCUMENT)` | First page in a linearized PDF |
| `FPDFAvail_IsPageAvail` | `fpdf_dataavail.h` | `int FPDFAvail_IsPageAvail(FPDF_AVAIL, int page_index, FX_DOWNLOADHINTS*)` | |
| `FPDFAvail_IsFormAvail` | `fpdf_dataavail.h` | `int FPDFAvail_IsFormAvail(FPDF_AVAIL, FX_DOWNLOADHINTS*)` | Form data availability |
| `FPDFAvail_IsLinearized` | `fpdf_dataavail.h` | `int FPDFAvail_IsLinearized(FPDF_AVAIL)` | |

### 2.3 Document Metadata

| Symbol | Header | Signature | Description |
|---|---|---|---|
| `FPDF_GetMetaText` | `fpdf_doc.h` | `unsigned long FPDF_GetMetaText(FPDF_DOCUMENT, FPDF_BYTESTRING tag, void* buffer, unsigned long buflen)` | Tag is one of `Title`, `Author`, `Subject`, `Keywords`, `Creator`, `Producer`, `CreationDate`, `ModDate`; buffer is UTF-16LE |
| `FPDF_GetFileIdentifier` | `fpdf_doc.h` | `unsigned long FPDF_GetFileIdentifier(FPDF_DOCUMENT, FPDF_FILEIDTYPE id_type, void* buffer, unsigned long buflen)` | `FILEIDTYPE_PERMANENT` or `_CHANGING` |
| `FPDF_GetPageLabel` | `fpdf_doc.h` | `unsigned long FPDF_GetPageLabel(FPDF_DOCUMENT, int page_index, void* buffer, unsigned long buflen)` | Per-page label (UTF-16LE) |
| `FPDFCatalog_IsTagged` | `fpdf_catalog.h` | `FPDF_BOOL FPDFCatalog_IsTagged(FPDF_DOCUMENT)` | Tagged-PDF flag |
| `FPDFCatalog_GetLanguage` | `fpdf_catalog.h` | `unsigned long FPDFCatalog_GetLanguage(FPDF_DOCUMENT, FPDF_WCHAR* buffer, unsigned long buflen)` | `/Lang` entry (UTF-16LE) |
| `FPDFCatalog_SetLanguage` | `fpdf_catalog.h` | `FPDF_BOOL FPDFCatalog_SetLanguage(FPDF_DOCUMENT, FPDF_WIDESTRING language)` | Set `/Lang` |
| `FPDFDoc_GetPageMode` | `fpdf_ext.h` | `int FPDFDoc_GetPageMode(FPDF_DOCUMENT)` | `PAGEMODE_*` flag (none/outlines/thumbs/fullscreen/oc/attachments) |
| `FPDF_GetXFAPacketCount` | `fpdfview.h` | `int FPDF_GetXFAPacketCount(FPDF_DOCUMENT)` | Number of XFA packets, or -1 |
| `FPDF_GetXFAPacketName` | `fpdfview.h` | `unsigned long FPDF_GetXFAPacketName(FPDF_DOCUMENT, int index, void* buffer, unsigned long buflen)` | UTF-8 packet name |
| `FPDF_GetXFAPacketContent` | `fpdfview.h` | `FPDF_BOOL FPDF_GetXFAPacketContent(FPDF_DOCUMENT, int index, void* buffer, unsigned long buflen, unsigned long* out_buflen)` | XFA packet bytes |
| `FPDF_VIEWERREF_GetPrintScaling` | `fpdfview.h` | `FPDF_BOOL FPDF_VIEWERREF_GetPrintScaling(FPDF_DOCUMENT)` | Viewer-pref entry |
| `FPDF_VIEWERREF_GetNumCopies` | `fpdfview.h` | `int FPDF_VIEWERREF_GetNumCopies(FPDF_DOCUMENT)` | |
| `FPDF_VIEWERREF_GetPrintPageRange` | `fpdfview.h` | `FPDF_PAGERANGE FPDF_VIEWERREF_GetPrintPageRange(FPDF_DOCUMENT)` | Opaque handle |
| `FPDF_VIEWERREF_GetPrintPageRangeCount` | `fpdfview.h` | `size_t FPDF_VIEWERREF_GetPrintPageRangeCount(FPDF_PAGERANGE)` | |
| `FPDF_VIEWERREF_GetPrintPageRangeElement` | `fpdfview.h` | `int FPDF_VIEWERREF_GetPrintPageRangeElement(FPDF_PAGERANGE, size_t index)` | |
| `FPDF_VIEWERREF_GetDuplex` | `fpdfview.h` | `FPDF_DUPLEXTYPE FPDF_VIEWERREF_GetDuplex(FPDF_DOCUMENT)` | `DuplexUndefined`/`Simplex`/`DuplexFlipShortEdge`/`DuplexFlipLongEdge` |
| `FPDF_VIEWERREF_GetName` | `fpdfview.h` | `unsigned long FPDF_VIEWERREF_GetName(FPDF_DOCUMENT, FPDF_BYTESTRING key, char* buffer, unsigned long length)` | Generic viewer-pref name lookup |
| `FPDF_CountNamedDests` | `fpdfview.h` | `FPDF_DWORD FPDF_CountNamedDests(FPDF_DOCUMENT)` | |
| `FPDF_GetNamedDestByName` | `fpdfview.h` | `FPDF_DEST FPDF_GetNamedDestByName(FPDF_DOCUMENT, FPDF_BYTESTRING name)` | |
| `FPDF_GetNamedDest` | `fpdfview.h` | `FPDF_DEST FPDF_GetNamedDest(FPDF_DOCUMENT, int index, void* buffer, long* buflen)` | Iterate by index |

### 2.4 Page Lifecycle

| Symbol | Header | Signature | Description |
|---|---|---|---|
| `FPDF_GetPageCount` | `fpdfview.h` | `int FPDF_GetPageCount(FPDF_DOCUMENT)` | |
| `FPDF_LoadPage` | `fpdfview.h` | `FPDF_PAGE FPDF_LoadPage(FPDF_DOCUMENT, int page_index)` | Zero-based |
| `FPDF_ClosePage` | `fpdfview.h` | `void FPDF_ClosePage(FPDF_PAGE)` | |
| `FPDF_GetPageWidth` | `fpdfview.h` | `double FPDF_GetPageWidth(FPDF_PAGE)` | Deprecated; affected by rotation |
| `FPDF_GetPageWidthF` | `fpdfview.h` | `float FPDF_GetPageWidthF(FPDF_PAGE)` | Preferred |
| `FPDF_GetPageHeight` | `fpdfview.h` | `double FPDF_GetPageHeight(FPDF_PAGE)` | Deprecated; affected by rotation |
| `FPDF_GetPageHeightF` | `fpdfview.h` | `float FPDF_GetPageHeightF(FPDF_PAGE)` | Preferred |
| `FPDF_GetPageSizeByIndex` | `fpdfview.h` | `int FPDF_GetPageSizeByIndex(FPDF_DOCUMENT, int page_index, double* width, double* height)` | Without loading the page |
| `FPDF_GetPageSizeByIndexF` | `fpdfview.h` | `FPDF_BOOL FPDF_GetPageSizeByIndexF(FPDF_DOCUMENT, int page_index, FS_SIZEF* size)` | Preferred |
| `FPDF_GetPageBoundingBox` | `fpdfview.h` | `FPDF_BOOL FPDF_GetPageBoundingBox(FPDF_PAGE, FS_RECTF* rect)` | Intersection of media + crop boxes |
| `FPDFPage_GetRotation` | `fpdf_edit.h` | `int FPDFPage_GetRotation(FPDF_PAGE)` | 0/1/2/3 (multiples of 90 deg CW), -1 on error |
| `FPDFPage_SetRotation` | `fpdf_edit.h` | `void FPDFPage_SetRotation(FPDF_PAGE, int rotate)` | |
| `FPDFPage_HasTransparency` | `fpdf_edit.h` | `FPDF_BOOL FPDFPage_HasTransparency(FPDF_PAGE)` | |
| `FPDFPage_New` | `fpdf_edit.h` | `FPDF_PAGE FPDFPage_New(FPDF_DOCUMENT, int page_index, double width, double height)` | Add new blank page |
| `FPDFPage_Delete` | `fpdf_edit.h` | `void FPDFPage_Delete(FPDF_DOCUMENT, int page_index)` | |
| `FPDF_MovePages` | `fpdf_edit.h` | `FPDF_BOOL FPDF_MovePages(FPDF_DOCUMENT, const int* page_indices, unsigned long page_indices_len, int dest_page_index)` | Reorder pages |
| `FPDFPage_GenerateContent` | `fpdf_edit.h` | `FPDF_BOOL FPDFPage_GenerateContent(FPDF_PAGE)` | Must call before save/reload to persist edits |
| `FPDF_DeviceToPage` | `fpdfview.h` | `FPDF_BOOL FPDF_DeviceToPage(FPDF_PAGE, int start_x, int start_y, int size_x, int size_y, int rotate, int device_x, int device_y, double* page_x, double* page_y)` | Device->page coord |
| `FPDF_PageToDevice` | `fpdfview.h` | `FPDF_BOOL FPDF_PageToDevice(FPDF_PAGE, int start_x, int start_y, int size_x, int size_y, int rotate, double page_x, double page_y, int* device_x, int* device_y)` | Page->device coord |
| `FPDFPage_SetMediaBox` | `fpdf_transformpage.h` | `void FPDFPage_SetMediaBox(FPDF_PAGE, float left, float bottom, float right, float top)` | |
| `FPDFPage_GetMediaBox` | `fpdf_transformpage.h` | `FPDF_BOOL FPDFPage_GetMediaBox(FPDF_PAGE, float* left, float* bottom, float* right, float* top)` | |
| `FPDFPage_SetCropBox`/`GetCropBox` | `fpdf_transformpage.h` | analogous | |
| `FPDFPage_SetBleedBox`/`GetBleedBox` | `fpdf_transformpage.h` | analogous | |
| `FPDFPage_SetTrimBox`/`GetTrimBox` | `fpdf_transformpage.h` | analogous | |
| `FPDFPage_SetArtBox`/`GetArtBox` | `fpdf_transformpage.h` | analogous | |

### 2.5 Page Rendering

| Symbol | Header | Signature | Description |
|---|---|---|---|
| `FPDF_RenderPage` | `fpdfview.h` | `FPDF_BOOL FPDF_RenderPage(HDC dc, FPDF_PAGE, int start_x, int start_y, int size_x, int size_y, int rotate, int flags)` | Windows GDI only |
| `FPDF_RenderPageBitmap` | `fpdfview.h` | `void FPDF_RenderPageBitmap(FPDF_BITMAP, FPDF_PAGE, int start_x, int start_y, int size_x, int size_y, int rotate, int flags)` | Device-independent bitmap render |
| `FPDF_RenderPageBitmapWithMatrix` | `fpdfview.h` | `void FPDF_RenderPageBitmapWithMatrix(FPDF_BITMAP, FPDF_PAGE, const FS_MATRIX* matrix, const FS_RECTF* clipping, int flags)` | Matrix-based render |
| `FPDF_RenderPageSkia` | `fpdfview.h` | `void FPDF_RenderPageSkia(FPDF_SKIA_CANVAS canvas, FPDF_PAGE, int size_x, int size_y)` | Skia builds only |
| `FPDF_RenderPageBitmap_Start` | `fpdf_progressive.h` | `int FPDF_RenderPageBitmap_Start(FPDF_BITMAP, FPDF_PAGE, int start_x, int start_y, int size_x, int size_y, int rotate, int flags, IFSDK_PAUSE*)` | Progressive (cancellable) render |
| `FPDF_RenderPageBitmapWithColorScheme_Start` | `fpdf_progressive.h` | as above + `const FPDF_COLORSCHEME*` | Color-scheme override |
| `FPDF_RenderPage_Continue` | `fpdf_progressive.h` | `int FPDF_RenderPage_Continue(FPDF_PAGE, IFSDK_PAUSE*)` | Continue progressive render |
| `FPDF_RenderPage_Close` | `fpdf_progressive.h` | `void FPDF_RenderPage_Close(FPDF_PAGE)` | Release progressive resources |
| `FPDFPage_Flatten` | `fpdf_flatten.h` | `int FPDFPage_Flatten(FPDF_PAGE, int nFlag)` | Bake annotations/forms into content. nFlag: `FLAT_NORMALDISPLAY` or `FLAT_PRINT` |

Render flags (bitwise OR in `flags` argument): `FPDF_ANNOT` (render annots),
`FPDF_LCD_TEXT`, `FPDF_NO_NATIVETEXT`, `FPDF_GRAYSCALE`, `FPDF_DEBUG_INFO`,
`FPDF_NO_CATCH`, `FPDF_RENDER_LIMITEDIMAGECACHE`, `FPDF_RENDER_FORCEHALFTONE`,
`FPDF_PRINTING`, `FPDF_RENDER_NO_SMOOTHTEXT`, `FPDF_RENDER_NO_SMOOTHIMAGE`,
`FPDF_RENDER_NO_SMOOTHPATH`, `FPDF_REVERSE_BYTE_ORDER`,
`FPDF_CONVERT_FILL_TO_STROKE`.

### 2.6 Page Editing (creating, inserting, deleting page objects)

| Symbol | Header | Signature | Description |
|---|---|---|---|
| `FPDFPage_InsertObject` | `fpdf_edit.h` | `FPDF_BOOL FPDFPage_InsertObject(FPDF_PAGE, FPDF_PAGEOBJECT)` | Page takes ownership |
| `FPDFPage_InsertObjectAtIndex` | `fpdf_edit.h` | `FPDF_BOOL FPDFPage_InsertObjectAtIndex(FPDF_PAGE, FPDF_PAGEOBJECT, size_t index)` | At specific Z-order |
| `FPDFPage_RemoveObject` | `fpdf_edit.h` | `FPDF_BOOL FPDFPage_RemoveObject(FPDF_PAGE, FPDF_PAGEOBJECT)` | Ownership returns to caller |
| `FPDFPage_CountObjects` | `fpdf_edit.h` | `int FPDFPage_CountObjects(FPDF_PAGE)` | |
| `FPDFPage_GetObject` | `fpdf_edit.h` | `FPDF_PAGEOBJECT FPDFPage_GetObject(FPDF_PAGE, int index)` | |
| `FPDFPageObj_Destroy` | `fpdf_edit.h` | `void FPDFPageObj_Destroy(FPDF_PAGEOBJECT)` | For unparented objects only |
| `FPDFPageObj_CreateNewPath` | `fpdf_edit.h` | `FPDF_PAGEOBJECT FPDFPageObj_CreateNewPath(float x, float y)` | |
| `FPDFPageObj_CreateNewRect` | `fpdf_edit.h` | `FPDF_PAGEOBJECT FPDFPageObj_CreateNewRect(float x, float y, float w, float h)` | |
| `FPDFPageObj_NewImageObj` | `fpdf_edit.h` | `FPDF_PAGEOBJECT FPDFPageObj_NewImageObj(FPDF_DOCUMENT)` | |
| `FPDFPageObj_NewTextObj` | `fpdf_edit.h` | `FPDF_PAGEOBJECT FPDFPageObj_NewTextObj(FPDF_DOCUMENT, FPDF_BYTESTRING font, float font_size)` | With standard font name |
| `FPDFPageObj_CreateTextObj` | `fpdf_edit.h` | `FPDF_PAGEOBJECT FPDFPageObj_CreateTextObj(FPDF_DOCUMENT, FPDF_FONT, float font_size)` | With loaded font handle |

### 2.7 Page Objects - Common Attributes

| Symbol | Header | Signature | Description |
|---|---|---|---|
| `FPDFPageObj_GetType` | `fpdf_edit.h` | `int FPDFPageObj_GetType(FPDF_PAGEOBJECT)` | One of `FPDF_PAGEOBJ_TEXT`/`_PATH`/`_IMAGE`/`_SHADING`/`_FORM`/`_UNKNOWN` |
| `FPDFPageObj_GetIsActive` | `fpdf_edit.h` | `FPDF_BOOL FPDFPageObj_GetIsActive(FPDF_PAGEOBJECT, FPDF_BOOL* active)` | |
| `FPDFPageObj_SetIsActive` | `fpdf_edit.h` | `FPDF_BOOL FPDFPageObj_SetIsActive(FPDF_PAGEOBJECT, FPDF_BOOL active)` | |
| `FPDFPageObj_HasTransparency` | `fpdf_edit.h` | `FPDF_BOOL FPDFPageObj_HasTransparency(FPDF_PAGEOBJECT)` | |
| `FPDFPageObj_GetBounds` | `fpdf_edit.h` | `FPDF_BOOL FPDFPageObj_GetBounds(FPDF_PAGEOBJECT, float* left, float* bottom, float* right, float* top)` | Axis-aligned bounding box |
| `FPDFPageObj_GetRotatedBounds` | `fpdf_edit.h` | `FPDF_BOOL FPDFPageObj_GetRotatedBounds(FPDF_PAGEOBJECT, FS_QUADPOINTSF* quad_points)` | Tighter quad for rotated text/image objects |
| `FPDFPageObj_Transform` | `fpdf_edit.h` | `void FPDFPageObj_Transform(FPDF_PAGEOBJECT, double a, double b, double c, double d, double e, double f)` | Apply matrix |
| `FPDFPageObj_TransformF` | `fpdf_edit.h` | `FPDF_BOOL FPDFPageObj_TransformF(FPDF_PAGEOBJECT, const FS_MATRIX*)` | Float version, returns success |
| `FPDFPageObj_GetMatrix` | `fpdf_edit.h` | `FPDF_BOOL FPDFPageObj_GetMatrix(FPDF_PAGEOBJECT, FS_MATRIX*)` | Object's own CTM |
| `FPDFPageObj_SetMatrix` | `fpdf_edit.h` | `FPDF_BOOL FPDFPageObj_SetMatrix(FPDF_PAGEOBJECT, const FS_MATRIX*)` | |
| `FPDFPage_TransformAnnots` | `fpdf_edit.h` | `void FPDFPage_TransformAnnots(FPDF_PAGE, double a, double b, double c, double d, double e, double f)` | Transform all annotations |
| `FPDFPage_TransFormWithClip` | `fpdf_transformpage.h` | `FPDF_BOOL FPDFPage_TransFormWithClip(FPDF_PAGE, const FS_MATRIX*, const FS_RECTF* clipRect)` | Apply transform + clipping to whole page |
| `FPDFPageObj_SetStrokeColor` | `fpdf_edit.h` | `FPDF_BOOL FPDFPageObj_SetStrokeColor(FPDF_PAGEOBJECT, unsigned int R, unsigned int G, unsigned int B, unsigned int A)` | RGBA 0-255 |
| `FPDFPageObj_GetStrokeColor` | `fpdf_edit.h` | `FPDF_BOOL FPDFPageObj_GetStrokeColor(FPDF_PAGEOBJECT, unsigned int* R, unsigned int* G, unsigned int* B, unsigned int* A)` | |
| `FPDFPageObj_SetStrokeWidth` | `fpdf_edit.h` | `FPDF_BOOL FPDFPageObj_SetStrokeWidth(FPDF_PAGEOBJECT, float width)` | |
| `FPDFPageObj_GetStrokeWidth` | `fpdf_edit.h` | `FPDF_BOOL FPDFPageObj_GetStrokeWidth(FPDF_PAGEOBJECT, float* width)` | |
| `FPDFPageObj_GetLineJoin` | `fpdf_edit.h` | `int FPDFPageObj_GetLineJoin(FPDF_PAGEOBJECT)` | `FPDF_LINEJOIN_MITER`/`_ROUND`/`_BEVEL` |
| `FPDFPageObj_SetLineJoin` | `fpdf_edit.h` | `FPDF_BOOL FPDFPageObj_SetLineJoin(FPDF_PAGEOBJECT, int line_join)` | |
| `FPDFPageObj_GetLineCap` | `fpdf_edit.h` | `int FPDFPageObj_GetLineCap(FPDF_PAGEOBJECT)` | `FPDF_LINECAP_BUTT`/`_ROUND`/`_PROJECTING_SQUARE` |
| `FPDFPageObj_SetLineCap` | `fpdf_edit.h` | `FPDF_BOOL FPDFPageObj_SetLineCap(FPDF_PAGEOBJECT, int line_cap)` | |
| `FPDFPageObj_SetFillColor` | `fpdf_edit.h` | `FPDF_BOOL FPDFPageObj_SetFillColor(FPDF_PAGEOBJECT, unsigned int R, unsigned int G, unsigned int B, unsigned int A)` | |
| `FPDFPageObj_GetFillColor` | `fpdf_edit.h` | `FPDF_BOOL FPDFPageObj_GetFillColor(FPDF_PAGEOBJECT, unsigned int* R, unsigned int* G, unsigned int* B, unsigned int* A)` | |
| `FPDFPageObj_GetDashPhase` | `fpdf_edit.h` | `FPDF_BOOL FPDFPageObj_GetDashPhase(FPDF_PAGEOBJECT, float* phase)` | |
| `FPDFPageObj_SetDashPhase` | `fpdf_edit.h` | `FPDF_BOOL FPDFPageObj_SetDashPhase(FPDF_PAGEOBJECT, float phase)` | |
| `FPDFPageObj_GetDashCount` | `fpdf_edit.h` | `int FPDFPageObj_GetDashCount(FPDF_PAGEOBJECT)` | Array length, -1 on error |
| `FPDFPageObj_GetDashArray` | `fpdf_edit.h` | `FPDF_BOOL FPDFPageObj_GetDashArray(FPDF_PAGEOBJECT, float* dash_array, size_t dash_count)` | |
| `FPDFPageObj_SetDashArray` | `fpdf_edit.h` | `FPDF_BOOL FPDFPageObj_SetDashArray(FPDF_PAGEOBJECT, const float* dash_array, size_t dash_count, float phase)` | |
| `FPDFPageObj_SetBlendMode` | `fpdf_edit.h` | `void FPDFPageObj_SetBlendMode(FPDF_PAGEOBJECT, FPDF_BYTESTRING blend_mode)` | One of `Color`, `ColorBurn`, `ColorDodge`, `Darken`, `Difference`, `Exclusion`, `HardLight`, `Hue`, `Lighten`, `Luminosity`, `Multiply`, `Normal`, `Overlay`, `Saturation`, `Screen`, `SoftLight` |
| `FPDFPageObj_GetMarkedContentID` | `fpdf_edit.h` | `int FPDFPageObj_GetMarkedContentID(FPDF_PAGEOBJECT)` | |
| `FPDFPageObj_CountMarks` | `fpdf_edit.h` | `int FPDFPageObj_CountMarks(FPDF_PAGEOBJECT)` | |
| `FPDFPageObj_GetMark` | `fpdf_edit.h` | `FPDF_PAGEOBJECTMARK FPDFPageObj_GetMark(FPDF_PAGEOBJECT, unsigned long index)` | |
| `FPDFPageObj_AddMark` | `fpdf_edit.h` | `FPDF_PAGEOBJECTMARK FPDFPageObj_AddMark(FPDF_PAGEOBJECT, FPDF_BYTESTRING name)` | |
| `FPDFPageObj_RemoveMark` | `fpdf_edit.h` | `FPDF_BOOL FPDFPageObj_RemoveMark(FPDF_PAGEOBJECT, FPDF_PAGEOBJECTMARK)` | |
| `FPDFPageObjMark_GetName` | `fpdf_edit.h` | `FPDF_BOOL FPDFPageObjMark_GetName(FPDF_PAGEOBJECTMARK, FPDF_WCHAR* buffer, unsigned long buflen, unsigned long* out_buflen)` | |
| `FPDFPageObjMark_CountParams` | `fpdf_edit.h` | `int FPDFPageObjMark_CountParams(FPDF_PAGEOBJECTMARK)` | |
| `FPDFPageObjMark_GetParamKey` | `fpdf_edit.h` | `FPDF_BOOL FPDFPageObjMark_GetParamKey(FPDF_PAGEOBJECTMARK, unsigned long index, FPDF_WCHAR*, unsigned long buflen, unsigned long* out_buflen)` | |
| `FPDFPageObjMark_GetParamValueType` | `fpdf_edit.h` | `FPDF_OBJECT_TYPE FPDFPageObjMark_GetParamValueType(FPDF_PAGEOBJECTMARK, FPDF_BYTESTRING key)` | |
| `FPDFPageObjMark_GetParamIntValue` | `fpdf_edit.h` | `FPDF_BOOL FPDFPageObjMark_GetParamIntValue(FPDF_PAGEOBJECTMARK, FPDF_BYTESTRING key, int* out_value)` | |
| `FPDFPageObjMark_GetParamFloatValue` | `fpdf_edit.h` | analogous, `float* out_value` | |
| `FPDFPageObjMark_GetParamStringValue` | `fpdf_edit.h` | analogous, UTF-16 buffer | |
| `FPDFPageObjMark_GetParamBlobValue` | `fpdf_edit.h` | analogous, byte buffer | |
| `FPDFPageObjMark_SetIntParam` | `fpdf_edit.h` | `FPDF_BOOL FPDFPageObjMark_SetIntParam(FPDF_DOCUMENT, FPDF_PAGEOBJECT, FPDF_PAGEOBJECTMARK, FPDF_BYTESTRING key, int value)` | |
| `FPDFPageObjMark_SetFloatParam` | `fpdf_edit.h` | analogous | |
| `FPDFPageObjMark_SetStringParam` | `fpdf_edit.h` | analogous | |
| `FPDFPageObjMark_SetBlobParam` | `fpdf_edit.h` | `FPDF_BOOL ... (..., const unsigned char* value, unsigned long value_len)` | |
| `FPDFPageObjMark_RemoveParam` | `fpdf_edit.h` | `FPDF_BOOL FPDFPageObjMark_RemoveParam(FPDF_PAGEOBJECT, FPDF_PAGEOBJECTMARK, FPDF_BYTESTRING key)` | |

### 2.8 Page Objects - Path

| Symbol | Header | Signature | Description |
|---|---|---|---|
| `FPDFPath_CountSegments` | `fpdf_edit.h` | `int FPDFPath_CountSegments(FPDF_PAGEOBJECT path)` | |
| `FPDFPath_GetPathSegment` | `fpdf_edit.h` | `FPDF_PATHSEGMENT FPDFPath_GetPathSegment(FPDF_PAGEOBJECT path, int index)` | |
| `FPDFPath_MoveTo` | `fpdf_edit.h` | `FPDF_BOOL FPDFPath_MoveTo(FPDF_PAGEOBJECT, float x, float y)` | |
| `FPDFPath_LineTo` | `fpdf_edit.h` | `FPDF_BOOL FPDFPath_LineTo(FPDF_PAGEOBJECT, float x, float y)` | |
| `FPDFPath_BezierTo` | `fpdf_edit.h` | `FPDF_BOOL FPDFPath_BezierTo(FPDF_PAGEOBJECT, float x1, float y1, float x2, float y2, float x3, float y3)` | Cubic Bezier (writer side only) |
| `FPDFPath_Close` | `fpdf_edit.h` | `FPDF_BOOL FPDFPath_Close(FPDF_PAGEOBJECT)` | |
| `FPDFPath_SetDrawMode` | `fpdf_edit.h` | `FPDF_BOOL FPDFPath_SetDrawMode(FPDF_PAGEOBJECT, int fillmode, FPDF_BOOL stroke)` | `FPDF_FILLMODE_NONE`/`_ALTERNATE`/`_WINDING` |
| `FPDFPath_GetDrawMode` | `fpdf_edit.h` | `FPDF_BOOL FPDFPath_GetDrawMode(FPDF_PAGEOBJECT, int* fillmode, FPDF_BOOL* stroke)` | |
| `FPDFPathSegment_GetPoint` | `fpdf_edit.h` | `FPDF_BOOL FPDFPathSegment_GetPoint(FPDF_PATHSEGMENT, float* x, float* y)` | Endpoint only |
| `FPDFPathSegment_GetType` | `fpdf_edit.h` | `int FPDFPathSegment_GetType(FPDF_PATHSEGMENT)` | `FPDF_SEGMENT_LINETO`/`_BEZIERTO`/`_MOVETO`/`_UNKNOWN` |
| `FPDFPathSegment_GetClose` | `fpdf_edit.h` | `FPDF_BOOL FPDFPathSegment_GetClose(FPDF_PATHSEGMENT)` | True if this segment closes the subpath |

**Important gap**: `FPDFPathSegment_GetPoint()` only returns the segment's
endpoint. There is no exposed accessor for the Bezier control points of an
existing `FPDF_SEGMENT_BEZIERTO` segment - the segments returned from
`FPDFPath_GetPathSegment` only let you read the type, the endpoint, and the
close flag. The Bezier control points exist in the internal `CFX_Path::Point`
structure but are not in the public C ABI. To recover control points the
embedder must parse the page content stream directly. `FPDFPath_BezierTo` is
the inverse and works for path *construction* only.

### 2.9 Page Objects - Text

| Symbol | Header | Signature | Description |
|---|---|---|---|
| `FPDFText_SetText` | `fpdf_edit.h` | `FPDF_BOOL FPDFText_SetText(FPDF_PAGEOBJECT, FPDF_WIDESTRING text)` | UTF-16LE |
| `FPDFText_SetCharcodes` | `fpdf_edit.h` | `FPDF_BOOL FPDFText_SetCharcodes(FPDF_PAGEOBJECT, const uint32_t* charcodes, size_t count)` | |
| `FPDFText_SetPositions` | `fpdf_edit.h` | `FPDF_BOOL FPDFText_SetPositions(FPDF_PAGEOBJECT, const float* positions, size_t count)` | Per-char positions |
| `FPDFTextObj_GetText` | `fpdf_edit.h` | `unsigned long FPDFTextObj_GetText(FPDF_PAGEOBJECT, FPDF_TEXTPAGE, FPDF_WCHAR* buffer, unsigned long length)` | Get text from a single text object via its text page |
| `FPDFTextObj_GetFont` | `fpdf_edit.h` | `FPDF_FONT FPDFTextObj_GetFont(FPDF_PAGEOBJECT)` | |
| `FPDFTextObj_GetFontSize` | `fpdf_edit.h` | `FPDF_BOOL FPDFTextObj_GetFontSize(FPDF_PAGEOBJECT text, float* size)` | Font size in points |
| `FPDFTextObj_GetTextRenderMode` | `fpdf_edit.h` | `FPDF_TEXT_RENDERMODE FPDFTextObj_GetTextRenderMode(FPDF_PAGEOBJECT)` | Fill/Stroke/Invisible/Clip/etc. |
| `FPDFTextObj_SetTextRenderMode` | `fpdf_edit.h` | `FPDF_BOOL FPDFTextObj_SetTextRenderMode(FPDF_PAGEOBJECT, FPDF_TEXT_RENDERMODE)` | |
| `FPDFTextObj_GetRenderedBitmap` | `fpdf_edit.h` | `FPDF_BITMAP FPDFTextObj_GetRenderedBitmap(FPDF_DOCUMENT, FPDF_PAGE, FPDF_PAGEOBJECT, float scale)` | Rasterize one text object |
| `FPDFText_LoadPage` | `fpdf_text.h` | `FPDF_TEXTPAGE FPDFText_LoadPage(FPDF_PAGE)` | Build text-page index |
| `FPDFText_ClosePage` | `fpdf_text.h` | `void FPDFText_ClosePage(FPDF_TEXTPAGE)` | |
| `FPDFText_CountChars` | `fpdf_text.h` | `int FPDFText_CountChars(FPDF_TEXTPAGE)` | |
| `FPDFText_GetUnicode` | `fpdf_text.h` | `unsigned int FPDFText_GetUnicode(FPDF_TEXTPAGE, int index)` | |
| `FPDFText_GetTextObject` | `fpdf_text.h` | `FPDF_PAGEOBJECT FPDFText_GetTextObject(FPDF_TEXTPAGE, int index)` | Page object owning a char |
| `FPDFText_IsGenerated` | `fpdf_text.h` | `int FPDFText_IsGenerated(FPDF_TEXTPAGE, int index)` | |
| `FPDFText_IsHyphen` | `fpdf_text.h` | `int FPDFText_IsHyphen(FPDF_TEXTPAGE, int index)` | |
| `FPDFText_HasUnicodeMapError` | `fpdf_text.h` | `int FPDFText_HasUnicodeMapError(FPDF_TEXTPAGE, int index)` | |
| `FPDFText_GetFontSize` | `fpdf_text.h` | `double FPDFText_GetFontSize(FPDF_TEXTPAGE, int index)` | Em size in points |
| `FPDFText_GetFontInfo` | `fpdf_text.h` | `unsigned long FPDFText_GetFontInfo(FPDF_TEXTPAGE, int index, void* buffer, unsigned long buflen, int* flags)` | Per-char font name + flags |
| `FPDFText_GetFontWeight` | `fpdf_text.h` | `int FPDFText_GetFontWeight(FPDF_TEXTPAGE, int index)` | |
| `FPDFText_GetFillColor` | `fpdf_text.h` | `FPDF_BOOL FPDFText_GetFillColor(FPDF_TEXTPAGE, int index, unsigned int* R, unsigned int* G, unsigned int* B, unsigned int* A)` | |
| `FPDFText_GetStrokeColor` | `fpdf_text.h` | analogous | |
| `FPDFText_GetCharAngle` | `fpdf_text.h` | `float FPDFText_GetCharAngle(FPDF_TEXTPAGE, int index)` | Radians |
| `FPDFText_GetCharBox` | `fpdf_text.h` | `FPDF_BOOL FPDFText_GetCharBox(FPDF_TEXTPAGE, int index, double* left, double* right, double* bottom, double* top)` | |
| `FPDFText_GetLooseCharBox` | `fpdf_text.h` | `FPDF_BOOL FPDFText_GetLooseCharBox(FPDF_TEXTPAGE, int index, FS_RECTF*)` | Glyph-bounds box |
| `FPDFText_GetMatrix` | `fpdf_text.h` | `FPDF_BOOL FPDFText_GetMatrix(FPDF_TEXTPAGE, int index, FS_MATRIX*)` | Effective glyph CTM |
| `FPDFText_GetCharOrigin` | `fpdf_text.h` | `FPDF_BOOL FPDFText_GetCharOrigin(FPDF_TEXTPAGE, int index, double* x, double* y)` | |
| `FPDFText_GetCharIndexAtPos` | `fpdf_text.h` | `int FPDFText_GetCharIndexAtPos(FPDF_TEXTPAGE, double x, double y, double xTolerance, double yTolerance)` | |
| `FPDFText_GetText` | `fpdf_text.h` | `int FPDFText_GetText(FPDF_TEXTPAGE, int start_index, int count, unsigned short* result)` | UCS-2 |
| `FPDFText_CountRects` | `fpdf_text.h` | `int FPDFText_CountRects(FPDF_TEXTPAGE, int start_index, int count)` | |
| `FPDFText_GetRect` | `fpdf_text.h` | `FPDF_BOOL FPDFText_GetRect(FPDF_TEXTPAGE, int rect_index, double* left, double* top, double* right, double* bottom)` | |
| `FPDFText_GetBoundedText` | `fpdf_text.h` | `int FPDFText_GetBoundedText(FPDF_TEXTPAGE, double left, double top, double right, double bottom, unsigned short* buffer, int buflen)` | UTF-16 text in rect |
| `FPDFText_GetCharIndexFromTextIndex` | `fpdf_searchex.h` | `int FPDFText_GetCharIndexFromTextIndex(FPDF_TEXTPAGE, int nTextIndex)` | |
| `FPDFText_GetTextIndexFromCharIndex` | `fpdf_searchex.h` | `int FPDFText_GetTextIndexFromCharIndex(FPDF_TEXTPAGE, int nCharIndex)` | |

### 2.10 Page Objects - Image

| Symbol | Header | Signature | Description |
|---|---|---|---|
| `FPDFImageObj_LoadJpegFile` | `fpdf_edit.h` | `FPDF_BOOL FPDFImageObj_LoadJpegFile(FPDF_PAGE* pages, int count, FPDF_PAGEOBJECT, FPDF_FILEACCESS*)` | Set image from JPEG (file-referenced) |
| `FPDFImageObj_LoadJpegFileInline` | `fpdf_edit.h` | analogous | Set image from JPEG (inline, copies data) |
| `FPDFImageObj_SetMatrix` | `fpdf_edit.h` | `FPDF_BOOL FPDFImageObj_SetMatrix(FPDF_PAGEOBJECT, double a, ..., double f)` | Legacy; prefer `FPDFPageObj_SetMatrix` |
| `FPDFImageObj_SetBitmap` | `fpdf_edit.h` | `FPDF_BOOL FPDFImageObj_SetBitmap(FPDF_PAGE* pages, int count, FPDF_PAGEOBJECT, FPDF_BITMAP)` | |
| `FPDFImageObj_GetBitmap` | `fpdf_edit.h` | `FPDF_BITMAP FPDFImageObj_GetBitmap(FPDF_PAGEOBJECT)` | Image alone, no mask/matrix |
| `FPDFImageObj_GetRenderedBitmap` | `fpdf_edit.h` | `FPDF_BITMAP FPDFImageObj_GetRenderedBitmap(FPDF_DOCUMENT, FPDF_PAGE, FPDF_PAGEOBJECT)` | With mask + matrix applied |
| `FPDFImageObj_GetImageDataDecoded` | `fpdf_edit.h` | `unsigned long FPDFImageObj_GetImageDataDecoded(FPDF_PAGEOBJECT, void* buffer, unsigned long buflen)` | After filter pipeline |
| `FPDFImageObj_GetImageDataRaw` | `fpdf_edit.h` | `unsigned long FPDFImageObj_GetImageDataRaw(FPDF_PAGEOBJECT, void* buffer, unsigned long buflen)` | Compressed/raw |
| `FPDFImageObj_GetImageFilterCount` | `fpdf_edit.h` | `int FPDFImageObj_GetImageFilterCount(FPDF_PAGEOBJECT)` | |
| `FPDFImageObj_GetImageFilter` | `fpdf_edit.h` | `unsigned long FPDFImageObj_GetImageFilter(FPDF_PAGEOBJECT, int index, void* buffer, unsigned long buflen)` | UTF-8 |
| `FPDFImageObj_GetImageMetadata` | `fpdf_edit.h` | `FPDF_BOOL FPDFImageObj_GetImageMetadata(FPDF_PAGEOBJECT, FPDF_PAGE, FPDF_IMAGEOBJ_METADATA*)` | Width/height/DPI/bpp/colorspace |
| `FPDFImageObj_GetImagePixelSize` | `fpdf_edit.h` | `FPDF_BOOL FPDFImageObj_GetImagePixelSize(FPDF_PAGEOBJECT, unsigned int* width, unsigned int* height)` | Faster than full metadata |
| `FPDFImageObj_GetIccProfileDataDecoded` | `fpdf_edit.h` | `FPDF_BOOL FPDFImageObj_GetIccProfileDataDecoded(FPDF_PAGEOBJECT, FPDF_PAGE, uint8_t* buffer, size_t buflen, size_t* out_buflen)` | |

`FPDF_IMAGEOBJ_METADATA` struct fields: `width`, `height`, `horizontal_dpi`,
`vertical_dpi`, `bits_per_pixel`, `colorspace`
(one of `FPDF_COLORSPACE_DEVICEGRAY`/`_DEVICERGB`/`_DEVICECMYK`/`_CALGRAY`/
`_CALRGB`/`_LAB`/`_ICCBASED`/`_SEPARATION`/`_DEVICEN`/`_INDEXED`/`_PATTERN`/
`_UNKNOWN`), `marked_content_id`.

### 2.11 Page Objects - Form XObject

| Symbol | Header | Signature | Description |
|---|---|---|---|
| `FPDFFormObj_CountObjects` | `fpdf_edit.h` | `int FPDFFormObj_CountObjects(FPDF_PAGEOBJECT form_object)` | Number of inner page objects |
| `FPDFFormObj_GetObject` | `fpdf_edit.h` | `FPDF_PAGEOBJECT FPDFFormObj_GetObject(FPDF_PAGEOBJECT form_object, unsigned long index)` | |
| `FPDFFormObj_RemoveObject` | `fpdf_edit.h` | `FPDF_BOOL FPDFFormObj_RemoveObject(FPDF_PAGEOBJECT form_object, FPDF_PAGEOBJECT page_object)` | |
| `FPDF_NewXObjectFromPage` | `fpdf_ppo.h` | `FPDF_XOBJECT FPDF_NewXObjectFromPage(FPDF_DOCUMENT dest_doc, FPDF_DOCUMENT src_doc, int src_page_index)` | Make XObject template from another doc's page |
| `FPDF_CloseXObject` | `fpdf_ppo.h` | `void FPDF_CloseXObject(FPDF_XOBJECT)` | |
| `FPDF_NewFormObjectFromXObject` | `fpdf_ppo.h` | `FPDF_PAGEOBJECT FPDF_NewFormObjectFromXObject(FPDF_XOBJECT)` | |

### 2.12 Clipping Paths

| Symbol | Header | Signature | Description |
|---|---|---|---|
| `FPDFPageObj_GetClipPath` | `fpdf_transformpage.h` | `FPDF_CLIPPATH FPDFPageObj_GetClipPath(FPDF_PAGEOBJECT)` | Read clip path from a page object |
| `FPDFPageObj_TransformClipPath` | `fpdf_transformpage.h` | `void FPDFPageObj_TransformClipPath(FPDF_PAGEOBJECT, double a, ..., double f)` | |
| `FPDFClipPath_CountPaths` | `fpdf_transformpage.h` | `int FPDFClipPath_CountPaths(FPDF_CLIPPATH)` | |
| `FPDFClipPath_CountPathSegments` | `fpdf_transformpage.h` | `int FPDFClipPath_CountPathSegments(FPDF_CLIPPATH, int path_index)` | |
| `FPDFClipPath_GetPathSegment` | `fpdf_transformpage.h` | `FPDF_PATHSEGMENT FPDFClipPath_GetPathSegment(FPDF_CLIPPATH, int path_index, int segment_index)` | |
| `FPDF_CreateClipPath` | `fpdf_transformpage.h` | `FPDF_CLIPPATH FPDF_CreateClipPath(float left, float bottom, float right, float top)` | Make rectangle clip path |
| `FPDF_DestroyClipPath` | `fpdf_transformpage.h` | `void FPDF_DestroyClipPath(FPDF_CLIPPATH)` | For caller-owned clip paths only |
| `FPDFPage_InsertClipPath` | `fpdf_transformpage.h` | `void FPDFPage_InsertClipPath(FPDF_PAGE, FPDF_CLIPPATH)` | Apply clip to entire page |

### 2.13 Fonts

| Symbol | Header | Signature | Description |
|---|---|---|---|
| `FPDFText_LoadFont` | `fpdf_edit.h` | `FPDF_FONT FPDFText_LoadFont(FPDF_DOCUMENT, const uint8_t* data, uint32_t size, int font_type, FPDF_BOOL cid)` | Embed font from data. `font_type` is `FPDF_FONT_TYPE1` or `FPDF_FONT_TRUETYPE` |
| `FPDFText_LoadStandardFont` | `fpdf_edit.h` | `FPDF_FONT FPDFText_LoadStandardFont(FPDF_DOCUMENT, FPDF_BYTESTRING font)` | One of the 14 standard PDF fonts (e.g. `Helvetica-BoldItalic`) |
| `FPDFText_LoadCidType2Font` | `fpdf_edit.h` | `FPDF_FONT FPDFText_LoadCidType2Font(FPDF_DOCUMENT, const uint8_t* font_data, uint32_t font_data_size, FPDF_BYTESTRING to_unicode_cmap, const uint8_t* cid_to_gid_map_data, uint32_t cid_to_gid_map_data_size)` | CID font with explicit ToUnicode and CIDToGIDMap |
| `FPDFFont_Close` | `fpdf_edit.h` | `void FPDFFont_Close(FPDF_FONT)` | |
| `FPDFFont_GetBaseFontName` | `fpdf_edit.h` | `size_t FPDFFont_GetBaseFontName(FPDF_FONT, char* buffer, size_t length)` | PostScript name (UTF-8) |
| `FPDFFont_GetFamilyName` | `fpdf_edit.h` | `size_t FPDFFont_GetFamilyName(FPDF_FONT, char* buffer, size_t length)` | UTF-8 |
| `FPDFFont_GetFontData` | `fpdf_edit.h` | `FPDF_BOOL FPDFFont_GetFontData(FPDF_FONT, uint8_t* buffer, size_t buflen, size_t* out_buflen)` | Decoded font bytes |
| `FPDFFont_GetIsEmbedded` | `fpdf_edit.h` | `int FPDFFont_GetIsEmbedded(FPDF_FONT)` | 0/1, -1 on error |
| `FPDFFont_GetFlags` | `fpdf_edit.h` | `int FPDFFont_GetFlags(FPDF_FONT)` | ISO 32000-1 table 123 flags |
| `FPDFFont_GetWeight` | `fpdf_edit.h` | `int FPDFFont_GetWeight(FPDF_FONT)` | Typical 400/700 |
| `FPDFFont_GetItalicAngle` | `fpdf_edit.h` | `FPDF_BOOL FPDFFont_GetItalicAngle(FPDF_FONT, int* angle)` | Degrees CCW |
| `FPDFFont_GetAscent` | `fpdf_edit.h` | `FPDF_BOOL FPDFFont_GetAscent(FPDF_FONT, float font_size, float* ascent)` | |
| `FPDFFont_GetDescent` | `fpdf_edit.h` | `FPDF_BOOL FPDFFont_GetDescent(FPDF_FONT, float font_size, float* descent)` | |
| `FPDFFont_GetGlyphWidth` | `fpdf_edit.h` | `FPDF_BOOL FPDFFont_GetGlyphWidth(FPDF_FONT, uint32_t glyph, float font_size, float* width)` | |
| `FPDFFont_GetGlyphPath` | `fpdf_edit.h` | `FPDF_GLYPHPATH FPDFFont_GetGlyphPath(FPDF_FONT, uint32_t glyph, float font_size)` | Vector glyph outline |
| `FPDFGlyphPath_CountGlyphSegments` | `fpdf_edit.h` | `int FPDFGlyphPath_CountGlyphSegments(FPDF_GLYPHPATH)` | |
| `FPDFGlyphPath_GetGlyphPathSegment` | `fpdf_edit.h` | `FPDF_PATHSEGMENT FPDFGlyphPath_GetGlyphPathSegment(FPDF_GLYPHPATH, int index)` | Reuses `FPDF_PATHSEGMENT` accessors |
| `FPDF_GetDefaultTTFMap` | `fpdf_sysfontinfo.h` | `const FPDF_CharsetFontMap* FPDF_GetDefaultTTFMap()` | Deprecated default font map |
| `FPDF_GetDefaultTTFMapCount` | `fpdf_sysfontinfo.h` | `size_t FPDF_GetDefaultTTFMapCount()` | |
| `FPDF_GetDefaultTTFMapEntry` | `fpdf_sysfontinfo.h` | `const FPDF_CharsetFontMap* FPDF_GetDefaultTTFMapEntry(size_t index)` | |
| `FPDF_AddInstalledFont` | `fpdf_sysfontinfo.h` | `void FPDF_AddInstalledFont(void* mapper, const char* face, int charset)` | Plug into a custom `FPDF_SYSFONTINFO` |
| `FPDF_SetSystemFontInfo` | `fpdf_sysfontinfo.h` | `void FPDF_SetSystemFontInfo(FPDF_SYSFONTINFO* pFontInfo)` | Replace platform font lookup |
| `FPDF_GetDefaultSystemFontInfo` | `fpdf_sysfontinfo.h` | `FPDF_SYSFONTINFO* FPDF_GetDefaultSystemFontInfo()` | |
| `FPDF_FreeDefaultSystemFontInfo` | `fpdf_sysfontinfo.h` | `void FPDF_FreeDefaultSystemFontInfo(FPDF_SYSFONTINFO*)` | |

### 2.14 Bitmaps

| Symbol | Header | Signature | Description |
|---|---|---|---|
| `FPDFBitmap_Create` | `fpdfview.h` | `FPDF_BITMAP FPDFBitmap_Create(int width, int height, int alpha)` | BGRA/BGRx |
| `FPDFBitmap_CreateEx` | `fpdfview.h` | `FPDF_BITMAP FPDFBitmap_CreateEx(int width, int height, int format, void* first_scan, int stride)` | `FPDFBitmap_Gray`/`_BGR`/`_BGRx`/`_BGRA`/`_BGRA_Premul` |
| `FPDFBitmap_GetFormat` | `fpdfview.h` | `int FPDFBitmap_GetFormat(FPDF_BITMAP)` | |
| `FPDFBitmap_FillRect` | `fpdfview.h` | `FPDF_BOOL FPDFBitmap_FillRect(FPDF_BITMAP, int left, int top, int width, int height, FPDF_DWORD color)` | ARGB 32-bit fill |
| `FPDFBitmap_GetBuffer` | `fpdfview.h` | `void* FPDFBitmap_GetBuffer(FPDF_BITMAP)` | |
| `FPDFBitmap_GetWidth` | `fpdfview.h` | `int FPDFBitmap_GetWidth(FPDF_BITMAP)` | |
| `FPDFBitmap_GetHeight` | `fpdfview.h` | `int FPDFBitmap_GetHeight(FPDF_BITMAP)` | |
| `FPDFBitmap_GetStride` | `fpdfview.h` | `int FPDFBitmap_GetStride(FPDF_BITMAP)` | Bytes per row |
| `FPDFBitmap_Destroy` | `fpdfview.h` | `void FPDFBitmap_Destroy(FPDF_BITMAP)` | |
| `FPDFPage_GetThumbnailAsBitmap` | `fpdf_thumbnail.h` | `FPDF_BITMAP FPDFPage_GetThumbnailAsBitmap(FPDF_PAGE)` | |
| `FPDFPage_GetDecodedThumbnailData` | `fpdf_thumbnail.h` | `unsigned long FPDFPage_GetDecodedThumbnailData(FPDF_PAGE, void* buffer, unsigned long buflen)` | |
| `FPDFPage_GetRawThumbnailData` | `fpdf_thumbnail.h` | `unsigned long FPDFPage_GetRawThumbnailData(FPDF_PAGE, void* buffer, unsigned long buflen)` | |

### 2.15 Annotations

| Symbol | Header | Signature | Description |
|---|---|---|---|
| `FPDFAnnot_IsSupportedSubtype` | `fpdf_annot.h` | `FPDF_BOOL FPDFAnnot_IsSupportedSubtype(FPDF_ANNOTATION_SUBTYPE)` | Create-time support check |
| `FPDFPage_CreateAnnot` | `fpdf_annot.h` | `FPDF_ANNOTATION FPDFPage_CreateAnnot(FPDF_PAGE, FPDF_ANNOTATION_SUBTYPE)` | |
| `FPDFPage_GetAnnotCount` | `fpdf_annot.h` | `int FPDFPage_GetAnnotCount(FPDF_PAGE)` | |
| `FPDFPage_GetAnnot` | `fpdf_annot.h` | `FPDF_ANNOTATION FPDFPage_GetAnnot(FPDF_PAGE, int index)` | |
| `FPDFPage_GetAnnotIndex` | `fpdf_annot.h` | `int FPDFPage_GetAnnotIndex(FPDF_PAGE, FPDF_ANNOTATION)` | |
| `FPDFPage_CloseAnnot` | `fpdf_annot.h` | `void FPDFPage_CloseAnnot(FPDF_ANNOTATION)` | |
| `FPDFPage_RemoveAnnot` | `fpdf_annot.h` | `FPDF_BOOL FPDFPage_RemoveAnnot(FPDF_PAGE, int index)` | |
| `FPDFAnnot_GetSubtype` | `fpdf_annot.h` | `FPDF_ANNOTATION_SUBTYPE FPDFAnnot_GetSubtype(FPDF_ANNOTATION)` | One of `FPDF_ANNOT_*` (TEXT, LINK, FREETEXT, LINE, SQUARE, CIRCLE, POLYGON, POLYLINE, HIGHLIGHT, UNDERLINE, SQUIGGLY, STRIKEOUT, STAMP, CARET, INK, POPUP, FILEATTACHMENT, SOUND, MOVIE, WIDGET, SCREEN, PRINTERMARK, TRAPNET, WATERMARK, THREED, RICHMEDIA, XFAWIDGET, REDACT) |
| `FPDFAnnot_IsObjectSupportedSubtype` | `fpdf_annot.h` | `FPDF_BOOL FPDFAnnot_IsObjectSupportedSubtype(FPDF_ANNOTATION_SUBTYPE)` | |
| `FPDFAnnot_UpdateObject` | `fpdf_annot.h` | `FPDF_BOOL FPDFAnnot_UpdateObject(FPDF_ANNOTATION, FPDF_PAGEOBJECT)` | |
| `FPDFAnnot_AddInkStroke` | `fpdf_annot.h` | `int FPDFAnnot_AddInkStroke(FPDF_ANNOTATION, const FS_POINTF*, size_t point_count)` | |
| `FPDFAnnot_RemoveInkList` | `fpdf_annot.h` | `FPDF_BOOL FPDFAnnot_RemoveInkList(FPDF_ANNOTATION)` | |
| `FPDFAnnot_AppendObject` | `fpdf_annot.h` | `FPDF_BOOL FPDFAnnot_AppendObject(FPDF_ANNOTATION, FPDF_PAGEOBJECT)` | |
| `FPDFAnnot_GetObjectCount` | `fpdf_annot.h` | `int FPDFAnnot_GetObjectCount(FPDF_ANNOTATION)` | |
| `FPDFAnnot_GetObject` | `fpdf_annot.h` | `FPDF_PAGEOBJECT FPDFAnnot_GetObject(FPDF_ANNOTATION, int index)` | |
| `FPDFAnnot_RemoveObject` | `fpdf_annot.h` | `FPDF_BOOL FPDFAnnot_RemoveObject(FPDF_ANNOTATION, int index)` | |
| `FPDFAnnot_SetColor`/`GetColor` | `fpdf_annot.h` | `(..., FPDFANNOT_COLORTYPE type, unsigned int R/G/B/A)` | `FPDFANNOT_COLORTYPE_Color` or `_InteriorColor` |
| `FPDFAnnot_HasAttachmentPoints` | `fpdf_annot.h` | `FPDF_BOOL FPDFAnnot_HasAttachmentPoints(FPDF_ANNOTATION)` | |
| `FPDFAnnot_SetAttachmentPoints` | `fpdf_annot.h` | `FPDF_BOOL FPDFAnnot_SetAttachmentPoints(FPDF_ANNOTATION, size_t quad_index, const FS_QUADPOINTSF*)` | |
| `FPDFAnnot_AppendAttachmentPoints` | `fpdf_annot.h` | `FPDF_BOOL FPDFAnnot_AppendAttachmentPoints(FPDF_ANNOTATION, const FS_QUADPOINTSF*)` | |
| `FPDFAnnot_CountAttachmentPoints` | `fpdf_annot.h` | `size_t FPDFAnnot_CountAttachmentPoints(FPDF_ANNOTATION)` | |
| `FPDFAnnot_GetAttachmentPoints` | `fpdf_annot.h` | `FPDF_BOOL FPDFAnnot_GetAttachmentPoints(FPDF_ANNOTATION, size_t quad_index, FS_QUADPOINTSF*)` | |
| `FPDFAnnot_SetRect`/`GetRect` | `fpdf_annot.h` | `(FPDF_ANNOTATION, FS_RECTF*)` | |
| `FPDFAnnot_GetVertices` | `fpdf_annot.h` | `unsigned long FPDFAnnot_GetVertices(FPDF_ANNOTATION, FS_POINTF* buffer, unsigned long length)` | Polygon/polyline vertices |
| `FPDFAnnot_GetInkListCount` | `fpdf_annot.h` | `unsigned long FPDFAnnot_GetInkListCount(FPDF_ANNOTATION)` | |
| `FPDFAnnot_GetInkListPath` | `fpdf_annot.h` | `unsigned long FPDFAnnot_GetInkListPath(FPDF_ANNOTATION, unsigned long path_index, FS_POINTF* buffer, unsigned long length)` | |
| `FPDFAnnot_GetLine` | `fpdf_annot.h` | `FPDF_BOOL FPDFAnnot_GetLine(FPDF_ANNOTATION, FS_POINTF* start, FS_POINTF* end)` | For LINE subtype |
| `FPDFAnnot_SetBorder`/`GetBorder` | `fpdf_annot.h` | `(..., float horizontal_radius, float vertical_radius, float border_width)` | |
| `FPDFAnnot_GetFormAdditionalActionJavaScript` | `fpdf_annot.h` | with `FPDF_FORMHANDLE` | JS for K/F/V/C additional action |
| `FPDFAnnot_HasKey` | `fpdf_annot.h` | `FPDF_BOOL FPDFAnnot_HasKey(FPDF_ANNOTATION, FPDF_BYTESTRING key)` | Dictionary key check |
| `FPDFAnnot_GetValueType` | `fpdf_annot.h` | `FPDF_OBJECT_TYPE FPDFAnnot_GetValueType(FPDF_ANNOTATION, FPDF_BYTESTRING key)` | |
| `FPDFAnnot_SetStringValue`/`GetStringValue` | `fpdf_annot.h` | UTF-16LE | |
| `FPDFAnnot_GetNumberValue` | `fpdf_annot.h` | `FPDF_BOOL FPDFAnnot_GetNumberValue(FPDF_ANNOTATION, FPDF_BYTESTRING key, float* value)` | |
| `FPDFAnnot_SetAP`/`GetAP` | `fpdf_annot.h` | `(..., FPDF_ANNOT_APPEARANCEMODE)` modes: `_NORMAL`/`_ROLLOVER`/`_DOWN` | |
| `FPDFAnnot_GetLinkedAnnot` | `fpdf_annot.h` | `FPDF_ANNOTATION FPDFAnnot_GetLinkedAnnot(FPDF_ANNOTATION, FPDF_BYTESTRING key)` | |
| `FPDFAnnot_GetFlags`/`SetFlags` | `fpdf_annot.h` | `int / FPDF_BOOL` with `FPDF_ANNOT_FLAG_*` bits | |
| `FPDFAnnot_GetLink` | `fpdf_annot.h` | `FPDF_LINK FPDFAnnot_GetLink(FPDF_ANNOTATION)` | |
| `FPDFAnnot_SetURI` | `fpdf_annot.h` | `FPDF_BOOL FPDFAnnot_SetURI(FPDF_ANNOTATION, const char* uri)` | Set link URI |
| `FPDFAnnot_AddFileAttachment` | `fpdf_annot.h` | `FPDF_ATTACHMENT FPDFAnnot_AddFileAttachment(FPDF_ANNOTATION, FPDF_WIDESTRING name)` | |
| `FPDFAnnot_GetFileAttachment` | `fpdf_annot.h` | `FPDF_ATTACHMENT FPDFAnnot_GetFileAttachment(FPDF_ANNOTATION)` | |

### 2.16 Form Fields / AcroForm / XFA

The form-fill interface centers on `FPDF_FORMFILLINFO`, a versioned struct
the embedder fills with callbacks (Release, FFI_Invalidate, FFI_OutputSelectedRect,
FFI_SetCursor, FFI_SetTimer, FFI_KillTimer, FFI_GetLocalTime, etc.), and on
`FPDF_FORMHANDLE` returned by initialization.

| Symbol | Header | Signature | Description |
|---|---|---|---|
| `FPDFDOC_InitFormFillEnvironment` | `fpdf_formfill.h` | `FPDF_FORMHANDLE FPDFDOC_InitFormFillEnvironment(FPDF_DOCUMENT, FPDF_FORMFILLINFO*)` | |
| `FPDFDOC_ExitFormFillEnvironment` | `fpdf_formfill.h` | `void FPDFDOC_ExitFormFillEnvironment(FPDF_FORMHANDLE)` | |
| `FPDF_GetFormType` | `fpdf_formfill.h` | `int FPDF_GetFormType(FPDF_DOCUMENT)` | None/AcroForm/XFA Full/XFA Foreground |
| `FPDF_LoadXFA` | `fpdf_formfill.h` | `FPDF_BOOL FPDF_LoadXFA(FPDF_DOCUMENT)` | XFA builds only |
| `FPDF_FFLDraw` | `fpdf_formfill.h` | `void FPDF_FFLDraw(FPDF_FORMHANDLE, FPDF_BITMAP, FPDF_PAGE, int start_x, int start_y, int size_x, int size_y, int rotate, int flags)` | Render forms on top of page |
| `FPDF_FFLDrawSkia` | `fpdf_formfill.h` | analogous for Skia | |
| `FPDF_SetFormFieldHighlightColor` | `fpdf_formfill.h` | `void FPDF_SetFormFieldHighlightColor(FPDF_FORMHANDLE, int fieldType, unsigned long color)` | |
| `FPDF_SetFormFieldHighlightAlpha` | `fpdf_formfill.h` | `void FPDF_SetFormFieldHighlightAlpha(FPDF_FORMHANDLE, unsigned char alpha)` | |
| `FPDF_RemoveFormFieldHighlight` | `fpdf_formfill.h` | `void FPDF_RemoveFormFieldHighlight(FPDF_FORMHANDLE)` | |
| `FPDFPage_HasFormFieldAtPoint` | `fpdf_formfill.h` | `int FPDFPage_HasFormFieldAtPoint(FPDF_FORMHANDLE, FPDF_PAGE, double page_x, double page_y)` | |
| `FPDFPage_FormFieldZOrderAtPoint` | `fpdf_formfill.h` | `int FPDFPage_FormFieldZOrderAtPoint(FPDF_FORMHANDLE, FPDF_PAGE, double page_x, double page_y)` | |
| `FORM_OnAfterLoadPage` / `FORM_OnBeforeClosePage` | `fpdf_formfill.h` | (FPDF_PAGE, FPDF_FORMHANDLE) | Page lifecycle hooks for forms |
| `FORM_DoDocumentJSAction` / `FORM_DoDocumentOpenAction` / `FORM_DoDocumentAAction` | `fpdf_formfill.h` | | Execute doc-level scripts/actions |
| `FORM_DoPageAAction` | `fpdf_formfill.h` | `(FPDF_PAGE, FPDF_FORMHANDLE, int aaType)` | |
| `FORM_OnMouseMove` / `FORM_OnMouseWheel` / `FORM_OnLButtonDown`/`Up` / `FORM_OnLButtonDoubleClick` / `FORM_OnRButtonDown`/`Up` / `FORM_OnFocus` | `fpdf_formfill.h` | | Mouse event dispatch (event flags from `fpdf_fwlevent.h`) |
| `FORM_OnKeyDown` / `FORM_OnKeyUp` / `FORM_OnChar` | `fpdf_formfill.h` | | Keyboard event dispatch |
| `FORM_GetFocusedText` / `FORM_GetSelectedText` / `FORM_ReplaceSelection` / `FORM_ReplaceAndKeepSelection` / `FORM_SelectAllText` | `fpdf_formfill.h` | | Text editing |
| `FORM_CanUndo` / `FORM_CanRedo` / `FORM_Undo` / `FORM_Redo` | `fpdf_formfill.h` | | Undo/redo |
| `FORM_ForceToKillFocus` / `FORM_GetFocusedAnnot` / `FORM_SetFocusedAnnot` | `fpdf_formfill.h` | | Focus control |
| `FORM_SetIndexSelected` / `FORM_IsIndexSelected` | `fpdf_formfill.h` | | Listbox/combo selection |
| `FPDFAnnot_GetFormFieldFlags` / `SetFormFieldFlags` | `fpdf_annot.h` | `(FPDF_FORMHANDLE, FPDF_ANNOTATION, [int])` | `FPDF_FORMFLAG_READONLY`/`_REQUIRED`/`_NOEXPORT`/`_TEXT_MULTILINE`/`_TEXT_PASSWORD`/`_CHOICE_COMBO`/`_CHOICE_EDIT`/`_CHOICE_MULTI_SELECT` |
| `FPDFAnnot_GetFormFieldAtPoint` | `fpdf_annot.h` | | |
| `FPDFAnnot_GetFormFieldName`/`AlternateName`/`Value`/`Type`/`ExportValue` | `fpdf_annot.h` | | Field properties |
| `FPDFAnnot_GetOptionCount` / `GetOptionLabel` / `IsOptionSelected` | `fpdf_annot.h` | | Choice fields |
| `FPDFAnnot_GetFontSize` / `GetFontColor` / `SetFontColor` | `fpdf_annot.h` | | Field font |
| `FPDFAnnot_IsChecked` | `fpdf_annot.h` | | Check/radio state |
| `FPDFAnnot_GetFormControlCount` / `GetFormControlIndex` | `fpdf_annot.h` | | |
| `FPDFAnnot_SetFocusableSubtypes` / `GetFocusableSubtypes` / `GetFocusableSubtypesCount` | `fpdf_annot.h` | | Restrict which annotation subtypes can be focused |

### 2.17 Embedded File Attachments

| Symbol | Header | Signature | Description |
|---|---|---|---|
| `FPDFDoc_GetAttachmentCount` | `fpdf_attachment.h` | `int FPDFDoc_GetAttachmentCount(FPDF_DOCUMENT)` | |
| `FPDFDoc_AddAttachment` | `fpdf_attachment.h` | `FPDF_ATTACHMENT FPDFDoc_AddAttachment(FPDF_DOCUMENT, FPDF_WIDESTRING name)` | |
| `FPDFDoc_GetAttachment` | `fpdf_attachment.h` | `FPDF_ATTACHMENT FPDFDoc_GetAttachment(FPDF_DOCUMENT, int index)` | |
| `FPDFDoc_DeleteAttachment` | `fpdf_attachment.h` | `FPDF_BOOL FPDFDoc_DeleteAttachment(FPDF_DOCUMENT, int index)` | |
| `FPDFAttachment_GetName` | `fpdf_attachment.h` | `unsigned long FPDFAttachment_GetName(FPDF_ATTACHMENT, FPDF_WCHAR* buffer, unsigned long buflen)` | |
| `FPDFAttachment_HasKey` | `fpdf_attachment.h` | `FPDF_BOOL FPDFAttachment_HasKey(FPDF_ATTACHMENT, FPDF_BYTESTRING key)` | |
| `FPDFAttachment_GetValueType` | `fpdf_attachment.h` | `FPDF_OBJECT_TYPE FPDFAttachment_GetValueType(FPDF_ATTACHMENT, FPDF_BYTESTRING key)` | |
| `FPDFAttachment_SetStringValue` | `fpdf_attachment.h` | `FPDF_BOOL FPDFAttachment_SetStringValue(FPDF_ATTACHMENT, FPDF_BYTESTRING key, FPDF_WIDESTRING value)` | |
| `FPDFAttachment_GetStringValue` | `fpdf_attachment.h` | `unsigned long FPDFAttachment_GetStringValue(FPDF_ATTACHMENT, FPDF_BYTESTRING key, FPDF_WCHAR* buffer, unsigned long buflen)` | |
| `FPDFAttachment_SetFile` | `fpdf_attachment.h` | `FPDF_BOOL FPDFAttachment_SetFile(FPDF_ATTACHMENT, FPDF_DOCUMENT, const void* contents, unsigned long len)` | |
| `FPDFAttachment_GetFile` | `fpdf_attachment.h` | `FPDF_BOOL FPDFAttachment_GetFile(FPDF_ATTACHMENT, void* buffer, unsigned long buflen, unsigned long* out_buflen)` | |
| `FPDFAttachment_GetSubtype` | `fpdf_attachment.h` | `unsigned long FPDFAttachment_GetSubtype(FPDF_ATTACHMENT, FPDF_WCHAR* buffer, unsigned long buflen)` | MIME type |

### 2.18 Search

(See "Page Objects - Text" above for `FPDFText_FindStart`, `FPDFText_FindNext`,
`FPDFText_FindPrev`, `FPDFText_GetSchResultIndex`, `FPDFText_GetSchCount`,
`FPDFText_FindClose`.)

Find flags: `FPDF_MATCHCASE` (0x1), `FPDF_MATCHWHOLEWORD` (0x2),
`FPDF_CONSECUTIVE` (0x4).

Weblink auto-detection on a text page:

| Symbol | Header | Signature | Description |
|---|---|---|---|
| `FPDFLink_LoadWebLinks` | `fpdf_text.h` | `FPDF_PAGELINK FPDFLink_LoadWebLinks(FPDF_TEXTPAGE)` | |
| `FPDFLink_CountWebLinks` | `fpdf_text.h` | `int FPDFLink_CountWebLinks(FPDF_PAGELINK)` | |
| `FPDFLink_GetURL` | `fpdf_text.h` | `int FPDFLink_GetURL(FPDF_PAGELINK, int link_index, unsigned short* buffer, int buflen)` | |
| `FPDFLink_CountRects` | `fpdf_text.h` | `int FPDFLink_CountRects(FPDF_PAGELINK, int link_index)` | |
| `FPDFLink_GetRect` | `fpdf_text.h` | `FPDF_BOOL FPDFLink_GetRect(FPDF_PAGELINK, int link_index, int rect_index, double* left, double* top, double* right, double* bottom)` | |
| `FPDFLink_GetTextRange` | `fpdf_text.h` | `FPDF_BOOL FPDFLink_GetTextRange(FPDF_PAGELINK, int link_index, int* start_char_index, int* char_count)` | |
| `FPDFLink_CloseWebLinks` | `fpdf_text.h` | `void FPDFLink_CloseWebLinks(FPDF_PAGELINK)` | |

### 2.19 Bookmarks / Outline / Actions / Destinations / Link Annotations

| Symbol | Header | Signature | Description |
|---|---|---|---|
| `FPDFBookmark_GetFirstChild` | `fpdf_doc.h` | `FPDF_BOOKMARK FPDFBookmark_GetFirstChild(FPDF_DOCUMENT, FPDF_BOOKMARK)` | Pass NULL for top-level |
| `FPDFBookmark_GetNextSibling` | `fpdf_doc.h` | `FPDF_BOOKMARK FPDFBookmark_GetNextSibling(FPDF_DOCUMENT, FPDF_BOOKMARK)` | |
| `FPDFBookmark_GetTitle` | `fpdf_doc.h` | `unsigned long FPDFBookmark_GetTitle(FPDF_BOOKMARK, void* buffer, unsigned long buflen)` | UTF-16LE |
| `FPDFBookmark_GetCount` | `fpdf_doc.h` | `int FPDFBookmark_GetCount(FPDF_BOOKMARK)` | Open/closed state per PDF 32000-1 table 153 |
| `FPDFBookmark_Find` | `fpdf_doc.h` | `FPDF_BOOKMARK FPDFBookmark_Find(FPDF_DOCUMENT, FPDF_WIDESTRING title)` | |
| `FPDFBookmark_GetDest` | `fpdf_doc.h` | `FPDF_DEST FPDFBookmark_GetDest(FPDF_DOCUMENT, FPDF_BOOKMARK)` | |
| `FPDFBookmark_GetAction` | `fpdf_doc.h` | `FPDF_ACTION FPDFBookmark_GetAction(FPDF_BOOKMARK)` | |
| `FPDFAction_GetType` | `fpdf_doc.h` | `unsigned long FPDFAction_GetType(FPDF_ACTION)` | `PDFACTION_*` (UNSUPPORTED/GOTO/REMOTEGOTO/URI/LAUNCH/EMBEDDEDGOTO) |
| `FPDFAction_GetDest` | `fpdf_doc.h` | `FPDF_DEST FPDFAction_GetDest(FPDF_DOCUMENT, FPDF_ACTION)` | |
| `FPDFAction_GetFilePath` | `fpdf_doc.h` | `unsigned long FPDFAction_GetFilePath(FPDF_ACTION, void* buffer, unsigned long buflen)` | UTF-8 |
| `FPDFAction_GetURIPath` | `fpdf_doc.h` | `unsigned long FPDFAction_GetURIPath(FPDF_DOCUMENT, FPDF_ACTION, void* buffer, unsigned long buflen)` | |
| `FPDFDest_GetDestPageIndex` | `fpdf_doc.h` | `int FPDFDest_GetDestPageIndex(FPDF_DOCUMENT, FPDF_DEST)` | |
| `FPDFDest_GetView` | `fpdf_doc.h` | `unsigned long FPDFDest_GetView(FPDF_DEST, unsigned long* pNumParams, FS_FLOAT* pParams)` | `PDFDEST_VIEW_*` |
| `FPDFDest_GetLocationInPage` | `fpdf_doc.h` | `FPDF_BOOL FPDFDest_GetLocationInPage(FPDF_DEST, FPDF_BOOL* hasXVal, FPDF_BOOL* hasYVal, FPDF_BOOL* hasZoomVal, FS_FLOAT* x, FS_FLOAT* y, FS_FLOAT* zoom)` | |
| `FPDFLink_GetLinkAtPoint` | `fpdf_doc.h` | `FPDF_LINK FPDFLink_GetLinkAtPoint(FPDF_PAGE, double x, double y)` | |
| `FPDFLink_GetLinkZOrderAtPoint` | `fpdf_doc.h` | `int FPDFLink_GetLinkZOrderAtPoint(FPDF_PAGE, double x, double y)` | |
| `FPDFLink_GetDest` | `fpdf_doc.h` | `FPDF_DEST FPDFLink_GetDest(FPDF_DOCUMENT, FPDF_LINK)` | |
| `FPDFLink_GetAction` | `fpdf_doc.h` | `FPDF_ACTION FPDFLink_GetAction(FPDF_LINK)` | |
| `FPDFLink_Enumerate` | `fpdf_doc.h` | `FPDF_BOOL FPDFLink_Enumerate(FPDF_PAGE, int* start_pos, FPDF_LINK* link_annot)` | |
| `FPDFLink_GetAnnot` | `fpdf_doc.h` | `FPDF_ANNOTATION FPDFLink_GetAnnot(FPDF_PAGE, FPDF_LINK)` | |
| `FPDFLink_GetAnnotRect` | `fpdf_doc.h` | `FPDF_BOOL FPDFLink_GetAnnotRect(FPDF_LINK, FS_RECTF*)` | |
| `FPDFLink_CountQuadPoints` | `fpdf_doc.h` | `int FPDFLink_CountQuadPoints(FPDF_LINK)` | |
| `FPDFLink_GetQuadPoints` | `fpdf_doc.h` | `FPDF_BOOL FPDFLink_GetQuadPoints(FPDF_LINK, int quad_index, FS_QUADPOINTSF*)` | |
| `FPDF_GetPageAAction` | `fpdf_doc.h` | `FPDF_ACTION FPDF_GetPageAAction(FPDF_PAGE, int aa_type)` | Page additional actions |

### 2.20 Structure Tree / Tagged PDF

| Symbol | Header | Signature | Description |
|---|---|---|---|
| `FPDF_StructTree_GetForPage` | `fpdf_structtree.h` | `FPDF_STRUCTTREE FPDF_StructTree_GetForPage(FPDF_PAGE)` | |
| `FPDF_StructTree_LoadPage` | `fpdf_structtree.h` | Alias (deprecated?) | |
| `FPDF_StructTree_Close` | `fpdf_structtree.h` | `void FPDF_StructTree_Close(FPDF_STRUCTTREE)` | |
| `FPDF_StructTree_CountChildren` | `fpdf_structtree.h` | `int FPDF_StructTree_CountChildren(FPDF_STRUCTTREE)` | |
| `FPDF_StructTree_GetChildAtIndex` | `fpdf_structtree.h` | `FPDF_STRUCTELEMENT FPDF_StructTree_GetChildAtIndex(FPDF_STRUCTTREE, int index)` | |
| `FPDF_StructElement_GetAltText` | `fpdf_structtree.h` | `unsigned long FPDF_StructElement_GetAltText(FPDF_STRUCTELEMENT, void* buffer, unsigned long buflen)` | |
| `FPDF_StructElement_GetActualText` | `fpdf_structtree.h` | analogous | |
| `FPDF_StructElement_GetExpansion` | `fpdf_structtree.h` | analogous | |
| `FPDF_StructElement_GetID` | `fpdf_structtree.h` | analogous | |
| `FPDF_StructElement_GetLang` | `fpdf_structtree.h` | analogous | |
| `FPDF_StructElement_GetStringAttribute` | `fpdf_structtree.h` | `unsigned long FPDF_StructElement_GetStringAttribute(FPDF_STRUCTELEMENT, FPDF_BYTESTRING attr_name, void* buffer, unsigned long buflen)` | |
| `FPDF_StructElement_GetMarkedContentID` | `fpdf_structtree.h` | `int FPDF_StructElement_GetMarkedContentID(FPDF_STRUCTELEMENT)` | |
| `FPDF_StructElement_GetType` | `fpdf_structtree.h` | UTF-16LE element type name | |
| `FPDF_StructElement_GetObjType` | `fpdf_structtree.h` | UTF-16LE object type | |
| `FPDF_StructElement_GetTitle` | `fpdf_structtree.h` | UTF-16LE | |
| `FPDF_StructElement_CountChildren` | `fpdf_structtree.h` | `int` | |
| `FPDF_StructElement_GetChildAtIndex` | `fpdf_structtree.h` | `FPDF_STRUCTELEMENT FPDF_StructElement_GetChildAtIndex(FPDF_STRUCTELEMENT, int index)` | |
| `FPDF_StructElement_GetChildMarkedContentID` | `fpdf_structtree.h` | `int` | |
| `FPDF_StructElement_GetParent` | `fpdf_structtree.h` | `FPDF_STRUCTELEMENT FPDF_StructElement_GetParent(FPDF_STRUCTELEMENT)` | |
| `FPDF_StructElement_GetAttributeCount` | `fpdf_structtree.h` | `int` | |
| `FPDF_StructElement_GetAttributeAtIndex` | `fpdf_structtree.h` | `FPDF_STRUCTELEMENT_ATTR FPDF_StructElement_GetAttributeAtIndex(FPDF_STRUCTELEMENT, int index)` | |
| `FPDF_StructElement_Attr_GetCount` | `fpdf_structtree.h` | `int FPDF_StructElement_Attr_GetCount(FPDF_STRUCTELEMENT_ATTR)` | |
| `FPDF_StructElement_Attr_GetName` | `fpdf_structtree.h` | analogous | |
| `FPDF_StructElement_Attr_GetValue` | `fpdf_structtree.h` | `FPDF_STRUCTELEMENT_ATTR_VALUE FPDF_StructElement_Attr_GetValue(FPDF_STRUCTELEMENT_ATTR, FPDF_BYTESTRING name)` | |
| `FPDF_StructElement_Attr_GetType` | `fpdf_structtree.h` | `FPDF_OBJECT_TYPE FPDF_StructElement_Attr_GetType(FPDF_STRUCTELEMENT_ATTR_VALUE)` | |
| `FPDF_StructElement_Attr_GetBooleanValue` | `fpdf_structtree.h` | `FPDF_BOOL FPDF_StructElement_Attr_GetBooleanValue(FPDF_STRUCTELEMENT_ATTR_VALUE, FPDF_BOOL* out_value)` | |
| `FPDF_StructElement_Attr_GetNumberValue` | `fpdf_structtree.h` | `FPDF_BOOL ... float* out_value` | |
| `FPDF_StructElement_Attr_GetStringValue` | `fpdf_structtree.h` | UTF-16LE | |
| `FPDF_StructElement_Attr_GetBlobValue` | `fpdf_structtree.h` | byte buffer | |
| `FPDF_StructElement_Attr_CountChildren` | `fpdf_structtree.h` | `int` | |
| `FPDF_StructElement_Attr_GetChildAtIndex` | `fpdf_structtree.h` | nested attr value | |
| `FPDF_StructElement_GetMarkedContentIdCount` | `fpdf_structtree.h` | `int` | |
| `FPDF_StructElement_GetMarkedContentIdAtIndex` | `fpdf_structtree.h` | `int FPDF_StructElement_GetMarkedContentIdAtIndex(FPDF_STRUCTELEMENT, int index)` | |

### 2.21 Signatures

| Symbol | Header | Signature | Description |
|---|---|---|---|
| `FPDF_GetSignatureCount` | `fpdf_signature.h` | `int FPDF_GetSignatureCount(FPDF_DOCUMENT)` | |
| `FPDF_GetSignatureObject` | `fpdf_signature.h` | `FPDF_SIGNATURE FPDF_GetSignatureObject(FPDF_DOCUMENT, int index)` | Owned by document |
| `FPDFSignatureObj_GetContents` | `fpdf_signature.h` | `unsigned long FPDFSignatureObj_GetContents(FPDF_SIGNATURE, void* buffer, unsigned long length)` | PKCS#1 or PKCS#7 DER blob |
| `FPDFSignatureObj_GetByteRange` | `fpdf_signature.h` | `unsigned long FPDFSignatureObj_GetByteRange(FPDF_SIGNATURE, int* buffer, unsigned long length)` | Pairs of (offset, length) |
| `FPDFSignatureObj_GetSubFilter` | `fpdf_signature.h` | `unsigned long FPDFSignatureObj_GetSubFilter(FPDF_SIGNATURE, char* buffer, unsigned long length)` | 7-bit ASCII |
| `FPDFSignatureObj_GetReason` | `fpdf_signature.h` | `unsigned long FPDFSignatureObj_GetReason(FPDF_SIGNATURE, void* buffer, unsigned long length)` | UTF-16LE |
| `FPDFSignatureObj_GetTime` | `fpdf_signature.h` | `unsigned long FPDFSignatureObj_GetTime(FPDF_SIGNATURE, char* buffer, unsigned long length)` | `D:YYYYMMDDHHMMSS+XX'YY'` |
| `FPDFSignatureObj_GetDocMDPPermission` | `fpdf_signature.h` | `unsigned int FPDFSignatureObj_GetDocMDPPermission(FPDF_SIGNATURE)` | 1, 2, or 3 |

Note: PDFium provides only signature *metadata*; cryptographic verification of
the byte range and certificate chain is the embedder's responsibility.

### 2.22 JavaScript Actions

| Symbol | Header | Signature | Description |
|---|---|---|---|
| `FPDFDoc_GetJavaScriptActionCount` | `fpdf_javascript.h` | `int FPDFDoc_GetJavaScriptActionCount(FPDF_DOCUMENT)` | |
| `FPDFDoc_GetJavaScriptAction` | `fpdf_javascript.h` | `FPDF_JAVASCRIPT_ACTION FPDFDoc_GetJavaScriptAction(FPDF_DOCUMENT, int index)` | |
| `FPDFDoc_CloseJavaScriptAction` | `fpdf_javascript.h` | `void FPDFDoc_CloseJavaScriptAction(FPDF_JAVASCRIPT_ACTION)` | |
| `FPDFJavaScriptAction_GetName` | `fpdf_javascript.h` | `unsigned long FPDFJavaScriptAction_GetName(FPDF_JAVASCRIPT_ACTION, FPDF_WCHAR* buffer, unsigned long buflen)` | UTF-16LE |
| `FPDFJavaScriptAction_GetScript` | `fpdf_javascript.h` | `unsigned long FPDFJavaScriptAction_GetScript(FPDF_JAVASCRIPT_ACTION, FPDF_WCHAR* buffer, unsigned long buflen)` | UTF-16LE |

### 2.23 Page Imposition / Import / Misc

| Symbol | Header | Signature | Description |
|---|---|---|---|
| `FPDF_ImportPages` | `fpdf_ppo.h` | `FPDF_BOOL FPDF_ImportPages(FPDF_DOCUMENT dest, FPDF_DOCUMENT src, FPDF_BYTESTRING pagerange, int index)` | Page-range string ("1,3,5-7") |
| `FPDF_ImportPagesByIndex` | `fpdf_ppo.h` | `FPDF_BOOL FPDF_ImportPagesByIndex(FPDF_DOCUMENT dest, FPDF_DOCUMENT src, const int* page_indices, unsigned long length, int index)` | |
| `FPDF_ImportNPagesToOne` | `fpdf_ppo.h` | `FPDF_DOCUMENT FPDF_ImportNPagesToOne(FPDF_DOCUMENT src, float output_width, float output_height, size_t num_pages_on_x, size_t num_pages_on_y)` | N-up imposition |
| `FPDF_CopyViewerPreferences` | `fpdf_ppo.h` | `FPDF_BOOL FPDF_CopyViewerPreferences(FPDF_DOCUMENT dest, FPDF_DOCUMENT src)` | |
| XFA: `FPDF_BStr_Init`/`FPDF_BStr_Set`/`FPDF_BStr_Clear` | `fpdfview.h` | | XFA builds only |

## 3. 0.1.0 Surface Check Against Planned Tier 1/2 R Capabilities

For each planned R-level capability, the exact PDFium symbols that back it.

### MVP / Tier 1

| Planned R-level capability | PDFium symbols |
|---|---|
| Document open from path | `FPDF_LoadDocument` (or `FPDF_LoadCustomDocument` if streaming); `FPDF_CloseDocument`; password handling via the `password` parameter; error code via `FPDF_GetLastError` |
| Document open from raw bytes (R `raw` vector) | `FPDF_LoadMemDocument64` (preferred over `_LoadMemDocument` which takes `int` size) |
| Page count | `FPDF_GetPageCount` |
| Page size (without loading) | `FPDF_GetPageSizeByIndexF` (returns `FS_SIZEF`); page is in PDF user-space points |
| Page load/close | `FPDF_LoadPage`, `FPDF_ClosePage` |
| Page rotation read | `FPDFPage_GetRotation` (0..3) |
| Page object enumeration | `FPDFPage_CountObjects`, `FPDFPage_GetObject` |
| Page object type | `FPDFPageObj_GetType` -> one of `FPDF_PAGEOBJ_TEXT`/`_PATH`/`_IMAGE`/`_SHADING`/`_FORM`/`_UNKNOWN` |
| Object bounds (axis-aligned) | `FPDFPageObj_GetBounds` |
| Path segments + endpoints | `FPDFPath_CountSegments`, `FPDFPath_GetPathSegment`, `FPDFPathSegment_GetType`, `FPDFPathSegment_GetPoint` |
| Path segment close flag | `FPDFPathSegment_GetClose` |
| Stroke color/width (read) | `FPDFPageObj_GetStrokeColor`, `FPDFPageObj_GetStrokeWidth` |
| Fill color (read) | `FPDFPageObj_GetFillColor` |
| Text object font size | `FPDFTextObj_GetFontSize` |

Status: all Tier 1 capabilities are backed by stable public symbols. No
gaps. Note that `FPDF_GetPageWidthF`/`FPDF_GetPageHeightF` (per-page) and
`FPDF_GetPageSizeByIndexF` (without loading) are both available; for the MVP,
using the latter avoids paying the `FPDF_LoadPage` cost just to read dimensions.

### Tier 1 Extensions

| Planned R-level capability | PDFium symbols |
|---|---|
| Bezier control points for path segments | **GAP**: not exposed. `FPDFPathSegment_GetPoint` returns only the segment endpoint. For a `FPDF_SEGMENT_BEZIERTO` segment, the two control points exist in the underlying `CFX_Path::Point` storage but are not exposed in the public C ABI. To recover them, the embedder would need to either (a) parse the page content stream directly (the `c` operator gives `x1 y1 x2 y2 x3 y3`), or (b) consume PDFium internals (not stable). The constructor side (`FPDFPath_BezierTo`) does accept all 6 floats. Recommendation: defer Bezier control points from 0.1.0; document the limitation in `pdf_page_objects()`. |
| Dash patterns | `FPDFPageObj_GetDashCount`, `FPDFPageObj_GetDashArray`, `FPDFPageObj_GetDashPhase` (all marked experimental but present) |
| Line cap | `FPDFPageObj_GetLineCap` -> `FPDF_LINECAP_BUTT`/`_ROUND`/`_PROJECTING_SQUARE` |
| Line join | `FPDFPageObj_GetLineJoin` -> `FPDF_LINEJOIN_MITER`/`_ROUND`/`_BEVEL` |
| Transformation matrix per object | `FPDFPageObj_GetMatrix` -> `FS_MATRIX{a,b,c,d,e,f}` |
| Text content via `FPDFText_LoadPage` | `FPDFText_LoadPage` -> `FPDF_TEXTPAGE`; `FPDFText_CountChars`; `FPDFText_GetText`; `FPDFText_GetUnicode`; per-char `FPDFText_GetCharBox`, `FPDFText_GetCharOrigin`, `FPDFText_GetMatrix`; `FPDFText_ClosePage` |
| Text content per-text-object (avoid building text page) | `FPDFTextObj_GetText` (takes a `FPDF_TEXTPAGE` so still requires one) |
| Font metadata | `FPDFTextObj_GetFont` -> `FPDF_FONT`; `FPDFFont_GetBaseFontName`, `FPDFFont_GetFamilyName`, `FPDFFont_GetIsEmbedded`, `FPDFFont_GetFlags`, `FPDFFont_GetWeight`, `FPDFFont_GetItalicAngle`, `FPDFFont_GetAscent`, `FPDFFont_GetDescent` |
| Text render mode | `FPDFTextObj_GetTextRenderMode` -> `FPDF_TEXTRENDERMODE_FILL`/`_STROKE`/`_FILL_STROKE`/`_INVISIBLE`/`_FILL_CLIP`/`_STROKE_CLIP`/`_FILL_STROKE_CLIP`/`_CLIP` |
| Text fill/stroke color per char | `FPDFText_GetFillColor`, `FPDFText_GetStrokeColor` (experimental) |

Gap summary for Tier 1 extensions: only Bezier control-point readout is
missing. Everything else maps to public symbols.

### Tier 2

| Planned R-level capability | PDFium symbols |
|---|---|
| Image data + metadata | `FPDFImageObj_GetImageMetadata` -> `FPDF_IMAGEOBJ_METADATA` (width/height/dpi/bpp/colorspace); `FPDFImageObj_GetImagePixelSize` (fast path); `FPDFImageObj_GetImageDataDecoded` / `_GetImageDataRaw`; `FPDFImageObj_GetImageFilterCount` / `_GetImageFilter`; `FPDFImageObj_GetIccProfileDataDecoded`; `FPDFImageObj_GetBitmap` (no mask/matrix) and `FPDFImageObj_GetRenderedBitmap` (with mask/matrix) |
| Form XObjects (Tier 2: enumeration of nested objects) | `FPDFFormObj_CountObjects`, `FPDFFormObj_GetObject`. Note: the matrix of the form-object instance itself is on the parent page object (`FPDFPageObj_GetMatrix`). |
| Clipping paths | `FPDFPageObj_GetClipPath`; `FPDFClipPath_CountPaths`, `FPDFClipPath_CountPathSegments`, `FPDFClipPath_GetPathSegment` (segments reuse `FPDF_PATHSEGMENT`) |
| Page rendering | `FPDFBitmap_CreateEx`, `FPDFBitmap_FillRect`, `FPDF_RenderPageBitmap` (or `FPDF_RenderPageBitmapWithMatrix` for arbitrary transforms), `FPDFBitmap_GetBuffer`/`_GetStride`/`_GetWidth`/`_GetHeight`/`_GetFormat`, `FPDFBitmap_Destroy` |
| Document metadata | `FPDF_GetMetaText` (Title/Author/Subject/Keywords/Creator/Producer/CreationDate/ModDate); `FPDF_GetFileVersion`; `FPDF_GetDocPermissions`; `FPDFCatalog_IsTagged`, `FPDFCatalog_GetLanguage`; `FPDF_GetPageLabel`; `FPDF_GetFileIdentifier` |
| Page boxes (Tier 2 if exposed beyond MediaBox) | `FPDFPage_GetMediaBox`/`GetCropBox`/`GetBleedBox`/`GetTrimBox`/`GetArtBox`; `FPDF_GetPageBoundingBox` (intersection of media+crop) |

Status: all Tier 2 capabilities are backed. Form XObject support is complete;
clipping path support is complete; rendering and metadata are complete.

## 4. API-Shape Implications for 0.1.0

The following post-0.1.0 capabilities have day-1 API consequences. Each
implication lists the future capability, the day-1 R API shape decision it
forces, and a recommended choice.

1. **Password-protected PDFs.** PDFium accepts `password` in
   `FPDF_LoadDocument`, `FPDF_LoadMemDocument`/`64`, `FPDF_LoadCustomDocument`,
   and `FPDFAvail_GetDocument`. `NULL` is valid for "no password".
   - Day-1 API decision: does `pdf_open()` accept a `password=` argument?
   - Recommendation: **yes, add `password = NULL` from day 1**. Passing through
     a `NULL` `FPDF_BYTESTRING` is what PDFium expects when no password is
     needed, so the wrapper can implement this cheaply and the absent argument
     is a no-op for unencrypted PDFs. Postponing forces a future
     non-backwards-compatible signature change.

2. **Annotation enumeration / linked-annotation traversal.**
   `FPDFPage_GetAnnotCount`, `FPDFPage_GetAnnot`, `FPDFAnnot_GetLinkedAnnot`,
   `FPDFLink_GetAnnot`, `FPDF_GetPageAAction`, and the form-fill `FORM_*`
   handlers all take a `FPDF_PAGE` *and* require the document to remain alive.
   Some annotation properties additionally require `FPDF_FORMHANDLE` (form-field
   accessors).
   - Day-1 API decision: do `pdfium_page` objects hold a stable handle (external
     pointer) back to their parent `pdfium_document`?
   - Recommendation: **yes**. The R-level `pdfium_page` must retain a strong
     reference to its parent `pdfium_document` (and treat it as a closure
     environment or a slot on the S7/R7 object) so that any future annotation,
     destination, or form-field accessor that needs the document handle works
     without changing the page object's class layout. Failing to do this means
     that future versions need to either (a) change `pdf_load_page()`'s return
     shape, or (b) re-derive the document by storing it in a hidden global
     registry.

3. **Signature verification.**
   `FPDFSignatureObj_GetByteRange` returns the digest-covered ranges and
   `FPDFSignatureObj_GetContents` returns the DER blob, but PDFium does *not*
   verify signatures - cryptographic verification is the embedder's job.
   - Day-1 API decision: how rich should the error/condition system be?
   - Recommendation: **use a hierarchy of error conditions** (e.g.
     `pdfium_error` with subclasses `pdfium_password_error`,
     `pdfium_format_error`, `pdfium_file_error`, `pdfium_security_error`,
     `pdfium_page_error`) mapped from `FPDF_GetLastError` (which has a fixed
     small set: `FPDF_ERR_SUCCESS`/`_UNKNOWN`/`_FILE`/`_FORMAT`/`_PASSWORD`/
     `_SECURITY`/`_PAGE`, plus `_XFALOAD`/`_XFALAYOUT` in XFA builds). When
     signature verification or other higher-level capabilities are added, new
     subclasses can be inserted without disturbing existing
     `tryCatch(..., pdfium_error = ...)` users.

4. **Progressive rendering / large-document support.** PDFium has two parallel
   doc-loading interfaces: `FPDF_LoadDocument` (eager, full file) and
   `FPDFAvail_*` (linearized / progressive). They produce the same
   `FPDF_DOCUMENT` handle but via different code paths, and the progressive
   path requires `FX_FILEAVAIL`/`FX_DOWNLOADHINTS` callbacks plus
   `FPDFAvail_IsDocAvail`/`_IsPageAvail` checks before use.
   - Day-1 API decision: do we expose `pdf_open()` only, or also a
     `pdf_open_stream()` that is willing to deferred-load?
   - Recommendation: **expose only `pdf_open()` in 0.1.0**, but make sure its
     return type is the same `pdfium_document` class that a future
     `pdf_open_stream()` would return. Treat the question of streaming as
     internal: 0.1.0 can use `FPDF_LoadMemDocument64` for raw vectors and
     `FPDF_LoadDocument` for paths. Adding `FPDFAvail_*` later does not require
     any user-visible 0.1.0 changes because the resulting `FPDF_DOCUMENT`
     handle is identical.

5. **Custom random-access file readers.** `FPDF_LoadCustomDocument` takes an
   `FPDF_FILEACCESS` struct with a `m_GetBlock` callback. If we ever want to
   read directly from R `connection` objects (gz-compressed, HTTP, etc.)
   without slurping into memory, we will need this.
   - Day-1 API decision: does `pdf_open()` allow connection objects?
   - Recommendation: **document path/raw-only in 0.1.0**. Adding a
     `pdf_open_connection()` later is additive and non-breaking, so no day-1
     decision is forced beyond keeping the per-document handle abstraction.

6. **Page editing / save.** `FPDF_SaveAsCopy` and `FPDF_SaveWithVersion` both
   take an `FPDF_FILEWRITE` callback rather than a path. Saving inherently
   needs `FPDFPage_GenerateContent()` to be called on every modified page or
   changes are lost.
   - Day-1 API decision: does the `pdfium_document` class need a "dirty"
     marker even though 0.1.0 is read-only?
   - Recommendation: **document the 0.1.0 R API as strictly read-only**. Do not
     expose mutation. When write support is added (post-1.0), introduce a
     parallel `pdf_save()` and a *new* mutable class (e.g. `pdfium_doc_writer`)
     rather than mutating the read-only one. This keeps the read-only API
     immutable-by-construction and frees 0.1.0 from carrying a `$dirty` slot.

7. **Form-field access requires `FPDF_FORMHANDLE`.** Almost every
   `FPDFAnnot_*FormField*` accessor takes `FPDF_FORMHANDLE` as its first
   argument, which is obtained from `FPDFDOC_InitFormFillEnvironment` with a
   filled-in `FPDF_FORMFILLINFO` callback struct. The form environment is
   per-document, not per-page.
   - Day-1 API decision: if/when we add form-field reading, where does the
     `FPDF_FORMHANDLE` live - on the document, or lazily created?
   - Recommendation: **lazy creation on first form-field access, stored as a
     hidden slot on `pdfium_document`**. Day 1 does not need to expose this,
     but the document class should be implemented in a way that permits adding
     a slot later without breaking serialization (e.g., environment-backed or
     R7/S7 with explicit slot list rather than a plain external pointer).

8. **Text extraction requires building a text page first.** `FPDFTextObj_GetText`
   takes a `FPDF_TEXTPAGE` parameter, meaning even the per-object text accessor
   relies on `FPDFText_LoadPage` having been called. The text page must be
   closed with `FPDFText_ClosePage` and is invalidated if any text object is
   removed (see comment on `FPDFPage_RemoveObject`).
   - Day-1 API decision: do we cache the `FPDF_TEXTPAGE` on the page object,
     and how do we handle "remove invalidates text page" semantics?
   - Recommendation: **for 0.1.0, build the text page lazily on first text
     access and cache it on the `pdfium_page`; never expose a public
     "TextPage" object in R**. Because 0.1.0 is read-only, the invalidation
     scenario doesn't occur. Adding write support later may force a "text page
     is cached and may need invalidation" rule, but only at that point.

9. **Bitmap memory ownership.** `FPDFBitmap_CreateEx` accepts an external
   buffer (`first_scan != NULL`). PDFium does *not* free external buffers,
   even when `FPDFBitmap_Destroy` is called.
   - Day-1 API decision: if we ever render directly into an R `raw` or
     `integer` vector for zero-copy output, the destroy path needs to know
     "this is external memory".
   - Recommendation: **for 0.1.0, always let PDFium allocate** (pass `NULL`
     for `first_scan`) and copy out at the end. This avoids tying the R
     vector's lifetime to PDFium's. Once we want zero-copy, we can add an
     opt-in path; the API does not need to change to support that later.

10. **Renderer choice (AGG vs Skia) and font backend (FreeType vs Fontations).**
    These are set in `FPDF_LIBRARY_CONFIG` at `FPDF_InitLibraryWithConfig`
    time and cannot be changed afterward without `FPDF_DestroyLibrary`.
    - Day-1 API decision: do we let users pick at load time, or do we
      hard-code AGG + FreeType?
    - Recommendation: **hard-code AGG + FreeType in 0.1.0**, but call
      `FPDF_InitLibraryWithConfig` (not the deprecated `FPDF_InitLibrary`) so
      that future versions can read e.g. an `options()` setting or an
      environment variable without touching the user-facing API. Skia support
      requires extra build-time dependencies and is not necessary for the
      MVP.

## 5. Tier Reassignment

Based on this survey, **no change is needed** to the Tier 1 / 2 / 3 split in
the project plan. Specifically:

- The MVP set (Tier 1) is fully backed by stable public symbols. The path-
  segment Bezier-control-point gap is real but is a path-rendering nuance,
  not a blocker for the MVP.
- The Tier 1 extension set is fully backed except for Bezier control points,
  which should be marked explicitly as a known limitation in the 0.1.0
  documentation (one sentence: "PDFium's public C API exposes only the
  endpoint of a path segment; cubic-Bezier control points require content-
  stream parsing and are not currently returned.").
- The Tier 2 set is fully backed.

Two minor observations worth surfacing for the implementation phase:

- **Per-character text properties (Tier 1 extension territory).** PDFium
  exposes `FPDFText_GetCharBox`, `FPDFText_GetCharOrigin`, `FPDFText_GetMatrix`,
  `FPDFText_GetCharAngle`, `FPDFText_GetUnicode`, `FPDFText_GetFontSize`,
  `FPDFText_GetFontWeight`, `FPDFText_GetFillColor`, `FPDFText_GetStrokeColor`,
  `FPDFText_GetFontInfo`. The R-level `pdf_text()` (or similar) can return a
  data frame with one row per character. This is richer than what was implicit
  in the original Tier 1 extension list, but does not require a new tier.
- **Form-object enumeration is Tier 2-only because it requires
  `FPDFPageObj_GetMatrix`** (to compose with the inner object's matrix) and
  the user is unlikely to want a full-page-object tree in the MVP. This
  matches the existing tier split.

## Appendix: Symbol Count Tallies

- Total `FPDF_EXPORT` declarations: 471.
- Headers consumed: 22 (all of `public/*.h`).
- C++ helper headers (`public/cpp/*.h`) skipped intentionally per scope.

Source: pdfium repo HEAD as of clone time, `https://pdfium.googlesource.com/pdfium/+/main/public/`.
