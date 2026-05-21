# Summarise every PDF in a directory in one call

Scans a directory for PDF files and returns a tibble whose rows are the
[`pdf_doc_summary()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_summary.md)
output for each file. The natural replacement for the standard "loop
over a folder of PDFs and triage" workflow — encrypted-which /
has-forms-which / has-attachments-which.

## Usage

``` r
pdf_dir_summary(
  dir = ".",
  pattern = "\\.pdf$",
  recursive = FALSE,
  password = NULL,
  errors = c("warn", "skip", "stop")
)
```

## Arguments

- dir:

  Character scalar. Path to the directory to scan.

- pattern:

  Regular expression filtering filenames. Defaults to `"\\.pdf$"`
  (case-insensitive).

- recursive:

  Logical. When `TRUE`, descend into subdirectories. Defaults `FALSE`.

- password:

  Optional password applied to every file. `NULL` (default) tries each
  file without a password. Useful when all files share the same
  password.

- errors:

  One of `"warn"`, `"skip"`, `"stop"` — see Details.

## Value

A tibble with the same columns as
[`pdf_doc_summary()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_summary.md).
Zero rows when the directory has no PDFs (or every PDF failed to open
under `errors = "skip"` / `"warn"`).

## Details

Files that fail to open (corrupt, wrong format, password protected) are
handled per the `errors` argument:

- `"warn"` (default) — a
  [`warning()`](https://rdrr.io/r/base/warning.html) per failed file;
  the file is dropped from the result tibble.

- `"skip"` — silently dropped.

- `"stop"` — the first failed file raises an error and the function
  aborts.

## See also

[`pdf_doc_summary()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_summary.md)
for the single-file companion.

## Examples

``` r
fixture_dir <- system.file("extdata", "fixtures",
                           package = "pdfium")
if (nzchar(fixture_dir)) {
  pdf_dir_summary(fixture_dir)
}
#> # A tibble: 14 × 27
#>    path   page_count file_version title author subject keywords creator producer
#>    <chr>       <int>        <int> <chr> <chr>  <chr>   <chr>    <chr>   <chr>   
#>  1 /home…          1           14 ""    ""     ""      ""       ""      ""      
#>  2 /home…          1           14 ""    ""     ""      ""       ""      ""      
#>  3 /home…          1           14 ""    ""     ""      ""       ""      ""      
#>  4 /home…          1           17 ""    ""     ""      ""       ""      "cairo …
#>  5 /home…          1           14 ""    ""     ""      ""       ""      ""      
#>  6 /home…          1           17 ""    ""     ""      ""       ""      "cairo …
#>  7 /home…          1           17 ""    ""     ""      ""       ""      "cairo …
#>  8 /home…          2           14 ""    ""     ""      ""       ""      ""      
#>  9 /home…          1           17 ""    ""     ""      ""       ""      "cairo …
#> 10 /home…          1           14 ""    ""     ""      ""       ""      ""      
#> 11 /home…          1           15 ""    ""     ""      ""       ""      ""      
#> 12 /home…          1           17 ""    ""     ""      ""       ""      "cairo …
#> 13 /home…          1           17 ""    ""     ""      ""       ""      "cairo …
#> 14 /home…          1           14 ""    ""     ""      ""       ""      ""      
#> # ℹ 18 more variables: creation_date <chr>, mod_date <chr>, trapped <chr>,
#> #   creation_date_parsed <dttm>, mod_date_parsed <dttm>, is_tagged <lgl>,
#> #   is_encrypted <lgl>, security_revision <int>, xref_valid <lgl>,
#> #   bookmark_count <int>, attachment_count <int>, signature_count <int>,
#> #   form_field_count <int>, javascript_count <int>, named_dest_count <int>,
#> #   has_page_labels <lgl>, file_id_permanent <chr>, file_id_changing <chr>
```
