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
- 音效與配樂：打擊、閃避風聲、腳步、毒霧、玻璃瓶、介面音、標題配樂（`scripts/gen_sfx.py`，只用 Python 標準函式庫合成，建置時產生、不進 git）
- 人物的動作（站、走、跑、閃、出手、釋放；`tools/blender/common.py` 用程式寫的關鍵影格，套在 Tripo 的模型上）
- 模型找不到時的替身（程式拼的人偶、球、圓柱）

## 第三方素材

| 名稱 | 作者 | 授權 | 來源 | 用在哪裡 | AI 生成 |
|---|---|---|---|---|---|
| KayKit Adventurers Character Pack 1.0 的雙手劍（`sword_2handed.gltf`＋`.bin`＋`knight_texture.png`；Tripo 的劍找不到時的替身，也是擺正武器時對齊的基準） | Kay Lousberg（www.kaylousberg.com） | **CC0 1.0**（素材包根目錄的 `LICENSE.txt`：`License: (Creative Commons Zero, CC0)`、「free to use in personal, educational and commercial projects」；該檔一起放進 `game/assets/props/kaykit/LICENSE-KayKit-Adventurers.txt`） | https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0 （commit 672074b，路徑 `addons/kaykit_character_pack_adventures/Assets/gltf/`；檔案小，直接放進本 repo） | 席菈手上的劍（`Sheila._build_sword()` 經 `PropModels` 載入；縮到 0.42 倍、劍尖朝下）。檔案照原樣，沒有改 | 否 |
| Fantasy Props MegaKit（免費的 Standard 版；94 個模型＋13 張貼圖） | Quaternius（quaternius.com） | **CC0 1.0**——根據是素材包裡附的 `License_Standard.txt`（原樣放在 `art-inbox/props/`）。作者網站另有一頁「Quaternius Asset License v1.0」（2026-08-28 更新）禁止把素材本身轉散布，也寫「以取得當時的版本為準」；素材包自己的頁面到 2026-11-13 還是標 CC0——以包裡附的授權檔為準（`art-inbox/props/README.md`） | https://quaternius.com/packs/fantasypropsmegakit.html （Jacky 2026-11-13 從 itch.io 下載，commit e4fdaa3；貼圖由 `scripts/compact_props.py` 縮成 1024² 的 JPEG） | **還沒用在遊戲裡**——放在 `art-inbox/props/` 當素材庫，用到哪個再複製到 `game/assets/props/quaternius/` 並更新這一格 | 否 |

## AI 生成素材

- Tripo（VAST AI）產的 3D 模型：`art-inbox/tripo/<id>/`，每個資料夾的 `SOURCE.json` 記提示、task id 與日期。2026-11-14 兩批共約 40 個（人物、怪物、武器、場景物件；清單在 `docs/ART_REQUESTS.md`）。Jacky 付費 API 帳號產出，商用權依 Tripo 條款歸帳號持有人；不是 CC0，不得當素材再散布。**上架時要在 Steamworks 申報 Pre-Generated AI content。**
