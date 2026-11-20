# LIB_SFX: game sound effects from numbers

Wednesday, November 18, 2026. Built by Claude (Fable 5.2) at the owner's request, from
`LIB_LLMIN/Raylib-rfxgen-master` (now in `LIB_LLMOUT/Read/LIB_SFX/`).

A bridge from xTalk to **rfxgen**, raysan5's sound-effect generator (the sfxr family: coin,
laser, explosion, power-up, hit, jump, blip). A sound is 24 numbers; no sound files are needed.
It stands alone: no raylib, no xt3d, no audio library. It makes `.wav` files and the engine's
own `play` plays them, so Vibecode3D games can use it as well as xt3d games.

```
xTalk script ──▶ lib_sfx.livecodescript ──▶ xtsfx.lcb ──▶ xtsfx.dll  (c/xtsfx.c + c/rfxgen.h)
 Sfx.Make / Sfx.Play     keeps sounds by name    the binding    makes the wave, writes .wav / .rfx
```

## Use

1. Once: close LiveCode, double-click `build.bat`. It compiles the DLL and the extension into
   `C:\xtsfx\extension`. No Extension Builder step.
2. In a stack:

```
start using stack "<path>/LIB_SFX/livecode/lib_sfx.livecodescript"
Sfx.Start
Sfx.Make "pickup", "coin", 7      -- name, preset, seed: the same seed is the same sound everywhere
Sfx.Play "pickup"
```

Every command leaves `the result` empty when it worked, or one line saying why not.

| Call | What it does |
|---|---|
| `Sfx.Start [folder]` | loads the extension (default `C:/xtsfx/extension`) |
| `Sfx.SetFolder folder` | where the `.wav` files go (default: the temporary folder `/xtsfx`) |
| `Sfx.Make name, preset, [seed]` | presets: coin, laser, explosion, powerup, hit, jump, blip, random |
| `Sfx.Play name` / `Sfx.Stop` | one sound at a time |
| `Sfx.Set name, param, value` | change one of the 24 numbers |
| `Sfx.SetParams name, text` | several at once, lines of `name=value`; makes the sound if it is new |
| `Sfx.Mutate name, [seed]` | nudge it a little |
| `Sfx.Save name, file` / `Sfx.Load name, file` | `.rfx`, rFXGen's own 104-byte file |
| `Sfx.Export name, file, [rate], [bits], [channels]` | a `.wav` anywhere: 44100 or 22050, 16 or 8, 1 or 2 |
| `Sfx.Forget name` | drop it |
| `Sfx.Names()`, `Sfx.Has(name)`, `Sfx.Params(name)`, `Sfx.Get(name, param)` | what there is |
| `Sfx.File(name)`, `Sfx.Duration(name)`, `Sfx.Peaks(name, count)` | the `.wav` path, seconds, the shape for drawing (0..1000) |

The 24 numbers: `randSeed`, `waveType` (0 square, 1 sawtooth, 2 sine, 3 noise), `attackTime`,
`sustainTime`, `sustainPunch`, `decayTime`, `startFrequency`, `minFrequency`, `slide`,
`deltaSlide`, `vibratoDepth`, `vibratoSpeed`, `changeAmount`, `changeSpeed`, `squareDuty`,
`dutySweep`, `repeatSpeed`, `phaserOffset`, `phaserSweep`, `lpfCutoff`, `lpfCutoffSweep`,
`lpfResonance`, `hpfCutoff`, `hpfCutoffSweep`.

Underneath, the extension's own handlers can be called directly (`xtsfx_Preset`, `xtsfx_SetParam`,
`xtsfx_GetParams`, `xtsfx_ExportWav`, `xtsfx_Peaks` ...: see `xtsfx.lcb`). They work on one
"current" sound; the script library is what gives sounds names.

**With xt3d** (several sounds at once): `put xt3d_LoadSound(Sfx.File("pickup")) into tHandle`, then
`xt3d_PlaySound tHandle`. Tried 18 Nov in the xt3d bench standalone: 8 presets playing at once
(`xt3d_IsSoundPlaying` true for all 8), plus `xt3d_LoadSoundAlias` copies of one sound on top of
each other. `demos/sfx_xt3d_cacophony.livecodescript` (`Cacophony`) does it, with pan and pitch.
Run it in the xt3d bench, not LIB_MCP's standalone: there `load extension` of xt3d failed with
"unable to load foreign library" (not looked into).

## Layout

| Path | What it is |
|---|---|
| `c/xtsfx.c` | the C side, hand-written: one file, C standard library only |
| `c/rfxgen.h` | rfxgen 5.0's generator, unchanged (zlib licence: `c/RFXGEN_LICENSE.txt`) |
| `xtsfx.lcb` | the LiveCode Builder binding, hand-written (15 handlers) |
| `build.bat` | Windows build into `C:\xtsfx\extension` |
| `livecode/lib_sfx.livecodescript` | the script library: `Sfx.*` |
| `demos/sfx_xt3d_cacophony.livecodescript` | FOR OWNER: many sounds at once through xt3d's mixer (plays on the speakers) |
| `demos/sfx_demo.livecodescript` | FOR OWNER: preset buttons, the wave drawn, the numbers editable |
| `tests/run_test.sh`, `tests/sfx_test.txt` | 30 checks in a real Windows LiveCode through LIB_MCP; silent |

## What was tested, and what was not (18 Nov 2026)

Tested on Windows 11, LiveCode 9.6.3 (LIB_MCP's standalone): `build.bat` from WSL; the extension
loading with no Extension Builder; all 8 presets; same seed same bytes; set, mutate, `.rfx` out
and back, `.wav` export in 22050/8 bit/stereo, peaks, every refusal (`tests/run_test.sh`: PASS).
The demo opens and draws a sound's shape.

**Not tested: the sound itself.** Nothing was played on the owner's speakers. Whether each preset
sounds like its name, and whether `play` plays these `.wav` files, is for the owner's ears
(the demo). Also not tested: OXT-Beyond, Linux and macOS (no C compiler in WSL; the C file has no
Windows-only code), xt3d playing the files, non-English letters in file paths.

## Where it came from

rFXGen 5.0 by Ramon Santamaria (raylib technologies), https://github.com/raysan5/rfxgen, zlib
licence; itself based on DrPetter's sfxr. Only `src/rfxgen.h` and `LICENSE` were taken; the GUI
tool was not. One difference: our own small random-number generator replaces the C library's, so
a seed gives the same sound on every machine (the numbers therefore differ from rFXGen's own for
the same seed; `.rfx` files are the same format and sound the same).

## Licence

GPL-3.0 (see `LICENSE`), because the xTalk work here is built on the GPL-licensed LiveCode Community 9 engine. Copyright (c) 2026 xAction.
