# 這些詛咒對我太有用了～被嫌棄的易感染體質，其實是逆轉一切的外掛～

PC 單機、第三人稱的動漫風動作 RPG（Godot 4）。F 級冒險者諾恩的身體會把**所有異常狀態與詛咒反轉成增益**：別人中毒掉血，他中毒回血；別人麻痺倒地，他麻痺變快。只有他能把鍊金術師席菈那些「副作用超強的失敗作」當神藥用——所以這個遊戲裡，陷阱、毒霧、詛咒裝備都是補給，要**故意去踩**。

> 狀態（2026-11-14）：劇情改版後**重新開始**，正在做第一章《毒瘤與破爛的共鳴》（[劇本](docs/story/chapter-1.md)、[實作計畫](docs/design/13-chapter-1-plan.md)）。現在玩得到的是「腐敗之森入口」的最小版：走進瘴氣、打三隻史萊姆。repo 名稱 `yuming-city` 是早期的名字（執行檔與存檔資料夾叫 `CursesTooUseful`）。

## 怎麼開始玩

1. 到 [Releases → latest](https://github.com/twjackysu/yuming-city/releases/tag/latest) 下載 `CursesTooUseful-windows-x64-*.zip`。
2. 解壓縮，雙擊 `CursesTooUseful.exe`。
3. 標題畫面按「**新遊戲**」。鍵鼠或 Xbox 類手把都可以；操作在 [docs/design/02-gameplay.md](docs/design/02-gameplay.md)。

## 資料夾

| 路徑 | 內容 |
|---|---|
| `game/` | Godot 專案（GDScript）。`scenes/` 場景、`src/` 邏輯、`data/` 對話與任務、`i18n/` 翻譯、`tests/` 自動測試 |
| `docs/story/` | 劇情：[總覽](docs/story/README.md)、[第一章劇本](docs/story/chapter-1.md) |
| `docs/design/13-chapter-1-plan.md` | 第一章的實作計畫（場景、系統、順序、要產的模型） |
| `docs/design/14-repo-and-assets.md` | repo 與素材的放法（什麼進 git、什麼不進） |
| `docs/design/02-gameplay.md`／`03-art-audio-direction.md`／`04-architecture.md` | 操作與規則、美術與音效方向、架構＋程式地圖（東西在哪個檔）＋開發工具 |
| `docs/NEXT.md`／`docs/PROGRESS.md`／`docs/DECISIONS.md` | 待辦、每一輪做了什麼、還在生效的決策 |
| `docs/FOR_JACKY.md` | 需要 Jacky 看或回覆的事 |
| `docs/ART_QUALITY_BAR.md`／`docs/ART_REQUESTS.md` | 畫面標準（漫畫風）、美術待辦與規格 |
| `art-inbox/` | 美術素材：`tripo/`（Tripo 產的模型與佇列）、`props/`（CC0 套件） |
| `tools/blender/` | 把 Tripo 的模型轉成遊戲用的（bpy） |
| `scripts/` | 檢查、截圖、產生音效與字型的腳本 |

## 用原始碼開

- 安裝 [Godot 4.7.2 stable](https://godotengine.org/download/archive/4.7.2-stable/)（標準版，不是 .NET 版），在專案管理員「匯入」`game/project.godot`，按 F5。
- Linux 可以直接執行 `scripts/get-godot.sh` 下載並驗證同一版本。
- 檢查：`scripts/check.sh`（匯入＋全部測試）；`scripts/check.sh --export` 再匯出 Windows／Linux。
- 每次推到 `main`，GitHub Actions 會跑測試、匯出，並把建置檔放到 [latest](https://github.com/twjackysu/yuming-city/releases/tag/latest)、截圖放到 [screens](https://github.com/twjackysu/yuming-city/releases/tag/screens)。

## 舊版去哪了

2026-11-14 以前的版本（霜橋鎮、地下市場、戰鬥場）在分支 [`archive/pre-restart-2026-11-14`](https://github.com/twjackysu/yuming-city/tree/archive/pre-restart-2026-11-14)。更早的在 git 歷史裡。

## 約定

- 引擎固定 Godot 4.7.2 stable（GDScript＋靜態型別，不用 C#），版本寫在 `scripts/get-godot.sh`。
- 玩家看得到的字一律走翻譯 key（繁中＋英文）。
- 建置產物、Godot 快取、機密與 `steam_appid.txt` 不進 git。
- 本儲存庫未授予開源授權；第三方素材依各自授權管理，見 [docs/CREDITS.md](docs/CREDITS.md)。
