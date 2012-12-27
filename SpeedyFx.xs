#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#define MAX_MAP_SIZE 0x2ffff

typedef struct {
    U32 length;
    U32 code_table[];
} SpeedyFx;

typedef SpeedyFx *Text__SpeedyFx;

SpeedyFx *new (U32 seed, U8 bits) {
    U32 i;
    U8 s[8];
    U8 *t;
    U8 u[8];
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
    Newxz(pSpeedyFx, 1 + length, U32);

    pSpeedyFx->length = length;
    code_table = pSpeedyFx->code_table;

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

                    c = utf8_to_uvchr(u, &len);

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
        Renew(pSpeedyFx, 1 + length, U32);

        pSpeedyFx->length = length;
        code_table = pSpeedyFx->code_table;
    }

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

void _store(HV *r, U32 *wordhash) {
    double count = 1;
    U8 buf[16];
    U8 len;
    SV **ps;

    if (*wordhash) {
        sprintf(buf, "%u", (unsigned int) *wordhash);
        len = strlen(buf);

        ps = hv_fetch(r, buf, len, 0);
        if (ps && SvOK(*ps))
            count = SvNV(*ps) + 1;

        hv_store(r, buf, len, newSVnv(count), 0);

        *wordhash = 0;
    }
}

HV *hash (SpeedyFx *pSpeedyFx, const char *s) {
    U32 code;
    U32 wordhash = 0;
    UV c;
    STRLEN len;
    HV *r = (HV *) sv_2mortal((SV *) newHV());

    U32 length = pSpeedyFx->length;
    U32 *code_table = pSpeedyFx->code_table;

    while (*s) {
        if (length > 256) {
            c = utf8_to_uvchr(s, &len);
            s += len;
        } else
            c = *s++;

        if (code = code_table[c % length])
            wordhash
                = (wordhash >> 1)
                + code;
        else if (wordhash)
            _store(r, &wordhash);
    }
    _store(r, &wordhash);

    return r;
}

#define SetBit(a, b) (((U8 *) a)[(b) >> 3] |= (1 << ((b) & 7)))

SV *hash_fv (SpeedyFx *pSpeedyFx, const char *s, U32 n) {
    U32 code;
    U32 wordhash = 0;
    U32 i = 0;
    UV c;
    STRLEN len;
    U32 size = ceil((float) n / 8.0);
    U8 *fv;
    Newxz(fv, size, U8);

    U32 length = pSpeedyFx->length;
    U32 *code_table = pSpeedyFx->code_table;

    while (*s) {
        if (length > 256) {
            c = utf8_to_uvchr(s, &len);
            s += len;
        } else
            c = *s++;

        if (code = code_table[c % length])
            wordhash
                = (wordhash >> 1)
                + code;
        else if (wordhash) {
            SetBit(fv, wordhash % n);
            wordhash = 0;
        }
    }
    if (wordhash)
        SetBit(fv, wordhash % n);

    return newSVpv(fv, size);
}

SV *hash_min (SpeedyFx *pSpeedyFx, const char *s) {
    U32 code;
    U32 wordhash = 0;
    U32 min = 0xffffffff;
    UV c;
    STRLEN len;

    U32 length = pSpeedyFx->length;
    U32 *code_table = pSpeedyFx->code_table;

    while (*s) {
        if (length > 256) {
            c = utf8_to_uvchr(s, &len);
            s += len;
        } else
            c = *s++;

        if (code = code_table[c % length])
            wordhash
                = (wordhash >> 1)
                + code;
        else if (wordhash) {
            if (min > wordhash)
                min = wordhash;

            wordhash = 0;
        }
    }
    if (wordhash && min > wordhash)
        min = wordhash;

    return newSVnv(min);
}

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

HV *
hash (pSpeedyFx, str)
    Text::SpeedyFx pSpeedyFx
    const char *str

SV *
hash_fv (pSpeedyFx, str, n)
    Text::SpeedyFx pSpeedyFx
    const char *str
    U32 n

SV *
hash_min (pSpeedyFx, str)
    Text::SpeedyFx pSpeedyFx
    const char *str
