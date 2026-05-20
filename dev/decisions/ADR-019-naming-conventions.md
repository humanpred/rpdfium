# ADR-019 — Naming conventions: accessors vs. verbs

- Status: Accepted
- Date: 2026-05-20
- Deciders: Bill Denney

## Context

Earlier ADRs locked in pieces of the naming story:

- ADR-004 (API style): snake_case, `pdf_*` prefix, S3 classes,
  tibble outputs.
- ADR-018 (setter conventions): writers follow the
  `pdf_<thing>_set_<attr>` shape (object-first), polymorphic page
  arg, etc.

Both ADRs left a residual asymmetry on the *reader* and
*lifecycle* side: the pre-ADR-019 names `pdf_open()` /
`pdf_close()` / `pdf_load_page()` / `pdf_close_page()` were
verb-first, but `pdf_doc_info()` / `pdf_doc_meta()` /
`pdf_page_size()` were object-first. After a package-surface
review the inconsistency was judged worth fixing while we have no
users (zero-backcompat window).

## Decision

Two parallel conventions cover every public function in `pdfium`.
Which one applies is determined by *what the function does*, not
by whether it reads or writes.

### Convention A — Accessors are object-first

If a function reads or sets an attribute of a specific PDFium
object (`doc`, `page`, `obj`, `path`, `text`, `image`, `annot`,
`form_field`, `attachment`, `signature`, `bookmark`, …), the
function name starts with the object's short name.

Reader form:

```
pdf_<object>_<attribute>()
```

Setter form:

```
pdf_<object>_set_<attribute>()
```

Constructor form (a function that materialises a new instance of
the object):

```
pdf_<object>_new()       # fresh empty instance
pdf_<object>_open()      # load from disk / external source
pdf_<object>_load()      # load by index from a parent handle
```

Destructor form (the inverse — releases the in-memory handle but
does not necessarily delete the underlying PDF object):

```
pdf_<object>_close()     # release a loaded handle
pdf_<object>_delete()    # remove the underlying PDF object from
                         # its parent (e.g. delete a page from a doc)
```

Examples (after this ADR lands):

| Function | Object | Pattern |
|---|---|---|
| `pdf_doc_open(path)` | doc | constructor |
| `pdf_doc_close(doc)` | doc | destructor |
| `pdf_doc_new()` | doc | constructor |
| `pdf_doc_info(doc)` | doc | accessor |
| `pdf_doc_meta(doc, tag)` | doc | accessor |
| `pdf_doc_set_language(doc, lang)` | doc | setter |
| `pdf_page_load(doc, n)` | page | constructor |
| `pdf_page_close(page)` | page | destructor |
| `pdf_page_new(doc, n, w, h)` | page | constructor |
| `pdf_page_delete(doc, n)` | page | destructor (deletes from doc) |
| `pdf_page_size(page)` | page | accessor |
| `pdf_page_rotation(page)` | page | accessor |
| `pdf_page_set_rotation(page, degrees)` | page | setter |
| `pdf_page_objects(page)` | page | accessor (returns child list) |
| `pdf_obj_bounds(obj)` | obj | accessor |
| `pdf_path_segments(obj)` | path obj | accessor |

### Convention B — Verbs / actions are verb-first

If a function performs an *action* — render, extract, merge,
parse, search — that doesn't naturally belong to one object's
attribute namespace, the name starts with the verb. The verb may
or may not be followed by an object name; both shapes are
acceptable.

```
pdf_<verb>()
pdf_<verb>_<object>()
pdf_<verb>_<modifier>()
```

Examples (kept verb-first):

| Function | Verb | Note |
|---|---|---|
| `pdf_render_page(page, ...)` | render | render is canonically a verb |
| `pdf_render_page_with_matrix(page, ...)` | render | modifier suffix |
| `pdf_render_to_png(page, file)` | render | output-form suffix |
| `pdf_extract_paths(doc, page)` | extract | one-call helper; the verb IS the operation |
| `pdf_docs_merge(docs, file)` | merge | acts on multiple docs |
| `pdf_n_up(doc, file, cols, rows)` | (idiomatic PDF term) | "n-up imposition" — unchanged |
| `pdf_parse_date(s)` | parse | pure utility |

Note `pdf_docs_merge` uses the plural object name. The principle:
when the verb operates on a *collection* of objects rather than
one, the object name is plural. A future per-doc merger (e.g.
"merge annotations from two docs into one") might be
`pdf_doc_annotations_merge` or similar.

### Convention C — at-point hit testers

A small idiom for spatial queries:

```
pdf_<thing>_at_point(parent, x, y, ...)
```

Examples: `pdf_link_at_point`, `pdf_link_annot_at_point`,
`pdf_form_field_at_point`, `pdf_text_char_at_point`. These are
accessors (return a thing under a coordinate) so they're
object-first; the trailing `_at_point` is the conventional
spatial-query suffix.

## Consequences

- The package-surface rename touches every reference to the
  renamed functions: R source, tests, vignettes, docs, ADRs,
  README, `_pkgdown.yml`, bug-report template. ~14 renames; all
  mechanical via search-and-replace.
- New functions added in any future phase MUST follow one of
  these three conventions. CLAUDE.md gains a "Naming"
  section that summarises the rule + points at this ADR.
- The verb-first vs. object-first decision is determined by
  *what the function does*, not by phase or by who is using it.
  An action that mutates state can still be verb-first
  (`pdf_extract_paths` would be `pdf_extract_paths` even if it
  somehow mutated, because "extract" is the operation, not an
  attribute).

## Alternatives considered

- **All-verb-first** (`pdf_open_doc`, `pdf_close_doc`,
  `pdf_get_page_rotation`, `pdf_set_page_rotation`): rejected —
  splits readers and writers in tab completion. Verbose for
  the common-case accessor.
- **All-object-first** (`pdf_render_page` → `pdf_page_render`):
  considered, but loses the natural English reading order for
  actions, and breaks idiomatic uses like `pdf_render_to_png`.
  Hybrid is more readable.
- **Drop the `doc` prefix for top-level reader functions**
  (`pdf_doc_text`, `pdf_doc_fonts`, etc.) and keep them as-is: rejected —
  the `pdf_doc_*` namespace is the only consistent home for
  document-level readers, and the asymmetry against
  `pdf_doc_info` / `pdf_doc_meta` / `pdf_doc_new` was the entire
  reason for this ADR.

## References

- ADR-004 (API style baseline).
- ADR-017 (handle-returning readers — the prefix unification
  was the seed for this ADR).
- ADR-018 (setter conventions — the writer half of the same
  principle).
- CLAUDE.md "Naming" section (operational summary for AI
  contributors).
