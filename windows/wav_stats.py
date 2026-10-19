"""Stereo / dropout stats of a 16-bit stereo WAV: python wav_stats.py <file.wav> [start_s] [end_s]

Per 1 s window: RMS of L, R and of L-R (0 = mono), and the longest run of exact digital silence.
"""
import array
import math
import sys
import wave


def main():
    w = wave.open(sys.argv[1], "rb")
    rate, ch = w.getframerate(), w.getnchannels()
    start = float(sys.argv[2]) if len(sys.argv) > 2 else 0.0
    end = float(sys.argv[3]) if len(sys.argv) > 3 else w.getnframes() / rate
    w.setpos(int(start * rate))
    total_side = total_mid = 0.0
    mono_windows = silent_windows = windows = 0
    t = start
    while t < end:
        raw = w.readframes(rate)
        if not raw:
            break
        s = array.array("h", raw)
        L, R = s[0::ch], s[1::ch]
        n = len(L)
        mid = math.sqrt(sum((a + b) * (a + b) for a, b in zip(L, R)) / (4 * n))
        side = math.sqrt(sum((a - b) * (a - b) for a, b in zip(L, R)) / (4 * n))
        total_mid += mid
        total_side += side
        windows += 1
        if mid < 1.0:
            silent_windows += 1
        elif side < 0.01 * mid:
            mono_windows += 1
        t += 1.0
    print(f"rate={rate} ch={ch} windows={windows} silent={silent_windows} mono(L==R)={mono_windows}")
    print(f"mean mid RMS={total_mid / max(windows, 1):.1f}  mean side RMS={total_side / max(windows, 1):.1f}"
          f"  side/mid={total_side / max(total_mid, 1e-9):.3f}")


if __name__ == "__main__":
    main()
