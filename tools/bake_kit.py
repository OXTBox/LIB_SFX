"""bake_kit.py - make the shared sound kit (.wav files) from kit/kit.txt with LIB_SFX.

Run with WINDOWS Python (it loads the built xtsfx.dll; build.bat makes it once):
    python.exe tools/bake_kit.py [--dll C:/xtsfx/extension/code/x86_64-win32/xtsfx.dll]
Writes kit/Sounds/<type>/<type>_<seed>.wav (22050 Hz, 16 bit, mono) and kit/Sounds/KIT.txt.
"""
import ctypes, os, shutil, sys

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KIT = os.path.join(HERE, "kit")
DLL = "C:/xtsfx/extension/code/x86_64-win32/xtsfx.dll"
if "--dll" in sys.argv:
    DLL = sys.argv[sys.argv.index("--dll") + 1]

lib = ctypes.CDLL(DLL)
lib.xtsfx_Preset.argtypes = [ctypes.c_char_p, ctypes.c_int]
lib.xtsfx_SetParams.argtypes = [ctypes.c_char_p]
lib.xtsfx_ExportWav.argtypes = [ctypes.c_char_p, ctypes.c_int, ctypes.c_int, ctypes.c_int]
lib.xtsfx_Duration.restype = ctypes.c_double

out = os.path.join(KIT, "Sounds")
made = []
for line in open(os.path.join(KIT, "kit.txt"), encoding="utf-8"):
    line = line.rstrip("\r\n")
    if not line.strip() or line.startswith("#"):
        continue
    parts = line.split("\t")
    kind, preset, seeds = parts[0], parts[1], parts[2]
    extra = parts[3] if len(parts) > 3 else ""
    folder = os.path.join(out, kind)
    if os.path.isdir(folder):
        shutil.rmtree(folder)
    os.makedirs(folder)
    for seed in seeds.split(","):
        seed = int(seed)
        if not lib.xtsfx_Preset(preset.encode(), seed):
            sys.exit("unknown preset %s (%s)" % (preset, kind))
        if extra:
            lib.xtsfx_SetParams(extra.replace(";", "\n").encode())
        path = os.path.join(folder, "%s_%d.wav" % (kind, seed))
        if not lib.xtsfx_ExportWav(path.encode(), 22050, 16, 1):
            sys.exit("could not write " + path)
        made.append("%s\t%s\t%d\t%.2f s" % (kind, preset, seed, lib.xtsfx_Duration()))

with open(os.path.join(out, "KIT.txt"), "w", encoding="utf-8", newline="\n") as f:
    f.write("Made by LIB_SFX/tools/bake_kit.py from kit/kit.txt: type, preset, seed, length.\n")
    f.write("\n".join(made) + "\n")
print("%d sounds in %d types -> %s" % (len(made), len({m.split()[0] for m in made}), out))
