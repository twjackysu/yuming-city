# 14　repo 與素材的放法（怎麼不讓 git 爆掉）

Jacky 2026-11-14 問：「很多遊戲動輒好幾 GB，我怕 git 爆掉。」

## 先講結論

商業遊戲的幾 GB 幾乎都是**素材**（貼圖、模型、音樂、影片）；**程式碼通常只有幾 MB 到幾十 MB**。這個 repo 的工作目錄現在約 85 MB（2026-11-14），其中 `art-inbox/` 的模型約 80 MB、程式與資料不到 5 MB。只要守下面的規則，做到完成也會在幾百 MB 以內，GitHub 沒問題。

GitHub 的限制：單一檔案超過 100 MB 會被拒絕（50 MB 會警告）；整個 repo 建議保持在 1 GB 左右以內。

## 規則

| 東西 | 放哪 | 進 git？ |
|---|---|---|
| 程式、場景、對話、翻譯、shader、測試 | `game/` | 進 |
| 產生素材的腳本（Blender、音效、字型） | `tools/`、`scripts/` | 進 |
| **Tripo 產的模型（已縮過）** | `art-inbox/tripo/<id>/` | 進。`tripo_queue.py` 會把貼圖縮成 1024 的 JPEG：物件約 0.8 MB、人物每個檔約 2 MB。**單檔上限 6 MB** |
| Tripo 的原始下載（一個約 10 MB） | `art-work/`（只在 Jacky 的電腦） | **不進**（.gitignore） |
| 現成的 CC0 素材包 | `art-inbox/<包名>/` | 進，但**先縮**（`scripts/compact_props.py`：貼圖 1024 JPEG）；整包超過 30 MB 就只留用得到的 |
| 建置產生的東西（轉好的角色、擺正的武器、字型子集、音效） | `build/`、`game/assets/characters/`、`game/assets/props/tripo/`、`game/assets/generated/` | **不進**：本機與 CI 每次從來源重新產生 |
| 匯出的遊戲（exe、pck、zip） | GitHub Releases（`latest`） | **不進** |
| 截圖、對照圖 | Releases（`screens`）、`build/shots/` | **不進** |

- **同一個模型不要反覆改了又提交**：git 會把每一版都留著。要重產就換 id（`_v2`），確定不用的舊版在下一次整理時從 `art-inbox/` 刪掉（歷史裡還是佔空間，所以一開始就少放）。
- 人物只留 `_rig`（有動作的再加 `_anim`）；`tripo_queue.py` 已經不存 `_model`。
- **預算**：`art-inbox/` 全部加起來保持在 300 MB 以內；超過 200 MB 時 loop 在 FOR_JACKY 提醒一次。
- 不用 Git LFS（雲端 loop 推不了，免費額度也小）。`.gitattributes` 裡舊的 LFS 規則只影響舊檔。
- 真的需要很大的東西（影片、整包未壓縮的原檔）：放 GitHub Releases 當附件，repo 裡只留下載與驗雜湊的腳本。

程式放哪裡、東西在哪個檔：[`04-architecture.md`](04-architecture.md)。
