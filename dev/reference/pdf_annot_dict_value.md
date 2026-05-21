# Read an annotation-dict entry by key

Parallel to
[`pdf_attachment_dict_value()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_attachment_dict_value.md)
but for annotations. Returns the typed value of a key in the
annotation's dictionary — useful for ad-hoc access to keys
[`pdf_annotations()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annotations.md)
doesn't surface (e.g. `/M` modification date, `/NM` unique name, `/CA`
overall opacity, `/RC` rich-text contents).

## Usage

``` r
pdf_annot_dict_value(annot, key)
```

## Arguments

- annot:

  A `pdfium_annot` handle (e.g. one element of `pdf_annotations(page)`).

- key:

  The annotation-dict key as a single non-empty character string (ASCII
  PDF name, e.g. `"M"`, `"NM"`, `"CA"`).

## Value

A list with four fields:

- `has_key` (logical) — `TRUE` when the annotation dict contains `key`.

- `value_type` (integer) — PDFium's `FPDF_OBJECT_*` enum value
  (`0`=unknown, `1`=boolean, `2`=number, `3`=string, `4`=name, ...);
  `NA` when the key is absent.

- `value_string` (character) — populated when the value is a PDF string
  or name; `NA_character_` otherwise.

- `value_number` (numeric) — populated when the value is a PDF number;
  `NA_real_` otherwise.

## Details

Wraps `FPDFAnnot_HasKey`, `FPDFAnnot_GetValueType`,
`FPDFAnnot_GetStringValue`, and `FPDFAnnot_GetNumberValue`. Only
string-, name-, and number-typed values come back; other value types
(dict / array / stream / reference) report `value_type` accordingly but
leave the typed accessors as `NA`.

## See also

[`pdf_annotations()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annotations.md)
for the structured per-annotation readout,
[`pdf_annot_appearance()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_appearance.md)
for the `/AP` appearance stream.
