# Set the document's declared language

Wraps `FPDFCatalog_SetLanguage`. The language tag follows BCP-47 (e.g.
`"en"`, `"en-US"`, `"de-AT"`).

## Usage

``` r
pdf_doc_set_language(doc, lang)
```

## Arguments

- doc:

  A read-write `pdfium_doc`.

- lang:

  Character scalar — the BCP-47 language tag.

## Value

Invisibly returns `doc`.
