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

### `pdfium-FPDFPathSegment_GetBezierControlPoints.patch`

Adds the public symbol

```c
FPDF_EXPORT FPDF_BOOL FPDF_CALLCONV
FPDFPathSegment_GetBezierControlPoints(FPDF_PATHSEGMENT segment,
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

Files touched (against upstream HEAD `9f6089d4d`):

* `public/fpdf_edit.h` — declaration with full doc comment.
* `fpdfsdk/fpdf_editpath.cpp` — implementation reading two
  predecessor points via `std::vector<Point>` pointer arithmetic.
* `fpdfsdk/fpdf_view_c_api_test.c` — `CHK()` entry so the C API
  surface smoke-test covers the new symbol.
* `fpdfsdk/fpdf_edit_embeddertest.cpp` — new
  `FPDFEditEmbedderTest::GetBezierControlPoints` exercising every
  documented behavior, including the back-to-back-curve caveat as
  a contract test.

The commit message in the patch carries the deterministic
`Change-Id: I2ddaa58d13a615777c3ac146d3f53faf5bad6be1` so the
upload lands on a single Gerrit CL even across `git commit
--amend` cycles.

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

2. **Sign in to Gerrit and seed `.gitcookies`.** Open
   <https://pdfium-review.googlesource.com/new-password>, sign in
   with the Google account you'll author CLs from, and copy the
   shell snippet they generate into your terminal. It writes a
   line to `~/.gitcookies` that `git cl upload` will use.

3. **Install `depot_tools`** (small, ~50 MB):

   ```sh
   cd ~
   git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
   echo 'export PATH="$HOME/depot_tools:$PATH"' >> ~/.bashrc
   exec $SHELL -l
   ```

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
   pdfium-FPDFPathSegment_GetBezierControlPoints.patch
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
   ../../../dev/upstream-patches/pdfium-FPDFPathSegment_GetBezierControlPoints.patch
```

Preserve the `Change-Id` line — if it changes, Gerrit will treat
the next upload as a brand-new CL rather than an update to the
existing one.
