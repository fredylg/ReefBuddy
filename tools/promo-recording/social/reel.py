#!/usr/bin/env python3
"""Build a social-ready reel from a raw simulator clip.

spec = {
  "source": path, "out": path, "voice": "en-US-AndrewNeural", "rate": "+6%",
  "music": path or None, "music_offset": 8.0,
  "segments": [ {"src": [start, end] | None (end card), "min": seconds, "vo": text,
                 "zoom": {"to": 1.3, "x": 0.5, "y": 0.35} | None,
                 "caps": [ {"text": "STILL *GUESSING*?", "at": 0.0, "until": None, "pos": "top"|"mid"|"low", "style": "white"|"black"} ] } ],
  "endcard": {...}
}
Words wrapped in *asterisks* render as an inverted highlight chip (aquamarine on black).
Words wrapped in _underscores_ render in Safety Orange (pain points).
"""
import json, os, subprocess, sys, math, shutil
import numpy as np
from PIL import Image, ImageDraw, ImageFont

W, H, FPS = 1080, 1920, 30
PHONE_W = 720; PHONE_H = round(PHONE_W * 2622 / 1206); PHONE_X = (W - PHONE_W) // 2; PHONE_Y = 175
BORDER, SHADOW = 6, 16
AQUA, ORANGE, BLACK, WHITE = (0, 255, 209), (255, 61, 0), (0, 0, 0), (255, 255, 255)
FONT_BLACK = "/System/Library/Fonts/Supplemental/Arial Black.ttf"
FONT_BOLD = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"

def sh(cmd, quiet=True):
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        print(" ".join(cmd)); print(r.stderr[-3000:]); sys.exit(1)
    return r.stdout

def dur(path):
    return float(sh(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", path]).strip())

# ---------------------------------------------------------------- captions
import re
def tokens(text):
    """Split into (span, kind): kind in {'plain','aqua','orange','br'}. *…* spans become aqua chips
    (may contain spaces), _…_ spans render in Safety Orange, plain words split on spaces."""
    out = []
    for line in text.split("\n"):
        for part in re.split(r"(\*[^*]+\*|_[^_]+_)", line):
            if not part: continue
            if part.startswith("*") and part.endswith("*"): out.append((part.strip("*").strip(), "aqua"))
            elif part.startswith("_") and part.endswith("_"): out.append((part.strip("_").strip(), "orange"))
            else:
                for w in part.split(" "):
                    if w: out.append((w, "plain"))
        out.append(("\n", "br"))
    return out[:-1]

def render_caption(text, style="black", size=66, maxw=W - 120, path=None):
    """Brutalist caption block: hard box, 6px border, 16px offset shadow, uppercase heavy type.
    Highlight words become inverted chips. Returns PIL image (RGBA)."""
    font = ImageFont.truetype(FONT_BLACK, size)
    pad, chip_pad, gap, lead = 34, 14, 18, int(size * 1.35)
    # wrap into lines by width
    lines, cur, curw = [], [], 0
    def wlen(w, kind):
        bw = font.getlength(w.upper())
        return bw + (2 * chip_pad if kind != "plain" else 0)
    for w, kind in tokens(text):
        if kind == "br":
            lines.append(cur); cur, curw = [], 0; continue
        ww = wlen(w, kind)
        if cur and curw + gap + ww > maxw - 2 * pad:
            lines.append(cur); cur, curw = [], 0
        cur.append((w, kind, ww)); curw += (gap if len(cur) > 1 else 0) + ww
    if cur: lines.append(cur)
    widths = [sum(x[2] for x in ln) + gap * (len(ln) - 1) for ln in lines]
    bw = int(max(widths) + 2 * pad); bh = int(len(lines) * lead + 2 * pad - (lead - size) // 2)
    img = Image.new("RGBA", (bw + SHADOW + 4, bh + SHADOW + 4), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    fill, ink = (WHITE, BLACK) if style == "white" else (BLACK, WHITE)
    d.rectangle([SHADOW, SHADOW, SHADOW + bw, SHADOW + bh], fill=BLACK)              # hard shadow
    d.rectangle([0, 0, bw, bh], fill=fill, outline=BLACK, width=BORDER)
    y = pad - (lead - size) // 4
    for ln, lw in zip(lines, widths):
        x = (bw - lw) / 2
        for w, kind, ww in ln:
            if kind == "plain":
                d.text((x, y), w.upper(), font=font, fill=ink)
            elif kind == "orange":
                d.text((x, y), w.upper(), font=font, fill=ORANGE)
            else:  # aqua chip: inverted block
                chip_fill, chip_ink = (BLACK, AQUA) if style == "white" else (AQUA, BLACK)
                d.rectangle([x, y - 6, x + ww, y + size + 10], fill=chip_fill)
                d.text((x + chip_pad, y), w.upper(), font=font, fill=chip_ink)
            x += ww + gap
        y += lead
    if path: img.save(path)
    return img

def caption_xy(img, pos):
    x = (W - img.width) // 2
    return x, {"top": 200, "mid": 760, "low": 1380}.get(pos, 200)

def render_endcard(spec, path):
    img = Image.new("RGB", (W, H), WHITE); d = ImageDraw.Draw(img)
    tile = 240; tx, ty = (W - tile) // 2, 290
    d.rectangle([tx + 18, ty + 18, tx + tile + 18, ty + tile + 18], fill=BLACK)
    d.rectangle([tx, ty, tx + tile, ty + tile], fill=AQUA, outline=BLACK, width=8)
    f = ImageFont.truetype(FONT_BLACK, 140)
    tw = f.getlength("RB"); d.text((tx + (tile - tw) / 2, ty + 32), "RB", font=f, fill=BLACK)
    def block(text, y, size, style="black", maxw=W - 140):
        c = render_caption(text, style=style, size=size, maxw=maxw)
        img.paste(c, ((W - c.width) // 2, y), c); return y + c.height + 24
    handle = spec.get("handle", "@reefbuddyapp").upper()
    y = 610
    y = block("DOWNLOAD *REEF BUDDY*", y, 76)
    y = block("*LINK IN BIO*", y, 60)
    y += 26
    y = block(f"FOLLOW *{handle}*\nFOR MORE REEF TIPS", y, 52)
    y += 30
    y = block("3 FREE ANALYSES · NO SUBSCRIPTION", y, 34, maxw=W - 60)
    if spec.get("music_credit"):
        block(spec["music_credit"], 1560, 26, maxw=W - 60)
    img.save(path)

# ---------------------------------------------------------------- audio
import hashlib, urllib.request

def eleven_key():
    k = os.environ.get("ELEVENLABS_API_KEY")
    for f in (os.path.join(os.path.dirname(os.path.abspath(__file__)), ".elevenlabs_key"),
              os.path.join(os.environ.get("REEFBUDDY_REPO", "/Users/fredylievano-adaca/Projects/ReefBuddy"), ".dev.vars")):
        if k: break
        if os.path.exists(f):
            for line in open(f):
                if line.startswith("ELEVENLABS_KEY=") or line.startswith("ELEVENLABS_API_KEY="):
                    k = line.split("=", 1)[1].strip().strip('"')
                elif not line.strip().startswith("#") and "=" not in line and line.strip():
                    k = line.strip()
    return k

VOICES = {"jessica": "cgSgspJ2msm6clMCkdW9", "laura": "FGY2WhTYpPnrIDTdsKH5", "sarah": "EXAVITQu4vr4xnSDxMaL",
          "matilda": "XrExE9yKIg1WjnnlVkGX", "alice": "Xb7hH8MSUJpSbSDYk0k2", "lily": "pFZP5JQG7iQjIQuC4Bku"}

def tts(text, voice, rate, path, settings=None):
    """ElevenLabs when a key is available (voice = name in VOICES or a voice id), else edge-tts.
    Results are cached by content so rebuilds do not spend characters again."""
    key = eleven_key()
    if key and not voice.startswith("en-"):
        vid = VOICES.get(voice.lower(), voice)
        vs = {"stability": 0.45, "similarity_boost": 0.8, "style": 0.45, "use_speaker_boost": True, "speed": 1.05}
        vs.update(settings or {})
        cache = os.path.join(os.path.dirname(os.path.abspath(__file__)), "tts-cache")
        os.makedirs(cache, exist_ok=True)
        h = hashlib.sha1(json.dumps([text, vid, vs], sort_keys=True).encode()).hexdigest()[:16]
        cached = os.path.join(cache, h + ".mp3")
        if not os.path.exists(cached):
            body = json.dumps({"text": text, "model_id": "eleven_multilingual_v2", "voice_settings": vs}).encode()
            req = urllib.request.Request(f"https://api.elevenlabs.io/v1/text-to-speech/{vid}?output_format=mp3_44100_128",
                                         data=body, headers={"xi-api-key": key, "Content-Type": "application/json"})
            try:
                with urllib.request.urlopen(req, timeout=120) as r: open(cached, "wb").write(r.read())
            except urllib.error.HTTPError as e:
                print("ElevenLabs error", e.code, e.read()[:300]); sys.exit(1)
        shutil.copy(cached, path)
        return dur(path)
    sh([VENV + "/bin/edge-tts", "--voice", voice, "--rate=" + rate, "--text", text, "--write-media", path])
    return dur(path)

def wav_read(path, sr=48000):
    raw = sh_bytes(["ffmpeg", "-v", "error", "-i", path, "-f", "f32le", "-ac", "1", "-ar", str(sr), "-"])
    return np.frombuffer(raw, dtype=np.float32).copy()

def sh_bytes(cmd):
    r = subprocess.run(cmd, capture_output=True)
    if r.returncode != 0: print(" ".join(cmd)); print(r.stderr.decode()[-2000:]); sys.exit(1)
    return r.stdout

def wav_write(path, x, sr=48000):
    import wave
    x = np.clip(x, -1, 1); pcm = (x * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(sr); w.writeframes(pcm.tobytes())

# ---------------------------------------------------------------- video
def build(spec):
    b = os.path.join(os.path.dirname(spec["out"]), "build_" + os.path.splitext(os.path.basename(spec["out"]))[0])
    shutil.rmtree(b, ignore_errors=True); os.makedirs(b)
    src, voice, rate = spec["source"], spec.get("voice", "en-US-AndrewNeural"), spec.get("rate", "+6%")
    SR = 48000
    # 1. voiceover per segment → durations decide the cut
    segs = spec["segments"]; t = 0.0
    for i, s in enumerate(segs):
        s["vo_dur"] = tts(s["vo"], voice, rate, f"{b}/vo{i}.mp3") if s.get("vo") else 0.0
        s["dur"] = max(s.get("min", 1.0), s["vo_dur"] + s.get("tail", 0.35))
        s["t0"] = t; t += s["dur"]
    total = t
    print(f"timeline {total:.1f}s: " + " | ".join(f"{s['dur']:.1f}" for s in segs))
    # 2. per-segment video
    parts = []
    for i, s in enumerate(segs):
        out = f"{b}/seg{i}.mp4"
        if s.get("src") is None:  # end card
            render_endcard(spec, f"{b}/endcard.png")
            sh(["ffmpeg", "-y", "-v", "error", "-loop", "1", "-framerate", str(FPS), "-t", f"{s['dur']:.3f}", "-i", f"{b}/endcard.png",
                "-vf", f"scale={W}:{H},format=yuv420p", "-c:v", "libx264", "-preset", "fast", "-crf", "18", "-r", str(FPS), out])
            parts.append(out); continue
        a, e = s["src"]; srclen = e - a
        speed = srclen / s["dur"]
        hold = 0.0
        if speed < 0.9:  # do not slow real footage down much; hold the last frame instead
            speed = 0.9; hold = s["dur"] - srclen / speed
        n_frames = int(round(s["dur"] * FPS))
        vf = [f"trim=start={a}:end={e}", "setpts=(PTS-STARTPTS)/%.5f" % speed, f"fps={FPS}"]
        if hold > 0: vf.append(f"tpad=stop_mode=clone:stop_duration={hold:.3f}")
        z = s.get("zoom")
        if z:
            zto, zx, zy = z.get("to", 1.25), z.get("x", 0.5), z.get("y", 0.4)
            zf = int(z.get("frames", min(n_frames, 18)))  # frames to reach the zoom
            zstart = int(z.get("start", 0) * FPS)
            zexpr = f"if(lt(on,{zstart}),1,min(1+({zto}-1)*(on-{zstart})/{zf},{zto}))"
            vf.append(f"zoompan=z='{zexpr}':x='{zx}*(iw-iw/zoom)':y='{zy}*(ih-ih/zoom)':d=1:s=1206x2622:fps={FPS}")
        vf.append(f"scale={PHONE_W}:{PHONE_H}:flags=lanczos")
        vf.append(f"trim=duration={s['dur']:.3f}")
        # canvas: white, hard shadow, phone, border
        fc = (f"[0:v]{','.join(vf)}[ph];"
              f"color=c=white:s={W}x{H}:r={FPS}:d={s['dur']:.3f}[bg];"
              f"[bg]drawbox=x={PHONE_X+SHADOW}:y={PHONE_Y+SHADOW}:w={PHONE_W}:h={PHONE_H}:color=black:t=fill[bg2];"
              f"[bg2][ph]overlay=x={PHONE_X}:y={PHONE_Y}:shortest=1[v0];"
              f"[v0]drawbox=x={PHONE_X-BORDER}:y={PHONE_Y-BORDER}:w={PHONE_W+2*BORDER}:h={PHONE_H+2*BORDER}:color=black:t={BORDER}[v1]")
        if s.get("patch"):
            fc += f";[v1]drawbox=x={PHONE_X+40}:y={PHONE_Y+205}:w=330:h=48:color=white:t=fill[v1p]"
            last0 = "v1p"
        else:
            last0 = "v1"
        inputs = ["-i", src]; last = last0; k = 1
        for c in s.get("caps", []):
            png = f"{b}/cap{i}_{k}.png"
            img = render_caption(c["text"], style=c.get("style", "black"), size=c.get("size", 66), path=png)
            x, y = caption_xy(img, c.get("pos", "top"))
            if "y" in c: y = c["y"]
            at, until = c.get("at", 0.0), c.get("until", s["dur"])
            inputs += ["-i", png]
            fc += f";[{last}][{k}:v]overlay=x={x}:y={y}:enable='between(t,{at},{until})'[v{k+1}]"
            last = f"v{k+1}"; k += 1
        sh(["ffmpeg", "-y", "-v", "error"] + inputs + ["-filter_complex", fc, "-map", f"[{last}]",
            "-t", f"{s['dur']:.3f}", "-c:v", "libx264", "-preset", "fast", "-crf", "18", "-pix_fmt", "yuv420p", "-r", str(FPS), "-an", out])
        parts.append(out)
        print(f"  seg{i}: src {a:.1f}-{e:.1f} x{speed:.2f} hold {hold:.1f} -> {s['dur']:.2f}s")
    with open(f"{b}/concat.txt", "w") as f:
        for p in parts: f.write(f"file '{p}'\n")
    sh(["ffmpeg", "-y", "-v", "error", "-f", "concat", "-safe", "0", "-i", f"{b}/concat.txt", "-c", "copy", f"{b}/video.mp4"])
    vdur = dur(f"{b}/video.mp4")
    # 3. audio: voiceover placed at segment starts, music ducked under it
    n = int(vdur * SR) + SR
    vo = np.zeros(n, dtype=np.float32)
    for i, s in enumerate(segs):
        if not s.get("vo"): continue
        x = wav_read(f"{b}/vo{i}.mp3", SR)
        st = int((s["t0"] + s.get("vo_delay", 0.15)) * SR)
        vo[st:st + len(x)] += x[:max(0, n - st)]
    vo *= 0.9 / max(1e-6, np.abs(vo).max())
    mix = vo.copy()
    if spec.get("music"):
        m = wav_read(spec["music"], SR)
        off = int(spec.get("music_offset", 0) * SR); m = m[off:off + n]
        if len(m) < n: m = np.pad(m, (0, n - len(m)))
        m *= 0.9 / max(1e-6, np.abs(m).max())
        # ducking envelope from the voiceover
        win = int(0.05 * SR); env = np.convolve(np.abs(vo), np.ones(win) / win, mode="same")
        speaking = (env > 0.01).astype(np.float32)
        smooth = np.convolve(speaking, np.ones(int(0.25 * SR)) / int(0.25 * SR), mode="same")
        gain = 10 ** (spec.get("music_db", -13) / 20) * (1 - smooth) + 10 ** (spec.get("music_duck_db", -24) / 20) * smooth
        fade_in = np.minimum(1, np.arange(n) / (0.6 * SR)); fade_out = np.clip((vdur * SR - np.arange(n)) / (1.5 * SR), 0, 1)
        mix = mix + m * gain * fade_in * fade_out
    mix = mix[:int(vdur * SR)]
    wav_write(f"{b}/mix.wav", mix, SR)
    wav_write(f"{b}/vo_only.wav", vo[:int(vdur * SR)], SR)
    # 4. mux (Instagram target loudness -14 LUFS)
    for name, wav in (("", "mix.wav"), ("_voice-only", "vo_only.wav")):
        o = spec["out"].replace(".mp4", f"{name}.mp4")
        sh(["ffmpeg", "-y", "-v", "error", "-i", f"{b}/video.mp4", "-i", f"{b}/{wav}", "-c:v", "copy",
            "-af", "loudnorm=I=-14:TP=-1.5:LRA=11", "-c:a", "aac", "-b:a", "192k", "-shortest", "-movflags", "+faststart", o])
        print("wrote", o, f"{dur(o):.1f}s")
    # script export
    with open(spec["out"].replace(".mp4", "_script.md"), "w") as f:
        f.write(f"# Voiceover and captions — {os.path.basename(spec['out'])}\n\nVoice: {voice} (rate {rate}). Music: {spec.get('music')}\n\n| # | Time | Shot | Voiceover | Captions |\n|---|------|------|-----------|----------|\n")
        for i, s in enumerate(segs):
            shot = "End card" if s.get("src") is None else f"src {s['src'][0]:.1f}–{s['src'][1]:.1f}s"
            caps = " / ".join(c["text"].replace("\n", " ") for c in s.get("caps", []))
            f.write(f"| {i+1} | {s['t0']:.1f}–{s['t0']+s['dur']:.1f}s | {shot} | {s.get('vo','')} | {caps} |\n")

VENV = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "venv")
if __name__ == "__main__":
    spec_path = sys.argv[1]
    ns = {}; exec(open(spec_path).read(), ns)
    build(ns["spec"])
