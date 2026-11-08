# 04　架構

> 狀態：**定稿 v1**（2026-11-08）。寫下現況與接下來切片要長出來的結構。原則：**邏輯是純資料類別、場景只負責顯示**，所以 loop 能在沒有 GPU 的 session 用 headless 測試驗證大部分行為。

## 目錄

```
game/
  project.godot          # Forward+、D3D12、GDScript 型別警告設為錯誤
  autoload/              # 全域單例（越少越好）
  src/core/              # 純邏輯：RefCounted／Resource，不碰場景樹
  src/ui/                # UI 共用：字型、主題、按鍵圖示
  scenes/                # .tscn＋配套 .gd；依用途分資料夾
  data/                  # 任務、對話、戰鬥數值（JSON），文字只放翻譯 key
  i18n/                  # 翻譯 CSV（keys,en,zh_TW）
  assets/generated/      # 建置時程序生成（字型子集、音效），不進 git
  tests/                 # 自製測試框架；unit／flow
scripts/                 # get-godot、check、screenshot、gen-assets
```

## 現況（11/8 第 7 輪結束）

| 模組 | 位置 | 職責 |
|---|---|---|
| App | `autoload/app.gd` | 解析 `--` 後的命令列（截圖模式等）、套用字型主題、註冊按鍵 |
| Settings | `autoload/settings.gd` | 語言、各匯流排音量、字幕、畫質、全螢幕、垂直同步、減少晃動；存 `user://settings.cfg` |
| GameState | `src/core/game_state.gd` | 章節、檢查點、旗標、任務階段、已付記憶、遊玩時間 |
| SaveCodec | `src/core/save_codec.gd` | JSON＋版本號、逐版遷移、`.tmp` 改名、`.bak` 回復（D-011） |
| NineBreath | `src/core/nine_breath.gd` | 九息狀態機（D-012） |
| InputSetup | `src/core/input_setup.gd` | 16 個動作的鍵鼠＋手把預設綁定，程式註冊 |
| UiFonts | `src/ui/ui_fonts.gd` | Noto CJK 子集；不存在時退回系統字型（D-010） |
| Game | `autoload/game.gd` | 持有 GameSession；新遊戲、繼續、依檢查點切關卡；`--level`、`--benchmark` |
| Perf | `autoload/perf.gd` | 效能 overlay（F3）＋ `snapshot()` 給 benchmark |
| StoryLogic／QuestDB／QuestRunner | `src/core/` | 條件與效果、任務資料驗證、依旗標推進（D-013） |
| GameSession | `src/core/game_session.gd` | 一局遊戲：狀態＋任務＋自動存檔＋死亡重試 |
| FrameStats／BenchmarkRun | `src/core/` | 幀時間統計、benchmark 計時與報告 |
| PlayerController | `scenes/actors/player/` | 第三人稱移動、閃避、越肩鏡頭 |
| StoryLevel／Frostbridge／Sandbox | `scenes/levels/`、`scenes/dev/` | 切片關卡共用劇情邏輯（觸發區、敲鐘事件、北街陷落、送葬者戰）；霜橋鎮白盒（正式關卡，所有檢查點，各段落觸發與檢查點出生位置）；沙盒留給開發（D-032） |
| StaticBatch／FrostbridgeLook | `src/world/` | 靜態幾何依材質合併成少數 MeshInstance＋一個 StaticBody；共用冬夜環境與色盤材質（D-032） |
| Journal／JournalView | `src/core/journal.gd`、`data/journal/`、`scenes/ui/journal_view.gd` | 記憶條目；付出後內文變剪掉的空白、保留殘留；Tab 打開（暫停）、九息預覽時一角顯示代價卡（D-033） |
| RescueSite | `scenes/world/rescue_site.gd` | 北街受困者：按住互動鍵搬瓦礫、`slice.rescued_count`、讀檔不重複（D-034） |
| Benchmark | `scenes/bench/` | 霜橋鎮固定鏡頭路徑（廣場 → 主街 → 北街 → 鐘樓） |
| Boot | `scenes/boot/` | 標題畫面（霧 shader）；新遊戲／繼續／設定 |
| QualityPreset | `src/core/quality_preset.gd` | 畫質三級：效果開關、MSAA、體積霧格點（D-019） |
| DialogueDB／DialogueRunner | `src/core/` | 對話資料驗證、台詞與選項、效果（D-018）；`Game.start_dialogue()` 接任務 |
| Puppet | `scenes/actors/puppet/` | 程序人偶與程式動畫，介面固定以便換模型（D-017） |
| PauseMenu／SettingsMenu／Hud／DialogueBox | `scenes/ui/` | 暫停、設定、目標與存檔提示、對話框；文字全走翻譯 key |
| ControlsMenu／InputGlyphs | `scenes/ui/`、`src/ui/` | 按鍵重新綁定（衝突交換、存 `[input]`）；依最後使用的裝置顯示鍵名（D-020） |
| CutsceneRunner／CutsceneView／HoldToSkip | `src/core/`、`scenes/ui/`、`src/ui/` | 資料驅動過場與可互動演出、按住跳過（D-021）；`Game.play_cutscene()` |
| CombatTuning／Health | `src/core/` | 戰鬥數值（`data/combat/tuning.json`＋`user://tuning.json`、F5）；生命元件 |
| EnemyBrain／Ashwalker／TrainingDummy | `src/core/`、`scenes/actors/` | 一般敵人狀態機（追、前兆、出招、破綻、失衡跪地）；練習木樁（D-022） |
| EnemyActor／Undertaker | `scenes/actors/enemy/`、`scenes/actors/undertaker/` | 敵人共用基底（追最近心跳、看穿、弱點、難度、`hit_heartbeats`、`_held` 劇情動作）；EnemyBrain 多招（`moves`＋`pattern`、連段 `chain`、讀不懂 `unreadable`）；送葬者兩階段（D-026、D-029） |
| CaravanRunner／Caravan | `src/core/caravan_runner.gd`、`scenes/actors/caravan/` | 傷者車隊：沿路線推進、被打停下＋傷者、抵達（D-029） |
| NineBreathSite | `scenes/world/nine_breath_site.gd` | 九息可保存物的場景側：提示＋代價、按住預覽、重現（碰撞、去飽和、心跳）、化灰（D-030） |
| FrameThrowEvent／ConvoyEncounter | `src/core/frame_throw.gd`、`scenes/world/convoy_encounter.gd` | 鐵架拋擲結局（石拱／薪火劍）；送葬者戰串接與結束旗標（D-030） |
| CombatHud | `scenes/ui/combat_hud.gd` | 戰鬥中才顯示：生命、體力、指令冷卻、席菈倒下、掙扎提示（D-031） |
| EnemyIntel | `src/core/enemy_intel.gd`、`data/combat/intel.json` | 看穿資料與文字（已證實／未證實）、弱點方向判定（D-024） |
| CompanionBrain／Sheila | `src/core/companion_brain.gd`、`scenes/actors/sheila/` | 席菈：跟隨、自主斬擊、三指令、時機窗、冷卻、拒絕（D-025） |
| Sfx | `src/core/sfx.gd`、`scripts/gen_sfx.py` | 程序音效（建置時產生、不進 git），SFX 匯流排（D-027） |

## 接下來的結構（切片）

### Autoload（只增加兩個）

- **Game**：持有目前的 `GameState`、`QuestRunner`；負責新遊戲、檢查點、存讀檔、場景切換（`change_level(level_id, spawn_id)`，先淡出、載入、放置玩家、淡入）。場景不直接改存檔。
- **Perf**：效能 overlay（F3 切換，CanvasLayer）與 benchmark 統計。用 `Performance` 單例讀 frame time、draw calls、VRAM、記憶體；1% low 由最近 1000 幀計算。

App、Settings 保持原樣；音訊用 Godot 的匯流排（Master／Music／SFX／Voice／UI），音量由 Settings 套用。

### 純邏輯（`src/core/`）

| 類別 | 職責 | 測試重點 |
|---|---|---|
| `QuestDB` | 載入 `data/quests/*.json`，驗證格式（階段 id 唯一、條件引用的旗標存在） | 資料檔全部通過驗證 |
| `QuestRunner` | 依旗標推進任務階段；觸發事件 `quest_stage_changed`；所有狀態存在 `GameState.quests` | 新遊戲 → 結尾整條推進；讀檔後恢復到同一階段 |
| `DialogueDB`／`DialogueRunner` | 對話圖：節點（說話者、文字 key、選項、條件、效果）；效果只透過旗標與記憶 | 選項條件、付過的記憶讓選項消失 |
| `Journal` | 記憶條目（id、標題 key、內文 key、相關人物）；付出後內文變「被剪掉」 | 付出後顯示狀態、存讀檔 |
| `CombatTuning` | 讀 `data/combat/*.json`＋開發覆寫 `user://tuning.json` | 預設值完整、覆寫生效 |
| `TellTimer`／`CommandWindow` | 前兆計時與指令時機判定（依難度倍率） | 時機窗邊界、難度倍率 |
| `CompanionBrain` | 席菈狀態機：跟隨／攻擊／閃避／守住／拉人；指令優先、可拒絕 | 指令被拒的條件、狀態轉移 |

場景節點（玩家、席菈、敵人、可保存物件）只呼叫這些類別並負責動畫、碰撞、音效。

### 資料格式（D-013）

- **結構用 JSON，文字用翻譯 key**。JSON 裡不出現玩家看得到的文字，只出現 `DLG_SLICE_SHEILA_001` 這類 key；文字在 `i18n/*.csv`（切片的任務與對話放 `i18n/slice.csv`，與介面 `strings.csv` 分開）。
- 任務（範例）：

```json
{
  "id": "slice_main",
  "title": "Q_SLICE_MAIN_TITLE",
  "stages": [
    {"id": "meet_pear_seller", "objective": "Q_SLICE_OBJ_MEET", "done_when": {"flag": "slice.met_pear_seller"}},
    {"id": "ring_bell", "objective": "Q_SLICE_OBJ_BELL", "done_when": {"flag": "slice.bell_rings", "gte": 9}}
  ]
}
```

- 對話節點：`{"id", "speaker", "text", "next" | "choices": [{"text", "next", "if", "do"}]}`；`if`／`do` 只能讀寫旗標與記憶，不能執行任意程式。
- 字型子集化（`gen_fonts.py`）掃描 `i18n/*.csv`，新增對話不會缺字；測試會檢查每個 key 都有 en＋zh_TW、JSON 引用的 key 都存在。

### 存檔與檢查點

- 存檔內容只有 `GameState.to_dict()`；場景狀態（敵人位置等）不存，從檢查點重建。
- 檢查點＝`(chapter, checkpoint_id)`；每個關卡場景有對應的 `SpawnPoint` 節點。自動存檔在遭遇前與章節切換時寫入。
- 死亡重試＝重讀最近的自動存檔（記憶代價與旗標一起回到檢查點，D-012 已保證不重複扣）。
- 改存檔格式：`CURRENT_VERSION` +1、在 `SaveCodec` 加一步遷移、加一個從舊版 JSON 讀起的測試。

### 輸入

- 動作名稱照 `InputSetup.BINDINGS`。重新綁定寫進 `user://settings.cfg` 的 `[input]` 區段，啟動時覆寫預設。
- `InputGlyphs`（`src/ui/`）依最後一次輸入事件的裝置類型（鍵鼠／手把）發出 `device_changed`，提示圖示用程式畫的文字框（`[F]`、`Ⓐ`），之後可換成圖示貼圖。

### 場景

```
scenes/boot/            標題畫面
scenes/levels/frostbridge/   霜橋鎮（拆成 town、north_street、south_arch 子場景）
scenes/actors/          player、sheila、ashwalker、undertaker、villager
scenes/props/           preservable_arch（九息物件）、rubble、bell
scenes/ui/              hud、pause_menu、settings_menu、journal、subtitles、prompt
scenes/bench/           benchmark.tscn（固定鏡頭路徑，結束寫 user://benchmark/*.json）
scenes/dev/             sandbox（測試移動、鏡頭、戰鬥用）
```

### 角色模型接入點（D-041）

- 交件：`art-inbox/characters/<id>/<id>.glb`（id：noen、sheila、undertaker、ashwalker；規格見 `art-inbox/README.md`、`docs/ART_QUALITY_BAR.md`）。
- 收件：`scripts/gen-assets.sh` → `scripts/import_characters.py` → `scripts/check_character_glb.py`（靜態檢查、不執行模型內容）。通過才複製到 `game/assets/characters/<id>/<id>.glb`（gitignore）；LFS 指標檔略過；沒過就刪掉舊複本。CI 先 `git lfs pull --include="art-inbox/characters/**"`。
- 遊戲端：`CharacterModels`（路徑、動作表對應、手骨骼名稱）＋`Puppet.character_id`。有 Skeleton3D 的模型才採用；AnimationPlayer 依 `current_state()` 播 `ANIM_MAP` 裡的第一個存在的動作（idle、walk、run、dodge_roll、light_attack_01；比對結尾，所以 `Armature|idle` 也行），走跑循環、播放速度跟移動速度走。缺閃避動作 → 整個人前滾；缺其他 → idle。
- 掛點：`hand("L"|"R")` 回傳手骨骼上的 BoneAttachment3D（`lefthand`／`hand_l`／`hand.l`…，去掉 `mixamorig_` 前綴比對）；找不到骨骼就放在估計位置並警告。提燈、鐘錘、席菈的劍照舊掛上。
- 不跟模型走的：碰撞膠囊、AI、弱點判定（灰巡者左膝、送葬者鐵架關節的位置仍由程式決定，之後用骨骼名或 Marker 對齊時要在這裡補）。
- 下一步：敵人（Undertaker、Ashwalker）也走同一個入口；動作多了以後換 AnimationTree。

### 測試與命令列

- `scripts/check.sh`：import（兩次，D-006）→ 所有腳本載入 → `tests/unit` → `tests/flow`。
- 主線流程測試（`tests/flow/test_main_flow.gd`）會逐步長大：開機 → 標題 → 新遊戲 → 各檢查點 → 存檔 → 讀檔 → 切片結尾，在 GameState／QuestRunner 層面跑，不需要畫面。
- 命令列旗標（`--` 之後）：`--screenshot=<png> --frames=<n>`（已有）、`--locale=zh_TW`（已有）、`--quality=0..2`、`--open=pause|settings`、`--dialogue=<id> --dialogue-steps=<n>`（截圖用，已有）、`--level=<id> --spawn=<id>`（直接進關卡）、`--benchmark`（跑 benchmark 後結束）。
