#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "nedtrie.h"

#define MAX_MAP_SIZE    0x2ffff
#define MAX_TRIE_SIZE   (1 << 21)
#define SFX_SIGNATURE   0x4c9da21d

typedef struct {
    U32 length;
    U32 code_table[];
} SpeedyFx;
typedef SpeedyFx *Text__SpeedyFx;

typedef struct sfxaa_s sfxaa_t;
struct sfxaa_s {
    NEDTRIE_ENTRY(sfxaa_s) link;
    U32 key;
    U32 val;
};
typedef struct sfxaa_tree_s sfxaa_tree_t;
NEDTRIE_HEAD(sfxaa_tree_s, sfxaa_s);

U32 sfxaakeyfunct(const sfxaa_t *r) {
    return r->key;
}

NEDTRIE_GENERATE(static, sfxaa_tree_s, sfxaa_s, link, sfxaakeyfunct, NEDTRIE_NOBBLEONES(sfxaa_tree_s))

typedef struct {
    U32 signature;
    U32 count;
    sfxaa_tree_t root;
    sfxaa_t *last;
    sfxaa_t index[MAX_TRIE_SIZE];
} SpeedyFxResult;
typedef SpeedyFxResult *Text__SpeedyFx__Result;

#if PERL_VERSION >= 16
#define ChrCode(u, v, len) (U32) utf8_to_uvchr_buf(u, v, len);
#else
#define ChrCode(u, v, len) (U32) utf8_to_uvchr(u, len)
#endif

#define SetBit(a, b)    (((U8 *) a)[(b) >> 3] |= (1 << ((b) & 7)))
#define FastMin(x, y)   (y ^ ((x ^ y) & -(x < y)))

SpeedyFx *new (U32 seed, U8 bits) {
    U32 i;
    U8 s[8];
    U8 *t;
    U8 u[8], *v;
    UV c;
    STRLEN len;
    U32 length, *code_table;
    static U32 fold_init = 0;
    static U32 fold_table[MAX_MAP_SIZE];
    U32 rand_table[MAX_MAP_SIZE];

    if (seed == 0)
        croak("seed must be not 0!");

    if (bits <= 8)
        length = 256;
    else if (bits > 17)
        length = MAX_MAP_SIZE;
    else
        length = 1 << bits;

    SpeedyFx *pSpeedyFx;
    Newxc(pSpeedyFx, 1 + length, U32, SpeedyFx);

    pSpeedyFx->length = length;
    code_table = pSpeedyFx->code_table;

    fold_table[0] = 0;
    if (fold_init < length) {
        for (i = fold_init + 1; i < length; i++) {
            if (i >= 0xd800 && i <= 0xdfff)         // high/low-surrogate code points
                c = 0;
            else if (i >= 0xfdd0 && i <= 0xfdef)    // noncharacters
                c = 0;
            else if ((i & 0xffff) == 0xfffe)        // noncharacters
                c = 0;
            else if ((i & 0xffff) == 0xffff)        // noncharacters
                c = 0;
            else {
                t = uvchr_to_utf8(s, (UV) i);
                *t = '\0';

                if (isALNUM_utf8(s)) {
                    (void) toLOWER_utf8(s, u, &len);
                    *(u + len) = '\0';
                    v = u + len;

                    c = ChrCode(u, v, &len);

                    // grow the tables, if necessary
                    if (length < c)
                        length = c;
                } else
                    c = 0;
            }
            fold_table[i] = c;
        }
        fold_init = length;
    }

    if (pSpeedyFx->length != length) {
        Renewc(pSpeedyFx, 1 + length, U32, SpeedyFx);

        pSpeedyFx->length = length;
        code_table = pSpeedyFx->code_table;
    }
    Zero(code_table, length, U32);

    rand_table[0] = seed;
    for (i = 1; i < length; i++)
        rand_table[i]
            = (
                rand_table[i - 1]
                * 0x10a860c1
            ) % 0xfffffffb;

    for (i = 0; i < length; i++)
        if (fold_table[i])
            code_table[i] = rand_table[fold_table[i]];

    return pSpeedyFx;
}

void DESTROY (SpeedyFx *pSpeedyFx) {
    Safefree(pSpeedyFx);
}

/**
 * C++ version 0.4 char* style "itoa":
 * Written by Lukás Chmela
 * Released under GPLv3.
 * http://www.jb.man.ac.uk/~slowe/cpp/itoa.html#newest
 */
U32 speedyfx_itoa(U32 value, char *result) {
    char *ptr = result, *ptr1 = result, tmp_char;
    U32 tmp_value, len;

    do {
        tmp_value = value;
        value /= 10;
        *ptr++ = "zyxwvutsrqponmlkjihgfedcba9876543210123456789abcdefghijklmnopqrstuvwxyz" [35 + (tmp_value - value * 10)];
    } while (value);

    len = ptr - result;
    *ptr-- = '\0';

    while (ptr1 < ptr) {
        tmp_char = *ptr;
        *ptr--= *ptr1;
        *ptr1++ = tmp_char;
    }

    return len;
}

#define _SPEEDYFX_INIT                                  \
    U32 code, c;                                        \
    U32 wordhash = 0;                                   \
    STRLEN len;                                         \
    U32 length = pSpeedyFx->length;                     \
    U32 *code_table = pSpeedyFx->code_table;            \
    U8 *s, *se;                                         \
    s = (U8 *) SvPV(str, len);                          \
    se = s + len;

#define _WALK_LATIN1    c = *s++
#define _WALK_UTF8      c = ChrCode(s, se, &len); s += len

#define _SPEEDYFX(_STORE, _WALK, _LENGTH)               \
    STMT_START {                                        \
        while (*s) {                                    \
            _WALK;                                      \
            if ((code = code_table[c % _LENGTH]) != 0)  \
                wordhash = (wordhash >> 1) + code;      \
            else if (wordhash) {                        \
                _STORE;                                 \
                wordhash = 0;                           \
            }                                           \
        }                                               \
        if (wordhash) {                                 \
            _STORE;                                     \
        }                                               \
    } STMT_END

#define _NEDTRIE_STORE                                  \
    tmp.key = wordhash;                                 \
    if ((p = NEDTRIE_FIND(sfxaa_tree_s, &sfxaatree, &tmp)) != 0)\
        p->val++;                                       \
    else {                                              \
        p = &uniq[count++];                             \
        p->key = wordhash;                              \
        p->val = 1;                                     \
        NEDTRIE_INSERT(sfxaa_tree_s, &sfxaatree, p);    \
        if (count >= MAX_TRIE_SIZE)                     \
            croak("too many unique tokens in a single data chunk"); \
    }

MODULE = Text::SpeedyFx::Result PACKAGE = Text::SpeedyFx::Result

PROTOTYPES: ENABLE

SV *
new (package, ...)
    char *package;
PREINIT:
    SpeedyFxResult *pSpeedyFxResult;
    HV *thingy;
    HV *stash;
    SV *tie;
    sfxaa_t *p;
CODE:
    Newx(pSpeedyFxResult, 1, SpeedyFxResult);
    pSpeedyFxResult->signature = SFX_SIGNATURE;
    pSpeedyFxResult->count = 0;

    NEDTRIE_INIT(&(pSpeedyFxResult->root));

    thingy = newHV();
    tie = newRV_noinc(newSViv(PTR2IV(pSpeedyFxResult)));
    stash = gv_stashpv(package, GV_ADD);
    sv_bless(tie, stash);
    hv_magic(thingy, (GV *) tie, PERL_MAGIC_tied);

    RETVAL = newRV_noinc((SV *) thingy);
OUTPUT:
    RETVAL

void
FETCH (pSpeedyFxResult, key)
    Text::SpeedyFx::Result pSpeedyFxResult
    SV *key
INIT:
    sfxaa_t *p, tmp;
PPCODE:
    tmp.key = SvNV(key);
    if ((p = NEDTRIE_FIND(sfxaa_tree_s, &(pSpeedyFxResult->root), &tmp)) == 0) {
        XSRETURN_UNDEF;
    } else {
        ST(0) = sv_2mortal(newSVnv(p->val));
        XSRETURN(1);
    }

void
STORE (pSpeedyFxResult, key, value)
    Text::SpeedyFx::Result pSpeedyFxResult
    SV *key
    SV *value
INIT:
    sfxaa_t *p;
PPCODE:
    p = &(pSpeedyFxResult->index[pSpeedyFxResult->count++]);
    p->key = SvNV(key);
    p->val = SvNV(value);
    NEDTRIE_INSERT(sfxaa_tree_s, &(pSpeedyFxResult->root), p);
    if (pSpeedyFxResult->count >= MAX_TRIE_SIZE)
        croak("too many unique tokens in a single data chunk");

void
DELETE (pSpeedyFxResult, key)
    Text::SpeedyFx::Result pSpeedyFxResult
    SV *key
PPCODE:
    croak("DELETE not implemented");
    XSRETURN(0);

void
CLEAR (pSpeedyFxResult)
    Text::SpeedyFx::Result pSpeedyFxResult
PPCODE:
    NEDTRIE_INIT(&(pSpeedyFxResult->root));
    pSpeedyFxResult->count = 0;
    XSRETURN(0);

void
EXISTS (pSpeedyFxResult, key)
    Text::SpeedyFx::Result pSpeedyFxResult
    SV *key
INIT:
    sfxaa_t *p, tmp;
PPCODE:
    tmp.key = SvNV(key);
    if ((p = NEDTRIE_FIND(sfxaa_tree_s, &(pSpeedyFxResult->root), &tmp)) == 0) {
        XSRETURN_NO;
    } else {
        XSRETURN_YES;
    }

void
FIRSTKEY (pSpeedyFxResult)
    Text::SpeedyFx::Result pSpeedyFxResult
INIT:
    sfxaa_t *p;
PPCODE:
    if ((p = NEDTRIE_MIN(sfxaa_tree_s, &(pSpeedyFxResult->root))) == 0) {
        XSRETURN_UNDEF;
    } else {
        pSpeedyFxResult->last = p;

        ST(0) = sv_2mortal(newSVnv(p->key));
        XSRETURN(1);
    }

void
NEXTKEY (pSpeedyFxResult, last)
    Text::SpeedyFx::Result pSpeedyFxResult
    SV *last
INIT:
    sfxaa_t *p;
PPCODE:
    if ((p = NEDTRIE_NEXT(sfxaa_tree_s, &(pSpeedyFxResult->root), pSpeedyFxResult->last)) == 0) {
        XSRETURN_UNDEF;
    } else {
        pSpeedyFxResult->last = p;

        ST(0) = sv_2mortal(newSVnv(p->key));
        XSRETURN(1);
    }

void
SCALAR (pSpeedyFxResult)
    Text::SpeedyFx::Result pSpeedyFxResult
PPCODE:
    ST(0) = sv_2mortal(newSVpvf("%d/%d", pSpeedyFxResult->count, MAX_TRIE_SIZE));
    XSRETURN(1);

void
UNTIE (pSpeedyFxResult)
    Text::SpeedyFx::Result pSpeedyFxResult
PPCODE:
    croak("UNTIE not implemented");
    XSRETURN(0);

void
DESTROY (pSpeedyFxResult)
    Text::SpeedyFx::Result pSpeedyFxResult
PPCODE:
    Safefree(pSpeedyFxResult);
    XSRETURN(0);

MODULE = Text::SpeedyFx PACKAGE = Text::SpeedyFx

PROTOTYPES: ENABLE

Text::SpeedyFx
new (package, ...)
    char *package
PREINIT:
    U32 seed = 1;
    U8 bits = 18;
CODE:
    if (items > 1)
        seed = SvNV(ST(1));
    if (items > 2)
        bits = SvNV(ST(2));

    RETVAL = new(seed, bits);
OUTPUT:
    RETVAL

SV *
peek_addr (self)
    SV *self
INIT:
    SV *hash;
    MAGIC *magic;
    SV *attr;
    SpeedyFxResult *pSpeedyFxResult;
CODE:
    hash = SvRV(self);
    if (SvRMAGICAL((SV *) hash)) {
        if ((magic = mg_find((SV *) hash, PERL_MAGIC_tied)) != NULL) {
            attr = magic->mg_obj;
            if (SvROK(attr)) {
                pSpeedyFxResult = (SpeedyFxResult *) SvIV(SvRV(attr));
                if (pSpeedyFxResult->signature == SFX_SIGNATURE) {
                    ST(0) = sv_2mortal(newSViv(SvIV(SvRV(attr))));
                    XSRETURN(1);
                }
            }
        }
    }
    XSRETURN_UNDEF;

void
hash (pSpeedyFx, str)
    Text::SpeedyFx pSpeedyFx
    SV *str
INIT:
    _SPEEDYFX_INIT;
    HV *results;
    static sfxaa_tree_t sfxaatree;
    sfxaa_t *uniq, tmp, *p;
    U32 count = 0;
    SV **ps;
    char buf[16];
PPCODE:
    NEDTRIE_INIT(&sfxaatree);

    Newx(uniq, MAX_TRIE_SIZE, sfxaa_t);

    if (length > 256) {
        _SPEEDYFX(_NEDTRIE_STORE, _WALK_UTF8, length);
    } else {
        _SPEEDYFX(_NEDTRIE_STORE, _WALK_LATIN1, 256);
    }

    results = newHV();
    NEDTRIE_FOREACH(p, sfxaa_tree_s, &sfxaatree) {
        length = speedyfx_itoa(p->key, buf);
        ps = hv_store(results, buf, length, newSVnv(p->val), 0);
    }
    Safefree(uniq);

    ST(0) = sv_2mortal((SV *) newRV_noinc((SV *) results));
    XSRETURN(1);

void
hash_fv (pSpeedyFx, str, n)
    Text::SpeedyFx pSpeedyFx
    SV *str
    U32 n
INIT:
    _SPEEDYFX_INIT;
    U32 size = ceil((float) n / 8.0);
    char *fv;
PPCODE:
    Newxz(fv, size, char);

    if (length > 256) {
        _SPEEDYFX(SetBit(fv, wordhash % n), _WALK_UTF8, length);
    } else {
        _SPEEDYFX(SetBit(fv, wordhash % n), _WALK_LATIN1, 256);
    }

    ST(0) = sv_2mortal(newSVpv(fv, size));
    XSRETURN(1);

void
hash_min (pSpeedyFx, str)
    Text::SpeedyFx pSpeedyFx
    SV *str
INIT:
    _SPEEDYFX_INIT;
    U32 min = 0xffffffff;
PPCODE:
    if (length > 256) {
        _SPEEDYFX(min = FastMin(min, wordhash), _WALK_UTF8, length);
    } else {
        _SPEEDYFX(min = FastMin(min, wordhash), _WALK_LATIN1, 256);
    }

    ST(0) = sv_2mortal(newSVnv(min));
    XSRETURN(1);
