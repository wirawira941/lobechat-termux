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

echo "== Installing dependencies"
# Tag v1.143.3 ships NO pnpm-lock.yaml, so a frozen install is impossible
# (and --frozen-lockfile fails). Mirror the official Dockerfile, which runs
# a plain `pnpm i`. If a future pin gains a lockfile, use the frozen form.
if [ -f pnpm-lock.yaml ]; then
  pnpm install --frozen-lockfile
else
  pnpm install
fi

echo "== Building standalone (DOCKER=true flips output:'standalone')"
# Equivalent of `npm run build:docker`, but WITHOUT its `npm run lint` gate:
# the tag's own sources fail upstream's tsgo type-check under freshly
# resolved dependency minors (no lockfile shipped at v1.143.3), and the lint
# gate is a dev-quality check irrelevant to shipping a standalone server.
# next.config.ts sets typescript.ignoreBuildErrors, so `next build` itself
# is safe against those errors.
pnpm exec tsx scripts/prebuild.mts
export NODE_OPTIONS="--max-old-space-size=6144"
# `next` is a local binary (node_modules/.bin); invoke via pnpm exec —
# bare `next` is not on PATH outside an npm-script context (broke run #3).
# APP_URL must be set at build time (same placeholder the official
# Dockerfile uses): src/libs/oidc-provider/config.ts does
# urlJoin(appEnv.APP_URL!, ...) at module scope, and with APP_URL unset
# `next build` dies at "Collecting page data for /oidc/consent" with
# "TypeError: Url must be a string. Received undefined" (broke run #4).
#
# The changelog pages fetch remote markdown from raw.githubusercontent.com
# at build time (ChangelogService.getChangelogIndex/getPostById); on CI that
# exceeds Next's 60s static-generation timeout and aborts the whole build
# (broke run #5). Render them on demand instead — for a personal deployment
# the static changelog has no value, and the data is fresher at runtime.
for f in \
  "src/app/[variants]/(main)/changelog/page.tsx" \
  "src/app/[variants]/(main)/changelog/modal/page.tsx" \
  "src/app/[variants]/@modal/(.)changelog/modal/page.tsx"; do
  grep -q "force-dynamic" "$f" || printf "\nexport const dynamic = 'force-dynamic';\n" >> "$f"
done
APP_URL="http://app.com" DOCKER=true pnpm exec next build
npm run build-sitemap

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
# --symlinks is load-bearing: the standalone tree is a pnpm layout whose
# packages resolve their deps through symlinks into .pnpm/. Plain zip
# dereferences them into detached copies, and Node then cannot find e.g.
# styled-jsx from inside next (MODULE_NOT_FOUND on device, run #6 zip).
zip -qr --symlinks "$ROOT/lobechat-termux-android.zip" install.sh lobechat app
ls -lh "$ROOT/lobechat-termux-android.zip"
