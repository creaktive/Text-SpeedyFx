#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#define MAP_SIZE 0x2ffff

typedef struct {
    U32 code_table[MAP_SIZE];
} SpeedyFx;

typedef SpeedyFx *Text__SpeedyFx;

SpeedyFx *new (U32 seed) {
    U32 i;
    U8 s[8];
    U8 *t;
    U8 u[8];
    UV c;
    STRLEN len;
    static U8 fold_init = 0;
    static U32 fold_table[MAP_SIZE];
    U32 rand_table[MAP_SIZE];
    SpeedyFx *pSpeedyFx = (SpeedyFx *) calloc(1, sizeof(SpeedyFx));

    if (fold_init == 0) {
        for (i = 0; i < MAP_SIZE; i++) {
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
                } else
                    c = 0;
            }
            fold_table[i] = c;
        }
        fold_init = 1;
    }

    rand_table[0]
        = seed
            ? seed
            : 1;

    for (i = 1; i < MAP_SIZE; i++)
        rand_table[i]
            = (
                rand_table[i - 1]
                * 0x10a860c1
            ) % 0xfffffffb;

    for (i = 0; i < MAP_SIZE; i++)
        if (fold_table[i])
            pSpeedyFx->code_table[i] = rand_table[fold_table[i]];

    return pSpeedyFx;
}

void DESTROY (SpeedyFx *pSpeedyFx) {
    free(pSpeedyFx);
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


    while (*s) {
        c = utf8_to_uvchr(s, &len);
        s += len;

        if (code = pSpeedyFx->code_table[c % MAP_SIZE])
            wordhash
                = (wordhash >> 1)
                + code;
        else if (wordhash)
            _store(r, &wordhash);
    }
    _store(r, &wordhash);

    return r;
}

AV *hash_fv (SpeedyFx *pSpeedyFx, const char *s, U16 n) {
    U32 code;
    U32 wordhash = 0;
    U32 i = 0;
    UV c;
    STRLEN len;
    AV *r = (AV *) sv_2mortal((SV *) newAV());
    U8 *fv = (U8 *) calloc(1, n);

    while (*s) {
        c = utf8_to_uvchr(s, &len);
        s += len;

        if (code = pSpeedyFx->code_table[c % MAP_SIZE])
            wordhash
                = (wordhash >> 1)
                + code;
        else if (wordhash) {
            fv[wordhash % n] = 1;
            wordhash = 0;
        }
    }
    if (wordhash)
        fv[wordhash % n] = 1;

    for (i = 0; i < n; i++)
        av_push(r, newSVnv(fv[i]));

    free(fv);
    return r;
}

SV *hash_min (SpeedyFx *pSpeedyFx, const char *s) {
    U32 code;
    U32 wordhash = 0;
    U32 min = 0xffffffff;
    UV c;
    STRLEN len;

    while (*s) {
        c = utf8_to_uvchr(s, &len);
        s += len;

        if (code = pSpeedyFx->code_table[c % MAP_SIZE])
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
CODE:
    if (items > 1)
        seed = SvNV(ST(1));
    RETVAL = new(seed);
OUTPUT:
    RETVAL

HV *
hash (pSpeedyFx, str)
    Text::SpeedyFx pSpeedyFx
    const char *str

AV *
hash_fv (pSpeedyFx, str, n)
    Text::SpeedyFx pSpeedyFx
    const char *str
    U16 n

SV *
hash_min (pSpeedyFx, str)
    Text::SpeedyFx pSpeedyFx
    const char *str
