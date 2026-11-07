#!/usr/bin/env bash
# 下載並驗證固定版本的 Godot（Linux x86_64 編輯器，可選匯出模板）。
# 用法：
#   scripts/get-godot.sh              # 只下載編輯器
#   scripts/get-godot.sh --templates  # 另外下載並安裝 export templates
# 結果：
#   $GODOT_HOME/godot  （預設 GODOT_HOME=$HOME/.cache/yuming-godot/<版本>）
#   會在 stdout 最後一行印出 godot 執行檔的絕對路徑。
# 版本固定理由見 docs/DECISIONS.md（D-002）。不要只因有新版就升級。
set -euo pipefail

GODOT_VERSION="4.7.2"
GODOT_TAG="${GODOT_VERSION}-stable"
BASE_URL="https://github.com/godotengine/godot/releases/download/${GODOT_TAG}"
EDITOR_ZIP="Godot_v${GODOT_TAG}_linux.x86_64.zip"
EDITOR_BIN="Godot_v${GODOT_TAG}_linux.x86_64"
TEMPLATES_TPZ="Godot_v${GODOT_TAG}_export_templates.tpz"

GODOT_HOME="${GODOT_HOME:-$HOME/.cache/yuming-godot/${GODOT_TAG}}"
WANT_TEMPLATES=0
for arg in "$@"; do
  case "$arg" in
    --templates) WANT_TEMPLATES=1 ;;
    *) echo "未知參數：$arg" >&2; exit 2 ;;
  esac
done

mkdir -p "$GODOT_HOME"
cd "$GODOT_HOME"

fetch() {
  local name="$1"
  if [[ ! -f "$name" ]]; then
    echo "下載 $name ..." >&2
    curl -fsSL --retry 3 -o "$name.part" "$BASE_URL/$name"
    mv "$name.part" "$name"
  fi
}

verify() {
  local name="$1"
  local expected
  expected="$(awk -v n="$name" '$2 == n { print $1 }' SHA512-SUMS.txt)"
  if [[ -z "$expected" ]]; then
    echo "SHA512-SUMS.txt 找不到 $name" >&2
    exit 1
  fi
  local actual
  actual="$(sha512sum "$name" | awk '{ print $1 }')"
  if [[ "$expected" != "$actual" ]]; then
    echo "SHA512 不符：$name" >&2
    rm -f "$name"
    exit 1
  fi
  echo "SHA512 驗證通過：$name" >&2
}

fetch SHA512-SUMS.txt

if [[ ! -x "$GODOT_HOME/godot" ]]; then
  fetch "$EDITOR_ZIP"
  verify "$EDITOR_ZIP"
  python3 -c 'import sys, zipfile; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])' "$EDITOR_ZIP" "$GODOT_HOME"
  mv "$GODOT_HOME/$EDITOR_BIN" "$GODOT_HOME/godot"
  chmod +x "$GODOT_HOME/godot"
fi

if [[ "$WANT_TEMPLATES" == "1" ]]; then
  TEMPLATE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/${GODOT_VERSION}.stable"
  if [[ ! -f "$TEMPLATE_DIR/version.txt" ]]; then
    fetch "$TEMPLATES_TPZ"
    verify "$TEMPLATES_TPZ"
    mkdir -p "$TEMPLATE_DIR"
    # .tpz 是 zip，內容在 templates/ 底下
    python3 - "$TEMPLATES_TPZ" "$TEMPLATE_DIR" <<'PY'
import sys, zipfile, os, shutil
src, dst = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(src) as z:
    for info in z.infolist():
        if info.is_dir() or not info.filename.startswith("templates/"):
            continue
        rel = info.filename[len("templates/"):]
        # 只需要 Windows / Linux 的 x86_64 桌面模板，略過其他平台以節省空間與 CI cache
        if not (rel == "version.txt" or (rel.startswith(("windows_", "linux_")) and "x86_64" in rel)):
            continue
        out = os.path.join(dst, rel)
        with z.open(info) as fsrc, open(out, "wb") as fdst:
            shutil.copyfileobj(fsrc, fdst)
PY
    rm -f "$TEMPLATES_TPZ"
    echo "匯出模板已安裝到 $TEMPLATE_DIR" >&2
  fi
fi

"$GODOT_HOME/godot" --version >&2 || true
echo "$GODOT_HOME/godot"
