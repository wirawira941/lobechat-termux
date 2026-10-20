#!/data/data/com.termux/files/usr/bin/sh
# Installs the LobeChat standalone server into ~/lobechat and drops the
# `lobechat` launcher into $PREFIX/bin. Run from the unzipped folder:
#   ./install.sh
set -e
cd "$(dirname "$0")"

if ! command -v node >/dev/null 2>&1; then
  echo "Node.js belum terpasang. Menginstall paket nodejs Termux..."
  pkg install -y nodejs
fi

DEST="$HOME/lobechat"
mkdir -p "$DEST"
rm -rf "$DEST/app"
cp -r app "$DEST/app"
cp lobechat "$PREFIX/bin/lobechat"
chmod +x "$PREFIX/bin/lobechat"

echo ""
echo "Selesai. Jalankan dengan perintah:  lobechat"
echo "Lalu buka http://localhost:3210 di browser HP."
echo "Data chat tersimpan di browser (client DB) — tidak perlu database server."
