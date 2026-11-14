# 04　架構與技術規則

> 2026-11-11 重寫：把舊的「架構」與 `docs/technical-direction.md` 併成這一份，只留現在還成立的（D-227）。原則：**邏輯是純資料類別、場景只負責顯示**，所以開發 loop 能在沒有 GPU 的雲端 session 用 headless 測試驗證大部分行為。

## 技術決定（不變）

- **引擎**：Godot 4.7.2 stable（標準版），固定在 `scripts/get-godot.sh`，不因新版發布就升級。選它的原因：能在 Linux 與 GitHub Actions 上 import、測試、匯出 Windows 版；場景與腳本是純文字；開源、無權利金。
- **語言**：GDScript＋靜態型別（未加型別的宣告視為錯誤）。不使用 C#／.NET。
- **渲染**：Forward+。Windows 預設 D3D12，失敗時由 Godot 退回 Vulkan。
- **平台**：Windows 64-bit；CI 順便匯出 Linux 跑 smoke test。
- **效能目標**（待實機驗證，不是承諾）：中階獨顯、1080p 中等畫質、60 fps。量測用遊戲內建的效能 overlay（F3）與 `--benchmark`（結果寫到 `user://benchmark/`）；實機步驟在 [`../playtest.md`](../playtest.md)。體積霧、SSAO、SSR 等都做成畫質選項（`QualityPreset` 三級）。
- **素材**：程式生成優先（音效、字型子集、貼圖、模型都在建置時產生，不進 git）；單檔超過 1 MB 不進 git；授權記在 `docs/CREDITS.md`。
- **機密**：Steam 憑證、`steam_appid.txt` 不進 git。

## 目錄

```
game/
  project.godot          # Forward+、D3D12、GDScript 型別警告設為錯誤
  autoload/              # App（命令列、字型主題、按鍵）、Settings、Game（持有 GameSession、切關卡）、Perf
  src/core/              # 純邏輯：RefCounted／Resource，不碰場景樹
  src/ui/                # UI 共用：字型、主題、按鍵圖示、HUD 小元件
  src/world/             # 場景用的共用零件：合併 mesh、材質與環境、粒子、shader
  scenes/                # .tscn＋配套 .gd：boot（標題）、levels、actors、ui、world、bench
  data/                  # 任務、對話、戰鬥數值、狀態（JSON），文字只放翻譯 key
  i18n/                  # 翻譯 CSV（keys,en,zh_TW）：strings.csv（介面）、reboot.csv（劇情）
  assets/generated/      # 建置時程序生成，不進 git
  tests/                 # 自製測試框架；unit／flow
scripts/                 # get-godot、check、screenshot、shots（固定鏡頭組）、gen-assets
```

## 主要模組

| 模組 | 位置 | 職責 |
|---|---|---|
| GameState／SaveCodec | `src/core/` | 可存檔的狀態（旗標、任務階段、檢查點、身上的狀態、反轉欄位、道具、一次性發放、生命）；JSON＋版本號、`.tmp` 改名、`.bak` 回復 |
| GameSession | `src/core/game_session.gd` | 一局遊戲：狀態＋任務＋自動存檔＋死亡重試。`new_game()` 開劇情、`in_story()` 問有沒有開 |
| StoryLogic／QuestDB／QuestRunner | `src/core/` | 條件與效果、任務資料驗證、依旗標推進（D-013） |
| DialogueDB／DialogueRunner | `src/core/` | 對話資料驗證、台詞與選項、效果（D-018） |
| StatusEffects／StatusRules／ReversalSlots／PotionBelt／MistZone | `src/core/` | 負面狀態、反轉欄位、身上的藥、毒霧範圍（設計 09） |
| CombatTuning／Health／EnemyBrain／EnemyIntel／CompanionBrain | `src/core/` | 戰鬥數值、生命、敵人狀態機（前兆、出招、破綻、失衡）、看穿資料、席菈的狀態機 |
| FrostbridgeOpening | `scenes/levels/frostbridge_opening.gd` | 前十分鐘的劇情控制器（開場 → 毒霧 → 守衛戰 → 藥箱 → 艾妲與貨梯）。`frostbridge.gd` 只蓋鎮，`in_story()` 時才掛它 |
| PlayerController／Sheila／EnemyActor／Undertaker／Ashwalker／Puppet／Caravan | `scenes/actors/` | 角色：移動、鏡頭、出招、程序人偶與程式動畫 |
| Hud／CombatHud／DialogueBox／PauseMenu／SettingsMenu／ControlsMenu | `scenes/ui/` | 介面；文字全走翻譯 key |
| StaticBatch／FrostbridgeLook／PoisonMist／PotionCrate／HealMotes | `src/world/`、`scenes/world/` | 靜態幾何合併、冬夜環境與材質、毒霧、藥箱、回血光點 |
| Sfx／Ambience／Footsteps | `src/core/`、`scripts/gen_sfx.py` | 程序音效（建置時產生） |

## 資料格式（D-013）

- **結構用 JSON，文字用翻譯 key**。JSON 裡不出現玩家看得到的文字，只出現 `RB_…`／`Q_RB_…` 這類 key；文字在 `i18n/*.csv`。測試會檢查每個 key 都有 en＋zh_TW、JSON 引用的 key 都存在。
- 任務：`{"id", "title", "stages": [{"id", "objective", "done_when", "marker", "checkpoint"}]}`；每個階段都要有 `marker` 與 `checkpoint`。
- 對話節點：`{"id", "speaker", "text", "next" | "choices": [{"text", "next", "if", "do"}]}`；`if`／`do` 只能讀寫旗標，不能執行任意程式。
- 字型子集化（`gen_fonts.py`）掃描 `i18n/*.csv`，新增文字不會缺字。

## 存檔與檢查點

- 場景只透過 `set_flag`／`add_flag` 改狀態，不直接改存檔。存檔內容只有 `GameState.to_dict()`；場景狀態（敵人位置等）不存，從檢查點重建。
- 進入有 `checkpoint` 的任務階段時自動存檔；死亡重試＝重讀那一份。寫檔前 `GameSession.saving` 讓玩家把生命、狀態、反轉欄位寫回去。
- **存檔資料夾是 `user://saves_reboot`、存檔裡的 `mode` 是 `"reboot"`、任務與旗標是 `rb_*`：這些名字不改**（玩家已經有存檔，D-227）。`user://saves` 是以前舊劇情的資料夾，遊戲不讀也不寫。開發旗標（`--level=…`）開的遊戲存在 `user://saves_dev_reboot`。
- 改存檔格式：`CURRENT_VERSION` +1、在 `SaveCodec` 加一步遷移、加一個從舊版 JSON 讀起的測試。目前 v3；比 `MIN_VERSION` 舊的回「太舊」，不遷移、不刪檔。

## 關卡

- 關卡繼承 `StoryLevel`（地面高度、腳步聲材質）。靜態幾何用 `StaticBatch` 依材質合併成少數 MeshInstance＋一個 StaticBody。
- 檢查點對到哪個關卡：`Game.CHECKPOINT_LEVELS`；出生點在劇情控制器的 `SPAWNS`。

## 角色模型接入點（D-041）

- 交件：`art-inbox/characters/<id>/<id>.glb`（id：noen、sheila、undertaker、ashwalker；規格見 `docs/ART_REQUESTS.md`）。
- 收件：`scripts/gen-assets.sh` → `scripts/import_characters.py` → `scripts/check_character_glb.py`（靜態檢查、不執行模型內容）。通過才複製到 `game/assets/characters/<id>/<id>.glb`（gitignore）；LFS 指標檔略過；沒過就刪掉舊複本。
- 遊戲端：`CharacterModels`（路徑、動作表對應、手骨骼名稱）＋`Puppet.character_id`。有 Skeleton3D 的模型才採用；AnimationPlayer 依 `current_state()` 播 `ANIM_MAP` 裡第一個存在的動作（idle、walk、run、dodge_roll、light_attack_01；比對結尾）。缺閃避動作 → 整個人前滾；缺其他 → idle。
- 掛點：`hand("L"|"R")` 回傳手骨骼上的 BoneAttachment3D；找不到骨骼就放在估計位置並警告。
- 不跟模型走的：碰撞膠囊、AI、弱點判定（位置仍由程式決定）。

## 測試與命令列

- `scripts/check.sh`：import（兩次）→ `tests/unit` → `tests/flow`；有 `SCRIPT ERROR` 一律算失敗。
- 主線流程測試 `tests/flow/test_story_playthrough.gd`：標題按新遊戲 → 一路玩到目前的結尾。**每加一段就把它的結尾往後延。**
- 命令列旗標（`--` 之後）與截圖做法寫在 [`../NEXT.md`](../NEXT.md) 的「0. 開工先確認」。
