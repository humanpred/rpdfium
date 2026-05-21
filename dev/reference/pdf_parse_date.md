# Parse a PDF date string into POSIXct

PDF Info-dictionary dates use the format `"D:YYYYMMDDHHmmSS+HH'mm'"`
(PDF spec, section 7.9.4 - a superset of ISO 8601). This helper extracts
the date and time fields and returns UTC `POSIXct`; the timezone offset
suffix is currently ignored (the date is treated as UTC). Truncated
strings (e.g. `"D:2024"`) parse to the longest valid prefix.

## Usage

``` r
pdf_parse_date(s)
```

## Arguments

- s:

  Character vector of PDF date strings.

## Value

`POSIXct` vector (UTC), same length as `s`. `NA` for empty or
unparseable entries.
