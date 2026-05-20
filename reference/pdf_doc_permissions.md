# Permission flags from a PDF's encryption dictionary

Returns the operations the PDF declares it allows. When the document is
unencrypted (or was opened with the owner password), PDFium reports
`0xFFFFFFFF` - every bit set, every operation allowed - and this
function returns a named logical vector of all `TRUE`. For an encrypted
document opened with a user password, the bitmask reflects whatever the
document author set.

## Usage

``` r
pdf_doc_permissions(doc)
```

## Arguments

- doc:

  A `pdfium_doc` from
  [`pdf_doc_open()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_open.md),
  or a character path.

## Value

A named logical vector with the eight flags listed above.

## Details

Wraps `FPDF_GetDocPermissions`. The decoded flags follow the PDF
specification's `/P` (UserAccess) bit assignments (ISO 32000-1 section
7.6.3.2, Table 22):

- `print` - bit 3: print the document.

- `modify` - bit 4: change content other than annotation / form-field
  values.

- `copy` - bit 5: copy or otherwise extract text and graphics from the
  document.

- `annotate` - bit 6: add or modify text annotations.

- `fill_forms` - bit 9: fill in interactive form fields, regardless of
  `modify`.

- `extract_for_a11y` - bit 10: extract text and graphics for
  accessibility purposes.

- `assemble` - bit 11: insert, rotate, or delete pages and create
  bookmarks / thumbnails, regardless of `modify`.

- `print_high_res` - bit 12: faithful digital print copy. When `FALSE`
  while `print` is `TRUE`, the document may print only at low
  resolution.
