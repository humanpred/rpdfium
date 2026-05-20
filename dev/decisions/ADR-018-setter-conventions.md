# ADR-018 — Setter conventions

- Status: Accepted
- Date: 2026-05-20
- Deciders: Bill Denney

## Context

Phase 1 + Phase 2 of the writer surface landed with first-draft
conventions. After a Q&A pass the conventions are formalized so
Phases 3–9 are consistent. The earlier ADRs (011 mutation
lifecycle, 012 readwrite flag, 014 structural-mutation set, 015
annotation authoring, 016 page-object creation) deferred this
naming/identity question.

## Decision

Five conventions, listed in order of how often they show up in a
writer function's signature.

### 1. Object-first naming

Every setter has the form `pdf_<thing>_set_<attr>(thing, ...)`,
where `<thing>` matches the prefix of the corresponding reader.

| Reader | Setter |
|---|---|
| `pdf_page_rotation(page)` | `pdf_page_set_rotation(page, degrees)` |
| `pdf_page_box(page, box)` | `pdf_page_set_box(page, box, rect)` |
| `pdf_path_stroke(obj)` | `pdf_path_set_stroke(obj, ...)` (or `_set_stroke_width`/`_set_stroke_color`) |
| `pdf_text_content(obj)` | `pdf_text_set_content(obj, text)` |
| `pdf_doc_info(doc)$producer` | `pdf_doc_set_meta(doc, "Producer", value)` |

The verb-first form (`pdf_set_*`) is **not** used. Reader/writer
pairs cluster together in tab completion.

### 2. Handle-based identity

Setters take the same handle the matching reader takes. When the
reader is polymorphic (`pdf_page_rotation()` accepts a
`pdfium_page` OR a `pdfium_doc + page_num`), the setter is
polymorphic too — same `as_open_page()` dispatch.

There is one carve-out: setters that need to *return* the doc for
chaining (most of them) accept a `pdfium_page` as input but route
through its parent doc for the doc-level return value.

### 3. Polymorphic page argument

Mirrors the reader. The R-side dispatch goes through
`as_open_page(page, page_num)` which already accepts either shape.

### 4. Composite setters take named partial updates

The complex setters (color + width, font color + size, border
horizontal/vertical/width) accept a single composite call with
named partial arguments:

```r
pdf_path_set_stroke(obj, width = 2)       # changes only width
pdf_path_set_stroke(obj, red = 1, alpha = 0.5)  # changes only those
pdf_path_set_stroke(obj, color = c(1, 0, 0), width = 2)  # both
```

Internally each setter calls the underlying PDFium getter to read
the current state, overlays the named partial update, and calls
the corresponding setter(s). Reads cost one C call per attribute
not being updated — cheap for the common case.

### 5. Color shape: accept both 0-255 and 0-1, normalize internally

Setters inspect the input:

- Integer or numeric in `[0, 255]` with any value `> 1` → treat as
  0-255 ints (PDFium-native).
- Numeric in `[0, 1]` → treat as 0-1 doubles.
- Edge case: vector that's all-zeros or all-ones. Treat as 0-1
  doubles (the more common scientific convention).

The normalization is documented per setter; users can pass either.

### 6. Invisibly return the doc

Every setter returns the doc invisibly so chaining works:

```r
doc <- pdf_open("in.pdf", readwrite = TRUE)
doc |>
  pdf_page_set_rotation(1, 90) |>
  pdf_page_set_rotation(2, 180) |>
  pdf_save("out.pdf")
```

Setters that take a `pdfium_obj` / `pdfium_annot` / `pdfium_*`
handle still return the doc — chaining edits across multiple
objects on the same doc is the dominant use case.

## Consequences

- Phase 2 mutators (`pdf_set_page_rotation`, `pdf_set_page_box`,
  `pdf_set_doc_language`, `pdf_delete_page`, `pdf_new_doc`,
  `pdf_new_page`) must be renamed to follow the convention. The
  rename lands before any further phase begins.
- The polymorphic-page dispatch means every page-targeted setter
  uses the `as_open_page()` helper that already exists for
  readers. Free for free.
- Composite setters with named-partial-update are slightly more
  code per setter than a split setter, but eliminate ~half of the
  exports a split-setter shape would generate. ~20 fewer
  user-facing functions.
- The color-shape auto-detection is a small heuristic per setter;
  documented and unit-tested.

## Alternatives considered

- **Verb-first naming** (`pdf_set_*`): rejected — splits readers
  from writers in tab completion.
- **Indices everywhere** (`pdf_form_set_value(doc, field_index)`):
  rejected — already covered by ADR-017; readers return handles
  so writers take handles.
- **Split setters only** (no composite): rejected — explodes the
  export count; harder to discover.
- **One color shape (0-1 only)**: rejected — forces all existing
  0-255-returning readers to change, which is a separate (and
  noisier) decision.

## References

- `dev/mutation-design.md` §2 (the phase table).
- ADR-011 (mutation lifecycle).
- ADR-012 (readwrite flag).
- ADR-015, ADR-016 (annotation + page-obj authoring).
- ADR-017 (handle-returning readers).
