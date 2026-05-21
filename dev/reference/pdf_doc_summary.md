# One-call summary of a PDF document

Returns a single-row tibble that aggregates the most-asked-for facts
about a PDF document: file path, page count, Info-dictionary metadata,
structural feature flags (forms, attachments, bookmarks, signatures,
JavaScript, tagged-PDF), counts for each of those feature groups,
encryption state, and the file-ID tuple. Designed to replace the
eight-or-so individual calls users typically chain together when
triaging a PDF.

## Usage

``` r
pdf_doc_summary(doc, password = NULL)
```

## Arguments

- doc:

  A `pdfium_doc` from
  [`pdf_doc_open()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_open.md),
  or a character path.

- password:

  Optional password for encrypted PDFs when `doc` is a path. Ignored
  when `doc` is an open `pdfium_doc`.

## Value

A one-row tibble.

## Details

Each column either exposes an existing reader or is a
[`length()`](https://rdrr.io/r/base/length.html) over the matching
`pdfium_*_list`. No new C-side work — purely an R-side aggregation. See
**Columns** below for the source reader for each entry.

## Columns

- `path` — character; canonical path the doc was opened from, or
  `"<raw bytes>"` for in-memory loads.

- `page_count`, `file_version` — from
  [`pdf_doc_info()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_info.md).

- `title`, `author`, `subject`, `keywords`, `creator`, `producer`,
  `creation_date`, `mod_date`, `trapped` — from
  [`pdf_doc_info()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_info.md);
  missing entries appear as `""`.

- `creation_date_parsed`, `mod_date_parsed` — POSIXct (UTC), `NA` when
  the source date is empty or unparseable. From
  [`pdf_parse_date()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_parse_date.md).

- `is_tagged` — from
  [`pdf_doc_is_tagged()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_is_tagged.md).

- `is_encrypted` — `TRUE` when
  [`pdf_doc_security()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_security.md)
  returns a non-NA revision; `FALSE` otherwise.

- `security_revision` — from
  [`pdf_doc_security()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_security.md);
  `NA` for unencrypted PDFs.

- `xref_valid` — from
  [`pdf_doc_xref_valid()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_xref_valid.md).

- `bookmark_count`, `attachment_count`, `signature_count`,
  `form_field_count`, `javascript_count`, `named_dest_count` —
  [`length()`](https://rdrr.io/r/base/length.html) of
  [`pdf_doc_bookmarks()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_bookmarks.md),
  [`pdf_attachments()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_attachments.md),
  [`pdf_signatures()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_signatures.md),
  [`pdf_form_fields()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_fields.md),
  [`pdf_doc_javascript()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_javascript.md),
  and
  [`pdf_doc_named_dests()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_named_dests.md)
  respectively. Zero when the document has none of the corresponding
  entries.

- `has_page_labels` — `TRUE` when
  [`pdf_page_labels()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_labels.md)
  returns non-NA strings.

- `file_id_permanent`, `file_id_changing` — from
  [`pdf_doc_file_id()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_file_id.md);
  UTF-8 hex strings or `NA`.

## See also

[`pdf_doc_info()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_info.md)
for the Info-dictionary subset alone, the per-feature readers listed
under **Columns** for richer per-row data.

## Examples

``` r
fixture <- system.file("extdata", "fixtures", "annotated.pdf",
  package = "pdfium"
)
if (nzchar(fixture)) pdf_doc_summary(fixture)
#> # A tibble: 1 × 27
#>   path    page_count file_version title author subject keywords creator producer
#>   <chr>        <int>        <int> <chr> <chr>  <chr>   <chr>    <chr>   <chr>   
#> 1 /home/…          1           14 ""    ""     ""      ""       ""      ""      
#> # ℹ 18 more variables: creation_date <chr>, mod_date <chr>, trapped <chr>,
#> #   creation_date_parsed <dttm>, mod_date_parsed <dttm>, is_tagged <lgl>,
#> #   is_encrypted <lgl>, security_revision <int>, xref_valid <lgl>,
#> #   bookmark_count <int>, attachment_count <int>, signature_count <int>,
#> #   form_field_count <int>, javascript_count <int>, named_dest_count <int>,
#> #   has_page_labels <lgl>, file_id_permanent <chr>, file_id_changing <chr>
```
