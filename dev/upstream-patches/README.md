# Upstream PDFium patches

Patches we maintain against upstream
[PDFium](https://pdfium.googlesource.com/pdfium) and intend to submit
through the project's contribution process. Each entry here has a
companion ADR in `dev/decisions/` that records the motivation and the
upstream status.

## Process

PDFium uses Gerrit for code review at
<https://pdfium-review.googlesource.com>. The full contribution
process (depot_tools, gclient sync, BUILD.gn awareness, the
`Change-Id` footer) is documented in
[`CONTRIBUTING.md`](https://pdfium.googlesource.com/pdfium/+/HEAD/CONTRIBUTING.md)
upstream. The short version:

1. Install
   [depot_tools](https://commondatastorage.googleapis.com/chrome-infra-docs/flat/depot_tools/docs/html/depot_tools_tutorial.html#_setting_up).
2. `gclient config --unmanaged
   https://pdfium.googlesource.com/pdfium.git` and `gclient sync`
   into a fresh tree.
3. `git apply` the patch (or `git am` if you want the commit message
   preserved with the `Change-Id` line).
4. `gn gen out/Default` and build the test target:
   `ninja -C out/Default pdfium_embeddertests pdfium_unittests`.
5. Run the embedder tests:
   `./out/Default/pdfium_embeddertests --gtest_filter='*BezierControlPoints*'`.
6. Run the C API smoke test:
   `./out/Default/pdfium_unittests --gtest_filter='*c_api_test*'`.
7. `git cl upload` to push to Gerrit.

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
side was asymmetric. See [ADR-009](../decisions/ADR-009-defer-bezier-controls.md)
for the cross-language demand record and the upstream-issue
discussion that produced the positive-response signal.

Files touched (against upstream HEAD `9f6089d4d`):

* `public/fpdf_edit.h` — declaration with full doc comment.
* `fpdfsdk/fpdf_editpath.cpp` — implementation reading two
  predecessor points via std::vector pointer arithmetic.
* `fpdfsdk/fpdf_view_c_api_test.c` — `CHK()` entry so the C API
  surface smoke-test covers the new symbol.
* `fpdfsdk/fpdf_edit_embeddertest.cpp` — new
  `FPDFEditEmbedderTest::GetBezierControlPoints`. Constructs a path
  with two adjacent cubic curves separated by a line, reads back
  each endpoint's control points, and contract-tests the documented
  back-to-back-curve caveat (a control point that happens to follow
  a previous Bezier endpoint cannot be distinguished from a real
  endpoint by the segment handle alone — the function returns the
  preceding two points and the caller is expected to walk the path
  to know which segments are endpoints).

To regenerate after a rebase against newer upstream:

```sh
# from this repo's root
git -C tmp/upstream/pdfium fetch origin main
git -C tmp/upstream/pdfium rebase origin/main
git -C tmp/upstream/pdfium format-patch -1 HEAD \
    --output-directory=dev/upstream-patches/
mv dev/upstream-patches/0001-Expose-cubic-Bezier-control-points-on-read.patch \
   dev/upstream-patches/pdfium-FPDFPathSegment_GetBezierControlPoints.patch
```

Track the Gerrit CL URL in this README once it's uploaded.
