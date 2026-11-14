# 04　架構、程式地圖與開發工具

原則：**邏輯是純資料類別、場景只負責顯示**，所以雲端 session 沒有 GPU 也能用 headless 測試驗證大部分行為。2026-11-14 重新開始時只留了跟劇情無關的底層（D-273）；舊的東西在分支 `archive/pre-restart-2026-11-14`。

## 技術決定

- Godot 4.7.2 stable（標準版，版本固定在 `scripts/get-godot.sh`）、GDScript＋靜態型別（沒加型別視為錯誤）、不用 C#、Forward+。平台 Windows 64-bit；CI 順便匯出 Linux 跑 smoke test。
- 玩家看得到的字一律走翻譯 key（`game/i18n/strings.csv`，欄位 `keys,en,zh_TW`）；JSON 資料裡只放 key。
- 建置時產生的東西（字型子集、音效、轉好的模型）不進 git；什麼進 git 看 [`14-repo-and-assets.md`](14-repo-and-assets.md)。

## 程式地圖（`game/`）

| 位置 | 內容 |
|---|---|
| `autoload/app.gd` | 命令列旗標、截圖／連拍、輸入裝置切換、字型主題 |
| `autoload/game.gd` | 持有 `GameSession`；新遊戲／繼續／切關卡／對話／倒下重試／打擊停頓。關卡表 `LEVELS`、檢查點對關卡 `CHECKPOINT_LEVELS` |
| `autoload/settings.gd`、`perf.gd` | 設定（音量、畫質、難度、語言、按鍵）；效能 overlay（F3） |
| `src/core/game_state.gd`、`save_codec.gd`、`game_session.gd` | 可存檔的狀態；JSON＋版本號＋`.bak` 回復；一局遊戲（任務、自動存檔、重試） |
| `src/core/story_logic.gd`、`quest_db.gd`、`quest_runner.gd`、`dialogue_db.gd`、`dialogue_runner.gd` | 條件與效果、任務與對話的資料驗證與推進 |
| `src/core/status_rules.gd`、`status_effects.gd`、`reversal_cue.gd`、`potion_belt.gd`、`mist_zone.gd` | 異常狀態（`reverses`＝這個人身上的全部反轉，只有諾恩是）、反轉回饋的時間軸（紫紅 → 碎裂 → 金光；畫面、圖示、聲音都照它）、身上的藥、狀態區（瘴氣）的規則 |
| `src/core/health.gd`、`combat_tuning.gd`、`enemy_brain.gd`、`sera_brain.gd` | 生命、戰鬥數值（`data/combat/tuning.json`，F5 重讀、`user://tuning.json` 可覆寫）、敵人狀態機、席菈要做什麼（跟隨距離、射藥節奏） |
| `src/core/input_setup.gd`、`sfx.gd`、`ambience.gd`、`footsteps.gd`、`quality_preset.gd`、`frame_stats.gd`、`benchmark_run.gd` | 按鍵、音效、環境音與配樂、腳步、畫質三級、效能統計 |
| `src/ui/` | 字型與主題、按鍵圖示（`GlyphLine`、`PadGlyph`）、狀態列（`StatusHud`，圖示會翻面）、反轉的畫面那一層（`ReversalOverlay`＋`reversal_overlay.gdshader`）、藥劑格、目標指引、章節卡（`ChapterCard`，還沒用到）、設定頁的小元件 |
| `src/world/` | `CharacterModels`／`PropModels`（模型載入，找不到回傳 null）、`ContactShadow`、`CameraFade`、`HealMotes`、`PoisonBurst`、`ParticleLook`、`GrassTufts`（一整片草叢，一個 MultiMesh）、`forest_ground.gdshader`（森林的地面：苔／土／落葉、路與空地、樹腳下的苔）、毒霧與接地陰影的 shader |
| `scenes/boot/` | 標題畫面 |
| `scenes/levels/story_level.gd`、`corrupt_forest.gd/.tscn` | 關卡基底；腐敗之森入口（建場景＋設劇情旗標） |
| `scenes/actors/player/` | `PlayerController`：移動、過肩鏡頭、鎖定、閃避、出手、釋放、手上的劍 |
| `scenes/actors/puppet/` | `Puppet`：有模型就播模型的動作，沒有就用程式拼的人偶（同一套介面：`set_move_speed`、`play_action("dodge"／"attack"／"shoot")`、`hand()`） |
| `scenes/actors/sera/` | `Sera`（席菈：結伴前站著等、走路、轉身、舉弩、右手的手弩、靠近瘴氣戴的防毒面具）、`SeraVial`（飛向諾恩的藥瓶，落地套用狀態來源） |
| `scenes/actors/enemy/enemy_actor.gd`、`scenes/actors/slime/` | 敵人共用（追人、受擊、硬撐、跪地、倒下）；劇毒史萊姆 |
| `scenes/world/poison_mist.gd` | 瘴氣／毒霧的節點（`MistZone`＋霧盤＋體積霧） |
| `scenes/ui/` | `Hud`（目標、橫幅、存檔提示）、`CombatHud`（生命條）、對話框、暫停、設定、按鍵設定、互動提示 |
| `scenes/bench/` | `--benchmark`：鏡頭飛過關卡、把統計寫到 `user://benchmark/` |
| `data/` | `quests/`、`dialogue/`（`ch1_forest_gate`、`ch1_after_slimes`）、`status/statuses.json`、`combat/tuning.json` |
| `tests/` | 自製測試框架（`framework/test_case.gd`）；`unit/`、`flow/test_chapter1.gd`（新遊戲 → 一個人走進來 → 遇到席菈、結伴 → 她戴面具 → 瘴氣 → 對話 → 席菈跟隨 → 拿錯的那一瓶 → 清場要幾幀、幾刀（超頻要一刀一隻）→ 戰後對話的兩個回答 → 讀檔） |

**加東西的做法**

- 新關卡：繼承 `StoryLevel`、場景裡放 `Spawn`／`Player`／`Hud`／`PauseMenu`／`DialogueBox`，在 `Game.LEVELS` 與 `CHECKPOINT_LEVELS` 登記；劇情只透過 `Game.session.set_flag()` 推進任務。
- 任務階段的操作提示：階段加 `"hint": "<翻譯 key>"`，字裡的 `{attack}`、`{dodge}` 這類動作名（`InputSetup.ACTION_KEYS`）與 `{move}`、`{look}` 會換成現在裝置的按鍵（`Hud._refresh_hint`）。
- 會走路的角色要腳步聲：接 `Puppet.footfall`（腳落地的那一刻）呼叫 `Footsteps.stomp()`，不要照距離算（看 `PlayerController`）。
- 新敵人：繼承 `EnemyActor`，覆寫 `tuning_id()`、`_build_body()`、`_on_strike()`，數值加在 `tuning.json`（看 `Slime`）。
- 新角色模型：`scripts/gen_art.sh` 的 `SRC`／`ARGS` 加一行、`scripts/import_characters.py` 的 `KNOWN` 加 id，場景裡 `Puppet.character_id = "<id>"`。
- 出手的動作：`tools/blender/common.py` 的 `standard_actions` 裡三段 `swing(拉開, 砍到, 帶過去, 踏幾步)`（`light_attack_01～03`）。遊戲的命中判定在出手後 0.19 秒，劍要在 `T_HIT` 之前砍到位；改完用 `--burst-on=combo` 連拍看。`Puppet.attack_variant` 選第幾段，模型沒有那一段就播第一段。
- 新的人物動作：`tools/blender/common.py` 的 `standard_actions` 加一段（每個角色都會有）、`CharacterModels.ANIM_MAP` 與 `Puppet.ACTION_TIME`／`STATES` 加名字、程式人偶補一個最簡單的姿勢（看 `shoot`）。
- 新物件／武器模型：`scripts/gen_props.sh` 的 `ARGS` 加一行 → `PropModels.instance("tripo/<名字>")`（記得寫檔案不在時的替身）。模型自帶一圈亮色草皮底座的（樹）加 `--moss-below <高度> --sink <公尺>`：草皮改塗成地面的苔色、底座邊緣埋進地面；苔色在 `tripo_prop.py` 的 `MOSS` 與 `forest_ground.gdshader` 的 `moss`，兩邊要一樣。
- 存檔格式要改：`SaveCodec.CURRENT_VERSION` +1、加遷移、加一個從舊 JSON 讀起的測試（現在 v4；看 `test_save.gd` 的 v3 → v4）。
- 新狀態：`statuses.json` 加一筆（種類 dot／action／guard／bleed；要會疊就寫 `stack_max`）＋翻譯 key＋`StatusHud._draw` 的圖示；一樣東西要帶兩種狀態就在來源寫 `also`。反轉的回饋不用接。
- 武器打中人時給自己的狀態：`PlayerController.on_hit_source` 填資料表的來源（現在是鏽劍的 `rusty_sword_cut`）；換武器就換這個。
- 關卡裡要有人喊一句（不停下遊戲）：`Hud.show_bark(講的人, 翻譯 key)`；要玩家選擇的才用對話（`Game.start_dialogue`），對話要改旗標寫在對話資料的 `do`。
- 量戰鬥的手感有沒有變：`test_chapter1.gd` 的 `_mash_until_clear`（像玩家那樣一直按出手，回傳清場要幾幀、`_mash_swings` 是出了幾刀；測試會印數字）。

## 還沒整理的舊東西（改到那個檔的時候順手清）

- `Puppet` 的程式人偶還帶著以前的躺、坐的姿勢；模型都到位之後可以把程式人偶縮成最簡單的替身。
- 部分註解還提到舊劇情的東西（霜橋、送葬者、守衛、提燈）。
- 標題畫面的背景還是舊的鐘樓剪影（`scenes/boot/title_fog.gdshader`）。
- `scripts/gen_sfx.py` 還會產幾個沒在用的音效（市場底噪、「待續」配樂等）。
- `tools/blender/common.py` 裡有以前自製人體用的函式，現在只有 `tripo_character.py` 在用它的動作部分。

## 開發工具

| 指令 | 用途 |
|---|---|
| `scripts/check.sh`（已經產過素材時約半分鐘；乾淨的機器第一次要下載 Godot、裝 bpy、轉模型，約 5 分鐘） | 產生素材 → import 兩次 → 全部測試；有 `SCRIPT ERROR` 就算失敗。`--export` 再匯出 |
| `TEST_FILTER=chapter1 <godot> --headless --path game -s res://tests/run_tests.gd` | 只跑檔名含這段字的測試 |
| `scripts/screenshot.sh <out.png> <幀數> [旗標…]` | 用 xvfb＋軟體 Vulkan 截一張。先 `apt-get update && apt-get install -y xvfb mesa-vulkan-drivers`；每個 session 第一張常逾時，先拍一張丟掉；幀數超過一百多也會逾時（沒有固定幀率，軟體算圖太慢）——進場幾秒之後的畫面改用 `BURST_LAZY=1 scripts/burst.sh`，單張在 `build/burst/.burst-<名字>/f-N.png` |
| `scripts/shots.sh forest [--save-baseline]` | 固定鏡頭組（`scripts/shots/forest.txt`），印跟基準的差異數字、拼對照圖 |
| `scripts/burst.sh <out.png> <從第幾幀> [旗標…]` | 連拍 8 張拼一張：會動的東西（出手、受擊）用這個驗收 |
| `scripts/gen_art.sh`、`gen_props.sh` | 用 bpy 把 `art-inbox/tripo/` 的模型轉成遊戲用的（`gen-assets.sh` 會叫） |

遊戲的命令列旗標（放在 `--` 之後）：`--level=corrupt_forest`（直接開新遊戲進關卡，存檔寫到 `user://saves_dev`）、`--cam-yaw=90|180`（鏡頭繞到諾恩側面／正面）、`--hold=move_right,sprint`（一直按住這些動作：連拍走路、跑步用；`move_right` 配預設鏡頭剛好是側面）、`--at=x,z`（把諾恩放到別的地方，例：空地前面 `--at=0,-5`）、`--joined`（直接從結伴之後開始，席菈在旁邊；不加的話她等在瘴氣前面、不跟不射）、`--burst-on=reversal`（進場 1.5 秒後讓諾恩中毒並從那一刻開始連拍；`--burst-on=combo` 是連砍三下，`BURST_EVERY=4 BURST_COUNT=24` 剛好三下各 8 格；`scripts/burst.sh` 的起始幀填很大的數字、`BURST_CROP="0,0,1,1"` 看整個畫面）、`--joined --burst-on=vial`（改成讓席菈射一瓶：舉弩 0.6 秒＋飛 0.55 秒，`BURST_EVERY=10` 以上才拍得到落地；加 `--cam-yaw=90`、`BURST_CROP="0.5,0.3,0.78,0.82"` 是她的側面近拍）、`--open=pause|settings|controls`、`--locale=zh_TW|en`、`--quality=0..2`、`--perf`、`--benchmark`、`--screenshot=<png> --frames=<n>`。
