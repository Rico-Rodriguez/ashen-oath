import glob
import os
import shutil
import subprocess
import wave
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "assets", "audio", "sfx")
SR = 44100
PEAK = 10.0 ** (-1.0 / 20.0)


def bandpass(x: np.ndarray, lo: float, hi: float) -> np.ndarray:
    spec = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1.0 / SR)
    mask = np.clip((freqs - lo) / max(lo * 0.2, 1.0), 0.0, 1.0) * np.clip((hi - freqs) / max(hi * 0.15, 1.0), 0.0, 1.0)
    return np.fft.irfft(spec * mask, n=len(x))


def fade_edges(x: np.ndarray, ms: float = 4.0) -> np.ndarray:
    n = int(round(ms * SR / 1000.0))
    if n * 2 >= len(x):
        return x
    ramp = np.linspace(0.0, 1.0, n, endpoint=False)
    out = x.copy()
    out[:n] *= ramp
    out[-n:] *= ramp[::-1]
    return out


def synth_blade_scrape(variant: int) -> np.ndarray:
    dur = 0.35 if variant == 0 else 0.37
    n = int(round(dur * SR))
    t = np.arange(n) / SR
    rng = np.random.default_rng(7101 + variant * 97)

    base_modes = (
        [1480.0, 2310.0, 3490.0, 4820.0, 6390.0, 8120.0]
        if variant == 0
        else [1620.0, 2540.0, 3780.0, 5190.0, 6840.0, 8640.0]
    )
    glide = 1.0 - (0.045 if variant == 0 else 0.06) * (t / dur)
    ring = np.zeros(n, dtype=np.float64)
    for idx, f0 in enumerate(base_modes):
        freq_curve = f0 * glide * (1.0 + 0.004 * np.sin(2.0 * np.pi * (19.0 + idx * 5.0) * t))
        phase = 2.0 * np.pi * np.cumsum(freq_curve) / SR
        decay = np.exp(-t / (0.24 - idx * 0.025))
        ring += (np.sin(phase) / (1.0 + idx * 0.55)) * decay

    raw_grit = rng.uniform(-1.0, 1.0, n)
    micro_grain = 0.45 + 0.55 * np.abs(np.sin(2.0 * np.pi * (46.0 + variant * 11.0) * t + rng.normal(0.0, 0.25, n)))
    grit_hi = bandpass(raw_grit * micro_grain, 2100.0, 9800.0)
    grit_mid = bandpass(raw_grit, 950.0, 2600.0)

    scrape_env = np.clip(t / 0.012, 0.0, 1.0) * np.exp(-np.maximum(0.0, t - 0.04) / 0.14)
    spark_click = bandpass(rng.uniform(-1.0, 1.0, n), 3200.0, 11500.0) * np.exp(-t / 0.014)

    mix = ring * 0.52 + grit_hi * scrape_env * 0.85 + grit_mid * scrape_env * 0.35 + spark_click * 0.65
    mix = bandpass(mix, 720.0, 12500.0)
    mix = fade_edges(mix, 3.5)
    peak = float(np.max(np.abs(mix)))
    if peak > 1e-8:
        mix = mix * (PEAK / peak)
    return mix


def find_ffmpeg() -> str:
    found = shutil.which("ffmpeg")
    if found:
        return found
    local_app = os.environ.get("LOCALAPPDATA", "")
    if local_app:
        matches = glob.glob(os.path.join(local_app, "Microsoft", "WinGet", "Packages", "Gyan.FFmpeg*", "**", "ffmpeg.exe"), recursive=True)
        if matches:
            return matches[0]
    return "ffmpeg"


def write_ogg(path: str, samples: np.ndarray) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp.wav"
    pcm = (np.clip(samples, -1.0, 1.0) * 32767.0).astype("<i2")
    with wave.open(tmp, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SR)
        wf.writeframes(pcm.tobytes())
    try:
        subprocess.run(
            [find_ffmpeg(), "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "3", path],
            check=True,
        )
    finally:
        if os.path.exists(tmp):
            os.remove(tmp)


def main() -> None:
    for idx in range(2):
        out_path = os.path.join(OUT_DIR, f"blade_scrape_{idx + 1}.ogg")
        samples = synth_blade_scrape(idx)
        write_ogg(out_path, samples)
        print(f"Wrote {out_path} ({os.path.getsize(out_path)} bytes)")


if __name__ == "__main__":
    main()
