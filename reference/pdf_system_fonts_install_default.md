# Install PDFium's default system-font-info provider

Wraps `FPDF_SetSystemFontInfo(FPDF_GetDefaultSystemFontInfo())`. Tells
PDFium to use the platform's default callback table for resolving font
requests against installed system fonts. Without this, PDFium falls back
to its built-in (static) substitution table only — which is fine for
most documents but misses platform-installed typefaces.

## Usage

``` r
pdf_system_fonts_install_default()
```

## Value

Invisibly returns `TRUE` if the provider was installed, `FALSE` if the
platform has no default provider (e.g. stripped-down builds).

## Details

Idempotent across calls; the provider persists for the package's
lifetime (PDFium retains the pointer; we don't call
`FPDF_FreeDefaultSystemFontInfo` because the provider is
library-global).

Custom providers (R-side callbacks for font enumeration) are deferred to
a later release — they require marshalling `FPDF_SYSFONTINFO`'s callback
table into R closures, which is non-trivial.
