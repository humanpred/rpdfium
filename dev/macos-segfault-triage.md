# macOS arm64 segfault triage — `plot(bmp)` + lazy `grid` load

**Status:** Investigation in progress. No macOS arm64 hardware available
locally; conclusions below are from code reading + Linux differential
testing. Final root-cause confirmation requires `lldb` on actual hardware.

**Symptom (from PR #43 CI):**

```
*** caught segfault ***
address 0x656c696620686375, cause 'invalid permissions'
1: dyn.load(file, DLLpath = DLLpath, ...)
2: library.dynam(lib, package, package.lib)
3: loadNamespace(x)
4: plot.pdfium_bitmap(bmp)
5: plot(bmp)
```

The fault address `0x656c696620686375`, read little-endian (Apple Silicon),
is the byte sequence `75 63 68 20 66 69 6c 65` = ASCII **`"uch file"`** —
the tail of "no such file or directory" or similar diagnostic string. A
function-pointer slot that should hold an executable address is holding
ASCII text. That's memory corruption, not a logical bug in `grid` or
`dyn.load`. The failing test (`test-render.R::"plot(bmp) draws into a PDF
device without erroring"`) is just the first one in the file to touch
`grid::*`; the corruption happens earlier and only surfaces when R tries
to call through the trampled slot.

## 1. What reproduced (and what didn't)

### Linux, full failing test sequence — **does not crash**

The exact test body from `tests/testthat/test-render.R:400-415`:

```r
library(pdfium)
fixture <- system.file("extdata", "fixtures", "shapes.pdf", package = "pdfium")
doc <- pdf_doc_open(fixture)
bmp <- pdf_render_page(doc, dpi = 72)

out <- tempfile(fileext = ".pdf")
grDevices::pdf(out, width = 5, height = 4)
plot(bmp)                  # first plot
grDevices::dev.off()

grDevices::pdf(out, width = 5, height = 4)
plot(bmp, interpolate = FALSE)   # crash site on macOS arm64
grDevices::dev.off()
```

Linux x86_64 (R 4.x release on a glibc system), `LD_LIBRARY_PATH=inst/lib`:
first plot OK, second plot OK, both PDFs are 7484/7504 bytes. The same
goes for `MALLOC_CHECK_=3 MALLOC_PERTURB_=42` (glibc heap audit) and a
full `testthat::test_file("tests/testthat/test-render.R")` run — 108
PASS, no SKIP, no crash.

### Linux ASan/UBSan — also clean

PR #43 runs ASan/UBSan on Ubuntu; the failing test passes there too.
That tells us:

- The corruption is **not** in memory ASan instruments (i.e. not in any
  R-side malloc or any `Rcpp::*` allocation), or
- The corruption is in PDFium's own heap (PDFium is not ASan-built in
  bblanchon's binaries), or
- The corruption is in macOS-arm64-specific code that has no Linux
  equivalent (Skia renderer, Mach allocator, dyld lazy binding).

### What this rules out

- A naive OOB write inside `cpp_render_page` — `out_ptr[y + x*pixel_height]`
  is in-bounds (max index = `height*width − 1`), and the index-arith
  uses `size_t` so no signed overflow. Same shape and identical
  guarantees as `bitmap_to_native_raster` in `src/images.cpp` and the
  thumbnail renderer in `src/tier3_extras.cpp`.
- A UTF-16 conversion overflow in `src/utf16.h` — the diff vs `main`
  on this PR is comment-only; the byte protocol (`buf(needed/2)`,
  passing `needed` bytes, deriving `wchars` from `needed/2 − 1`) is
  the same pattern used since v0.0.1.
- A C++-exception escape across the C ABI — every `Rcpp::stop` callsite
  inspected (more than 60) translates to `Rcpp::exception` which Rcpp
  catches and re-raises as `Rf_error`. No call site builds a giant
  format string from untrusted input that could blow a fixed-size
  buffer.
- A finalizer-vs-render race on the bitmap's `render_geometry`
  attribute (which now pins the parent doc): tested by holding the
  bitmap past `pdf_doc_close()` on Linux. The doc finalizer runs and
  clears the `externalptr`; subsequent calls return the documented
  "Parent document has been closed" error, not a crash.

## 2. Minimal reprex (what to run on macOS arm64)

This is the smallest sequence that reproduced the crash in CI. The order
of cuts below is what someone with macOS arm64 hardware should walk
through — each successful crash narrows the suspect surface.

```r
# A. Full crash path (known to crash on macOS arm64; passes on Linux):
library(pdfium)
fixture <- system.file("extdata", "fixtures", "shapes.pdf", package = "pdfium")
doc <- pdf_doc_open(fixture)
bmp <- pdf_render_page(doc, dpi = 72)
out <- tempfile(fileext = ".pdf")
grDevices::pdf(out, width = 5, height = 4); plot(bmp);                    grDevices::dev.off()
grDevices::pdf(out, width = 5, height = 4); plot(bmp, interpolate = FALSE); grDevices::dev.off()
# If A crashes, try the cuts below in order:

# B. Single plot (drops the second `pdf()` + `plot()`):
library(pdfium)
fixture <- system.file("extdata", "fixtures", "shapes.pdf", package = "pdfium")
doc <- pdf_doc_open(fixture)
bmp <- pdf_render_page(doc, dpi = 72)
out <- tempfile(fileext = ".pdf")
grDevices::pdf(out, width = 5, height = 4); plot(bmp); grDevices::dev.off()

# C. No render, no plot — just package load + grid lazy load:
library(pdfium)
grid::grid.newpage()

# D. No grid — does the render-only path crash?
library(pdfium)
fixture <- system.file("extdata", "fixtures", "shapes.pdf", package = "pdfium")
doc <- pdf_doc_open(fixture)
bmp <- pdf_render_page(doc, dpi = 72)
str(as.array(bmp))
pdf_doc_close(doc)
```

**Interpretation guide:**

- If **B crashes**, the corruption happens before the second `pdf()` —
  i.e. during the first `plot()` itself. That makes the suspect surface
  the bitmap → array conversion path or `grid::grid.raster()` on macOS.
- If **B passes but A crashes**, the corruption is induced by something
  during `dev.off()` + reopening `pdf()` — possibly PDFium's internal
  per-thread state across `grDevices::pdf` device cycling.
- If **C crashes**, PDFium's init (`FPDF_InitLibraryWithConfig` in
  `cpp_init_library()`) is corrupting state before any render call.
- If **C passes but B crashes**, the corruption is in
  `pdf_render_page()` / `cpp_render_page` / Skia render path on macOS.
- If **D passes**, `as.array(bmp)` and `as.raster(bmp)` are clean; the
  trigger is on the `grid` / device side.

We strongly suspect **C** will pass and **D** will pass and **A** /
**B** will crash, because the cross-platform companion test added at
`test-render.R:418` does exactly what D does and passes on all CI
targets.

## 3. Code-reading audit — what's in scope as a culprit

This is the C++ code reachable from the failing test, by priority. Each
sub-bullet says what we checked and the conclusion.

1. **`src/render.cpp` `cpp_render_page`** — bitmap → `IntegerMatrix`.
   *Checked:* indexing math, `size_t` casts, stride bounds (the
   PDFium BGRA bitmap is `pixel_width * 4` bytes per row, stride from
   `FPDFBitmap_GetStride` is `>= pixel_width * 4`, so `row[x*4+3]` is
   in-bounds). *Conclusion:* clean. The diff against `main` for this
   file is comment-only.

2. **`src/init.cpp` `cpp_init_library`** — calls
   `FPDF_InitLibraryWithConfig` with `cfg.version = 2`, all other
   fields zero. *Checked:* `FPDF_LIBRARY_CONFIG` layout in
   `inst/include/fpdfview.h:241-277`. Version 2 contract reads
   only the first four fields; `m_pPlatform` and `m_RendererType`
   (version 3 + 4) are not read on a version-2 declaration.
   *Correction (after reading bblanchon build):* bblanchon's
   `mac-arm64` build sets **no** `pdf_use_skia` flag in
   `steps/05-configure.sh`, so chromium/7202 falls back to the
   default renderer (AGG) — same as the Linux build. The renderer
   is not the difference between platforms.

3. **`src/utf16.h`** — UTF-16LE ↔ UTF-8 conversion. *Checked:*
   surrogate-pair handling reads `buf[i+1]` only when `i + 1 < n`;
   `push_back` auto-grows so `out.reserve(n)` underestimate is safe;
   embedded NULs are skipped. *Conclusion:* clean. Diff is
   comment-only.

4. **`src/render.R` `pdf_render_page`'s render-geometry stash** (new
   on this PR) stores the parent `doc` and `page_num` in
   `attr(data, "render_geometry")`. This means the bitmap pins the
   parent doc externalptr alive. If `pdf_doc_close(doc)` runs while
   the bitmap is live, the externalptr's address is cleared but the
   externalptr SEXP stays reachable. *Checked:* the `pdf_bitmap_*`
   converters guard with `is_open(rg$doc)`. The failing test never
   calls them; `as.array(bmp)` and the `plot.pdfium_bitmap` body
   don't touch `render_geometry`. *Conclusion:* clean.

5. **`src/api_completion.cpp` `ScopedFormHandle`** — confirmed
   already-fixed in commit 7a7ca78 (Form-Fill-Info struct must be a
   member, not a constructor-local). *Checked:* every other
   `FPDFDOC_InitFormFillEnvironment` call site (`src/form_fields.cpp`,
   `src/annot_probes.cpp`, `src/name_lookups.cpp`, `src/annotations.cpp`,
   `src/form_field_handles.cpp`, `src/annot_handles.cpp`) declares
   `FPDF_FORMFILLINFO ffi{}` in the same function scope as Init/Exit.
   *Conclusion:* the failing test doesn't touch any of these paths
   (no form, no annot probes).

6. **Rcpp format-string surface** — every `Rcpp::stop(...)` /
   `Rcpp::warning(...)` callsite uses tinyformat with fixed format
   specifiers and bounded arguments (`int`, `size_t`, `std::string`).
   No untrusted-length printf-style construction. *Conclusion:* not a
   credible source.

## 4. Likely cause

### 4.1 What the bblanchon mac-arm64 binary actually contains

Cloned `bblanchon/pdfium-binaries` to `~/src/pdfium-binaries` and the
PDFium source at the matching tag to `~/src/pdfium-7202` (worktree off
`origin/chromium/7202`, commit `cf433ae55`). Findings from
`steps/05-configure.sh`:

| Build flag                     | Value on mac-arm64       | Same on linux? |
|--------------------------------|---------------------------|----------------|
| `is_debug`                     | `false`                  | yes            |
| `pdf_is_standalone`            | `true`                   | yes            |
| `pdf_use_partition_alloc`      | `false` (system malloc)  | yes            |
| `pdf_enable_v8`                | `false`                  | yes            |
| `pdf_enable_xfa`               | `false`                  | yes            |
| `pdf_use_skia`                 | unset → AGG default      | yes            |
| `is_component_build`           | `false`                  | yes            |
| `clang_use_chrome_plugins`     | `false`                  | yes            |

The only mac-specific patch is `patches/mac/build.patch`, which adds
`-Wl,-headerpad_max_install_names` to the linker driver. **No source-
level differences between the mac-arm64 and linux-x64 PDFium binaries
besides target CPU + OS + system libs.**

That eliminates Skia, V8, XFA, PartitionAlloc, and component-build as
suspects. What's left:

- **Apple Silicon `libsystem_malloc` (the nano zone)** packs ≤256-byte
  objects much more densely than glibc's `malloc`. A 16-byte write
  past the end of a PDFium-owned string can clobber a neighbouring
  allocation that on Linux is two cache lines further out.
- **AArch64 hardware control-flow integrity.** Apple Silicon enforces
  `BTI` (Branch Target Identification) and PAC (Pointer Auth Codes)
  in user space. A function-pointer slot loaded with ASCII bytes
  fails the BTI landing-pad check and faults with the exact
  "cause 'invalid permissions'" wording seen in the trace.
- **Different signal-handling paths.** glibc's malloc detects double-
  frees and aborts cleanly; libsystem_malloc detects fewer corruption
  classes and lets the process limp on until the corrupted slot is
  used.

### 4.2 Mechanism

The strongest hypothesis is **a write inside PDFium's own heap on the
macOS arm64 build that Apple Silicon's `libsystem_malloc` places
adjacent to R's process-global namespace dispatch state**:

- R's `R_osDynSymbol` is a singleton struct of 8 function pointers
  (`include/Rdynpriv.h:143-163`) set up once at R startup. `dyn.load`
  calls through `R_osDynSymbol->dlsym(info, "R_init_grid")` and then
  calls the returned pointer at `Rdynload.c:906` (`f(info)`).
- If *any* of those nine slots (8 in `R_osDynSymbol` + the
  `R_init_grid` value returned from dlsym) gets overwritten with
  ASCII bytes, the crash will look exactly like the trace —
  "address `0x656c696620686375`" at `dyn.load`.
- A buffer in PDFium's heap holding the string "...no such file or
  directory" is the only obvious source of those specific bytes.
  PDFium loads font files, color profiles, and v8 snapshots at
  init; on macOS arm64 it links against CoreText and CoreGraphics
  which routinely produce "no such file" errors when probing the
  font cache.

Why Linux doesn't hit it:

- glibc's allocator places PDFium's heap segments and R's BSS far
  apart; an overflow inside PDFium's arena reaches at most other
  PDFium pages, which we never call through.
- Apple Silicon's libmalloc uses tcache-style nano-zone allocations
  that pack 16-byte objects much more densely. A 16-byte write past
  the end of a PDFium-owned string can land on R's globals when
  Linux's tcache would have left guard space.

This hypothesis is unproven without lldb on hardware; alternatives
worth investigating:

- **macOS-arm64-specific PDFium bug.** PR #43 ships a meaningful
  amount of new code that exercises PDFium surfaces (signatures,
  bookmarks, struct-tree, form-fields-per-handle) that older
  rpdfium versions didn't touch. Some of those code paths read
  font tables and ICC profiles; bblanchon's `mac-arm64` Skia
  build hasn't seen the same fuzzing coverage as the Linux build.
- **Skia renderer init.** The `m_RendererType` field is left at
  zero by `cpp_init_library`. If PDFium's macOS-arm64 build reads
  the field eagerly (ignoring `version=2`) and a stale FPDF_LIBRARY_CONFIG
  zeroing bug exists, init could be left in a half-initialised
  state. Easy to test: explicitly set `cfg.m_RendererType = 1`
  (Skia) and rebuild — does the macOS crash move or vanish?

## 5. Debugging within the bblanchon mac-arm64 binary

**Local setup (Linux dev machine):**

- `~/src/pdfium-binaries/` — clone of `bblanchon/pdfium-binaries` at
  HEAD. Read `steps/05-configure.sh` for the exact gn args fed to
  every platform; `patches/mac/build.patch` for the only mac-specific
  source change.
- `~/src/pdfium-7202/` — git worktree of `~/src/pdfium` pinned at
  `origin/chromium/7202` (commit `cf433ae55`, "Avoid a case of
  float-int-float conversion in CPDF_Page"). This is the exact PDFium
  source that compiled into the bundled `libpdfium.dylib`. Read code
  here when symbolicating an lldb backtrace.

**On the macOS arm64 machine, runnable without rebuilding PDFium:**

These all use the existing bblanchon binary (no PDFium recompile).
Each one is a single `R` invocation; together they should localise
the bug within an hour of triage.

### 5a. Allocator-density toggles (the cheapest tests)

Apple's libsystem_malloc honours env vars at process start. Use them
to confirm or rule out the "nano-zone adjacency" hypothesis from §4.

```sh
# Disable the nano zone — small allocations go to the larger,
# more-spaced-out scalable zone. If the crash vanishes here, the
# bug is a small-allocation OOB write that's only fatal under
# tight packing.
MallocNanoZone=0 \
  Rscript -e 'devtools::test(filter = "render")'

# Add guard pages around every allocation. Catches almost any
# OOB write (one-page slowdown per allocation, only for triage).
MallocGuardEdges=1 \
MallocScribble=1 \
MallocPreScribble=1 \
  Rscript -e 'devtools::test(filter = "render")'

# Full stack-logged trace of every malloc/free for postmortem.
# Combined with `malloc_history <pid> <addr>` after the crash.
MallocStackLoggingNoCompact=1 \
  Rscript -e 'devtools::test(filter = "render")'

# Strict mode: abort on first detected corruption + full backtrace.
MallocErrorAbort=1 \
MallocCorruptionAbort=1 \
  Rscript -e 'devtools::test(filter = "render")'
```

The first three are equivalent to glibc's `MALLOC_PERTURB_` /
`MALLOC_CHECK_=3`; they catch what those catch but with macOS's
allocator semantics.

### 5b. lldb attach + watchpoint on the corrupted slot

Once 5a tells you whether the bug is allocator-sensitive, point lldb
at the actual slot that gets clobbered. R's namespace dispatch is at
a known symbol:

```sh
# Find the address of Rf_osDynSymbol in the running R session.
# (Run interactively so the process stays alive.)
R --no-save
> # leave R idle, in another terminal:
lldb -p $(pgrep -n R)
(lldb) image lookup -s Rf_osDynSymbol
# This prints the address of the OSDynSymbol struct (8 function
# pointers, 64 bytes total) in R's BSS.

# Set a hardware watchpoint on the first slot.
(lldb) watchpoint set expression -w write -- 'Rf_osDynSymbol'
(lldb) continue

# Now in R, run the failing test:
> devtools::test(filter = "render")

# When the watchpoint fires, lldb prints the writer's full
# backtrace. That's the offending caller.
(lldb) bt
```

If `Rf_osDynSymbol` doesn't get written, try the other candidates
the trace implicates: the value returned from `dlsym` in
`Rdynload.c::AddDLL:897` (the `f` local just before `f(info)` at
line 906), or the bytecode dispatch table.

### 5c. ASan-instrumented PDFium build

If 5a + 5b implicate PDFium code rather than rpdfium code, recompile
PDFium with AddressSanitizer using bblanchon's harness:

```sh
cd ~/src/pdfium-binaries

# bblanchon build.sh accepts -d (debug) but not -a (ASan).
# Edit steps/05-configure.sh and add to the args.gn output:
#   echo "is_asan = true"
#   echo "is_debug = true"
#   echo "symbol_level = 2"

# Then run:
./build.sh -d mac arm64
# Output appears under pdfium/out/; copy libpdfium.dylib +
# headers into rpdfium's inst/lib + inst/include, rebuild rpdfium,
# and rerun the failing test. ASan will flag the OOB write at
# its source.
```

ASan-instrumented binaries are ~3-4x slower and need
`DYLD_INSERT_LIBRARIES=$(clang -print-resource-dir)/lib/darwin/libclang_rt.asan_osx_dynamic.dylib`
on the R invocation to load the ASan runtime against R. The
`MallocScribble` route (5a) is much cheaper and catches the same
class of bug for the simplest cases — try that first.

### 5d. Bisect against the renderer fallback

The fallback gn flag `pdf_use_skia = true` would force the Skia
renderer instead of AGG. If the crash is in AGG-on-mac-arm64 code
(unlikely but possible — AGG is a legacy renderer), Skia might
sidestep it:

```sh
cd ~/src/pdfium-binaries
# Add to steps/05-configure.sh:
#   echo "pdf_use_skia = true"
./build.sh mac arm64
```

This is a build experiment, not a production fix; AGG-vs-Skia
output isn't pixel-identical. Use only as a triage signal.

## 6. Concrete next steps (require macOS arm64 hardware)

In rough order of payoff vs. cost:

1. **Run the reprex cuts in §2 (A through D) and report which fail.**
   Each yes/no answer eliminates a third of the suspect surface.
2. **Re-run with `R_DEBUG_TASKCALLBACKS=1` and `R_GCTORTURE=1`** to
   exercise GC at every allocation. If the crash moves to a different
   line, the corruption is GC-finalizer-sensitive.
3. **lldb + watchpoint.** Attach lldb, set a watchpoint on the byte
   address that gets read at crash time (`R_osDynSymbol`'s
   `loadLibrary` slot is at a known offset from the symbol
   `Rf_osDynSymbol` — `nm /usr/local/lib/R/bin/exec/R | grep
   osDynSymbol` gives the address). The watchpoint will fire when
   PDFium (or whoever) writes the ASCII bytes; the backtrace at
   that moment names the source.
4. **Build with PDFium debug symbols.** The bblanchon
   `pdfium-mac-arm64-debug.tgz` variant has DWARF; swap that into
   `inst/lib/libpdfium.dylib` before running the reprex so frames
   inside PDFium are symbolicated.
5. **Try `FPDF_RENDERERTYPE_SKIA`.** Add `cfg.version = 3;
   cfg.m_pPlatform = nullptr; cfg.m_RendererType = FPDF_RENDERERTYPE_SKIA;`
   in `cpp_init_library` and rebuild. If the crash disappears,
   the renderer-init path on macOS arm64 is the culprit.
6. **Differential: bisect against earlier rpdfium release.** Check
   out the v0.0.x tag, run the reprex; if it doesn't crash, bisect
   to find the commit on this PR that introduced the corruption.
   This is the slowest path but the most decisive.

## 7. Draft bug-report bodies

### 7a. rpdfium issue (Issue #44, expanding the placeholder)

```markdown
**Title:** macOS arm64 segfault during lazy `grid` load after PDFium ops

**Affected:** R 4.6.0 on `macos-latest`, GitHub Actions arm64 runner.
Linux release/devel/oldrel-1 and ASan/UBSan all pass.

**Reproducer:** `tests/testthat/test-render.R:376`. Minimal:

```r
library(pdfium)
fixture <- system.file("extdata", "fixtures", "shapes.pdf", package = "pdfium")
doc <- pdf_doc_open(fixture)
bmp <- pdf_render_page(doc, dpi = 72)
out <- tempfile(fileext = ".pdf")
grDevices::pdf(out, width = 5, height = 4); plot(bmp);                     grDevices::dev.off()
grDevices::pdf(out, width = 5, height = 4); plot(bmp, interpolate = FALSE); grDevices::dev.off()
```

**Trace:**

```
*** caught segfault ***
address 0x656c696620686375, cause 'invalid permissions'
1: dyn.load(file, DLLpath = DLLpath, ...)
2: library.dynam(lib, package, package.lib)
3: loadNamespace(x)
4: plot.pdfium_bitmap(bmp)
5: plot(bmp)
```

The fault address decodes to ASCII "uch file" — fragment of "no such
file or directory" or similar. A function-pointer slot is holding
string bytes; this is memory corruption surfacing where R lazy-loads
the `grid` namespace's DLL.

**What we checked (in dev/macos-segfault-triage.md):**

- `cpp_render_page` indexing math: in-bounds.
- `utf16.h`: byte-count protocol correct, surrogate handling safe.
- `cpp_init_library` config: `version = 2`, zero-init for v3/v4 fields.
- Rcpp::stop format strings: bounded args, no untrusted printf.
- ScopedFormHandle (commit 7a7ca78): already correct.

**What we suspect:** a write inside PDFium's own heap on the
`pdfium-mac-arm64` (bblanchon) Skia build. PDFium isn't ASan-built;
Apple Silicon's allocator packs small objects more densely than
glibc, so an OOB write that's invisible on Linux can clobber R's
process globals on macOS arm64.

**To progress:** triage on macOS arm64 hardware with lldb + watchpoint
on `Rf_osDynSymbol` — see triage doc for the full plan.

**Workaround:** test skipped via `skip_on_os("mac")` in commit 6075f8e.
Companion `pdf_render_page() output survives common downstream ops` test
exercises the same C++ surface without `grid` so a regression that
manifests on Linux will still be caught.
```

### 7b. PDFium upstream (Google Groups / Monorail), if PDFium is the smoking gun

```markdown
**Title:** macOS arm64 build: heap write near init clobbers
process-adjacent memory (R embedder)

**PDFium build:** chromium/7202, bblanchon `pdfium-mac-arm64` Skia
distribution.

**Symptom:** an R embedder (rpdfium, packaging PDFium via the binary
release) sees R's `R_osDynSymbol` struct overwritten with ASCII string
bytes after a sequence of `FPDF_LoadDocument` +
`FPDF_RenderPageBitmap` calls on Apple Silicon. Same code on
`pdfium-linux-x64` and `pdfium-linux-arm64` is clean. Crash signature
is "address `0x656c696620686375`, cause invalid permissions" — the
address decoded as ASCII is "uch file", the tail of a "no such file"
diagnostic.

**What we'd love:** any known macOS-arm64-specific OOB write in the
font-loading path (CoreText probing) or Skia renderer init in
chromium/7202.

**Repro requires:** R 4.6.0 on Apple Silicon + rpdfium PR humanpred/rpdfium#43.
See https://github.com/humanpred/rpdfium/blob/main/dev/macos-segfault-triage.md.
```

Defer 6b until 6a's lldb session identifies a PDFium frame as the
writer. If the writer is in rpdfium's own C++, fix in rpdfium and
don't report upstream.

## 8. Proposed fix

There is no rpdfium-side fix to propose until §5 narrows down the
writer. The current `skip_on_os("mac")` in `test-render.R:398` is the
right workaround: it unblocks CI without hiding a Linux regression
(the cross-platform companion test at line 418 still exercises the
underlying C++ render path).

If §5 step 5 (explicit `FPDF_RENDERERTYPE_SKIA`) makes the crash
vanish, the fix is:

```diff
--- a/src/init.cpp
+++ b/src/init.cpp
@@ -33,9 +33,12 @@ void cpp_init_library() {
   if (g_library_initialised) return;
   FPDF_LIBRARY_CONFIG cfg = {};
-  cfg.version = 2;
+  cfg.version = 4;
   cfg.m_pUserFontPaths = nullptr;
   cfg.m_pIsolate = nullptr;
   cfg.m_v8EmbedderSlot = 0;
+  cfg.m_pPlatform = nullptr;
+  // bblanchon mac-arm64 ships a Skia-only build; AGG (0) requests a
+  // renderer the binary does not link against.
+  cfg.m_RendererType = FPDF_RENDERERTYPE_SKIA;
   FPDF_InitLibraryWithConfig(&cfg);
   g_library_initialised = true;
 }
```

Hold this change until the macOS lldb session confirms the renderer
init is the culprit — declaring `version = 4` makes us responsible
for honoring the version-3 + version-4 ABI on every platform, and
the Linux/Windows builds may not need it.
