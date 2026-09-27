# MIT License

Copyright (c) 2026 pdfium authors

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files (the
“Software”), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

------------------------------------------------------------------------

## Bundled binary distribution

This package downloads prebuilt PDFium binaries from
[bblanchon/pdfium-binaries](https://github.com/bblanchon/pdfium-binaries)
at install time. The PDFium engine itself is licensed under the
**BSD-3-Clause** license, and `libpdfium` also contains third-party code
under its own licenses (FreeType, ICU, libjpeg-turbo, libpng, zlib,
Little CMS, OpenJPEG, Abseil and others). The build scripts at
bblanchon/pdfium-binaries are licensed under **MIT**.

When `libpdfium` comes from that download, the installed package carries
all of these notices in its `pdfium-licenses/` directory:
`system.file("pdfium-licenses", package = "pdfium")` lists them.
`pdfium.txt` is PDFium’s license, `LICENSE` is
bblanchon/pdfium-binaries’ license, and the other files cover the
third-party code. Binary builds of the package include `libpdfium`, so
they include these notices too.

When `libpdfium` comes from an existing installation instead
(`PDFIUM_HOME`, `pkg-config` or a standard system prefix), `pdfium`
copies no PDFium notices; the license terms of that installation apply.

Neither the PDFium source nor its prebuilt binaries are part of the
`pdfium` R-package source tarball; both are fetched on demand. See
`dev/decisions/ADR-003-binary-distribution.md` for the rationale.
