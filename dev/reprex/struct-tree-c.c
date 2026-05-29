/*
 * Standalone C reprex for the macOS arm64 segfault triggered by
 * cpp_struct_tree_page → PDFium structure-tree walk.
 *
 * If this program reproduces the crash under ASan on Linux, the
 * bug is in PDFium (or in our build), not in R/Rcpp glue. If it
 * passes cleanly on Linux but reproduces on macOS arm64, the bug
 * is macOS-arm64-specific to PDFium (or to its system-library
 * interactions like CoreText).
 *
 * Build:
 *   gcc -O1 -g -fno-omit-frame-pointer -fsanitize=address,undefined \
 *       -I../../inst/include -L../../inst/lib -Wl,-rpath,../../inst/lib \
 *       struct-tree-c.c -lpdfium -o struct-tree-c
 *
 * Run:
 *   ./struct-tree-c ../../inst/extdata/fixtures/tagged.pdf
 *
 * Exit codes:
 *   0   success
 *   >0  PDFium reported an error (see stderr)
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "fpdfview.h"
#include "fpdf_structtree.h"

#define MAX_DEPTH 32
#define MAX_BUFLEN 4096

/* Match what rpdfium's read_struct_string does: probe size, alloc,
 * read, decode (we skip UTF-16 decoding here — the bytes are what
 * matter for memory safety, not the encoding). */
static void read_string_attr(FPDF_STRUCTELEMENT element,
                              const char *name,
                              char *out, size_t out_len) {
    unsigned long need =
        FPDF_StructElement_GetStringAttribute(element, name, NULL, 0);
    if (need <= 2 || need > out_len) {
        if (out_len > 0) out[0] = '\0';
        return;
    }
    /* PDFium emits UTF-16LE bytes; we only care about how many bytes
     * are written, not their meaning. */
    unsigned short tmp[MAX_BUFLEN / 2];
    if (need / 2 > MAX_BUFLEN / 2) need = MAX_BUFLEN;
    FPDF_StructElement_GetStringAttribute(element, name, tmp, need);
    /* ASCII-flatten (every other byte). */
    size_t out_i = 0;
    for (size_t i = 0; i < need / 2 - 1 && out_i + 1 < out_len; i++) {
        unsigned char c = (unsigned char)(tmp[i] & 0xFF);
        out[out_i++] = (c >= 0x20 && c < 0x7F) ? (char)c : '.';
    }
    if (out_i < out_len) out[out_i] = '\0';
}

/* Iterate attribute *objects* on an element and read every key. This
 * mirrors rpdfium's read_struct_attributes loop. */
static void walk_attrs(FPDF_STRUCTELEMENT element, int depth) {
    int n_attrs = FPDF_StructElement_GetAttributeCount(element);
    if (n_attrs <= 0) return;
    for (int a = 0; a < n_attrs; a++) {
        FPDF_STRUCTELEMENT_ATTR attr =
            FPDF_StructElement_GetAttributeAtIndex(element, a);
        if (!attr) continue;
        int n_keys = FPDF_StructElement_Attr_GetCount(attr);
        if (n_keys <= 0) continue;
        for (int k = 0; k < n_keys; k++) {
            unsigned long key_buflen = 0;
            if (!FPDF_StructElement_Attr_GetName(attr, k, NULL, 0,
                                                  &key_buflen)) {
                continue;
            }
            if (key_buflen <= 1) continue;
            char key_buf[256];
            if (key_buflen > sizeof(key_buf)) key_buflen = sizeof(key_buf);
            FPDF_StructElement_Attr_GetName(attr, k, key_buf,
                                              key_buflen, &key_buflen);
            FPDF_STRUCTELEMENT_ATTR_VALUE val =
                FPDF_StructElement_Attr_GetValue(attr, key_buf);
            if (!val) continue;
            int t = FPDF_StructElement_Attr_GetType(val);
            printf("%*s  attr a=%d k=%d name=%.*s type=%d\n",
                   depth * 2, "", a, k,
                   (int)(key_buflen - 1), key_buf, t);
            /* Exercise the value getters too — this matches the test
             * case that crashes (`/A` array with /Layout, /Block, BBox). */
            if (t == FPDF_OBJECT_STRING || t == FPDF_OBJECT_NAME) {
                unsigned long sneed = 0;
                if (FPDF_StructElement_Attr_GetStringValue(val, NULL, 0,
                                                            &sneed)) {
                    if (sneed > 2 && sneed < MAX_BUFLEN) {
                        unsigned short sbuf[MAX_BUFLEN / 2];
                        FPDF_StructElement_Attr_GetStringValue(val, sbuf,
                                                                sneed, &sneed);
                    }
                }
            } else if (t == FPDF_OBJECT_NUMBER) {
                float f = 0.f;
                FPDF_StructElement_Attr_GetNumberValue(val, &f);
            } else if (t == FPDF_OBJECT_BOOLEAN) {
                FPDF_BOOL b = 0;
                FPDF_StructElement_Attr_GetBooleanValue(val, &b);
            } else if (t == FPDF_OBJECT_ARRAY) {
                int nc = FPDF_StructElement_Attr_CountChildren(val);
                for (int c = 0; c < nc; c++) {
                    FPDF_STRUCTELEMENT_ATTR_VALUE child =
                        FPDF_StructElement_Attr_GetChildAtIndex(val, c);
                    (void)child;
                }
            }
        }
    }
}

static void walk_element(FPDF_STRUCTELEMENT element, int depth) {
    if (!element || depth > MAX_DEPTH) return;
    /* Read every per-attribute string that read_string_attribute()
     * inside cpp_struct_tree_page would: Placement, O, Headers, plus
     * the inherent getters (Type, Title, Lang, AltText, etc.) */
    char type_buf[256];
    read_string_attr(element, "Type", type_buf, sizeof(type_buf));
    char placement_buf[256];
    read_string_attr(element, "Placement", placement_buf,
                     sizeof(placement_buf));
    char o_buf[256];
    read_string_attr(element, "O", o_buf, sizeof(o_buf));
    char headers_buf[256];
    read_string_attr(element, "Headers", headers_buf, sizeof(headers_buf));
    printf("%*sdepth=%d Placement='%s' O='%s' Headers='%s'\n",
           depth * 2, "", depth, placement_buf, o_buf, headers_buf);

    walk_attrs(element, depth);

    int n = FPDF_StructElement_CountChildren(element);
    for (int i = 0; i < n; i++) {
        FPDF_STRUCTELEMENT child =
            FPDF_StructElement_GetChildAtIndex(element, i);
        walk_element(child, depth + 1);
    }
}

int main(int argc, char **argv) {
    if (argc != 2) {
        fprintf(stderr, "usage: %s <pdf-file>\n", argv[0]);
        return 1;
    }
    const char *path = argv[1];

    FPDF_LIBRARY_CONFIG cfg = {0};
    cfg.version = 2;
    FPDF_InitLibraryWithConfig(&cfg);

    FPDF_DOCUMENT doc = FPDF_LoadDocument(path, NULL);
    if (!doc) {
        fprintf(stderr, "FPDF_LoadDocument failed for %s (err=%lu)\n",
                path, FPDF_GetLastError());
        FPDF_DestroyLibrary();
        return 2;
    }
    int n_pages = FPDF_GetPageCount(doc);
    printf("doc opened: %s, pages=%d\n", path, n_pages);

    for (int p = 0; p < n_pages; p++) {
        FPDF_PAGE page = FPDF_LoadPage(doc, p);
        if (!page) continue;
        printf("== page %d ==\n", p);
        FPDF_STRUCTTREE tree = FPDF_StructTree_GetForPage(page);
        if (tree) {
            int top = FPDF_StructTree_CountChildren(tree);
            for (int i = 0; i < top; i++) {
                FPDF_STRUCTELEMENT child =
                    FPDF_StructTree_GetChildAtIndex(tree, i);
                walk_element(child, 0);
            }
            FPDF_StructTree_Close(tree);
        } else {
            printf("  (no structure tree)\n");
        }
        FPDF_ClosePage(page);
    }

    FPDF_CloseDocument(doc);
    FPDF_DestroyLibrary();
    printf("\nSTANDALONE C REPREX OK\n");
    return 0;
}
