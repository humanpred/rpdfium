# MIT License

Copyright (c) 2026 pdfium authors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

---

## Bundled binary distribution

This package downloads prebuilt PDFium binaries from
[bblanchon/pdfium-binaries](https://github.com/bblanchon/pdfium-binaries) at
install time. The PDFium engine itself is licensed under the **BSD-3-Clause**
license; see `inst/pdfium-binaries/LICENSE` after installation. The
distribution scripts at bblanchon/pdfium-binaries are licensed under
**Apache-2.0**.

Neither the PDFium source nor its prebuilt binaries are part of the `pdfium`
R-package source tarball; both are fetched on demand. See
`docs/decisions/ADR-003-binary-distribution.md` for the rationale.
