# 這些詛咒對我太有用了～被嫌棄的易感染體質，其實是逆轉一切的外掛～

PC 單機、第三人稱的動漫風動作 RPG（Godot 4）。F 級冒險者諾恩的身體會把**所有異常狀態與詛咒反轉成增益**：別人中毒掉血，他中毒回血；別人麻痺倒地，他麻痺變快。只有他能把鍊金術師席菈那些「副作用超強的失敗作」當神藥用——所以這個遊戲裡，陷阱、毒霧、詛咒裝備都是補給，要**故意去踩**。

> 狀態（2026-11-14）：劇情剛改版，正在做第一章《毒瘤與破爛的共鳴》（[劇本](docs/story/chapter-1.md)、[實作計畫](docs/design/13-chapter-1-plan.md)）。現在下載到的版本裡，「新遊戲」還是改版前的舊試玩（約 20 分鐘），人物與戰鬥是新的。repo 名稱 `yuming-city` 是早期的名字。

## 怎麼開始玩

1. 到 [Releases → latest](https://github.com/twjackysu/yuming-city/releases/tag/latest) 下載 `YumingCity-windows-x64-*.zip`。
2. 解壓縮，雙擊 `YumingCity.exe`。
3. 標題畫面按「**戰鬥場**」直接開打，或「**新遊戲**」玩舊版試玩。鍵鼠或 Xbox 類手把都可以；操作說明在 [docs/playtest.md](docs/playtest.md)。

## 資料夾

| 路徑 | 內容 |
|---|---|
| `game/` | Godot 專案（GDScript）。`scenes/` 場景、`src/` 邏輯、`data/` 對話與任務、`i18n/` 翻譯、`tests/` 自動測試 |
| `docs/story/` | 劇情：[總覽](docs/story/README.md)、[第一章劇本](docs/story/chapter-1.md) |
| `docs/design/13-chapter-1-plan.md` | 第一章的實作計畫（場景、系統、順序、要產的模型） |
| `docs/design/14-repo-and-assets.md` | repo 與素材的放法（什麼進 git、什麼不進） |
| `docs/design/02-gameplay.md`／`04-architecture.md`／`05-code-map.md`／`06-terminology.md` | 操作與戰鬥規則、程式架構與技術規則、程式地圖（東西在哪個檔）、用詞 |
| `docs/NEXT.md`／`docs/PROGRESS.md`／`docs/DECISIONS.md` | 待辦、每一輪做了什麼、決策紀錄 |
| `docs/FOR_JACKY.md` | 需要 Jacky 看或回覆的事 |
| `docs/ART_QUALITY_BAR.md`／`docs/ART_REQUESTS.md` | 畫面標準（漫畫風）、美術待辦與規格 |
| `art-inbox/` | 交付的美術素材與接入說明 |
| `scripts/` | 檢查、截圖、產生音效與字型的腳本 |

## 用原始碼開

- 安裝 [Godot 4.7.2 stable](https://godotengine.org/download/archive/4.7.2-stable/)（標準版，不是 .NET 版），在專案管理員「匯入」`game/project.godot`，按 F5。
- Linux 可以直接執行 `scripts/get-godot.sh` 下載並驗證同一版本。
- 檢查：`scripts/check.sh`（匯入＋全部測試）；`scripts/check.sh --export` 再匯出 Windows／Linux。
- 每次推到 `main`，GitHub Actions 會跑測試、匯出，並把建置檔放到 [latest](https://github.com/twjackysu/yuming-city/releases/tag/latest)、截圖放到 [screens](https://github.com/twjackysu/yuming-city/releases/tag/screens)。

## 舊版去哪了

之前的劇情（霜橋鎮敲鐘、「重現」與記憶代價、第 1～3 章）照 Jacky 2026-11-11 的指示移除：舊的程式、資料、文件都刪掉了（第 76～81 輪，D-220～D-227）。要回頭看舊內容，git 歷史裡都還在（`f7a3b50` 以前）。原作小說保留在 [docs/story/](docs/story/yuming-city-complete.zh-TW.md)。

## 約定

- 引擎固定 Godot 4.7.2 stable（GDScript＋靜態型別，不用 C#），版本寫在 `scripts/get-godot.sh`。
- 玩家看得到的字一律走翻譯 key（繁中＋英文）。
- 建置產物、Godot 快取、機密與 `steam_appid.txt` 不進 git。
- 本儲存庫未授予開源授權；第三方素材依各自授權管理，見 [docs/CREDITS.md](docs/CREDITS.md)。
