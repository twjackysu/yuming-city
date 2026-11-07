# 餘命城 / Yuming City

以原創小說《餘命城》改編的 PC 單機敘事動作 RPG。第三人稱、章節式，核心是「九息重現」：用九次呼吸的時間讓毀壞之物重新站起，代價是一段記憶。

> 目前狀態：**階段 0：骨架與設計**。Godot 專案、測試與自動建置已就緒，畫面只有標題選單。首個可玩切片《霜橋鎮的第九聲鐘》預計 2026-11-30 完成。

![標題畫面（原型）](https://github.com/twjackysu/yuming-city/releases/download/latest/title.png)

## 試玩

- **Windows**：到 [Releases → latest](https://github.com/twjackysu/yuming-city/releases/tag/latest) 下載 `YumingCity-windows-x64-*.zip`，解壓後執行 `YumingCity.exe`。這是每次推送到 `main` 自動建置的開發版。
- **用 Godot 開啟原始專案**：安裝 [Godot 4.7.2 stable](https://godotengine.org/download/archive/4.7.2-stable/)（標準版，不是 .NET 版），在專案管理員「匯入」`game/project.godot`。Linux 可以直接執行 `scripts/get-godot.sh` 下載並驗證同一版本。

## 操作方式

目前只有標題選單：方向鍵／滑鼠選擇，Enter 確認；「語言」切換英文與繁體中文。完整鍵鼠與手把操作會隨切片一起加入。

## 目前完成的範圍

- Godot 4.7.2 專案骨架（`game/`），Forward+ 渲染，Windows 預設 D3D12
- 繁中＋英文在地化，所有玩家可見文字都走翻譯 key
- 自動測試（腳本型別檢查、i18n 規則、主線流程）與 GitHub Actions 自動匯出 Windows／Linux

## Steam 上架還差什麼

Steamworks 帳號、App ID、商店頁與分級問卷需由 Jacky 處理，見 [docs/FOR_JACKY.md](docs/FOR_JACKY.md)。

## 路線圖

| 階段 | 日期 | 內容 |
|---|---|---|
| 0 | 11/7–11/9 | 骨架、CI、改編與系統設計文件 |
| 1 | 11/10–11/30 | 垂直切片《霜橋鎮的第九聲鐘》（20–30 分鐘，從頭玩到尾） |
| 2 | 12/1–12/24 | 打磨質感、Steam 整合準備、下一段章節 |
| 3 | 12/25–12/31 | 凍結、修 bug、效能、發表版本 |

詳見 [docs/PLAN.md](docs/PLAN.md)；技術方向見 [docs/technical-direction.md](docs/technical-direction.md)；開發紀錄見 [docs/PROGRESS.md](docs/PROGRESS.md)。

## 原作

[《餘命城》全篇完結小說](docs/story/yuming-city-complete.zh-TW.md)：四部、44 個編號章節，另含尾聲與終章。遊戲改編設計放在 `docs/design/`，與原作分開管理。

## 儲存庫約定

- 引擎：Godot 4.7.2 stable（GDScript＋靜態型別），版本固定在 `scripts/get-godot.sh`。
- 檢查：`scripts/check.sh`（import＋測試），`scripts/check.sh --export`（再匯出 Windows／Linux）。
- 建置產物、Godot 快取、機密與 `steam_appid.txt` 不進 git；大型二進位資產走 Git LFS。
- 本儲存庫未授予開源授權；第三方素材依各自授權管理，見 [docs/CREDITS.md](docs/CREDITS.md)。
