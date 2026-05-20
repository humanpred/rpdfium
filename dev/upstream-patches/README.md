# Upstream PDFium patches

Patches we maintain against upstream
[PDFium](https://pdfium.googlesource.com/pdfium) and intend to submit
through the project's contribution process. Each entry here has a
companion ADR in `dev/decisions/` that records the motivation and
the upstream status.

## Why these aren't pushed automatically

PDFium uses Gerrit at <https://pdfium-review.googlesource.com> for
code review, not GitHub PRs. A Gerrit upload via `git cl upload`
attributes the change to whichever Google account is signed in via
the local cookie store; **only the human contributor can do that
step**. The patches here are staged for someone with a signed
[Google CLA](https://cla.developers.google.com/) to upload from
their own machine.

## Active patches

### `pdfium-FPDFAnnot_AppendOption.patch`

**Status:** Drafted on 2026-05-20 against upstream HEAD
`e30fc3988`. Not yet uploaded to Gerrit; awaiting a human contributor
to run `git cl upload --bypass-hooks` per the walk-through below.

Adds two public symbols:

```c
FPDF_EXPORT int FPDF_CALLCONV
FPDFAnnot_AppendOption(FPDF_FORMHANDLE hHandle,
                       FPDF_ANNOTATION annot,
                       FPDF_WIDESTRING label);

FPDF_EXPORT FPDF_BOOL FPDF_CALLCONV
FPDFAnnot_RemoveOptions(FPDF_FORMHANDLE hHandle,
                        FPDF_ANNOTATION annot);
```

so embedders can write the `/Opt` array on listbox / combobox /
checkbox / radio widget annotations. The reader half
(`FPDFAnnot_GetOptionCount`, `FPDFAnnot_GetOptionLabel`,
`FPDFAnnot_IsOptionSelected`) already exists; this patch is the
symmetric writer.

The append-one + clear-all shape mirrors the existing
`FPDFAnnot_AddInkStroke` + `FPDFAnnot_RemoveInkList` pair — the same
established pattern PDFium uses for array-valued widget data —
rather than introducing a single-shot `FPDFAnnot_SetOptions` that
would require a double-pointer-of-`FPDF_WIDESTRING` ABI.

The implementation copies an inherited `/Opt` array down onto the
terminal field's own dictionary on first append, so writes to a
non-root child of an `/Opt`-bearing parent field don't silently
mutate every sibling that shares the parent.

Why this matters for `pdfium` (R): without it, `pdf_form_field_set_value()`
on combobox / listbox fields is constrained to values that already
appear in the field's `/Opt` array — there's no public API to *grow*
that array at fill time. Many real-world workflows want to populate
options from a database when the form is filled, not when it's
designed.

Files touched (against upstream HEAD `e30fc3988`):

* `public/fpdf_annot.h` — declarations with full doc comments,
  inserted between the existing `FPDFAnnot_IsOptionSelected`
  declaration and the start of the font/color block.
* `fpdfsdk/fpdf_annot.cpp` — implementations next to
  `FPDFAnnot_IsOptionSelected`. Both validate `HasOptField()` to
  produce the same error contract as the readers (return -1 / false
  for text fields, signatures, ink annots, etc.).
* `core/fpdfdoc/cpdf_formfield.{h,cpp}` — new core methods
  `CPDF_FormField::AppendOption()` and
  `CPDF_FormField::RemoveOptions()`, `CHECK()`-ed on `HasOptField()`
  like the existing readers.
* `fpdfsdk/fpdf_view_c_api_test.c` — alphabetized `CHK()` entries
  for both new symbols so api_check.py passes presubmit.
* `fpdfsdk/fpdf_annot_embeddertest.cpp` — six new
  `FPDFAnnotEmbedderTest` cases:
  - `AppendOptionCombobox` — appends + round-trips a UTF-16 label;
    second append goes to index 4.
  - `AppendOptionInvalidArgs` — NULL form / annot / label.
  - `AppendOptionWrongAnnotationType` — textfield rejected.
  - `RemoveOptionsCombobox` — removes /Opt, verifies count → -1,
    re-appends to a fresh /Opt.
  - `RemoveOptionsInvalidArgs` — NULL form / annot.
  - `RemoveOptionsWrongAnnotationType` — textfield rejected.

Deferred for a follow-up CL: the two-element `[export_value, label]`
entry form that some `/Opt` arrays use. The current API writes
single-label `CPDF_String` entries only; a future overload taking an
optional `export_value FPDF_WIDESTRING` can ship without breaking
this one.

The commit message carries the deterministic
`Change-Id: I502beb8b78a18256eb147919fe7b73dbf012b106` so re-uploads
(after rebases or reviewer-requested amends) all land on the same
Gerrit CL.

### `pdfium-FPDFPath_GetBezierControlPoints.patch`

**Status:** Patchset 2 uploaded to
[pdfium-review CL 147810](https://pdfium-review.googlesource.com/c/pdfium/+/147810)
on 2026-05-15, revising the original patchset after the first
reviewer pass.

Adds the public symbol

```c
FPDF_EXPORT FPDF_BOOL FPDF_CALLCONV
FPDFPath_GetBezierControlPoints(FPDF_PAGEOBJECT path,
                                int index,
                                float* cp1_x, float* cp1_y,
                                float* cp2_x, float* cp2_y);
```

so embedders can read back the two control points of a cubic Bezier
curve already in a PDF. The constructor side
(`FPDFPath_BezierTo()`) accepts all six floats; only the readout
side was asymmetric. See
[ADR-009](../decisions/ADR-009-defer-bezier-controls.md) for the
cross-language demand record and the upstream-issue discussion that
produced the positive-response signal.

Patchset 2 changes from patchset 1, per reviewer feedback:

* Function moved from `FPDFPathSegment_*` to `FPDFPath_*` namespace
  and takes the path + endpoint index instead of a bare
  `FPDF_PATHSEGMENT`. PDFium's build system rejected the original
  pattern (pointer arithmetic on the underlying `std::vector<Point>`
  storage) as unsafe-buffer-usage. The new implementation uses the
  same `pdfium::span` + `fxcrt::IndexInBounds` pattern that
  `FPDFPath_GetPathSegment` already uses next door.
* Back-to-back-curve disambiguation is now in the implementation
  rather than documented as a caller-must-handle caveat: the
  function walks back counting consecutive `kBezier` predecessors
  and requires the count mod 3 to equal 2, so indices that look
  like endpoints locally but are actually the first/second control
  point of a following curve correctly return `false`.
* New-code variable naming follows Google C++ style (`path_obj`,
  `cp1_point`, `cp2_point`); the existing `pPathPoint` naming in
  surrounding functions is left alone.
* Embedder test no longer calls `FPDFPage_InsertObject` /
  `FPDFPage_GenerateContent` (the test reads from the path
  directly; insertion was leftover boilerplate). The path is freed
  with `FPDFPageObj_Destroy(path)`.
* Commit-message footer reordered so `Change-Id` comes last
  (Gerrit convention).
* Commit-message `Bug:` line points at the real Chromium issue:
  <https://issues.chromium.org/issues/513613479>.

Files touched (against upstream HEAD `9f6089d4d`):

* `public/fpdf_edit.h` — declaration with full doc comment.
* `fpdfsdk/fpdf_editpath.cpp` — implementation using
  `pdfium::span<const CFX_Path::Point>` and `fxcrt::IndexInBounds`,
  with a walk-back loop that establishes the segment's position
  within its Bezier triplet.
* `fpdfsdk/fpdf_view_c_api_test.c` — `CHK()` entry so the C API
  surface smoke-test covers the new symbol.
* `fpdfsdk/fpdf_edit_embeddertest.cpp` — new
  `FPDFEditEmbedderTest::GetBezierControlPoints` exercising every
  documented behavior: each valid endpoint, every control-point
  index (with the back-to-back case asserted to return false), every
  non-Bezier segment, out-of-range indices, NULL path, and every
  NULL-out-param permutation.

The commit message in the patch carries the deterministic
`Change-Id: I2ddaa58d13a615777c3ac146d3f53faf5bad6be1` so re-uploads
(after rebases or reviewer-requested amends) all land on the same
Gerrit CL.

## Submission walk-through

These steps are written for a fresh Linux machine. Some are
one-time setup; once your `.gitcookies` and CLA are in place, only
steps 4–10 repeat on each upload.

### One-time setup

1. **Sign the Google CLA.** Visit
   <https://cla.developers.google.com/> and sign the Individual
   CLA (or have your employer sign the Corporate CLA covering
   `wdenney@humanpredictions.com`). Gerrit blocks tryjobs until
   this is on file. Allow ~15 minutes for it to propagate.

2. **Install `depot_tools`** (small, ~50 MB):

   ```sh
   cd ~
   git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
   echo 'export PATH="$HOME/depot_tools:$PATH"' >> ~/.bashrc
   exec $SHELL -l
   ```

   (Already present in this repo's machine at `~/depot_tools/` —
   just add it to `PATH` if you haven't.)

3. **Authenticate to Gerrit.** Two options; pick one.

   **3a. New auth stack (recommended on fresh machines).**
   depot_tools' default auth path runs `git credential-luci login`
   which opens a browser flow against your Google account and
   stores tokens under `~/.config/chrome_infra/auth/`. It engages
   automatically the first time `git cl upload` needs credentials
   — no separate URL to visit. Skip 3b if you go this route. If
   you want to verify ahead of time:

   ```sh
   git credential-luci login
   git cl creds-check                 # diagnoses any remaining issues
   ```

   **3b. Legacy `.gitcookies` flow.** Open
   <https://pdfium.googlesource.com/new-password> (note: no
   `-review` in the hostname — the password page is hosted on the
   canonical googlesource domain, not the Gerrit subdomain). Sign
   in with the Google account you'll author CLs from. The page
   shows a shell snippet — copy-paste it into your terminal. It
   appends an auth line to `~/.gitcookies` for
   `.googlesource.com` that depot_tools picks up. (When this file
   exists, depot_tools disables the new auth stack and uses
   `.gitcookies` instead.)

### Per-upload (or first upload)

4. **Get a PDFium tree.** The minimum-disk path is a plain clone —
   `git cl upload` only needs the working tree, not the build
   dependencies that `gclient sync` fetches. (Skip to step 5 if
   you'll want to run the embedder tests locally before upload;
   that does need the full `gclient` checkout.)

   ```sh
   # Minimum: ~150 MB, fast.
   mkdir -p ~/src && cd ~/src
   git clone https://pdfium.googlesource.com/pdfium
   cd pdfium
   ```

5. **(Optional) Full `gclient` checkout for local build.**
   `gclient sync` downloads third_party deps (~10 GB) and lets you
   run `gn gen out/Default && ninja -C out/Default
   pdfium_embeddertests pdfium_unittests`. Skip if you're willing
   to let the Gerrit trybots catch compile/test failures and
   re-upload once they report.

   ```sh
   cd ~/src
   rm -rf pdfium                                       # clean
   mkdir pdfium && cd pdfium
   gclient config --unmanaged https://pdfium.googlesource.com/pdfium.git
   gclient sync
   cd pdfium
   ```

6. **Install the Gerrit `commit-msg` hook.** This keeps the
   `Change-Id` line correct on amends:

   ```sh
   curl -Lo .git/hooks/commit-msg \
       https://gerrit-review.googlesource.com/tools/hooks/commit-msg
   chmod +x .git/hooks/commit-msg
   ```

7. **Create a branch and apply the patch.**

   ```sh
   git checkout -b bezier-control-points origin/main
   git am /path/to/rpdfium/dev/upstream-patches/\
   pdfium-FPDFPath_GetBezierControlPoints.patch
   ```

   The patch already includes the `Change-Id` footer; the hook
   from step 6 will leave it alone on subsequent amends.

8. **Add yourself to `AUTHORS`.** PDFium's `CONTRIBUTING.md`
   requires every first-time individual contributor to add an
   entry. Insert alphabetically (Bill goes between "Aryan P
   Krishnan" and "Chenguang Shao"):

   ```sh
   # Edit AUTHORS by hand, then:
   git add AUTHORS
   git commit --amend --no-edit
   ```

9. **(Optional, recommended) Local build + test.** Only works if
   you ran step 5.

   ```sh
   gn gen out/Default
   ninja -C out/Default pdfium_embeddertests pdfium_unittests
   ./out/Default/pdfium_unittests --gtest_filter='*c_api_test*'
   ./out/Default/pdfium_embeddertests \
       --gtest_filter='*GetBezierControlPoints*'
   ```

10. **Upload to Gerrit.**

    ```sh
    git cl upload --send-mail
    ```

    The command prints a CL URL on success — paste it into the
    Active-patches section above so future bumps can find the CL.

## Maintenance

If upstream PDFium moves significantly before this lands and the
patch no longer applies cleanly, regenerate from a fresh
upstream clone:

```sh
# From this repo's root.
cd tmp/upstream/pdfium
git fetch origin main && git rebase origin/main
git format-patch -1 HEAD \
    --output-directory=../../../dev/upstream-patches/
mv ../../../dev/upstream-patches/0001-Expose-cubic-Bezier-control-points-on-read.patch \
   ../../../dev/upstream-patches/pdfium-FPDFPath_GetBezierControlPoints.patch
```

Preserve the `Change-Id` line — if it changes, Gerrit will treat
the next upload as a brand-new CL rather than an update to the
existing one.
