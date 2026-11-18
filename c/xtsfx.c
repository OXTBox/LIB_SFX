/* xtsfx.c - hand-written C side of LIB_SFX: rfxgen (raysan5's sfxr) for xTalk.
 *
 * One file, C standard library only. No raylib, no audio device: this makes sounds,
 * it does not play them. A sound is 24 numbers (WaveParams); the DLL keeps ONE
 * "current" set, and every call reads or changes it. The script library
 * (livecode/lib_sfx.livecodescript) keeps one set per sound name and hands it over.
 *
 * Rules kept from the xt3d bridge:
 *   - no C string is ever returned: text goes into a buffer here, the call answers its
 *     length, and the .lcb reads it back with xtsfx_ResultByte;
 *   - every export is plain cdecl with int / double / const char* parameters.
 *
 * Build (Windows):  cl /nologo /O2 /MD /LD /TC xtsfx.c /Fe:xtsfx.dll
 * Build (Linux):    cc -O2 -shared -fPIC xtsfx.c -o xtsfx.so -lm
 */
#if defined(_MSC_VER) && !defined(_CRT_SECURE_NO_WARNINGS)
  #define _CRT_SECURE_NO_WARNINGS
#endif
#include <stdarg.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define XTSFX_VERSION "0.1.0"

#if defined(_WIN32)
  #define XTSFX_API __declspec(dllexport)
#else
  #define XTSFX_API __attribute__((visibility("default")))
#endif

/* ---------------------------------------------------------------- random numbers
 * Our own generator, so a seed gives the same sound on every machine and compiler
 * (the C library's rand() differs between them). */
static unsigned int xt_state = 0x2545F491u;
static int xt_seed_lock = 0;        /* 1: rfxgen's own reseeding is ignored */

static void xt_srand(unsigned int seed)
{
    if (xt_seed_lock) return;
    xt_state = seed*2654435761u + 0x9E3779B9u;
    if (xt_state == 0) xt_state = 0x2545F491u;
}

/* whole number from min to max, both included (as raylib's GetRandomValue) */
static int xt_rand(int min, int max)
{
    if (max < min) { int t = min; min = max; max = t; }
    xt_state ^= xt_state << 13;
    xt_state ^= xt_state >> 17;
    xt_state ^= xt_state << 5;
    return min + (int)(xt_state % (unsigned int)(max - min + 1));
}

/* rfxgen.h takes these two from raylib.h; we have no raylib here */
#ifndef PI
  #define PI 3.14159265358979323846f
#endif

#define RFXGEN_IMPLEMENTATION
#define RFXGEN_RAND(min, max)   xt_rand((min), (max))
#define RFXGEN_SRAND(seed)      xt_srand((unsigned int)(seed))
#define RFXGEN_LOG(...)         ((void)0)
#include "rfxgen.h"

/* ---------------------------------------------------------------- text results */
static char xt_result[16384];

static int xt_set(const char *fmt, ...)
{
    va_list args;
    int n;
    va_start(args, fmt);
    n = vsnprintf(xt_result, sizeof(xt_result), fmt, args);
    va_end(args);
    if (n < 0) n = 0;
    if (n >= (int)sizeof(xt_result)) n = (int)sizeof(xt_result) - 1;
    xt_result[n] = 0;
    return n;
}

XTSFX_API int xtsfx_ResultByte(int index)
{
    if (index < 0 || index >= (int)sizeof(xt_result)) return 0;
    return (unsigned char)xt_result[index];
}

/* ---------------------------------------------------------------- the current sound */
static WaveParams xt_params;
static int xt_started = 0;
static unsigned int xt_counter = 0;

/* The 24 numbers in the order they sit in WaveParams (and in a .rfx file).
 * The first two are whole numbers, the rest are floats. */
#define XT_PARAM_COUNT 24
static const char *xt_names[XT_PARAM_COUNT] = {
    "randSeed", "waveType",
    "attackTime", "sustainTime", "sustainPunch", "decayTime",
    "startFrequency", "minFrequency", "slide", "deltaSlide", "vibratoDepth", "vibratoSpeed",
    "changeAmount", "changeSpeed",
    "squareDuty", "dutySweep",
    "repeatSpeed",
    "phaserOffset", "phaserSweep",
    "lpfCutoff", "lpfCutoffSweep", "lpfResonance", "hpfCutoff", "hpfCutoffSweep"
};

typedef char xt_check_size[(sizeof(WaveParams) == XT_PARAM_COUNT*4) ? 1 : -1];

static void xt_start(void)
{
    if (xt_started) return;
    xt_started = 1;
    xt_srand((unsigned int)time(NULL));
    ResetWaveParams(&xt_params);
}

/* a seed of 0 means "a new one each time" */
static void xt_seed(int seed)
{
    xt_seed_lock = 0;
    if (seed == 0) xt_srand((unsigned int)time(NULL) ^ (xt_counter++ * 7919u) ^ xt_state);
    else xt_srand((unsigned int)seed);
}

static int xt_same(const char *a, const char *b)      /* compare, ignoring case */
{
    for (; *a && *b; a++, b++)
    {
        int ca = *a, cb = *b;
        if (ca >= 'A' && ca <= 'Z') ca += 32;
        if (cb >= 'A' && cb <= 'Z') cb += 32;
        if (ca != cb) return 0;
    }
    return *a == *b;
}

static int xt_index(const char *name)
{
    int i;
    if (!name) return -1;
    for (i = 0; i < XT_PARAM_COUNT; i++) if (xt_same(name, xt_names[i])) return i;
    return -1;
}

static double xt_get(int i)
{
    if (i == 0) return xt_params.randSeed;
    if (i == 1) return xt_params.waveTypeValue;
    return ((float *)&xt_params)[i];
}

static void xt_put(int i, double value)
{
    if (i == 0) xt_params.randSeed = (int)value;
    else if (i == 1)
    {
        int w = (int)value;
        if (w < 0) w = 0;
        if (w > 3) w = 3;
        xt_params.waveTypeValue = w;
    }
    else ((float *)&xt_params)[i] = (float)value;
}

XTSFX_API int xtsfx_Version(void)
{
    return xt_set("xtsfx %s / rfxgen 5.0", XTSFX_VERSION);
}

/* Back to the plain starting sound. */
XTSFX_API void xtsfx_Reset(void)
{
    xt_start();
    xt_seed(0);
    ResetWaveParams(&xt_params);
}

/* Answers the preset names, comma separated. */
XTSFX_API int xtsfx_Presets(void)
{
    return xt_set("coin,laser,explosion,powerup,hit,jump,blip,random");
}

/* Makes the current sound from a preset. The same preset and seed always give the
 * same sound; seed 0 gives a new one each time. Answers 1, or 0 for an unknown preset. */
XTSFX_API int xtsfx_Preset(const char *preset, int seed)
{
    WaveParams made;
    xt_start();
    if (!preset) return 0;
    xt_seed(seed);
    xt_seed_lock = 1;       /* the preset reseeds itself from its own numbers: keep ours */
    if      (xt_same(preset, "coin"))      made = GenPickupCoin();
    else if (xt_same(preset, "laser"))     made = GenLaserShoot();
    else if (xt_same(preset, "explosion")) made = GenExplosion();
    else if (xt_same(preset, "powerup"))   made = GenPowerup();
    else if (xt_same(preset, "hit"))       made = GenHitHurt();
    else if (xt_same(preset, "jump"))      made = GenJump();
    else if (xt_same(preset, "blip"))      made = GenBlipSelect();
    else if (xt_same(preset, "random"))    made = GenRandomize();
    else { xt_seed_lock = 0; return 0; }
    xt_seed_lock = 0;
    xt_params = made;
    return 1;
}

/* Nudges the current sound a little. Same seed, same nudge; 0 = a new one each time. */
XTSFX_API void xtsfx_Mutate(int seed)
{
    xt_start();
    xt_seed(seed);
    xt_seed_lock = 1;       /* WaveMutate reseeds from the clock: keep ours */
    WaveMutate(&xt_params);
    xt_seed_lock = 0;
}

/* Sets one number of the current sound by name. Answers 1, or 0 for an unknown name. */
XTSFX_API int xtsfx_SetParam(const char *name, double value)
{
    int i = xt_index(name);
    xt_start();
    if (i < 0) return 0;
    xt_put(i, value);
    return 1;
}

XTSFX_API double xtsfx_GetParam(const char *name)
{
    int i = xt_index(name);
    xt_start();
    if (i < 0) return 0.0;
    return xt_get(i);
}

/* The current sound as text: 24 lines of name=value. */
XTSFX_API int xtsfx_GetParams(void)
{
    char text[4096];
    int i, used = 0;
    xt_start();
    for (i = 0; i < XT_PARAM_COUNT; i++)
    {
        if (i < 2) used += snprintf(text + used, sizeof(text) - used, "%s=%d\n", xt_names[i], (int)xt_get(i));
        else used += snprintf(text + used, sizeof(text) - used, "%s=%.9g\n", xt_names[i], xt_get(i));
    }
    if (used > 0) text[used - 1] = 0;     /* no line end after the last one */
    return xt_set("%s", text);
}

/* Takes lines of name=value (any of the 24, any order). Lines it does not know are
 * skipped. Answers how many numbers it set. */
XTSFX_API int xtsfx_SetParams(const char *text)
{
    int count = 0;
    xt_start();
    if (!text) return 0;
    while (*text)
    {
        char name[64];
        int n = 0, i;
        while (*text == ' ' || *text == '\t' || *text == '\r' || *text == '\n') text++;
        while (*text && *text != '=' && *text != '\n' && *text != '\r')
        {
            if (n < 63 && *text != ' ' && *text != '\t') name[n++] = *text;
            text++;
        }
        name[n] = 0;
        if (*text == '=')
        {
            char *end;
            double value = strtod(text + 1, &end);
            i = xt_index(name);
            if (i >= 0 && end != text + 1) { xt_put(i, value); count++; }
            text = end;
        }
        while (*text && *text != '\n') text++;
    }
    return count;
}

/* Reads a .rfx file (rFXGen's own 104-byte format) into the current sound.
 * Answers 1, or 0 when the file is missing or is not a .rfx: the sound is then unchanged. */
XTSFX_API int xtsfx_LoadRfx(const char *path)
{
    unsigned char head[8];
    WaveParams loaded;
    FILE *f;
    xt_start();
    if (!path) return 0;
    f = fopen(path, "rb");
    if (!f) return 0;
    if (fread(head, 1, 8, f) != 8 || memcmp(head, "rFX ", 4) != 0
        || (head[4] | (head[5] << 8)) != 200 || (head[6] | (head[7] << 8)) != (int)sizeof(WaveParams)
        || fread(&loaded, 1, sizeof(WaveParams), f) != sizeof(WaveParams))
    {
        fclose(f);
        return 0;
    }
    fclose(f);
    xt_params = loaded;
    if (xt_params.waveTypeValue < 0 || xt_params.waveTypeValue > 3) xt_params.waveTypeValue = 0;
    return 1;
}

/* Writes the current sound as a .rfx file rFXGen can open. Answers 1 or 0. */
XTSFX_API int xtsfx_SaveRfx(const char *path)
{
    unsigned char head[8] = { 'r', 'F', 'X', ' ', 200, 0, (unsigned char)sizeof(WaveParams), 0 };
    FILE *f;
    int ok;
    xt_start();
    if (!path) return 0;
    f = fopen(path, "wb");
    if (!f) return 0;
    ok = (fwrite(head, 1, 8, f) == 8) && (fwrite(&xt_params, 1, sizeof(WaveParams), f) == sizeof(WaveParams));
    if (fclose(f) != 0) ok = 0;
    return ok;
}

static float *xt_generate(unsigned int *frames)
{
    xt_start();
    xt_seed_lock = 0;
    *frames = 0;
    return GenerateWave(xt_params, frames);
}

/* How long the current sound lasts, in seconds. */
XTSFX_API double xtsfx_Duration(void)
{
    unsigned int frames = 0;
    float *data = xt_generate(&frames);
    if (data) RFXGEN_FREE(data);
    return (double)frames/RFXGEN_GEN_SAMPLE_RATE;
}

/* The shape of the current sound for drawing: `count` loudness values from 0 to 1000,
 * comma separated, left to right. count is 1 to 1000. */
XTSFX_API int xtsfx_Peaks(int count)
{
    unsigned int frames = 0, i;
    float *data;
    int c, used = 0;
    if (count < 1) count = 1;
    if (count > 1000) count = 1000;
    data = xt_generate(&frames);
    if (!data || frames == 0) { if (data) RFXGEN_FREE(data); return xt_set("%s", ""); }
    xt_result[0] = 0;
    for (c = 0; c < count; c++)
    {
        unsigned int from = (unsigned int)(((double)c*frames)/count);
        unsigned int to = (unsigned int)(((double)(c + 1)*frames)/count);
        float peak = 0.0f;
        if (to <= from) to = from + 1;
        if (to > frames) to = frames;
        for (i = from; i < to; i++)
        {
            float v = data[i] < 0 ? -data[i] : data[i];
            if (v > peak) peak = v;
        }
        used += snprintf(xt_result + used, sizeof(xt_result) - used, c ? ",%d" : "%d", (int)(peak*1000.0f + 0.5f));
    }
    RFXGEN_FREE(data);
    return used;
}

static void xt_w16(FILE *f, unsigned int v) { fputc(v & 255, f); fputc((v >> 8) & 255, f); }
static void xt_w32(FILE *f, unsigned int v) { xt_w16(f, v & 65535u); xt_w16(f, v >> 16); }

/* Writes the current sound as a .wav file.
 *   rate:     44100 or 22050      (anything else: 44100)
 *   bits:     16 or 8             (anything else: 16)
 *   channels: 1 or 2              (anything else: 1)
 * Answers the number of sample frames written, or 0 when it failed. */
XTSFX_API int xtsfx_ExportWav(const char *path, int rate, int bits, int channels)
{
    unsigned int frames = 0, outFrames, i;
    int step, bytes, ch;
    float *data;
    FILE *f;
    if (!path) return 0;
    if (rate != 22050) rate = 44100;
    if (bits != 8) bits = 16;
    if (channels != 2) channels = 1;
    step = (rate == 22050) ? 2 : 1;
    bytes = bits/8;

    data = xt_generate(&frames);
    if (!data || frames == 0) { if (data) RFXGEN_FREE(data); return 0; }
    outFrames = frames/step;
    if (outFrames == 0) { RFXGEN_FREE(data); return 0; }

    f = fopen(path, "wb");
    if (!f) { RFXGEN_FREE(data); return 0; }
    fwrite("RIFF", 1, 4, f); xt_w32(f, 36 + outFrames*channels*bytes);
    fwrite("WAVE", 1, 4, f);
    fwrite("fmt ", 1, 4, f); xt_w32(f, 16);
    xt_w16(f, 1);                                   /* PCM */
    xt_w16(f, (unsigned int)channels);
    xt_w32(f, (unsigned int)rate);
    xt_w32(f, (unsigned int)(rate*channels*bytes));
    xt_w16(f, (unsigned int)(channels*bytes));
    xt_w16(f, (unsigned int)bits);
    fwrite("data", 1, 4, f); xt_w32(f, outFrames*channels*bytes);
    for (i = 0; i < outFrames; i++)
    {
        float v = data[i*step];
        if (step == 2 && i*step + 1 < frames) v = (v + data[i*step + 1])*0.5f;
        if (v > 1.0f) v = 1.0f;
        if (v < -1.0f) v = -1.0f;
        for (ch = 0; ch < channels; ch++)
        {
            if (bits == 8) fputc((int)(v*127.0f + 128.0f), f);         /* 8 bit wav is unsigned */
            else xt_w16(f, (unsigned int)(int)(v*32767.0f) & 65535u);
        }
    }
    RFXGEN_FREE(data);
    if (fclose(f) != 0) return 0;
    return (int)outFrames;
}
