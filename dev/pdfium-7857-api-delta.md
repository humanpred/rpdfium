# PDFium API delta — `chromium/7202` → `chromium/7857`

Triggered audit of the `pdfium` R package against the freshly-pinned
PDFium binary. The pin moved from `chromium/7202` to `chromium/7857`
(PR #46, merged commit `f521500`) — roughly a year of upstream change.
This document is the evidence base for what that bump changed in
PDFium's public C API and what, if anything, the package must do about
it.

## Provenance

- **Audit date:** 2026-05-29.
- **Old pin:** `chromium/7202` (PDFium tagged release; was in
  `tools/pdfium-version.txt` before PR #46).
- **New pin:** `chromium/7857` (current `tools/pdfium-version.txt`).
- **Header sources diffed** (both verified against the package's own
  copies before trusting the diff):
  - new = `pdfium-linux-x64.tgz` from
    `bblanchon/pdfium-binaries` release `chromium/7857` →
    `include/` — byte-identical to `inst/include/fpdf*.h` on this
    branch (e.g. `FPDFCatalog_SetLanguage` carries the `FPDF_WIDESTRING`
    signature).
  - old = same tarball for `chromium/7202` → `include/` —
    byte-identical to `/home/bill/src/pdfium-7202/public/`.
- **Method:** extract every `FPDF_EXPORT … FPDF_CALLCONV <name>(…)`
  prototype from all `fpdf*.h` (incl. `fpdfview.h`) in each header set,
  whitespace-normalise the signature, and take the three-way set diff
  (ADDED / REMOVED / SIGNATURE-CHANGED). Constants and enums diffed by
  comparing `#define`s and enum-member identifiers/values. Cross-checked
  against the symbols the package actually calls
  (`grep -rhoE 'FPDF[A-Za-z_0-9]*\(' src/*.cpp`, 375 distinct) and its
  277 `NAMESPACE` exports. The exact reproducer is in the appendix.
- **Build sanity check:** on this branch (which contains the bump),
  `find src -name '*.o' -delete` then
  `LD_LIBRARY_PATH=inst/lib Rscript -e 'devtools::load_all(".")'`
  compiles all 47 translation units and links `pdfium.so` clean
  (`-Wall -pedantic`, exit 0). A symbol the package calls cannot have
  been removed, or this would not link — see §"Removed symbols".

## TL;DR

- **0 symbols removed.** The bump cannot break the build on symbol
  grounds, and the clean compile confirms it.
- **6 symbols added** (all `// Experimental API.` in upstream). None are
  *required* for 0.1.0; one (`FPDFCatalog_GetLanguage`) is a strong
  should-have because it completes an accessor pair we already ship half
  of. The rest are Tier-2/Tier-3 completeness.
- **2 genuinely semantic signature/behaviour changes** beyond the one
  already fixed:
  1. `FPDFCatalog_SetLanguage` `FPDF_BYTESTRING → FPDF_WIDESTRING` —
     **already fixed** in `src/mutation.cpp` during the bump; verified
     correct here.
  2. `FPDFPage_InsertObject` return type `void → FPDF_BOOL` — was called
     at 6 sites that ignored the new success/failure return. **Fixed in
     this PR**: each site now checks it (destroy-on-failure for the
     creators, raise for the standalone insert).
- **Save-flag values changed** (`FPDF_REMOVE_SECURITY 3 → 4`,
  new `FPDF_SUBSET_NEW_FONTS = 8`). `R/save.R` *already* uses `4`/`8`,
  so it is **correct under the new pin** — but it was inconsistent with
  the *old* pin, meaning `remove_security=`/`subset_new_fonts=` were
  silently ineffective before this bump. **A stricter value-pinning test
  is folded into this PR** (the prior test only checked "flag accepted").
- **`pdf_doc_language()` and a tagged-tree `expansion` column added**
  this PR, wrapping the two new in-scope readers
  (`FPDFCatalog_GetLanguage`, `FPDF_StructElement_GetExpansion`).
- **No deprecated symbol needs removal:** the package already avoids
  every soft-deprecated PDFium API (uses the `*F` page-size getters,
  `FPDF_InitLibraryWithConfig`, the richer marked-content-ID accessors).
  See Bucket 2(c).
- **`FPDF_LIBRARY_CONFIG` grew a v5 field** (`m_FontLibraryType`).
  `src/init.cpp` is **safe** (zero-init + `version = 2`). No action.

---

## A. Symbol diff

### Added in 7857 (6)

All six are marked `// Experimental API.` in the headers except
`FPDFPage_InsertObjectAtIndex`, which is stable.

| # | Symbol | Header:line (7857) | Signature |
|---|---|---|---|
| 1 | `FPDFCatalog_GetLanguage` | `fpdf_catalog.h:46` | `unsigned long FPDFCatalog_GetLanguage(FPDF_DOCUMENT document, FPDF_WCHAR* buffer, unsigned long buflen)` |
| 2 | `FPDFPage_InsertObjectAtIndex` | `fpdf_edit.h:209` | `FPDF_BOOL FPDFPage_InsertObjectAtIndex(FPDF_PAGE page, FPDF_PAGEOBJECT page_object, size_t index)` |
| 3 | `FPDFPageObjMark_GetParamFloatValue` | `fpdf_edit.h:568` | `FPDF_BOOL FPDFPageObjMark_GetParamFloatValue(FPDF_PAGEOBJECTMARK mark, FPDF_BYTESTRING key, float* out_value)` |
| 4 | `FPDFPageObjMark_SetFloatParam` | `fpdf_edit.h:648` | `FPDF_BOOL FPDFPageObjMark_SetFloatParam(FPDF_DOCUMENT document, FPDF_PAGEOBJECT page_object, FPDF_PAGEOBJECTMARK mark, FPDF_BYTESTRING key, float value)` |
| 5 | `FPDF_StructElement_GetExpansion` | `fpdf_structtree.h:123` | `unsigned long FPDF_StructElement_GetExpansion(FPDF_STRUCTELEMENT struct_element, void* buffer, unsigned long buflen)` |
| 6 | `FPDFText_SetPositions` | `fpdf_edit.h:1354` | `FPDF_BOOL FPDFText_SetPositions(FPDF_PAGEOBJECT text_object, const float* positions, size_t count)` |

What each does (from the header doc comments):

1. **`FPDFCatalog_GetLanguage`** — reads the catalog `/Lang` entry into a
   buffer as UTF-16LE (sizing call when `buffer` is `NULL`). The read
   counterpart to `FPDFCatalog_SetLanguage`, which we already wrap.
2. **`FPDFPage_InsertObjectAtIndex`** — inserts a page object at a given
   z-order `index` (append when `index == count`). The positional
   sibling of `FPDFPage_InsertObject`, which only appends.
3. **`FPDFPageObjMark_GetParamFloatValue`** — reads a numeric
   content-mark param as `float` (for params where
   `FPDFPageObjMark_GetParamValueType()` is `FPDF_OBJECT_NUMBER`).
4. **`FPDFPageObjMark_SetFloatParam`** — sets/creates a `float`-valued
   content-mark param. Completes the param type matrix alongside the
   int/string/blob setters already wrapped (`cpp_obj_mark_set_int_param`,
   `cpp_obj_mark_set_string_param`, `cpp_obj_mark_set_blob`).
5. **`FPDF_StructElement_GetExpansion`** — reads the `/E` expansion text
   (the expanded form of an abbreviation/acronym) for a tagged-PDF
   structure element, UTF-16LE. One more accessor in a family of ~18 we
   already wrap (`GetActualText`, `GetAltText`, `GetTitle`, `GetLang`, …).
6. **`FPDFText_SetPositions`** — sets explicit per-glyph positions on a
   text page-object (advanced text authoring). For an N-char object,
   `count` must be `N-1`.

### Removed in 7857 (0)

**None.** `comm -13` of the two symbol sets is empty, and the package
links clean against the 7857 `libpdfium.so`, which it could not do if a
called symbol had been dropped. No deprecation attributes were added to
any symbol the package calls, either.

### Signature-changed (6 — 2 semantic, 4 cosmetic)

| Symbol | Header (7857) | Old (7202) | New (7857) | Class |
|---|---|---|---|---|
| `FPDFCatalog_SetLanguage` | `fpdf_catalog.h:59` | `…, FPDF_BYTESTRING language` | `…, FPDF_WIDESTRING language` | **SEMANTIC** (encoding) |
| `FPDFPage_InsertObject` | `fpdf_edit.h:193` | `void …` | `FPDF_BOOL …` | **SEMANTIC** (return) |
| `FPDF_SaveWithVersion` | `fpdf_save.h:84` | `…, int fileVersion` | `…, int file_version` | cosmetic (param name) |
| `FPDF_SaveAsCopy` | `fpdf_save.h` | `…, FPDF_FILEWRITE* pFileWrite, …` | `…, FPDF_FILEWRITE* file_write, …` | cosmetic (param name) |
| `FPDF_SetSystemFontInfo` | `fpdf_sysfontinfo.h:289` | `… FPDF_SYSFONTINFO* pFontInfo` | `… FPDF_SYSFONTINFO* font_info` | cosmetic (param name) |
| `FPDF_FreeDefaultSystemFontInfo` | `fpdf_sysfontinfo.h:316` | `… FPDF_SYSFONTINFO* pFontInfo` | `… FPDF_SYSFONTINFO* font_info` | cosmetic (param name) |

The four cosmetic changes are PDFium renaming parameters to snake_case
in the header. Parameter names are not part of the C ABI and the package
calls all of these positionally, so they are non-events — recorded only
so a future audit doesn't re-flag them. The two semantic changes are
analysed in §C.

### Constants, enums, structs

| Change | Where (7857) | Detail |
|---|---|---|
| Save flags became a real bitmask | `fpdf_save.h:46-54` | `FPDF_INCREMENTAL` `1→(1<<0)=1`, `FPDF_NO_INCREMENTAL` `2→(1<<1)=2` (values unchanged), **`FPDF_REMOVE_SECURITY` `3 → (1<<2)=4`** |
| New deprecated alias | `fpdf_save.h:50` | `FPDF_REMOVE_SECURITY_DEPRECATED 3` — the *old* `REMOVE_SECURITY` value, kept for back-compat; upstream TODO `crbug.com/42270430` to remove |
| New save flag | `fpdf_save.h:54` | `FPDF_SUBSET_NEW_FONTS (1<<3) = 8` — subset newly-embedded fonts |
| New enum | `fpdfview.h:243-247` | `FPDF_FONT_BACKEND_TYPE { FPDF_FONTBACKENDTYPE_FREETYPE=0, FPDF_FONTBACKENDTYPE_FONTATIONS=1 }` |
| New struct field (v5) | `fpdfview.h:298` | `FPDF_LIBRARY_CONFIG.m_FontLibraryType` (only read when `version >= 5` and renderer is Skia) |

No enum values elsewhere changed; no typedefs removed; no `#define`s
removed. Impact in §C.

---

## B. What the package calls (cross-reference)

- The package issues **375 distinct `FPDF*` calls** across 47
  `src/*.cpp` files. Every one resolves to a symbol present in 7857
  (consistent with 0 removed + clean link).
- It calls **zero `FORM_*` / `FSDK_*`** symbols. Interactive form-fill
  is done through `FPDFDOC_InitFormFillEnvironment` /
  `FPDFDOC_ExitFormFillEnvironment` + `FPDFAnnot_*` field accessors, not
  the `FORM_On*` event surface. This matches the deliberate exclusion in
  `dev/v0.1.0-api-gap-audit.md` §5; the bump does not change it.
- The 6 added symbols are **not yet wrapped** (verified by grep). Their
  sibling families *are* heavily wrapped, so each is a small, in-scope
  increment rather than a new subsystem.

---

## C. The three buckets

### Bucket 1 — New symbols that *should* be wrapped

Scope judged strictly against CLAUDE.md "Scope — wrap PDFium, don't
invent helpers" and the Tier 1/2/3 split. All six wrap a single PDFium
symbol and read/set an attribute of an existing object, so none are
"glue over base R". Priority is about release urgency, not scope.

| Symbol | `pdf_*` surface (ADR-019) | Rationale | Status |
|---|---|---|---|
| `FPDFCatalog_GetLanguage` | `pdf_doc_language(doc)` (reader; pairs with `pdf_doc_set_language()`) | We shipped the **setter with no getter** — an asymmetry users hit. New 7857 symbol, in scope, trivial UTF-16LE read identical to other string accessors. | **DONE this PR** (`cpp_catalog_get_language` in `src/mutation.cpp`; `pdf_doc_language()` in `R/mutation.R`) |
| `FPDF_StructElement_GetExpansion` | new `expansion` column in `pdf_structure_tree()` (the API surfaces struct elements as tibble rows, not per-element accessors — so a column, not `pdf_struct_element_expansion()` as first proposed) | One more tagged-PDF attribute in a family of ~18 already surfaced; near-zero marginal cost, mirrors `read_struct_string`. | **DONE this PR** (`src/struct_tree.cpp`, `R/struct_tree.R`) |
| `FPDFPageObjMark_GetParamFloatValue` + `FPDFPageObjMark_SetFloatParam` | extend `pdf_obj_marks()` decode + add `pdf_obj_mark_set_float()` | Completes the int/string/blob param matrix. **Deferred:** PDFium's `GetParamValueType` returns `FPDF_OBJECT_NUMBER` for *both* int and float with no discriminator (`src/obj_marks.cpp:83`), so a coherent reader+setter needs an int-vs-float representation decision (ADR-level) — adding only the setter would let you write a float you read back truncated. | Deferred (Tier-2; needs ADR) |
| `FPDFPage_InsertObjectAtIndex` | index arg on creators, or `pdf_page_insert_object(page, obj, index)` | Adds z-order control; today the package only appends. **Deferred:** there is no user-facing standalone-insert entry point today (creators auto-append), so exposing index-insert needs an ADR on how it composes with them. | Deferred (Tier-2/3; needs ADR) |
| `FPDFText_SetPositions` | `pdf_text_obj_set_positions()` | Manual per-glyph positioning on authored text objects — niche even within text authoring; constrained API (`count == N-1`). | Deferred (Tier-3) |

> **Implemented in this PR:** the should-have (`pdf_doc_language()`) and
> the cheap, consistent `expansion` column. The three deferred rows each
> need an ADR or are Tier-3 niche; deferring them respects the CLAUDE.md
> ADR process rather than rushing an authoring/representation API into a
> currency PR. They remain easy follow-ups.

### Bucket 2 — Deprecated / removed

- **(a) PDFium-removed symbols the package wraps:** **none.** (0 removed;
  clean link.)
- **Deprecated constant:** `FPDF_REMOVE_SECURITY_DEPRECATED = 3`
  (`fpdf_save.h:50`) — this is the *former* value of
  `FPDF_REMOVE_SECURITY`, retained only for back-compat with an upstream
  TODO to delete it. The package does **not** use `3`; `R/save.R` uses
  the new `4`. Action: none beyond "never reintroduce the literal `3`".
- **(b) `pdf_*` R functions to prune before 0.1.0:** none surfaced by
  this bump. `dev/v0.1.0-api-gap-audit.md` (2026-05-22) concluded the
  surface is by-design complete after the `pdf_dir_summary` /
  `pdf_doc_open_url` retraction (the deletion-justification precedent in
  `NEWS.md`). I re-scanned the exports for new scope violations
  introduced since and found none. No prune recommended.
- **(c) Deprecated PDFium symbols the package wraps — none actionable.**
  Scanning the 7857 headers for `deprecat` and cross-referencing the 375
  `FPDF*` call sites: the package already avoids every soft-deprecated
  symbol.
  - `FPDF_GetPageWidth` / `FPDF_GetPageHeight` / `FPDF_GetPageSizeByIndex`
    (`fpdfview.h:732/758/804`, "Prefer the `*F` variant … will be
    deprecated") — the package calls the `*F` variants, **not** these.
  - `FPDF_InitLibrary` (`fpdfview.h:323`, "New code should call
    `FPDF_InitLibraryWithConfig`") — the package uses
    `FPDF_InitLibraryWithConfig` (`src/init.cpp:41`).
  - `FPDF_StructElement_GetMarkedContentID` (`fpdf_structtree.h:202`,
    "may be deprecated in the future") — the package already also wraps
    the richer `…GetMarkedContentIdAtIndex` / `…GetMarkedContentIdCount`
    successors.
  - **One forward-looking note (not deprecated yet):**
    `src/image_authoring.cpp:104` calls `FPDFImageObj_SetMatrix`, which
    upstream marks "TODO(thestig): Start deprecating once
    `FPDFPageObj_SetMatrix()` is stable" (`fpdf_edit.h:750`). It is fully
    supported in 7857; `FPDFPageObj_SetMatrix` (already used at
    `src/obj_setters.cpp:66`) is the eventual replacement. Optional
    future-proofing — nothing to remove today.

### Bucket 3 — Other currency changes (semantics / flags / behaviour)

**C-1. `FPDFCatalog_SetLanguage` `FPDF_BYTESTRING → FPDF_WIDESTRING` —
FIXED, verified.**
`src/mutation.cpp:154-164` takes the R-side UTF-8 string
(`R/mutation.R:269` passes `enc2utf8(lang)`), transcodes via
`pdfium_r::utf8_to_utf16le_nul()`, and passes
`reinterpret_cast<FPDF_WIDESTRING>(lang16.data())`. Correct and
NUL-terminated. The bump also added a byte-pinning regression test
(`tests/testthat/test-mut-structural.R`, commit `0240d8b`). No action.
- *Nit (FIXED this PR):* the stale comment at `R/mutation.R` ("…accepts
  any UTF-8 string") was reworded to describe the actual UTF-8→UTF-16LE
  transcode the C++ shim performs.

**C-2. `FPDFPage_InsertObject` `void → FPDF_BOOL` — FIXED this PR.**
The package called it at 6 sites, all discarding the return
(`src/obj_creators.cpp` ×3, `src/font_authoring.cpp`,
`src/image_authoring.cpp`, `src/api_completion.cpp`). Under 7857 the
function reports success/failure; ignoring it was no worse than the prior
`void` behaviour (not a regression) but dropped a real signal. Now each
site checks the return: the five create-then-insert sites
`FPDFPageObj_Destroy` the object (ownership did not transfer on failure)
and `Rcpp::stop`; the standalone `cpp_page_insert_object` raises without
destroying (the object stays owned by the caller's handle). These guards
are defensively unreachable for an append, so they carry `// # nocov`.

**C-3. Save-flag bitmask change — already correct under 7857, but
previously latent-wrong; needs a stricter test.**
`R/save.R:20-24` defines:
```r
.pdfium_save_flags <- c(incremental = 1L, no_incremental = 2L,
                        remove_security = 4L, subset_new_fonts = 8L)
```
These are the **7857** values. They were introduced in commit `41f348e`
(*"writer foundation"*) while the package was still pinned to **7202**,
where `FPDF_REMOVE_SECURITY` was `3` and `FPDF_SUBSET_NEW_FONTS` did not
exist. Consequence:
- Under 7202, `remove_security = TRUE` passed `4`; PDFium tested
  `flags & 3`, and `4 & 3 == 0`, so **security was never stripped**.
  `subset_new_fonts = TRUE` passed `8`, an undefined flag → **no-op**.
- Under 7857 (now), `4` *is* `FPDF_REMOVE_SECURITY` and `8` *is*
  `FPDF_SUBSET_NEW_FONTS`. **Both flags now work as documented.**

So the bump silently fixed a latent flag bug. The existing test
`tests/testthat/test-mut-save.R:107` ("honours
incremental/remove_security/version flags") only asserts the flag is
*accepted without error* (its own comment at `:116` says
"no encrypted fixture to verify") — it would pass with `3`, `4`, or `8`
alike and never caught the 7202 no-op. **Recommended follow-up
(`future-save-flags-tests` branch):** a behavioural test that pins the
effect — e.g. open an encrypted fixture, `pdf_save(remove_security =
TRUE)`, and assert the output has no `/Encrypt`; and/or assert the exact
integer `encode_save_flags()` produces (`remove_security` → `4`,
`subset_new_fonts` → `8`).

**C-4. `FPDF_LIBRARY_CONFIG.m_FontLibraryType` (new v5 field) — safe, no
action.**
`src/init.cpp:36-40` does `FPDF_LIBRARY_CONFIG cfg = {};` (zero-initialises
*all* fields, including the new one) and sets `cfg.version = 2`. PDFium
reads `m_FontLibraryType` only when `version >= 5` **and** the renderer
is Skia. With `version = 2` it is never read. Confirmed safe.

**C-5. `FPDF_FONT_BACKEND_TYPE` enum — irrelevant to our binary.**
Only meaningful for Skia-backed builds selecting FreeType vs. Fontations.
The pinned bblanchon binary is not Skia. No action.

**C-6. Cosmetic parameter renames (4 functions) — no action.** ABI-irrelevant; all call sites are positional (`src/save.cpp:94,96,117,119`; `src/api_completion.cpp:1045`).

---

## D. Build sanity check (deliverable D)

```
$ find src -name '*.o' -delete
$ LD_LIBRARY_PATH="$(pwd)/inst/lib" Rscript -e 'devtools::load_all(".")'
… 47 translation units compiled with -Wall -pedantic …
x86_64-linux-gnu-g++ … -o pdfium.so  (link)
* DONE (pdfium)            # exit 0, no warnings
```
Clean. This is the ground truth that reconciles "0 removed": every
`FPDF*` symbol the package references exists and links in the 7857
`libpdfium.so`.

---

## E. Prioritised recommendations

| # | Action | Priority | Status |
|---|---|---|---|
| 1 | Wrap `FPDFCatalog_GetLanguage` as `pdf_doc_language()` (completes the set/get pair) | **Should-have for 0.1.0** | **DONE this PR** |
| 2 | `FPDF_StructElement_GetExpansion` → `expansion` column | Tier-2 (cheap completeness) | **DONE this PR** |
| 3 | Check `FPDFPage_InsertObject` return | Medium (robustness) | **DONE this PR** (6 sites + `// # nocov`) |
| 4 | Refresh stale `R/mutation.R` set-language comment | Low (doc nit) | **DONE this PR** |
| 5 | Stricter `remove_security` / `subset_new_fonts` value test | High (locks in the now-correct flags; the smoke test can't) | **DONE this PR** (`test-save-flags-strict.R`) |
| 6 | Float content-mark params (`Get/SetParamFloat*`) | Tier-2 | Deferred — needs int-vs-float representation ADR (Bucket 1) |
| 7 | `FPDFPage_InsertObjectAtIndex` | Tier-2/3 | Deferred — needs standalone-insert entry-point ADR |
| 8 | `FPDFText_SetPositions` | Tier-3 | Deferred — niche text authoring |

This PR (the audit follow-up) ships the report, the provenance refreshes,
the four implemented items (#1–#4), and folds in the value test (#5). The
three deferred items each need an ADR or are Tier-3 niche; they are not
required for 0.1.0 and are left as clean follow-ups. No symbol the package
calls was removed, so there was no build-breaking change to fix.

---

## F. Appendix — reproducer

```sh
# 1. fetch both header sets
mkdir -p /tmp/pa/new /tmp/pa/old && cd /tmp/pa
base=https://github.com/bblanchon/pdfium-binaries/releases/download/chromium
curl -sL $base/7857/pdfium-linux-x64.tgz | tar xz -C new include
curl -sL $base/7202/pdfium-linux-x64.tgz | tar xz -C old include

# 2. extract FPDF_EXPORT prototypes -> "<name>\t<header>\t<sig>"
#    (python extractor: strip comments, capture FPDF_EXPORT…; , take
#     return type before FPDF_CALLCONV and balanced (...) after the name,
#     whitespace-normalise). See dev/ history for extract.py.
python3 extract.py new/include | sort -t$'\t' -k1,1 > new.syms
python3 extract.py old/include | sort -t$'\t' -k1,1 > old.syms

# 3. three-way diff  (join MUST be field-1-sorted, not whole-line —
#    a whole-line sort hides return-type-only changes like InsertObject)
comm -23 <(cut -f1 new.syms|sort -u) <(cut -f1 old.syms|sort -u)   # ADDED
comm -13 <(cut -f1 new.syms|sort -u) <(cut -f1 old.syms|sort -u)   # REMOVED
join -t$'\t' -j1 old.syms new.syms | awk -F'\t' '$3!=$5'          # SIG-CHANGED

# 4. what the package calls
grep -rhoE 'FPDF[A-Za-z_0-9]*\(' "$RPDFIUM"/src/*.cpp | sort -u

# 5. build sanity
cd "$RPDFIUM" && find src -name '*.o' -delete && \
  LD_LIBRARY_PATH="$PWD/inst/lib" Rscript -e 'devtools::load_all(".")'
```
