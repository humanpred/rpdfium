# Set the flags bitmask of an annotation

Wraps `FPDFAnnot_SetFlags`. Accepts either an integer bitmask or a named
logical vector matching the names that
[`pdf_annot_flags_decoded()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_flags_decoded.md)
returns (`is_invisible`, `is_hidden`, `is_print`, `is_no_view`,
`is_read_only`, `is_locked`, ...). When a named logical is passed, any
TRUE position sets the corresponding bit; FALSE clears it.

## Usage

``` r
pdf_annot_set_flags(annot, flags)
```

## Arguments

- annot:

  A `pdfium_annot` handle. Parent doc must be readwrite.

- flags:

  Either an integer scalar (raw PDF /F bitmask) or a named logical
  vector with the documented flag-bit names.

## Value

Invisibly returns the parent `pdfium_doc`.

## See also

[`pdf_annot_flags()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_flags.md),
[`pdf_annot_flags_decoded()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_flags_decoded.md).
