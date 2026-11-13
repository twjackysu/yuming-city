# 現成的小物：Quaternius Fantasy Props MegaKit（免費版）

Jacky 2026-11-13 從 itch.io 下載、放進來的（`e4fdaa3`）。94 個模型：市場攤位與推車、木桶、木箱、寶箱、架子、桌椅、瓶子與藥水、燈、蠟燭、大鍋、籠子、鐵鏈、麻袋、書、武器架……地下市場與藥店用得到的幾乎都有。

## 授權

`License_Standard.txt`（跟著這包一起來的授權檔，原樣留著）寫 **CC0 1.0 Universal**。這是我們用這包的根據。

Quaternius 的網站另外有一頁「Quaternius Asset License (QAL) v1.0」（寫 2026-08-28 更新）：不能把素材本身當素材轉賣或轉散布；同一頁也寫「以你取得素材當時的版本為準」。那一頁沒有提 CC0，素材包自己的頁面（<https://quaternius.com/packs/fantasypropsmegakit.html>）到 2026-11-13 還是標 CC0。兩頁沒有說哪一份管這一包，所以**以這包裡附的授權檔為準**；之後要再下載他的別包，先看那一包裡附的授權檔寫什麼，不是 CC0 就不要放進這個公開的 repo。

## 這個資料夾裡的是縮過的版本（D-258）

| | 原檔（`e4fdaa3`） | 現在 |
|---|---|---|
| 貼圖 | 13 張 PNG，2048²（一張 4096²），38.3 MB，走 LFS | 13 張 JPEG，1024²（雜訊那張 512²），2.7 MB，直接進 git |
| 模型 | 94 個 `.gltf`＋`.bin`，5.6 MB | 一樣（`.gltf` 只改了貼圖的檔名） |
| 合計 | 43.9 MB | 8.2 MB |

- 縮的工具：`python3 -P scripts/compact_props.py art-inbox/props/Exports/glTF`（之後再放別包進來也用它；`--check` 只檢查不改檔）。
- 品質：跟「原檔無失真縮到同尺寸」比，PSNR 39～51 dB（看不出差別）。小物在畫面上只有一兩百個像素，1024² 夠用。
- 原檔還在 git 歷史裡，要拿回來：`git checkout e4fdaa3 -- art-inbox/props && git lfs pull --include="art-inbox/props/**"`。

## 怎麼用進遊戲

遊戲只讀 `game/assets/props/`（`PropModels`，D-257），**不直接讀這裡**。要用哪一個，就把它的 `.gltf`＋`.bin`＋它用到的貼圖（看 `.gltf` 的 `images`：`T_Trim_Props_*`、`T_Trim_Furniture_*`、`T_Trim_Metal_*`、`T_Trim_Cloth_*` 各三張）複製到 `game/assets/props/quaternius/`，再記進 `docs/CREDITS.md`。只複製用到的——放進 `game/` 的東西都會被打包進遊戲。

尺寸是公尺、跟我們的人物比例相近（木桶 0.7 × 0.9 m、攤位高 2.6 m），大多不用縮放。`Chest_Wood` 的外框量出來是 1.9 × 2.0 × 2.1 m（蓋子打開、原點不在底部），用之前先看一眼。
