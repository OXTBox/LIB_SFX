# LIB_SFX: notes for Claude Code

Read `README.md` first. Then `~/projects/LIB_SYSTEM/LIB_ALPHA.md` and the xt3d bridge's
`CLAUDE.md` (the same LCB rules apply here: never return a C string, every foreign call inside
`unsafe`, lowercase library name).

- **Build from WSL:** `cd /mnt/c && cmd.exe /c 'set XTSFX_NOPAUSE=1&& \\wsl$\Ubuntu\home\igame3d\projects\LIB_SFX\build.bat'`.
  It needs LiveCode closed only if LiveCode has the DLL loaded (LIB_MCP's standalone counts:
  after it has run the test, the DLL copy can fail; stop the standalone, build, run the test again).
- **Test:** `tests/run_test.sh` (LIB_MCP standalone, port 8767). It is silent on purpose. Never call
  `Sfx.Play` from a test or through LIB_MCP: it plays on the owner's speakers.
- `build.bat` has Windows line ends (CRLF). Keep them.
- `c/rfxgen.h` is upstream's file: do not edit it. What it expects from raylib (`bool`, `PI`,
  random numbers, logging) is supplied at the top of `c/xtsfx.c`.
- The DLL holds ONE current sound. `lib_sfx` pushes a named sound's 24 lines in
  (`xtsfx_SetParams`) before every call that reads it. Keep that order in new handlers.
- A new C function needs three edits: `c/xtsfx.c`, a foreign + public handler pair in
  `xtsfx.lcb`, and usually a `Sfx.` handler in `livecode/lib_sfx.livecodescript`.
- `the result` after a `Sfx.` command is overwritten by the next function call: copy it first.
- Generated `.wav` files, the DLL and `module.lcm` are not tracked (`C:\xtsfx` holds them).
