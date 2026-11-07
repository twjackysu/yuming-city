# 餘命城 / Yuming City

以原創小說《餘命城》改編的 PC 單機敘事動作 RPG。第三人稱、章節式，核心是「九息重現」：用九次呼吸的時間讓毀壞之物重新站起，代價是一段記憶。

> 目前狀態：**階段 1：垂直切片（核心框架完成，戰鬥系統大部分完成）**。「新遊戲」進入冬夜街道沙盒：和梨販說完話，走到鐘樓親手敲九下，第九聲北街陷落。戰鬥沙盒（`--enemies`／`--boss`）裡可以和席菈一起對付灰巡者與送葬者：看穿弱點、喊出指令。首個可玩切片《霜橋鎮的第九聲鐘》預計 2026-11-30 完成。

![冬夜街道沙盒（原型，程序生成）](https://github.com/twjackysu/yuming-city/releases/download/latest/sandbox.png)

![和梨販的對話（原型）](https://github.com/twjackysu/yuming-city/releases/download/latest/dialogue.png)

![親手敲九下（原型）](https://github.com/twjackysu/yuming-city/releases/download/latest/bell.png)

![看穿送葬者，席菈在旁（原型）](https://github.com/twjackysu/yuming-city/releases/download/latest/combat.png)

## 試玩

- **Windows**：到 [Releases → latest](https://github.com/twjackysu/yuming-city/releases/tag/latest) 下載 `YumingCity-windows-x64-*.zip`，解壓後執行 `YumingCity.exe`。這是每次推送到 `main` 自動建置的開發版。
- **用 Godot 開啟原始專案**：安裝 [Godot 4.7.2 stable](https://godotengine.org/download/archive/4.7.2-stable/)（標準版，不是 .NET 版），在專案管理員「匯入」`game/project.godot`。Linux 可以直接執行 `scripts/get-godot.sh` 下載並驗證同一版本。

## 操作方式

| 動作 | 鍵鼠 | 手把 |
|---|---|---|
| 移動／鏡頭 | WASD／滑鼠（點一下畫面鎖定滑鼠） | 左／右搖桿 |
| 衝刺 | Shift | 左搖桿按下 |
| 閃避（前滾） | Space | B |
| 揮擊（鐘錘下劈） | 滑鼠左鍵 | X |
| 看穿（按住：已知弱點與招式） | 滑鼠右鍵 | LT |
| 鎖定目標 | 滑鼠中鍵 | 右搖桿按下 |
| 指令席菈：打弱點／閃開／守住 | Q／E／R | 十字鍵 上／右／下 |
| 互動／對話下一句／敲鐘（按住跳過） | F | A |
| 再看一次目前目標 | Tab | Back |
| 暫停 | Esc | Start |
| 效能 overlay | F3 | — |

戰鬥沙盒：Windows 版在解壓資料夾開 PowerShell，執行 `.\YumingCity.exe ++ --level=sandbox --enemies`（灰巡者）或 `--boss`（送葬者）。繞到灰巡者左側打得到左膝；牠出完招的破綻或跪地時喊「打弱點」，前兆後段喊「閃開」。

選單：方向鍵／滑鼠或手把十字鍵選擇，Enter／A 確認，Esc／B 返回；設定裡左右鍵切換選項。所有按鍵都可以在「設定 → 按鍵設定」重新綁定（暫停鍵與移動搖桿除外）。戰鬥、指令、九息等完整操作見 [docs/design/02-gameplay.md](docs/design/02-gameplay.md)，會隨切片陸續加入。

## 目前完成的範圍

- Godot 4.7.2 專案骨架（`game/`），Forward+ 渲染，Windows 預設 D3D12
- 繁中＋英文在地化，所有玩家可見文字都走翻譯 key
- 自動測試（腳本型別檢查、i18n 規則、主線流程）與 GitHub Actions 自動匯出 Windows／Linux
- 資料驅動任務系統、版本化存檔（自動存檔、死亡重試）、九息狀態機；主線流程測試能從新遊戲走到切片結尾（任務層面）
- 第三人稱移動與越肩鏡頭、冬夜街道沙盒（體積霧、暖光）、程序人偶與程式動畫
- 暫停選單、設定選單（難度、語言、主音量／音樂／音效／語音、字幕、畫質三級、全螢幕、垂直同步、減少鏡頭晃動）、HUD（目前目標、存檔提示）
- 對話系統：逐字浮現、選項、按住跳過；付出記憶後，相關的對話選項會消失
- 按鍵重新綁定（鍵鼠＋手把、衝突自動交換），提示依目前裝置顯示 [F]／[A]
- 過場與可互動演出：黑邊、字幕、按住跳過；敲鐘九下（每下一個輸入）、北街陷落
- 戰鬥：鐘錘命中、打擊停頓、鏡頭震動、練習木樁；看穿（已證實／未證實）與弱點方向判定；鎖定目標；灰巡者（前兆、爪擊、失衡跪地）；送葬者第一階段（橫掃／下砸／衝撞＋地面霜紋，撞牆跪地）；倒下後從檢查點重來
- 同伴席菈：跟隨、自主斬擊、三個指令（時機窗依難度、冷卻、拒絕附理由、頭上回話）
- 難度三級（故事／標準／困難，即時套用）；程序生成音效（鐘聲、打擊、爪擊、斬擊、閃避）
- 效能 overlay（F3）與 benchmark：`YumingCity.exe ++ --benchmark`，結果寫到 `%APPDATA%\YumingCity\benchmark\`

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
