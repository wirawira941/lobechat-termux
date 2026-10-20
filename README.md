# lobechat-termux

LobeChat (LobeHub) **v1.143.3** — the last version with Client DB mode —
packaged to run natively on Android via Termux.

## Why v1?

LobeHub 2.0 removed Client DB (PGlite) mode and requires a PostgreSQL
server. v1.143.3 is the final v1 release: all chat data lives in the phone's
browser, so the only thing Termux has to run is the Next.js standalone
server. No database server, no auth secrets, no S3.

## Install (on the phone, in Termux)

1. Download `lobechat-termux-android.zip` from the Releases page and unzip it.
2. `./install.sh` (installs the Termux `nodejs` package if missing, copies
   the app to `~/lobechat`, and installs the launcher).
3. Run `lobechat`, then open **http://localhost:3210** in the phone browser.
   On the same Wi-Fi/hotspot, a laptop can also open
   `http://<phone-ip>:3210`.
4. In LobeChat settings, point the model provider at your OpenAI-compatible
   endpoint (e.g. a local router on `http://localhost:20128/v1`).

## Building

The Next.js production build needs a ~6 GB heap, so it runs in GitHub
Actions, not on the phone: dispatch the **Build LobeChat for Termux**
workflow (optionally with a release tag to publish a Release). The pipeline
clones the upstream `v1.143.3` tag (which carries the lockfile the npm
tarball strips), installs with pnpm 10.18.3, builds the standalone output
(`DOCKER=true`), prunes the `sharp` native module — it has no Android
build and only powers image-generation thumbnails — and zips the package.

See `termux/build-lobechat-android.sh` for the exact steps.

## Notes

- The bundle is plain Node/JavaScript (plus WASM PGlite in the browser),
  so nothing in it is compiled for a specific CPU — it runs on Termux's own
  Node.js.
- `@napi-rs/canvas` is not used by v1 at all; `sharp` is the only native
  dependency, and it is pruned as described above.
