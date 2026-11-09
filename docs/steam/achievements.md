# 成就（草稿，切片版）

> 第 35 輪寫的設計草稿，**第 36 輪實作完成（D-147）**：條件在 `game/data/achievements.json`、文字在 `i18n/strings.csv`（`ACH_<…>_NAME`／`_DESC`）、圖示替代版由 CI 產生（`achievement-icons.zip`，見 asset-specs）。名稱照 `docs/design/06-terminology.md` 的白話原則；Jacky 想改名或拿掉哪個，回覆在 FOR_JACKY 就好。
> 正式上架時 Jacky 要在 Steamworks 後台逐一建立（API 名稱＝下表的 ID），圖示需求見 `docs/ART_REQUESTS.md`（先用程序生成的替代圖示）。

## 原則

- **少而精**：切片 8 個，每個對應一個值得記住的時刻，不做「跑 1000 步」這種磨時間的。
- **不劇透**：選擇與結局相關的成就設成隱藏（Steam 的 hidden），名稱不寫出選項內容。
- **不逼玩家選某邊**：兩條路線（重現石拱／燃燒劍）各一個，記憶代價沒有「懲罰」成就。
- **跟存檔槽分開**：成就是帳號層級，存在 `user://achievements.json`（有版本號）；讀舊存檔不會解鎖也不會取消。有 GodotSteam 時同步到 Steam。

## 清單

| ID | 名稱（繁中／English） | 說明（繁中／English） | 條件（遊戲狀態） | 隱藏 |
|---|---|---|---|---|
| `ACH_NINTH_BELL` | 第九聲鐘／The Ninth Bell | 把那口舊鐘敲滿九下。／Ring the old bell nine times. | `slice.bell_rings` ≥ 9（跳過演出也算） | 否 |
| `ACH_NO_ONE_LEFT` | 沒有人被留在雪裡／No One Left in the Snow | 從倒塌的北街救出三個人。／Pull three people out of the collapsed north street. | `slice.rescued_count` ≥ 3 | 否 |
| `ACH_SEEN_THROUGH` | 看穿／Seen Through | 打中灰巡者的弱點，讓牠跪下。／Hit an Ashwalker's weak point and bring it to its knees. | `stats.ashwalker_weak_kneels` ≥ 1（打中弱點而失衡跪地時 `EnemyActor` 記一次） | 否 |
| `ACH_THE_TRUTH` | 實話／The Truth | 第一次見面就說了實話。／Tell the truth at the first meeting. | `slice.told_truth_about_bell` | 是 |
| `ACH_NINE_SECONDS` | 九秒的石拱／Nine Seconds of Stone | 讓重現的石拱擋下飛來的鐵架。／Let a restored arch stop the thrown iron frame. | `slice.frame_throw_outcome` ＝ `"arch"` | 是 |
| `ACH_BURNING_BLADE` | 燃燒劍／The Burning Blade | 讓席菈的燃燒劍斬斷鐵架。／Let Sheila's burning blade cut the iron frame in two. | `slice.frame_throw_outcome` ＝ `"kindling"` | 是 |
| `ACH_SAFE_PASSAGE` | 一個都沒少／Safe Passage | 護送車隊通過南街，沒有任何傷者再受傷。／Get the convoy through South Street without anyone hurt again. | `slice.convoy_through` 且 `slice.convoy_injured` ＝ 0 | 否 |
| `ACH_CELLAR_DOOR` | 地窖的門／The Cellar Door | 走完霜橋鎮的那一夜。／Live through the night in Frostbridge. | `slice.complete` | 否 |

候補（之後的章節或覺得太少時再加）：不倒下走完切片（要在存檔記這一輪倒下幾次）、日記讀完所有被剪掉的記憶、第 1 章的「攻略筆記」被推翻 N 條。

## 實作備註

- 判斷時機：`Game` 每次設旗標（或任務推進、存檔前）時檢查一次所有未解鎖的條件；條件用跟任務 `done_when` 一樣的格式（`flag`／`gte`／`eq`／`all`／`any`），寫在 `game/data/achievements.json`，不寫死在程式裡。
- `ACH_SEEN_THROUGH` 需要新事件（不是旗標）：在灰巡者因為弱點失衡時呼叫 `Achievements.unlock("ACH_SEEN_THROUGH")`，或設一個 `stats.ashwalker_knee_staggers` 計數旗標再用條件判斷（後者比較好測）。
- i18n key：`ACH_<ID 去掉 ACH_>_NAME`／`_DESC`（例如 `ACH_NINTH_BELL_NAME`）；中文進 CSV 前先過 `test_i18n::test_no_obscure_terms`。
- 解鎖時畫面右上角一張小卡（跟看穿小卡同一套 Theme），1.5 秒淡出；過場與對話中延後到結束才顯示。Steam 版由 Steam 自己的通知取代（有 GodotSteam 時不畫自己的）。
- 測試：流程測試兩條路線跑完後，各自該解鎖的都解鎖、另一條路線的沒有；重開（重建 Achievements）後還在；讀舊存檔不影響。

## Steam 端（等 Jacky 有 App ID）

- 後台逐一建立 8 個成就：API 名稱＝上表 ID，名稱／說明照 `i18n/strings.csv`，隱藏的三個勾 Hidden，圖示批次上傳 `achievement-icons.zip`。
- 遊戲端已經寫好轉接（`SteamBridge`）：放進 GodotSteam（GDExtension）後，解鎖時呼叫 `setAchievement`＋`storeStats`、啟動時把本機已解鎖的補上去，不用再改遊戲邏輯。
- 雲端存檔用 **Steam Auto-Cloud**（不用寫程式）：後台設定路徑 `%APPDATA%\YumingCity\saves\`（`*.json`）與 `%APPDATA%\YumingCity\achievements.json`；Steam 成就本身由 Steam 同步。
