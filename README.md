# rycollins.com

My personal site: a single static page, no build step, no third-party requests.

```
public/            everything that ships
  index.html       the page (styles and the little bit of JS are inline)
  assets/fonts/    Instrument Serif (OFL), self-hosted
  assets/img/      app icons, screenshots, portrait, share image
tools/             regenerates the app screenshots
deploy.sh          publishes public/ to the server
```

## Preview

```sh
python3 -m http.server 8765 --directory public
```

## Screenshots

`tools/make-screenshots.sh` rebuilds the app icons and screenshots from the app repos
(`../xcv`, `../../cedarinventive/percolate`, `../../cedarinventive/Astrolical`):

- **xcv**: builds a patched copy under its own bundle ID that reads seeded demo data
  (`tools/xcv_demo.py`), never your real clipboard history, and uses the app's `XCV_SNAPSHOT` mode.
- **Percolate**: renders the notch island frame by frame from the app's own `CupScene` and
  `CupLayer` (`tools/percolate_island.swift`) into a seamless looping H.264 video. The page clips it
  to the island shape, and the elapsed timer is live HTML.
- **Astrolical**: reuses the screenshots from its own site.

`tools/patch_sources.py` holds the few source patches the renders need. Each one has to match
exactly, so an app change fails loudly instead of producing a wrong screenshot.

## Deploy

```sh
./deploy.sh --dry-run   # see what would change
./deploy.sh
```

The web root on the server also holds files this repo doesn't own, so the deploy never deletes.

The site before this redesign is tagged `legacy-openclaw-site`.

## Brand pass (`brand/personal-pass`)

Homepage narrative, SEO/social meta (including JSON-LD `Person`), trust links, and light a11y/UX polish — without touching the xcv/Percolate notch demos or layout structure. Favicon and `assets/img/og.png` kept as-is.

