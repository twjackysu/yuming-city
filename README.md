# 餘命城：這些詛咒對我太有用了（暫名）

PC 單機、第三人稱的動作 RPG。主角諾恩的身體會把**負面狀態反過來用**：別人中毒會掉血，他中毒會回血。目前做到「前十分鐘」加上地下市場：彌夏的藥店、黑市示範場（聽叫賣、打倒兩個守衛、拿到護腕）、回藥店試戴護腕（**麻痺裝進第二格：出手加速**），可以從標題一路玩到第二格亮起來之後的「待續」。

## 怎麼開始玩（3 步）

1. 到 [Releases → latest](https://github.com/twjackysu/yuming-city/releases/tag/latest) 下載 `YumingCity-windows-x64-*.zip`。
2. 解壓縮，雙擊 `YumingCity.exe`。
3. 標題畫面按「**新遊戲**」。約 18 分鐘，玩到畫面出現「待續」就是目前的結尾。

鍵鼠或 Xbox 類手把都可以。不知道往哪走，就跟著畫面上的小菱形＋距離走。

![標題畫面](https://github.com/twjackysu/yuming-city/releases/download/latest/title.png)

![毒霧裡：中毒，生命卻往上爬](https://github.com/twjackysu/yuming-city/releases/download/screens/41-rb-mist.png)

![南街的守衛](https://github.com/twjackysu/yuming-city/releases/download/screens/45-rb-guardian.png)

## 前十分鐘會發生什麼

| # | 段落 | 你要做的事 |
|---|---|---|
| 1 | 北街鐵門 | 鐵門被關上，送葬者從屋頂跳下來。**站在推車旁邊它才會走**，把受傷的波克往南推 |
| 2 | 毒霧 | 牠扔燈柱砸破藥桶，主街一片綠霧。走進去：生命條往上爬。走出來等毒效結束，再踏進去一次確認 |
| 3 | 南街口 | 霧散了，繼續推車到南街口，席菈從麵包店出來，走到她旁邊 |
| 4 | 守衛戰 | 和席菈打倒南街的送葬者。牠胸口的管子發綠光＝要噴毒：**毒會讓你回血，爪子和下砸照樣會痛** |
| 5 | 藥箱 | 牠倒下後背上的箱子摔在旁邊，走近拿兩瓶毒藥，可以隨身帶著喝 |
| 6 | 梨攤與貨梯 | 回廣場找梨攤前的艾妲 → 站上攤子後面亮著燈的貨梯 → 下到地下市場 |
| 7 | 地下市場 | 走下坡道到街上（席菈說這裡的規矩）→ 沿著攤販街走到街底綠色窗戶的藥店 |
| 8 | 彌夏的藥店 | 從開著的門走進去 → 櫃台後面的彌夏不相信他 → 站到櫃台上的測試板前**按住互動鍵 2 秒** → 指針甩到綠色那邊、生命往上 → 她願意談，把人指到黑市示範場 |
| 9 | 黑市示範場 | 走出藥店往北，街中段有一座掛著紅白直條紋布的示範台 → 走近聽商人叫賣「高速護腕」→ 諾恩看出他真正在賣的是解藥 → 再走近：席菈要他「再示範一次」，兩個守衛打過來（拿棍子的、戴護腕的：出拳很快，但每打一拳手就麻掉僵住）→ 兩個都打倒，商人把護腕丟過來 |
| 10 | 試戴護腕 | 往南走回彌夏的店、到櫃台前 → 彌夏：先戴上、把那隻手放到測試板上 → 按住互動鍵 2 秒 → 畫面中央「【麻痺】／【第二格反轉】麻痺 → 出手加速」，左下多一行黃色閃電的狀態、護腕戴在右手上、這 12 秒出手變快 → 彌夏講結果 → 「待續」（下一段：兩格一起用，找地方打一場） |

想留感想：寫在 [docs/FOR_JACKY.md](docs/FOR_JACKY.md) 的「回覆」區。更細的試玩說明在 [docs/playtest.md](docs/playtest.md)。

## 操作

| 動作 | 鍵鼠 | 手把 |
|---|---|---|
| 移動／鏡頭 | WASD／滑鼠（點一下畫面鎖定滑鼠） | 左／右搖桿 |
| 衝刺 | Shift | 左搖桿按下 |
| 閃避 | Space | B |
| 揮擊 | 滑鼠左鍵 | X |
| 看穿（按住：看敵人的弱點與招式） | 滑鼠右鍵 | LT |
| 鎖定目標 | 滑鼠中鍵 | 右搖桿按下 |
| 叫席菈：打弱點／閃開／守住 | Q／E／R | 十字鍵 上／右／下 |
| 互動／對話下一句（按住跳過） | F | A |
| 喝隨身的藥 | 1 | 十字鍵左 |
| 暫停 | Esc | Start |

按鍵都可以在「設定 → 按鍵設定」改。設定裡還有難度（故事／標準／困難）、語言（繁中／英文）、音量、畫質、全螢幕。

## 這個 repo 裡有什麼

| 路徑 | 內容 |
|---|---|
| `game/` | Godot 專案（GDScript）。`scenes/` 場景、`src/` 邏輯、`data/` 對話與任務、`i18n/` 翻譯、`tests/` 自動測試 |
| `docs/story-reboot/` | 劇情：[入口](docs/story-reboot/README.md)、[故事大綱](docs/story-reboot/story-v2.md)、[開場](docs/story-reboot/opening-v2.zh-TW.txt)、[二十種反轉效果](docs/story-reboot/status-reversal.md) |
| `docs/design/09-reboot-first-ten-minutes.md` | 前十分鐘的規則、數值、進度 |
| `docs/design/10-reboot-underground-market.md` | 地下市場（第二段）：做好的部分與接下來的規劃 |
| `docs/design/02-gameplay.md`／`04-architecture.md`／`06-terminology.md` | 操作與戰鬥規則、程式架構與技術規則、用詞 |
| `docs/NEXT.md`／`docs/PROGRESS.md`／`docs/DECISIONS.md` | 待辦、每一輪做了什麼、決策紀錄 |
| `docs/FOR_JACKY.md` | 需要 Jacky 看或回覆的事 |
| `docs/ART_QUALITY_BAR.md` | 畫面品質的標準 |
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
