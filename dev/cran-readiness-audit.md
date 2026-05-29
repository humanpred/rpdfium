# CRAN-readiness audit — v0.1.0

Holistic pre-submission audit of the consolidated release branch: does
`R CMD check --as-cran` pass, are there any unfilled PDFium API gaps, and
is the package CRAN-policy clean?

## Provenance

- Audit date: 2026-05-29.
- Branch audited: `claude/v0.1.0-complete-pdfium-api` at the merge commit
  that integrates `origin/main` + the chromium/7857 API-audit work +
  the pypdfium2-parity / coverage work (real merge, full history).
- PDFium pin: `chromium/7857` (`tools/pdfium-version.txt`).
- Gate: `rcmdcheck::rcmdcheck(args = c("--as-cran", "--no-manual"))`
  (R 4.6, Linux x86-64). Source tarball built with `pkgbuild::build()`
  and inspected. Symbol coverage recomputed from the 7857 public headers.

## Verdict

**Essentially CRAN-ready.** `R CMD check --as-cran` is **0 errors,
1 warning, 2 notes**, and every warning/note is either environmental or a
small, well-understood fix. **There are no unfilled in-scope PDFium API
gaps** — every unwrapped public symbol is a documented by-design exclusion
or a documented post-0.1.0 deferral. Three concrete items should be
addressed before submission (one is a hard blocker); the rest are
non-issues or quality polish.

## Pre-submission action list (prioritised)

| # | Action | Severity | Evidence |
|---|---|---|---|
| 1 | Set `DESCRIPTION` `Version: 0.1.0` | **Blocker** | DESCRIPTION says `0.0.9000`; NEWS.md and cran-comments.md both say `0.1.0`. `--as-cran` NOTE: "Version contains large components (0.0.9000)". |
| 2 | Fix the 3 self-referential 404 URLs in `vignettes/comparison.Rmd` | Should-fix (NOTE) | `--as-cran` flags 3 `https://humanpred.github.io/rpdfium/reference/*.html` links as 404. The man pages exist; the URLs 404 because the pkgdown site isn't deployed for this version yet. |
| 3 | Add `\examples` to the 5 newest exports lacking them | Quality | `pdf_bitmap_from_page`, `pdf_bitmap_to_page`, `pdf_drain_unsupported_features`, `pdf_image_extract`, `pdf_text_obj_at_char` have no `\examples`; the rest of the surface does. Not a check failure. |
| 4 | (Optional) install `checkbashisms` locally | None | Clears the only WARNING locally; the scripts are already POSIX-clean (verified by hand). |

Items deliberately **not** actionable: the `-mno-omit-leaf-frame-pointer`
NOTE (injected by this machine's R `Makeconf`, not the package), and the
"New submission" NOTE (expected for a first submission).

---

## A. `R CMD check --as-cran` — 0E / 1W / 2N

### WARNING — `checking top-level files`: needs `checkbashisms`
Local tooling only: `checkbashisms` isn't installed on this machine, so
`--as-cran` can't verify the shell scripts are POSIX `sh`. Manually
audited `configure`, `configure.win`, `cleanup`, `cleanup.win`: all use
`#!/usr/bin/env sh` and contain none of the common bashisms (`[[ ]]`,
`==`, arrays, `local`, `source`, `+=`, `<<<`, `$(( ))`, `function name()`).
CRAN's builders have `checkbashisms` and will run it; with clean scripts
this warning will not appear there. **No package defect.**

### NOTE 1 — `checking CRAN incoming feasibility`
- *New submission* — expected; informational.
- ***"Version contains large components (0.0.9000)"*** — the DESCRIPTION
  `Version` field is still the development sentinel `0.0.9000`, while
  `NEWS.md` (`# pdfium 0.1.0`) and `cran-comments.md`
  (`# pdfium 0.1.0 — first CRAN submission`) declare `0.1.0`. **Set
  `Version: 0.1.0` before submission.** (Action #1.)
- *Invalid URLs (404)* — `inst/doc/comparison.html` links to
  `…/reference/pdf_font_load.html`, `…/pdf_font_load_standard.html`,
  `…/pdf_image_new.html`. All three man pages **exist**
  (`man/pdf_font_load*.Rd`, `man/pdf_image_new.Rd`); the URLs 404 only
  because the pkgdown site at that path isn't published for this version
  yet. Fix by deploying pkgdown before submission, or by changing the
  hard-coded absolute links in `vignettes/comparison.Rmd:139-141` to
  pkgdown auto-links / relative refs so they don't depend on a live site.
  (Action #2.)

### NOTE 2 — `checking compilation flags`: `-mno-omit-leaf-frame-pointer`
Non-portable, but **injected by this machine's R build configuration**
(`/usr/lib/R/etc/Makeconf` adds `-fno-omit-frame-pointer
-mno-omit-leaf-frame-pointer` to `CFLAGS`/`CXXFLAGS`), **not** by the
package. `configure` writes only
`PKG_CPPFLAGS = -I$PDFIUM_INCLUDE -DR_NO_REMAP` and no architecture flags.
Won't appear on CRAN's reference platforms. **No package defect.**

### No installed-size NOTE — source tarball is clean
`pkgbuild::build()` produces a **504 KB** source tarball that contains
**no** `inst/lib/libpdfium.so` (7.7 MB) and **no** `inst/include/` headers
— `configure` downloads them at build/install time (ADR-008; the `arrow`
precedent for configure-time downloads). The platform binary in the
working tree is a development artifact and is correctly absent from the
built source package. Verified, not assumed.

---

## B. PDFium 7857 API coverage — no in-scope gaps

Recomputed from the 7857 public headers (token cross-reference against
`src/*.cpp`, the methodology of `dev/v0.1.0-api-gap-audit.md`):

- **465** exported public functions in 7857.
- **79** not wrapped — every one accounted for:

| Bucket | Count | Disposition |
|---|---:|---|
| `FORM_*` interactive form-fill events | 31 | By design (form-fill via `FPDFAnnot_*`/`FPDFDOC_*`, not the event API) — gap-audit §5 |
| XFA (`FPDF_LoadXFA`, `FPDF_GetXFAPacket*`, `FPDF_BStr_*`) | 7 | By design — not in the bblanchon build — §1 |
| dataavail / progressive load (`FPDFAvail_*`) | 8 | By design — §2 |
| Progressive render (`FPDF_RenderPage*_Start/Continue/Close`) | 5 | By design — §3 |
| Skia render (`FPDF_*Skia`) | 2 | By design — §4 |
| Form-fill UI highlight (`FPDF_*FormFieldHighlight*`, `FPDF_FFLDraw`) | 4 | By design — §5 |
| V8 / JS (`FPDF_GetRecommendedV8Flags`, `…SandBoxPolicy`, …) | 3 | By design — §6 |
| Annot meta-validation (`FPDFAnnot_Is*SupportedSubtype`) | 2 | By design — §7 |
| Print mode (`FPDF_SetPrintMode`) | 1 | By design — §8 |
| Alt entry points (non-`F` page-size getters, `FPDF_InitLibrary`, `FPDF_LoadMemDocument`, `FPDF_LoadCustomDocument`, `FPDFImageObj_LoadJpegFile`, `FPDFBitmap_CreateEx`, `FPDFPageObj_TransformF`, `FPDFImageObj_SetMatrix`) | ~10 | By design — we wrap the newer/wider variant — §9 |
| `FSDK_SetLocaltimeFunction` / `FSDK_SetTimeFunction` | 2 | Out of scope — embedder time-injection hooks for deterministic timestamps |
| **7857 deferrals** (`FPDFPageObjMark_GetParamFloatValue`/`SetFloatParam`, `FPDFPage_InsertObjectAtIndex`, `FPDFText_SetPositions`) | 4 | Documented in `dev/pdfium-7857-api-delta.md` — need an ADR or Tier-3; not required for 0.1.0 |

**No undocumented in-scope symbol is missing.** The only "could wrap"
candidates are the 4 deferrals, each already analysed and consciously
postponed. Coverage is complete for the package's stated scope.

> Minor doc-hygiene note: `FSDK_SetLocaltimeFunction` /
> `FSDK_SetTimeFunction` aren't itemised in
> `dev/v0.1.0-api-gap-audit.md`'s exclusion list. Worth a one-line
> addition there so a future audit doesn't re-flag them.

## C. Documentation completeness

Every export has a man page (roxygen-generated; `R CMD check` reports no
undocumented arguments / usage). **Gap:** 5 of the 7 newest
(pypdfium2-parity) exports ship without a runnable `\examples` block —
`pdf_bitmap_from_page`, `pdf_bitmap_to_page`,
`pdf_drain_unsupported_features`, `pdf_image_extract`,
`pdf_text_obj_at_char`. The rest of the ~285-function surface carries
examples, so this is a consistency/quality gap, not a check failure.
Recommend adding short `\dontrun`-or-runnable examples (Action #3).

## D. Scope & naming

- **Scope:** the 7 new exports each wrap a real PDFium symbol
  (`FPDF_RenderPageBitmap` + `FPDFBitmap_*` for the bitmap↔page
  converters; the `FSDK`/`FPDF` unsupported-feature handler for
  `pdf_install_unsupported_handler` / `pdf_drain_unsupported_features`;
  `FPDFImageObj_*` for `pdf_image_extract` / `pdf_image_new_from_bitmap`).
  None are base-R glue. No scope violations.
- **Naming (ADR-019):** all 285 exports are object-first accessors or
  verb-first actions; the 7 new ones conform (`pdf_image_extract`,
  `pdf_text_obj_at_char`, `pdf_image_new_from_bitmap`,
  `pdf_bitmap_from_page`/`_to_page`, `pdf_install_*`/`pdf_drain_*`).

## E. Tests

`R CMD check` ran the full (merged) test suite with **0 errors**, so the
integrated branch's tests pass. Coverage remains CI-enforced (codecov
100% R-line gate; C++ tracked best-effort, not gated — see `codecov.yml`).

## F. Reproducer

```sh
R="LD_LIBRARY_PATH=$PWD/inst/lib Rscript -e"
# Gate
$R 'rcmdcheck::rcmdcheck(args=c("--as-cran","--no-manual"), error_on="never")'
# Clean-tarball check
$R 'pkgbuild::build(".", binary=FALSE, vignettes=FALSE)'   # then: tar tzf … | grep inst/lib
# Coverage recount
grep -rhoE "\b(FPDF[A-Za-z_0-9]+|FORM_[A-Za-z_0-9]+|FSDK_[A-Za-z_0-9]+)\b" src/*.cpp | sort -u
```
