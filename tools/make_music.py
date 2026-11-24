"""make_music.py - chiptune songs for the shared kit, from numbers (no samples, no files in).

    python3 tools/make_music.py            -> kit/Music/*.wav (22050 Hz, 16 bit, mono)

Each song is a seed, a key, a tempo and a mood (major/minor). The same seed makes the same
song. Four voices like an old sound chip: square lead (arpeggios and a tune), triangle bass,
square pad, noise drums. The engine plays one at random and the next when it ends; a file
with "theme" in its name is the title music.
"""
import math, os, random, struct, wave

RATE = 22050
HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(HERE, "kit", "Music")

SONGS = [  # file name, seed, root note (MIDI), beats per minute, mood, bars
    ("theme_vibecode", 7, 57, 112, "minor", 16),
    ("song_arcade_run", 21, 60, 140, "major", 16),
    ("song_night_patrol", 33, 55, 100, "minor", 16),
    ("song_bright_sky", 48, 62, 126, "major", 16),
    ("song_deep_cave", 59, 50, 88, "minor", 12),
]
SCALES = {"major": [0, 2, 4, 5, 7, 9, 11], "minor": [0, 2, 3, 5, 7, 8, 10]}
PROGS = {"major": [[0, 4, 5, 3], [0, 5, 3, 4], [0, 3, 4, 4]],
         "minor": [[0, 5, 2, 6], [0, 3, 4, 0], [0, 6, 5, 4]]}


def hz(n):
    return 440.0 * 2 ** ((n - 69) / 12.0)


def square(ph, duty=0.5):
    return 1.0 if (ph % 1.0) < duty else -1.0


def tri(ph):
    p = ph % 1.0
    return 4 * p - 1 if p < 0.5 else 3 - 4 * p


def add_note(buf, start, length, freq, vol, kind="square", duty=0.5):
    s, n = int(start * RATE), int(length * RATE)
    att, rel = int(0.005 * RATE), int(min(0.05, length * 0.3) * RATE)
    for i in range(n):
        if s + i >= len(buf):
            break
        ph = freq * i / RATE
        v = square(ph, duty) if kind == "square" else tri(ph)
        env = min(1.0, i / att if att else 1, (n - i) / rel if rel else 1)
        buf[s + i] += v * vol * env


def add_drum(buf, start, kind, rng):
    s = int(start * RATE)
    if kind == "kick":
        n = int(0.14 * RATE)
        for i in range(n):
            if s + i >= len(buf):
                break
            f = 120 * (1 - i / n) + 40
            buf[s + i] += math.sin(2 * math.pi * f * i / RATE) * 0.5 * (1 - i / n) ** 2
    else:
        n = int((0.03 if kind == "hat" else 0.12) * RATE)
        vol = 0.10 if kind == "hat" else 0.22
        for i in range(n):
            if s + i >= len(buf):
                break
            buf[s + i] += rng.uniform(-1, 1) * vol * (1 - i / n) ** 2


def song(seed, root, bpm, mood, bars):
    rng = random.Random(seed)
    scale, beat = SCALES[mood], 60.0 / bpm
    prog = rng.choice(PROGS[mood])
    total = bars * 4 * beat
    buf = [0.0] * int(total * RATE + RATE * 0.2)
    motif = [rng.choice([0, 2, 4, 4, 5, 7, 7, 9]) for _ in range(8)]   # scale steps, 8 eighths
    rests = [rng.random() < 0.25 for _ in range(8)]
    arp_dir = rng.choice([1, -1])

    def note(degree, octave=0):
        d = degree % 7
        return root + scale[d] + 12 * (octave + degree // 7)

    for bar in range(bars):
        t0 = bar * 4 * beat
        chord = prog[bar % 4]
        section = (bar // 4) % 4                     # A A' B A: the B part rises
        lift = 2 if section == 2 else 0
        # bass: root on beats, fifth on the off beats
        for b in range(8):
            deg = chord if b % 2 == 0 else chord + 4
            add_note(buf, t0 + b * beat / 2, beat / 2 * 0.9, hz(note(deg, -2)), 0.22, "tri")
        # pad: the chord, quiet, a whole bar
        for k in (0, 2, 4):
            add_note(buf, t0, 4 * beat * 0.95, hz(note(chord + k, 0)), 0.035, "square", 0.25)
        # lead: the motif over the chord (sections 1 and 2), arpeggios in 0 and 3
        if section in (1, 2):
            for i in range(8):
                if rests[i]:
                    continue
                deg = chord + motif[(i + bar) % 8] + lift
                add_note(buf, t0 + i * beat / 2, beat / 2 * 0.8, hz(note(deg, 1)), 0.09, "square", 0.5)
        else:
            steps = [0, 2, 4, 7][::arp_dir]
            for i in range(16):
                deg = chord + steps[i % 4]
                add_note(buf, t0 + i * beat / 4, beat / 4 * 0.7, hz(note(deg, 1)), 0.06, "square", 0.125)
        # drums
        for b in range(4):
            if b in (0, 2):
                add_drum(buf, t0 + b * beat, "kick", rng)
            else:
                add_drum(buf, t0 + b * beat, "snare", rng)
            add_drum(buf, t0 + b * beat + beat / 2, "hat", rng)
    peak = max(1e-6, max(abs(v) for v in buf))
    return [v / peak * 0.8 for v in buf]


def write(path, data):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(v * 32767)) for v in data))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    lines = []
    for name, seed, root, bpm, mood, bars in SONGS:
        data = song(seed, root, bpm, mood, bars)
        write(os.path.join(OUT, name + ".wav"), data)
        lines.append("%s\tseed %d\troot %d\t%d bpm\t%s\t%.1f s" % (name, seed, root, bpm, mood, len(data) / RATE))
    with open(os.path.join(OUT, "MUSIC.txt"), "w", newline="\n") as f:
        f.write("Made by LIB_SFX/tools/make_music.py (change a seed there, run it again).\n")
        f.write("\n".join(lines) + "\n")
    print("\n".join(lines))
