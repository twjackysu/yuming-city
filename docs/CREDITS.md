# 素材與授權

遊戲內「製作人員／授權」畫面會依這份清單產生。新增任何第三方素材都要記在這裡：名稱、作者、授權、來源網址、用在哪裡、是否 AI 生成。

## 引擎與工具

| 名稱 | 授權 | 來源 | 用途 |
|---|---|---|---|
| Godot Engine 4.7.2 | MIT（另含第三方元件授權，見 Godot 的 `COPYRIGHT.txt`） | https://godotengine.org/license/ | 遊戲引擎；遊戲內需附授權聲明 |
| Blender 5.3（`bpy` 模組） | GPL-3.0-or-later | https://www.blender.org/ ／ https://pypi.org/project/bpy/ | 只在建置時用來產生角色模型（`tools/blender/`、`scripts/gen_art.sh`）；不隨遊戲發布，產出的模型不受 GPL 約束 |

## 字型

| 名稱 | 授權 | 來源 | 用途 |
|---|---|---|---|
| Noto Serif CJK TC（SemiBold，Serif 2.003） | SIL Open Font License 1.1 | https://github.com/notofonts/noto-cjk | 標題字型；建置時依用字子集化（`scripts/gen_fonts.py`） |
| Noto Sans CJK TC（Regular／Medium，Sans 2.004） | SIL Open Font License 1.1 | https://github.com/notofonts/noto-cjk | 介面字型；同上 |

## 程式生成素材

以下由本專案程式生成，無第三方授權問題：

- 標題畫面背景（`game/scenes/boot/title_fog.gdshader`）
- 遊戲圖示（`game/icon.svg`）
- 音效與配樂：鈍擊、弱點鈍擊、爪擊、斬擊、閃避風聲、腳步、風雪、毒霧、玻璃瓶、介面音、標題與「待續」的配樂（`scripts/gen_sfx.py`，只用 Python 標準函式庫合成，建置時產生、不進 git）
- 席菈與諾恩的服裝、頭髮、骨架、貼圖與動作（`tools/blender/common.py`、`sheila.py`、`noen.py`；身體是上面「第三方素材」的 MakeHuman CC0 基底；建置時產生、不進 git；產生失敗時用程序人偶）
- 角色與敵人外型：諾恩、席菈的斷劍、灰巡者、送葬者（CSG／程序 mesh，霜紋前兆為程序扇形／圓形／直線）

## 第三方素材

| 名稱 | 作者 | 授權 | 來源 | 用在哪裡 | AI 生成 |
|---|---|---|---|---|---|
| MakeHuman 人體基底網格 `base.obj` 與 `targets/macrodetails/` 的 8 個 target（universal／asian／caucasian／african 的 female-young 與 male-young） | MakeHuman Community | **CC0 1.0**（該專案的 `LICENSE.ASSETS.md`；程式碼是 AGPL，本專案沒有使用或複製它的程式碼） | https://github.com/makehumancommunity/makehuman （commit a8bc2d54ff0ac92e78ff71431b1023eda42bf482；建置時由 `scripts/gen_art.sh` 下載，不進本 repo） | 席菈模型的身體、臉、手（`tools/blender/sheila.py`）；服裝、頭髮、骨架、貼圖、動作是本專案的程式產生的 | 否 |

## AI 生成素材

- 美術概念草案：霜橋鎮冬夜、廢鐘樓、南街石拱、席菈與諾恩（`art-inbox/concepts/`）。2026-11-08 使用 OpenAI 內建 image_gen 依本專案文字設定生成；未使用第三方參考圖。來源與使用條件見該目錄 `SOURCE.txt`，提示與實際解析度見 `prompts.json`、`manifest.json`。尚未用作遊戲內資產；若上架時使用，需納入 Steam AI 內容申報。

- 角色四面設計參考與諾恩獨立正面圖：`art-inbox/concepts/character_references/`，2026-11-08 使用內建 OpenAI image_gen 依原創文字設定生成，未使用第三方角色參考；來源與條款見該目錄 SOURCE.txt，提示與檔案記錄隨附。屬設計參考，尚未作為正式 3D 或運行時素材。
