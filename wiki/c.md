**Type punning example (GCC/Clang extension, UB in strict standard C):**

```c
union {
    float f;
    uint32_t i;
} u;

u.f = 1.0f;
printf("%x\n", u.i);   // reads the bit pattern of the float as an int
                        // NOT what you wrote (u.f) — this is "type punning"
```
This compiles and works predictably under GCC/Clang, but strict ISO C (C99) says reading a member other than the last one written is UB — only C11's *common initial sequence* rule carves out a narrow exception for structs sharing a prefix inside a union. GCC documents its extension explicitly: https://gcc.gnu.org/onlinedocs/gcc/Type-punning.html

---

**X-Macro example — tag enum and union stay in sync automatically:**

```c
#define VALUE_TYPES \
    X(TAG_INT,   int,    i) \
    X(TAG_FLOAT, float,  f) \
    X(TAG_STR,   char*,  s)

// generate the enum
typedef enum {
#define X(tag, type, field) tag,
    VALUE_TYPES
#undef X
} Tag;

// generate the union
typedef struct {
    Tag tag;
    union {
#define X(tag, type, field) type field;
        VALUE_TYPES
#undef X
    };
} Value;

// generate a print function — same list, no drift possible
void print_value(Value v) {
    switch (v.tag) {
#define X(tag, type, field) case tag: printf("%s\n", #field); break;
        VALUE_TYPES
#undef X
    }
}
```
Add one line to `VALUE_TYPES` and the enum, union, and switch all update together — that's the whole point: https://en.wikipedia.org/wiki/X_Macro

---

**SQLite's real one** (`sqlite3.c`, `Mem` struct) — worth reading because it's the same pattern at production scale: a `u.r` (double), `u.i` (int64), `u.nZero`, etc. inside a union, gated by a `flags` bitmask instead of a plain enum tag, since a `Mem` can validly hold cached representations of *multiple* types at once (e.g. both int and its string form) — a more advanced variant of the tagged-union idea: https://sqlite.org/src/file/src/vdbeInt.h
