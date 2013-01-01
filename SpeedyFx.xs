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

#if PERL_VERSION >= 16
#define ChrCode(u, v, len) (U32) utf8_to_uvchr_buf(u, v, len);
#else
#define ChrCode(u, v, len) (U32) utf8_to_uvchr(u, len)
#endif

#define SetBit(a, b) (((U8 *) a)[(b) >> 3] |= (1 << ((b) & 7)))

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

void speedyfx_store(HV *r, U32 wordhash) {
    double count = 1;
    char buf[16];
    U32 len;
    SV **ps;

    if (wordhash) {
        len = speedyfx_itoa(wordhash, buf);

        ps = hv_fetch(r, buf, len, 0);
        if (ps && SvOK(*ps))
            count = SvNV(*ps) + 1;

        ps = hv_store(r, buf, len, newSVnv(count), 0);
    }
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

void
hash (pSpeedyFx, str)
    Text::SpeedyFx pSpeedyFx
    SV *str
INIT:
    _SPEEDYFX_INIT;
    HV *results = newHV();
PPCODE:
    if (length > 256) {
        _SPEEDYFX(speedyfx_store(results, wordhash), _WALK_UTF8, length);
    } else {
        _SPEEDYFX(speedyfx_store(results, wordhash), _WALK_LATIN1, 256);
    }

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
    Newxz(fv, size, char);
PPCODE:
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
        _SPEEDYFX(if (min > wordhash) min = wordhash, _WALK_UTF8, length);
    } else {
        _SPEEDYFX(if (min > wordhash) min = wordhash, _WALK_LATIN1, 256);
    }

    ST(0) = sv_2mortal(newSVnv(min));
    XSRETURN(1);
