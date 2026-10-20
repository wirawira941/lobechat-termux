#!/data/data/com.termux/files/usr/bin/sh
# Installs the LobeChat standalone server into ~/lobechat and drops the
# `lobechat` launcher into $PREFIX/bin. Run from the unzipped folder:
#   ./install.sh
set -e
cd "$(dirname "$0")"
SRC_DIR="$(pwd)"

if ! command -v node >/dev/null 2>&1; then
  echo "Node.js belum terpasang. Menginstall paket nodejs Termux..."
  pkg install -y nodejs
fi

DEST="$HOME/lobechat"
mkdir -p "$DEST"

if [ "$SRC_DIR" = "$DEST" ]; then
  # The package was unzipped directly into ~/lobechat: app/ is already
  # where it belongs, so there is nothing to copy. (An earlier version
  # deleted $DEST/app before copying and ate its own source when the
  # unzip folder WAS ~/lobechat.)
  echo "Paket sudah berada di $DEST — melewati langkah salin app/."
else
  rm -rf "$DEST/app.new"
  cp -r app "$DEST/app.new"
  rm -rf "$DEST/app"
  mv "$DEST/app.new" "$DEST/app"
fi
cp lobechat "$PREFIX/bin/lobechat"
chmod +x "$PREFIX/bin/lobechat"

echo ""
echo "Selesai. Jalankan dengan perintah:  lobechat"
echo "Lalu buka http://localhost:3210 di browser HP."
echo "Data chat tersimpan di browser (client DB) — tidak perlu database server."
