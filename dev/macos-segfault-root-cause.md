# macOS arm64 segfault (#44): ROOT CAUSE FOUND

**Status: root-caused by static audit. Fix = bump the vendored PDFium binary.**

This supersedes the open questions in the earlier triage notes
(`macos-segfault-triage.md`, `macos-asan-ci-arch-block.md`, kept on the
`claude/macos-asan-pdfium-vendored` investigation branch). The ASan-CI
arm64/arm64e block documented there is now moot — we did not need a
runtime repro; a source audit of the pinned PDFium found the defect.

## The bug

`core/fxge/cfx_face.cpp`, `CFX_Face::RenderGlyph`, line 538 in our pinned
`chromium/7202` tree (`cf433ae55`):

```cpp
const FXDIB_Format format = anti_alias == FT_RENDER_MODE_MONO
                                ? FXDIB_Format::k1bppMask
                                : FXDIB_Format::k8bppMask;   // 1 byte / pixel
...
int dest_pitch = pGlyphBitmap->GetBitmap()->GetPitch();      // ~= width (1 B/px)
uint8_t* pDestBuf = pGlyphBitmap->GetBitmap()->GetWritableBuffer().data();
UNSAFE_TODO({
  if (anti_alias != FT_RENDER_MODE_MONO &&
      bitmap.pixel_mode == FT_PIXEL_MODE_MONO) {
    unsigned int bytes = anti_alias == FT_RENDER_MODE_LCD ? 3 : 1;   // <-- 3
    for (unsigned int i = 0; i < bitmap.rows; i++) {
      for (unsigned int n = 0; n < bitmap.width; n++) {
        uint8_t data = (pSrcBuf[i*bitmap.pitch + n/8] & (0x80 >> (n%8))) ? 255 : 0;
        for (unsigned int b = 0; b < bytes; b++) {
          pDestBuf[i * dest_pitch + n * bytes + b] = data;            // <-- OOB write
        }
      }
    }
  }
  ...
});
```

When a glyph is rendered in **LCD subpixel mode** but FreeType returns a
**monochrome** bitmap (`FT_PIXEL_MODE_MONO`, which happens for embedded
bitmap strikes / bitmap-only fonts), the destination glyph buffer is
allocated as `k8bppMask` = **1 byte per pixel** (`dest_pitch ≈ width`),
but the loop writes **3 bytes per pixel**. Each row writes `~3 × width`
bytes into a `~width`-byte row, overrunning the heap allocation by
roughly `2–3 × width` bytes per glyph. **Heap-buffer-overflow (write).**

## Why it reaches us (default `pdf_render_page`)

`cpp_render_page` (`src/render.cpp`) creates a 32-bpp ARGB bitmap
(`FPDFBitmap_Create(w, h, alpha=1)`) and calls `FPDF_RenderPageBitmap`.
PDFium's text AA selection (`core/fxge/cfx_renderdevice.cpp:1093-1134`)
picks `FT_RENDER_MODE_LCD` whenever:

* text is smooth (default; we do **not** set `FPDF_RENDER_NO_SMOOTHTEXT`),
* device is `kDisplay` (default; we do **not** set `FPDF_PRINTING`),
* `bpp_ > 1` and `bpp_ >= 16` (ours is 32), and
* FreeType supports hinting (`>= 2.8.1`; true on every modern build).

So **LCD mode is auto-selected** — `FPDF_LCD_TEXT` is *not* required
(rpdfium never sets it; it's an unused placeholder in
`R/render.R:.pdfium_render_flags`). The buggy branch additionally needs
a glyph that comes back `FT_PIXEL_MODE_MONO`, i.e. a font with a
monochrome bitmap strike.

## Why macOS-only, and why the crash bytes are a path

* The trigger needs a *mono-bitmap-strike* glyph under LCD. Which font
  supplies a given glyph depends on font **substitution**, which draws
  from the platform's enumerated fonts. On macOS those are
  `~/Library/Fonts` (= `/Users/runner/Library/Fonts` on the CI runner),
  `/Library/Fonts`, `/System/Library/Fonts`
  (`core/fxge/apple/fx_apple_platform.cpp:162-164`). Some macOS fonts
  carry bitmap strikes; the Linux substitute corpus for the same PDFs
  does not, so the mono-under-LCD branch is not entered on Linux.
* The faulting address `0x656e6e75722f7372` = ASCII **"rs/runne"** =
  offset 4 of `/Users/runner/`. `CFX_FolderFontInfo` allocates a
  `FontFaceInfo` per scanned font, each holding its
  `/Users/runner/Library/Fonts/...` path as a heap `ByteString`. The
  glyph overflow scribbles the adjacent heap where those path strings
  live; the resulting corrupted pointer/heap metadata surfaces later as
  a wild dereference whose bytes are the path string. R's
  `CEntryTable` traversal in the next `R_GetCCallable` is simply the
  first code to trip over the corrupted memory — which is why the crash
  *backtrace* shows `cpp_struct_tree_page` even though the *write*
  happened earlier during a render/text test. (This is why the
  struct-tree-only reprex passes but the full test_check crashes.)
* On Linux we only ran ASan over **our** code + R; the prebuilt PDFium
  was never ASan-instrumented, so even if it overran, ASan could not
  see it and the Linux heap layout did not fault.

Confidence: the OOB write, its presence in our exact pinned version, its
reachability from the default render path, and the upstream fix are all
**verified in source**. The precise heap-cascade that turns the overflow
into the "rs/runne" faulting address is inferred (heap corruption →
unpredictable wild deref is textbook); the byte pattern itself is not
the write's payload (the write stores 0/255), it's resident path data in
the trampled neighbourhood.

## The crbug.com/376633555 red herring

`cfx_folderfontinfo.cpp:451` has a `pdfium::Alias` + `char buf[256]`
block tagged `crbug.com/376633555`. That is **diagnostic instrumentation
for an unrelated `fread` hang**, the copy into `buf` is correctly bounded
(`std::min(len, 256)` into a 256-byte buffer), and upstream **reverted**
it (`db3687db7`, 2025-10-30) as no-longer-needed with no functional
change. It is not the write and not a fix.

## Upstream fix

`ee83ca8ef7b8804ef7ed735b200a1e27c5285bac` — "Avoid mismatch between
k8bppMask and 3 byte constant." (Tom Sepez, **Bug: 488585504**,
2026-03-02). Drops the `bytes` multiplier and writes 1 byte/pixel:

```diff
-    unsigned int bytes = anti_alias == FontAntiAliasingMode::kLcd ? 3 : 1;
     for (unsigned int i = 0; i < ft_bitmap.rows; i++) {
       for (unsigned int n = 0; n < ft_bitmap.width; n++) {
-        uint8_t data = (src_span[n / 8] & (0x80 >> (n % 8))) ? 255 : 0;
-        for (unsigned int b = 0; b < bytes; b++) {
-          dest_span[n * bytes + b] = data;
-        }
+        dest_span[n] = (src_span[n / 8] & (0x80 >> (n % 8))) ? 255 : 0;
       }
```

Verified absent from our checkpoint
(`git merge-base --is-ancestor ee83ca8ef cf433ae55` → false; buggy line
present at `cfx_face.cpp:538`). Backported to M138-LTS (`6b490ca22`) and
M146 (`bccc616f8`) — i.e. upstream treats it as a memory-safety fix.

## The fix for rpdfium

Bump the pinned binary past `ee83ca8ef`.

* Current: `tools/pdfium-version.txt` = `chromium/7202`.
* First bblanchon release after the fix: `chromium/7713`
  (PDFium 147.0.7713.0, published 2026-03-04).
* Latest at time of audit: `chromium/7857` (PDFium 150.0.7857.0,
  2026-05-25) — recommended target (gets the fix plus ~3 months of other
  fixes).

Per `CLAUDE.md`, a `tools/pdfium-version.txt` change must also update
`NEWS.md` and re-run the conformance suite, and preserve CRAN-cleanliness.

### Confirming the diagnosis (optional, recommended before/after the bump)

The arm64/arm64e DYLD block that defeated ASan-in-R does **not** apply to
a standalone reprex: a single arm64 test binary that links the
ASan-instrumented `libpdfium.dylib` directly has no arm64e child to
trip over. So on an Apple-Silicon Mac:

1. Build a tiny C program that `FPDF_RenderPageBitmap`s a page to a
   32-bpp ARGB bitmap, using a PDF whose text falls back to a macOS
   system font with a bitmap strike.
2. Link the ASan `libpdfium.dylib` already built at
   `inst/pdfium-binaries/pdfium-mac-arm64.tgz`.
3. ASan should report a heap-buffer-overflow write at
   `cfx_face.cpp` `RenderGlyph`.

Or, fully on Linux CI: build ASan-instrumented PDFium for linux via the
`billdenney/pdfium-binaries` fork and run the same render reprex (LCD is
selected on Linux too); choose a font with a mono bitmap strike.
