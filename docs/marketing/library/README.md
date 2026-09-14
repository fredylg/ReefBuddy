# ReefBuddy post library

Machine-readable social media library for the 14 feature stories. Start at `manifest.json`.

```
manifest.json                 index: brand block + one entry per post (id, title, hook, status, primary_image, post_json, reel)
schema.json                   JSON Schema for post.json
posts/<id>/post.json          everything an uploader needs for one post (see schema)
posts/<id>/caption.txt        caption + hashtags as plain text, ready to paste
posts/<id>/images/            post_4x5.png (primary feed image, 1080×1350)
                              post_1x1.png (square, 1080×1080)
                              still_clean_4x5.png (phone frame only, no text, 1080×1350)
                              carousel_1..3_4x5.png (three-slide carousel, 1080×1350)
                              frame1..3_raw.png (untouched simulator frames, 1206×2622)
```

Paths inside the JSON are relative to this folder. Video paths point at `../../stories/social/`
(the reels are not duplicated here). `status` is `draft` for every post; flip it to `approved` or
`published` in the manifest as you go. Hashtags are stored both as an array and pre-joined in
`caption_with_hashtags`. `alt_text` is written for the primary image.

Regenerate with `tools/promo-recording/social/stills.py <output dir>` after re-recording any clip.
