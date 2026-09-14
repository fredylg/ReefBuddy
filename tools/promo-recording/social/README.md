# Social cuts (reels)

`reel.py` turns a raw clip from `../run.sh … record` into an Instagram-ready reel: voiceover per shot (ElevenLabs when `ELEVENLABS_KEY` is in `.dev.vars` or `ELEVENLABS_API_KEY` is set, else edge-tts), shot speed fitted to each line, punch-in zooms, brutalist caption blocks in the
brand palette, ducked background music, loudness-normalised to -14 LUFS, plus a CTA end card.
It also writes a `_voice-only.mp4` (add trending audio in Instagram) and a `_script.md`.

```bash
python3 -m venv ~/ReefBuddy-Promo/venv && ~/ReefBuddy-Promo/venv/bin/pip install pillow numpy edge-tts
mkdir -p ~/ReefBuddy-Promo/social/music   # drop cipher.mp3 here (see docs/marketing/stories/social/MUSIC_CREDITS.txt)
~/ReefBuddy-Promo/venv/bin/python tools/promo-recording/social/reel.py tools/promo-recording/social/specs/s03.py
```
Caption markup: `*word or phrase*` = aquamarine chip on black, `_word_` = Safety Orange, `\n` = line break.

Voices: `jessica` (default, young/expressive), `laura` (upbeat), `sarah`, `matilda`, `alice`, `lily`, or any ElevenLabs voice id.
TTS results are cached in `tts-cache/` next to the script, so rebuilds do not spend characters.

`make_specs.py` writes the specs for stories 1, 2 and 4 to 14 (story 3 is `specs/s03.py`); run it, then build each spec with `reel.py`.

`stills.py <out dir>` builds the post library (stills, 4:5 and 1:1 post images, carousels, captions, hashtags, manifest.json). The delivered copy is `docs/marketing/library/`.
