# ADR-002 — License

- Status: Accepted
- Date: 2026-05-15

## Context

`pdfium` ships a thin R wrapper plus, at install time, a prebuilt
PDFium binary distributed by
[bblanchon/pdfium-binaries](https://github.com/bblanchon/pdfium-binaries).
We need to pick a license that:

1. Composes cleanly with PDFium's BSD-3-Clause.
2. Composes cleanly with the bblanchon distribution scripts (Apache-2.0).
3. Composes cleanly with the immediate downstream consumer
   (`kmextract`, MIT-licensed) and with the broader R ecosystem
   (predominantly GPL-2 / GPL-3 / MIT).
4. Lets corporate users adopt the package without legal review hurdles.

## Decision

- The `pdfium` R package: **MIT** (with the standard CRAN
  `MIT + file LICENSE` declaration).
- The bundled PDFium binary remains **BSD-3-Clause**, governed by its
  upstream license file, which is installed alongside the binary under
  `inst/pdfium-binaries/LICENSE`.
- The bblanchon distribution scripts are Apache-2.0; we do not vendor
  them and never redistribute their archives unmodified, so the only
  obligation we carry is to reference their copyright notice when we
  ship downstream.
- `LICENSE.md` at the repo root documents all three layers.

## Consequences

- Users may incorporate `pdfium` into commercial and proprietary
  workflows freely.
- We must ensure `LICENSE.md` is regenerated to reflect the actual
  PDFium release we ship whenever `tools/pdfium-version.txt` changes
  (see ADR-006).
- We cannot adopt GPL-licensed dependencies in `Imports:` without
  triggering reciprocal-license obligations on `pdfium` itself; for
  this reason we prefer permissively-licensed deps.

## Alternatives considered

- **GPL-3.** Rejected: many corporate users avoid GPL deps by policy,
  and the wrapper's value isn't tied to copyleft propagation.
- **Apache-2.0.** Compatible with MIT but conventionally less common in
  CRAN packages; MIT is the path of least friction for users.
- **BSD-3-Clause for the R wrapper.** Functionally near-identical to
  MIT. We pick MIT for ecosystem consistency.

## References

- [PDFium license](https://pdfium.googlesource.com/pdfium/+/main/LICENSE)
- [bblanchon/pdfium-binaries license](https://github.com/bblanchon/pdfium-binaries/blob/master/LICENSE)
- [CRAN MIT-license requirements](https://cran.r-project.org/doc/manuals/R-exts.html#Licensing)
