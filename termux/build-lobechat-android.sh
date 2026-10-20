#!/usr/bin/env bash
# Build LobeChat v1.143.3 (last client-DB version) as a Next.js standalone
# server and package it for Termux/Android. Runs in GitHub Actions (the
# Next.js build alone asks for a 6 GB heap — never build this on the phone).
#
# Output: ../lobechat-termux-android.zip (relative to this repo's root)
#   lobechat-termux-android.zip
#   ├── install.sh   (on-device installer)
#   ├── lobechat     (launcher, copied to $PREFIX/bin)
#   └── app/         (the standalone server tree; run: node server.js)
set -euo pipefail

VERSION="1.143.3"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$ROOT/work"
PKG="$ROOT/pkg"

rm -rf "$WORK" "$PKG"
mkdir -p "$WORK" "$PKG/app"

echo "== Cloning lobehub/lobe-chat v$VERSION (with its pnpm-lock.yaml)"
git clone --depth 1 --branch "v$VERSION" \
  https://github.com/lobehub/lobe-chat.git "$WORK/src"
cd "$WORK/src"

echo "== Installing dependencies (frozen lockfile)"
pnpm install --frozen-lockfile

echo "== Building standalone (DOCKER=true flips output:'standalone')"
# build:docker = prebuild + DOCKER=true next build (heap 6144) + build-sitemap
npm run build:docker

echo "== Assembling the standalone package"
cp -r .next/standalone/. "$PKG/app/"
# The standalone tree needs the static assets next to it; public/ is already
# traced into standalone by their next.config, static/ is not.
mkdir -p "$PKG/app/.next"
cp -r .next/static "$PKG/app/.next/static"
if [ ! -d "$PKG/app/public" ]; then
  cp -r public "$PKG/app/public"
fi
test -f "$PKG/app/server.js" || { echo "server.js missing — build is broken"; exit 1; }

echo "== Pruning sharp (no Android prebuild; only image-gen thumbnails use it)"
rm -rf "$PKG/app/node_modules/sharp" "$PKG/app/node_modules/@img"

echo "== Packaging zip"
cp "$ROOT/termux/install.sh" "$PKG/install.sh"
cp "$ROOT/termux/lobechat" "$PKG/lobechat"
cd "$PKG"
zip -qr "$ROOT/lobechat-termux-android.zip" install.sh lobechat app
ls -lh "$ROOT/lobechat-termux-android.zip"
