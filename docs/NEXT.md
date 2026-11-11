# 下一輪待辦（依優先順序）

> 每輪從最上面拿 1～3 項。開工前先跑 `scripts/check.sh` 確認全綠（約 2～3 分半；第一次會下載 Godot 與字型來源、產生音效、檢查角色模型）。截圖前先 `apt-get update && apt-get install -y xvfb mesa-vulkan-drivers`（**一定要先 update**，不然裝不到 mesa-vulkan-drivers，截圖退回 OpenGL、沒有體積霧）。
>
> **目前狀態（第 85 輪結束）**：唯一的劇情是《這些詛咒對我太有用了》（暫名）。從標題可以玩到**彌夏的藥店裡談完**才「待續／黑市示範場」（前十分鐘＋地下市場的街＋店內與測試板，約 13 分鐘）。`design/10` 的 **A 整段做完了**（第 85 輪，D-231）：藥店的門開著可以走進去，櫃台、藥架、彌夏、測試板（按住互動 2 秒 → 中毒 → 回血、指針甩到綠色）。**下一輪：開始做 B（黑市示範場）**——照「00」第 1 項，先讀 `story-v2.md` 第二章與 `design/10` 的表，B 還沒有設計稿，先寫再做。每一輪做了什麼在 `docs/PROGRESS.md`，決策在 `docs/DECISIONS.md`。

## 00. 唯一主線：《這些詛咒對我太有用了》（暫名；D-201～D-227）

- **先讀** `docs/design/09-reboot-first-ten-minutes.md`（段落↔任務↔檢查點↔位置、數值、UI）。故事口吻看 `docs/story-reboot/opening-v2.zh-TW.txt`，往後的劇情看 `docs/story-reboot/story-v2.md`。操作與戰鬥規則 `docs/design/02-gameplay.md`、架構 `04-architecture.md`、用詞 `06-terminology.md`（第 81 輪都重寫成只講現在的劇情）。
- **故意留著、不要改的名字（存檔與基準圖裡有，D-227）**：存檔資料夾 `user://saves_reboot`（`GameSession.STORY_SAVE_DIR`）與開發用的 `user://saves_dev_reboot`；存檔裡 `mode` 的值 `"reboot"`（`GameState.STORY_MODE`）；任務 `rb_main`、旗標 `rb.*`、檢查點 `rb_*`、節點名 `Rb…`；翻譯 key `RB_*` 與 `i18n/reboot.csv`；`data/reboot/statuses.json`；截圖旗標 `--rb-at=…` 與盤點截圖的檔名 `40-rb-start`…；文件 `docs/design/09-reboot-…`、`10-reboot-…`、`docs/story-reboot/`（Jacky 的資料夾）。`user://saves`（`DEFAULT_SAVE_DIR`）是以前舊劇情的資料夾：標題的新遊戲／繼續不讀也不寫它，這個「兩個資料夾」的機制也留著（測試在驗）。

### 現在有哪些東西、在哪個檔

| 東西 | 在哪裡 | 要知道的 |
|---|---|---|
| 劇情控制器 | `scenes/levels/frostbridge_opening.gd`（類別與節點名 `FrostbridgeOpening`；`frostbridge.gd` 只蓋鎮，`Game.session.in_story()` 時才掛它） | 流程：鐵門 `RbGate`＋雷德 `Red`＋推車 `RbCart`（`Caravan`，只留波克）→ 轉角藥桶 `RbBarrel0..2`＋毒霧 `RbBarrelMist` → 覺醒（`Hud.show_center_lines`）→ `rb_mist_test`／`rb_mist_confirmed` → 席菈接應 → 守衛 `RbGuardian` → 藥箱 `RbPotionCrate` → 艾妲 `Ada`、貨梯 `RbLift`（底下 `_build_shaft_mouth` 的井口）→ `play_end_card()`（配樂 `RbEndMusic`）。出生點 `SPAWNS`；`dev_advance(session, "start|mist|pursuer|guardian|potion|market…")` 測試與截圖旗標共用；南街吊燈 `RbSouthLantern`、麵包店燈 `RbBakeryLantern` |
| 任務、對話、文字 | `data/quests/rb_main.json`、`data/dialogue/rb_*.json`、`i18n/reboot.csv` | 階段 escape → poison_discovery → meet_sheila → guardian_fight → portable_poison → market_lead；每個階段都有 `marker` 與 `checkpoint` |
| 狀態與反轉 | `src/core/`：`StatusEffects`、`StatusRules`（`data/reboot/statuses.json`）、`ReversalSlots`、`PotionBelt`、`MistZone`、`Health.apply_status_damage`／`heal` | 玩家端：`PlayerController.status_effects`／`reversal`／`use_potion(confirmed)`／`potion_needs_confirm` |
| 毒霧 | `scenes/world/poison_mist.gd`：`PoisonMist.create(半徑, "barrel_mist"\|"guardian_spray", 壽命)` | 體積霧 `src/world/poison_mist_volume.gdshader`（`shader_type fog`）＋霧盤 `poison_mist.gdshader`。**不要在霧裡加綠色 OmniLight**（濕石板上會有刺眼的高光點）；小霧（半徑 2 m、3 秒）不用再調雜訊頻率 |
| 送葬者 | `scenes/actors/undertaker/undertaker.gd` | 兩種用法：`begin_pursuit()`（追擊的那一隻 `RbPursuer`：橫掃＋下砸、舉燈柱砸藥桶 `throw_phase` 0～3）、`begin_guardian()`（南街守衛：再加噴毒 `spray`、生命 480、胸口 `SprayPipes`）；兩個都會設 `no_charge`。`scripted_walk()`／`end_scripted()`（走位期間不出招、打不動）。特效：`EnemyActor._hit_fx`（命中）、`_slam_fx`（下砸落地：`SlamFx` 的 `Ring`／`Plume`／`Chunks`／`Scar`）、前兆 `telegraph.gdshader`（形狀 0～3） |
| 藥箱與藥 | `scenes/world/potion_crate.gd`（`PotionCrate`）；HUD `PotionHud`、`PotionConfirm`（開著時 `get_tree().paused`） | 一次性發放 `GameState.grant_once`；滿血喝藥先問 |
| 回血與生命條 | `src/world/heal_motes.gd`（`HealMotes`）、`src/ui/bar_trail.gd`（`BarTrail`）、`CombatHud` | 席菈的生命條還沒有紅色段（要加就再放一個 `BarTrail`） |
| 地下市場的場景 | `scenes/levels/underground_market.gd`（類別 `UndergroundMarket`，關卡 id `market`）；shader `src/world/awning_cloth.gdshader`、`paper_lantern.gdshader`、`cave_rock.gdshader`（岩面：`chunk_size` 一塊多寬、`facet_strength` 每塊偏多少、`damp_amount` 潮濕） | +z 往南（**鏡頭朝南時，畫面左邊是東＝+x**）。高台 `TERRACE_*`（高 2.4 m）→ 門架（`_build_terrace` 裡）→ 坡道（到 `RAMP_S`）→ 街（到 `SHOP_Z`）。`_stall(z, side, kind, cloth, vendor)` 一個攤子（`WEST_KINDS`／`EAST_KINDS` 排種類，`KIND_GAP`＝空位）；`awning_mesh()` 布棚；`_banner()` 垂布；`_build_ropes()` 掛燈繩（單數條紙燈籠 `PaperLanterns` MultiMesh、雙數條三角旗）；`_build_shop()` 藥店門面；`_light()` 所有 OmniLight（測試在數彩色的只有三種）；`_build_wall_lamps()` 岩壁上的掛燈（`WALL_LAMPS`：左右、z、高）；布棚的高度 `AWNING_FRONT_Y`／`AWNING_BACK_Y`／`AWNING_FRONT_OUT`、攤子的燈 `STALL_LAMP_*`、綠光 `SHOP_GLOW_*`、街面 `STREET_SLAB`／`STREET_ROUGHNESS`（大塊石板，`InteriorLook.flagstone`）；**場景裡多抽一次 `_rng` 後面的攤子全部會變**（要加東西就寫死位置）；`ShaftLight`／`ShaftSpill` 井口的冷光（SpotLight）。東西都進 `_batch`（節點 `Market`）。**第 84 輪加的（D-230）**：高台西側看街的人 `WATCHERS`／`_watcher()`（`watchers`，不算在 `vendors`）、行李上的提燈 `TerraceRestLamp`；藥店的窗 `SHOP_PANE_H`／`SHOP_WINDOW_ROWS`／`SHOP_TRANSOM_ROWS`（`_build_shop` 裡三組窗：主窗、東窄窗、氣窗；`shop_glass_area`）、遠看補償 `SHOP_GLASS_FAR_BOOST`／`SHOP_GLASS_FAR_SATURATE`（`window_glass.gdshader` 的 `far_boost`／`far_saturate`，預設 0）；藥店前的綠燈籠 `SHOP_PAPER`／`SHOP_PAPER_REACH`（`paper_color()`；`shop_paper_count`）；底噪 `MURMUR_SFX`／`MURMUR_DB`（`gen_sfx.py::market_murmur`） |
| 地下市場的劇情 | `scenes/levels/underground_market_story.gd`（`UndergroundMarketStory`，節點同名）；`data/quests/rb_market.json`、`data/dialogue/rb2_sheila_rules.json`、`rb2_misha_meet.json`、`rb2_misha_deal.json` | 階段 arrive → find_shop → test_board，**三個都做完了**（D-231）。`test_board` 的流程在 `_tick_test_board()`，用旗標一步一步走：`rb2.misha_met`（走到櫃台前 `at_counter()` → 對話 `rb2_misha_meet`）→ `rb2.pricked`（開口前記的 `rb2.full_health` 是 true 才扣 3 點）→ `rb2.board_done`（`board_ready()` 而且互動鍵按著，累計 `board_hold` 到 `BOARD_HOLD_SEC`＝2 秒；放開歸零；`player.status_effects.apply_source("test_board")`）→ `board_read` 累計到 `BOARD_READ_SEC`＝3 秒 → 對話 `rb2_misha_deal` → `rb2.first_shop_done` → 任務做完 → `play_end_card()`（卡名 `RB2_END2_TITLE`）。**任務做完之後**（讀檔回來）：`_physics_process` 最前面那一支——走到櫃台前就再播一次「待續」；B 做出來之後把這一支換成 B 的開頭。按住的提示：這個節點在 `interact_prompts` 群組，`interact_hint()` 回傳 `progress`。出生點 `SPAWNS`（`rb2_arrive`／`rb2_street`／`rb2_shop`＋截圖用的 `dev_board`，由旗標 `rb2.dev_spawn` 選）；`dev_advance(session, "arrive|street|shop|board|board_read")`；截圖 `--level=market --rb-at=…`。`GameSession.MAIN_QUESTS`＝兩條主線，`main_quest()` 回第一條沒做完的（都做完就是最後一條，沒有目標文字）；**兩條做完都會自動存檔**；舊存檔在 `load_slot` 補開 `rb_market` |
| 藥店裡面 | `UndergroundMarket._build_shop_interior()`、`_bottle()`、`_build_test_board()`、`_animate_board()` | 房間在門面後面：z＝`SHOP_INNER_Z`（37.0）～`SHOP_ROOM_S`（42.2）、x＝±`SHOP_ROOM_HALF`（4.6）、高 `SHOP_ROOM_H`（3.4）。**`CAVE_S` 沒有動**（洞的岩盤只到 40.5，後面是這間房自己的碰撞）。門洞 `SHOP_DOOR_W`／`SHOP_DOOR_H`（門面的牆在 `_build_shop()` 裡斷成三塊）。櫃台 `COUNTER_X`／`COUNTER_Z`／`COUNTER_LEN`／`COUNTER_TOP`；測試板 `BOARD_POS`（節點 `TestBoard/Dial/Needle`、`Lamp`、`LampLight`，不進 `_batch`）、彌夏 `MISHA_POS`（`misha`，會轉頭看人，最多 60 度）。**店裡的東西不要抽 `_rng`**，用 `_hash01(a, b)`。燈：`ShopCounterLamp`、`ShopCabinetLamp`（暖）、`ShopShelfGlow`、`ShopBenchGlow`（`SHOP_GREEN`），都不投影。**鏡頭朝南站在櫃台前：畫面右邊是西（抽屜櫃、門），左邊是東（蒸餾台、木桶）**；測試板不能放在門的正對面（鏡頭會卡在門框後面，D-231） |
| 標題 | `scenes/boot/boot.gd`：`%NewGame` → `Game.new_game()`、`%Continue` → `Game.continue_game()`（`Game.has_continue()`） | 測試設 `boot.load_levels = false`（按鈕只改狀態、不換場景） |
| 存檔 | `GameSession.new_game()`／`in_story()`／`load_story_slot()`／`has_story_save()`／`story_save_dir()` | 沒有開新遊戲的 session（`GameSession.new(db, dir)` 之後什麼都不呼叫）＝只有空的鎮 |
| 測試 | `tests/flow/test_story_{opening,guardian,potion,market,market_level,playthrough,south_lantern}.gd`、`test_title_entry.gd`、`test_frostbridge.gd`；`tests/unit/test_story_session.gd`、`test_heal_feedback`、`test_status_effects`、`test_mist_and_status_hud`、`test_hit_fx`、`test_slam_fx`、`test_undertaker`、`test_save` | 現在共 314 個測試。**每加一段，就把 `test_story_playthrough.gd::test_new_game_to_lift_in_one_run` 的結尾往後延**（現在的結尾在藥店裡：彌夏 → `Input.action_press("interact")` 按滿 2 秒 → 等 3 秒 → 第二段對話 → `end_card.finish()` → `story.end_done`）。**只看場景的測試要把劇情停住**（`level.story.set_physics_process(false)`）：不然人走到櫃台前彌夏會開口，對話留到下一個測試，後面一大片不相干的測試一起紅（第 85 輪 46 個問題就是這一個） |
| 固定鏡頭組 | `scripts/shots/rb_opening.txt`（`40`～`44`）、`rb_guardian.txt`（`45`～`47`、`49`、`50`、`54`、`55`）、`rb_market.txt`（`51`、`52`）、`rb_market_level.txt`（`60`～`62`：地下市場的街；`63`：藥店裡的櫃台前） | 用法在下面「畫面驗收」 |

### 寫程式與測試時踩過的坑

- **一次性粒子**：`EnemyActor.puff_build(extents, amount, color)`（建好、還沒噴、還沒進樹）→ 改參數 → `puff_start(ps, at)`。**不要寫「`add_child` 之後才設位置」的一次性 `CPUParticles3D`**（一進樹就在當下的位置噴完）。粉塵要吃光：用 `Undertaker.slam_dust_material()`（不受光的冷白圓點在暖燈逆光的場景裡像貼上去的；一顆一顆看得出圓形＝太少、太實，加數量、降透明度、放大）。
- 測試裡把推車放到轉角之後要等 130 幀（牠舉 0.9 秒＋飛 0.7 秒）藥桶才破。會暫停場景樹的測試（確認框）在 `after_each` 把 `tree.paused = false`。手把的 `_tap()` 要等 `physics_frame`。
- 測試裡 `s.new_game()` 會自動存檔；要模擬「重開遊戲」就再 `GameSession.new(QuestDB.load_default(), 同一個資料夾)`，不要再呼叫 `new_game()`。測試的資料夾清理要連 `_dir + "_reboot"` 一起刪（劇情存檔在那裡）。
- 有敵人在 20 m 內鏡頭會拉遠、時間會走：截圖的鏡頭要固定就讓那一段停住（`debug_hold_throw`、`debug_hold_jet`、`debug_hold_hit`、`debug_hold_slam`）。
- 南街兩邊房子在吊燈那一段高 6.1 m／7.4 m、牆面在 x＝±3.5；燈掛 5.4 m（4.1 m 會被牠的鐵架撞到、從鏡頭看還躲在牠頭後面）。

### 畫面驗收（固定鏡頭組，D-206）

- `scripts/shots.sh rb_opening --fetch-baseline`（一組約 5 分鐘；不要跟 `check.sh` 同時跑）→ 先看每張一行的數字（差異、亮度、過曝、死黑）→ 要看圖只 Read `build/shots/<組>-sheet.png`（960 px，左基準右這次；只看一列就用 PIL 裁那一列，每列高 270）。只改一個鏡頭：`SHOTS_ONLY=42-rb-pursuer scripts/shots.sh rb_opening`。基準＝CI 拍的那張（prerelease「screens」，檔名跟鏡頭同名）。新場景就加一個 `scripts/shots/<組名>.txt`（3～5 個鏡頭）＋同名的 CI `shot` 行。
- **本機第一張當暖機**：有時 Vulkan 逾時退回 OpenGL，數字會是「差異 70% 以上、死黑超標」——那是假的，直接再拍一次（拍完 `grep -c opengl3` 確認）。之後每張約 1 分鐘。
- 只是要確認「畫面沒有變」（重構、刪沒人用的 shader 參數）：照「0. 開工先確認」的「量畫面有沒有變」做，差異在 0.05% 上下就是沒變，不用看圖。
- **看遠處的小東西有沒有變（例如從高台看街底的綠窗）**：整張的差異與亮度看不出來（第 84 輪四個版本都是 22.2%／36.9）。用 PIL 在固定範圍數「綠色為主的像素」（`g > r+8 且 g > b+8`）的數量與平均顏色（`60` 的街底＝1600×900 圖上的 (700,330)-(860,395)：第 83 輪 401 個、第 84 輪 840 個、平均 (190,223,141)），數字有變再裁那一塊放大 1.5 倍、改前｜改後拼一張看。

### 下一步（照順序，每步都要測試、main 隨時綠；Jacky 11/10 17:53：新劇情是唯一主線、畫質優先）

1. **（下一輪從這裡開始）B：黑市示範場**。A（街＋店內與測試板）第 82～85 輪做完了（D-228～D-231）。B 的內容照 `story-v2.md` 第二章第二段與 `design/10`「這一段要做到的事」的表：商人當眾賣一種戴了會麻痺的「高速護腕」、說副作用吃他的高價藥就會好 → 諾恩看出是騙局 → 席菈打斷示範的守衛（一場小戰，1～2 個守衛）→ 拿到護腕。彌夏最後一句台詞已經把人指過去了（`DLG_RB2_MISHA_DEAL_005`）。
   - **B 還沒有設計稿：下一輪先寫再做**（寫在 `design/10` 裡加一節「B 的流程」，照 A 那張表的格式：階段、目標文字、檢查點、完成條件）。要先決定的：①**示範場在哪裡**——最省的是同一個關卡裡（街中段西側 `KIND_GAP` 那個空位後面開一個岩洞的缺口，或藥店東邊）；另開一個關卡要再蓋一次洞與燈。②**新任務**（例如 `rb_demo`，加進 `GameSession.MAIN_QUESTS`；`load_slot` 的補開照 `rb_market` 的寫法）還是在 `rb_market` 後面加階段（已經做完的存檔不會自己多出階段，所以用新任務比較乾淨）。③**守衛是什麼**：現成的敵人只有送葬者（`Undertaker`）；人形的守衛要新寫一個小敵人（`EnemyActor` 的子類別，`Puppet` 當身體），或 B 的第一版先不做戰鬥、只做「示範 → 席菈打斷（腳本）→ 拿到護腕」，戰鬥留到下一輪。④「麻痺」這個狀態在 B 只是商品說明，裝進第二格是 C 的事（`statuses.json` 現在只有 `poison`）。
   - **接 B 的時候要改的地方**：`UndergroundMarketStory._physics_process` 最前面「任務做完 → 走到櫃台前就播待續」那一支換成 B 的開頭（出店門 → 往示範場的標記）；`play_end_card()` 的卡名換新的 key；`test_story_playthrough` 的結尾往後延；README／`playtest.md` 的「目前的結尾」。
   - **店內還可以加強的（做 B 的時候順手，不另開一輪；`SHOTS_ONLY=63-rb2-board scripts/shots.sh rb_market_level --fetch-baseline`，基準＝CI 第 85 輪拍的）**：①店的北牆（門面的背面）是一整片空的木板——門上的氣窗從裡面看不到（外面的玻璃是貼在牆前面的盒子）；可以在裡面對應的位置貼一排淡綠的玻璃。②彌夏只是換了顏色的人偶（深綠工作服、淺色邊），沒有圍裙、手上沒東西，手垂在兩側。③測試板上的色塊沒有字（紅＝受傷、綠＝回復 靠顏色與彌夏的台詞）；手放上去的時候諾恩沒有伸手的姿勢（`Puppet._pose` 每幀覆寫關節）。④扎針沒有聲音、板子沒有聲音（指針甩過去可以加一聲「叮」：`gen_sfx.py`）。⑤席菈真人玩的時候跟不跟得進門沒有驗過（測試裡她停住）：她是直線走向諾恩（`Sheila._move`，沒有尋路），人在店裡往東走的時候她多半會貼著門面外牆走不進來；也可能剛好停在 1.3 m 寬的門洞裡——**B 要走出店門，那時候她擋在門洞會卡住人**。做 B 的時候先處理：進店時把她放到門的西邊站著（`_spawn_sheila` 在店裡的那個位置，停住不跟），出店時再放回街上。⑥櫃台兩端可以繞到後面去（西端離抽屜櫃 1 m、東端有木桶但沒擋死）。
   - **a. 街上第一眼剩下的（不急；`scripts/shots.sh rb_market_level --fetch-baseline`）**：②街底的綠從高台看還是淡——擋住它的是街尾那幾條三角旗與燈籠、還有 45 m 的暖霧；還想加強就從「擋住的東西」下手：最靠近藥店的兩條三角旗繩（`_build_ropes` 裡 i＝9、11）掛高或拿掉（整條不建的話後面的亂數全部會動，改成照抽、不放進場景），或街中段的樑下掛一幅綠條紋的長布（`_banner`）。**試過沒用的，不要再試**：門面上方加一盞只進霧的綠燈；只把窗的發光加亮（變白不是變綠）。③岩面只有掛燈附近看得出來，或把 `cave_rock` 的 `rock_color` 提亮一點（現在 0.17）。④街面沒有水窪——要倒影的話在 `plank_wood.gdshader` 的 `wet_spot` 基礎上做幾灘，不要換回小塊濕石板（D-229）。⑤顧攤的人從高台看不到、`61` 裡站得太裡面。⑥高台上看街的兩個人站得直直的：可以讓一個坐在箱子上（`Puppet.sitting = true`）。
   - **b. 聲音與吊牌**：底噪第 84 輪做了（`market_murmur`，-14 dB，D-230）。**這個環境沒辦法聽**；FOR_JACKY 請他聽了，他說怪就調 `gen_sfx.py::market_murmur` 或 `MURMUR_DB`。還沒做：鐵匠的敲打聲、鍋子的蒸氣聲（`Ambience.play_at`）；攤子靠近的吊牌字（三個攤子靠近出現「品名＋副作用」各一行，不是必經）；**店裡聽到的還是街上的底噪，音量沒有變小**。
   - 沒做的小事：貨梯高台上的貨梯只是布景（不能搭回去）；坡道兩旁的攤子前面只有 1 m 寬的走道；`UndergroundMarket` 沒有 `--pos`／`--face`／`--hide` 這些截圖旗標，要拍別的角度就在 `UndergroundMarketStory.SPAWNS` 加一個站位、`dev_advance` 設 `rb2.dev_spawn`（照 `board` 的寫法）。
2. **梨攤與結尾剩下的**：艾妲在 `51-rb-market` 裡有一半被諾恩擋住、帳本太小看不出來（書放大到 0.34 高、封面加一條亮色書籤，或在 `Puppet` 加一個 `carry` 姿勢把左前臂抬起來抱在胸前——`Puppet._pose` 每幀會覆寫關節）；（「待續」的配樂第 75 輪接了，D-219）；井口從 `52-rb-lift` 的低鏡頭看不到黑的洞（南邊石框擋住；可以把 `--rb-at=lift` 的站位移到框邊、或讓南邊那條石框缺一塊——不急，D-214 寫了）；貨梯的柱子、石框沒有碰撞；拿到工錢只有一行字。
3. **守衛戰與藥箱畫面剩下的**（動到那一段時順手做，一次一項、`scripts/shots.sh rb_guardian --fetch-baseline` 前後對照）：
   - 藥箱：`49-rb-potion` 裡箱子在 5 m 外約 80 px 寬，綠光照在濕石板上看得到、兩支滿瓶看得到；牠倒下時箱子摔下來那 0.4 秒沒有固定鏡頭拍過（`drop_in`：先藏 1.2 秒 → 從 1.5 m 掉下來 → 雪粉）。牠的屍體沉下去之後藥箱旁邊是空的——可以留一塊壓扁的雪痕或牠的兜帽（不擋進度）。 **藥箱沒有碰撞**（諾恩可以直接穿過去）：加 `StaticBody3D`＋`BoxShape3D` 之前先確認箱子出現的那一刻如果有人站在落點會不會被卡住（先把人往旁邊推開，或落點避開諾恩與席菈 1 m）。**確認框沒有 CI 截圖**：加 `--rb-at=confirm`（`_dev_stage_potion` 裡把生命補滿 → `player.use_potion()` → 框開了之後 `get_tree().paused = false`，不然截圖的幀數不會走）＋CI `51-rb-confirm`；第 71 輪本機這樣拍過一張，樣子沒問題。
   - 噴霧落地濺開：`Undertaker._spray()` 在落點（`spray_center()`）加一團往外的綠色粉（`puff_build(Vector3(0.9, 0.05, 0.9), 30, 淡綠)`→`spread` 85、`initial_velocity` 1.5～3、`gravity` 0→`puff_start`）；牠倒下時管口漏一口綠氣（同一招，掛在 `Body/Torso/SprayPipes` 的世界位置）。`47-rb-sprayed` 用 `debug_hold_jet` 停住噴霧，但粒子不會停：要拍就把幀數調到剛噴出去後 2～4 幀。
   - 打擊感（**第 74 輪：命中的霜屑／火星／閃光／亮斑做了，D-217；第 75 輪：下砸落地做了，D-218；剩下跪地**——失衡跪地的雪粉 `_kneel_puff` 還是不受光的小白點，可以換成 `Undertaker.slam_dust_material()` 那種吃光的、量加大；倒地的 `_ground_puff` 同理。下砸可以再加的：落地那一聲換成更重的石頭碎裂聲（`gen_sfx.py` 新做一個）、一圈很快往外擴的霜色細線（0.25 秒）。`55-rb-slam` 是隨機拍到的一刻，要看動態只能實機或錄幾張連續幀）：粒子現在可以用了（第 70 輪查出原因，見上）。諾恩砍中牠的火星／黑袍碎屑、牠下砸落地的雪塵（`undertaker.gd` 的 `_ground_puff(at, Vector3(0.6, 0.05, 1.2), 28, …)` 現在噴在落點了，先拍一張看夠不夠）、失衡跪地的雪粉。先各拍一張現況再決定加什麼，不要沒看就加。
   - 毒霧：第 70 輪的結論——大霧（`41-rb-mist`，半徑 4.4 m）看得出底濃上淡與不規則的邊；小霧（守衛噴的，半徑 2 m、3 秒）體積裡的流動看不太出來（體積霧格子粗＋時間短），**不用再調雜訊頻率**。還可以做的只有：霧裡飄幾片慢慢往上的淡綠粒子（常駐、不是一次性：`amount` 12 左右）。**不要再試「霧裡加一盞綠色 OmniLight」**（濕石板上會出現刺眼的高光點）。
   - 前兆的虛線圈裡面還是有一片綠（那是管口的綠光 `PipeLight` 打在地上，不是填色）：可以接受；要更乾淨就把 `PipeLight` 的範圍縮到 3 m。
   - **不停住牠實際看一輪**（第 74 輪列的第①項，還沒做）：480 生命打多久、席菈會不會卡在牠背後、牠的影子有沒有拉到諾恩腳邊——寫一個不設 `debug_hold_guardian` 的截圖旗標連拍 2～3 個時間點，或在流程測試裡量時間。`54-rb-hit` 裡諾恩是站著的（沒有出手的姿勢）。
- 守衛戰還沒有人實際玩過（只有自動測試）：480 生命打多久、四招一噴的頻率、席菈繞霧時會不會卡在牠背後、牠走過來的 5 秒會不會太長——做第 3 步的流程測試時順便用 `--level=frostbridge --rb-at=guardian` 以外的方式（不停住牠）拍 2～3 個時間點看一次。
- 追擊段可以再加強（不擋進度）：諾恩站著不動時牠只站在門邊——可以讓牠逼近到 3 m；落地瞬間沒有固定鏡頭；門邊的斷燈柱很小。**粒子的問題第 70 輪查出來了**（不是截圖環境：是先進樹才擺位置，整團噴在牠腳下；D-208），燈柱砸藥桶的木屑與藥霧已經補回來（`48-rb-impact`）。牠落地的雪塵（`_on_pursuer_landed`）本來就噴在牠腳下，位置沒問題，只是沒有固定鏡頭拍過。
- **程式註解裡還有約 40 處「新版／舊版／切片」的字樣**（`grep -rn "新版\|舊版\|切片" game/src game/autoload game/scenes --include=*.gd`）：意思都還對，只是用詞是清理之前的。不用專門開一輪，動到那個檔的時候順手改。
- 規則提醒：直接傷害、落下照常；NPC 不會跟著免疫、波克不放進毒區、席菈繞開毒霧；藥劑虛構、只標效果；反轉沒有代價（「重現」與記憶代價第 78 輪刪了，D-222）；參考作品只當方向。
- README 與 `docs/playtest.md` 寫的是「從標題到目前的結尾會發生什麼」（第 82 輪加了第 7 段地下市場）——之後「待續」往後移要跟著更新這兩份。

## 0. 開工先確認

- **第 85 輪的程式 commit：e482bfd（店內與測試板），05:48 推，run 43106311556：「測試與匯出」job 全綠（314 個測試、匯出版 smoke test、「latest」05:54 更新）。**「盤點截圖」job 的結果看 PROGRESS 第 85 輪那一則的最下面（收尾時補的）；那裡沒寫「綠」的話，開工先用 `actions_list`（`list_workflow_jobs`，run 43106311556）看一眼，紅了看 log——這一輪新增了 `63-rb2-board`（`--rb-at=board`），最可能出事的是它。本機的數字（下一輪的基準）：`60` 亮度 36.9、死黑 7.5%（這一輪沒有重拍，街上沒動）；`61` 48.8；`62` 61.7（只有門那一塊變了）；`63` 47.4、死黑 0.09%。本機 `check.sh` 314 個全綠（約 2 分 15 秒）；本機一張截圖約 40 秒～1 分鐘，沒有逾時、沒有退回 OpenGL。**這一輪的節奏**：開工 4 分鐘讀完交接（背景先跑 `apt`＋`check.sh`）→ 寫場景與流程 → 先跑 `TEST_FILTER=story_`（1 分鐘）再跑整套 → 畫面每一步只重拍 `63`、先看數字 → 開工後 21 分鐘推程式 → 等 CI 的時候寫文件。
- **`latest` 的 `town.png`／`dialogue.png` 不穩，還沒修**（第 79 輪猜錯一次，不擋主線，README 沒有用到這兩張）：`ci.yml`「測試與匯出」job 的截圖步驟裡，`town.png` 是那個 job 第一次開關卡，軟體 Vulkan 編 shader 就超過 `screenshot.sh` 的 120 秒逾時（跟幀數無關）；逾時之後會退回 OpenGL 再拍，120 幀通常也逾時（＝沒有這張圖），幀數少的話會拍出一張**沒有體積霧、很暗**的圖發布出去（亮度 15.6；正常約 68）。`dialogue.png`（150 幀）靠前一張把 shader 快取暖起來才拍得完。**要修的話照這個順序**：先用 `get_job_logs` 看那個 job 截圖步驟實際印了什麼（有沒有「Vulkan 截圖失敗，改用 opengl3」、各花幾秒），確認原因再動；方向：①在 `town.png` 前面先拍一張丟掉的暖機圖（看「盤點截圖」job 是怎麼讓第一張穩的，照做）；②`screenshot.sh` 加一個環境變數，讓發布用的圖「退回 OpenGL 就當失敗、不留檔」；③改完**同一輪看到那個 run 的截圖步驟結果**再收尾，所以要在開工後 15 分鐘內推。
- **CI 的節奏**：同一時間只跑一個 run；一個 run「Import、測試、匯出」約 2 分半就有結果，之後截圖與「盤點截圖」job 再跑 7～25 分鐘（第 81 輪整個 run 10 分鐘就結束）。新的 push 不會取消正在跑的 run，只會排在後面（排隊中的才會被更新的 push 取代）。所以**一輪最多推兩次程式，第二次要在開工後 25 分鐘內推**，收尾時才看得到第二個 run 的測試結果。`[skip ci]` 的文件 commit 不受影響。「盤點截圖」job 是 `continue-on-error`，要自己進 run 的 jobs 看它有沒有綠。CI 的盤點截圖現在是 `01`～`03`、`05`、`10`、`40`～`52`、`54`、`55`、`60`～`63`。
- **量「畫面有沒有變」的做法（第 80 輪整套約 5 分鐘）**：改畫面之前 `cp -r game scripts <scratch>/before/`，在那一份背景拍「改前」（`cd <scratch>/before && scripts/screenshot.sh build/x.png 30 <旗標>`；**第一張當暖機多拍一次**——這台機器這一輪兩張都 1 分鐘內拍完，沒有逾時，但以前第一張白等過 4 分鐘），同時在工作目錄改程式；`check.sh` **不要跟截圖同時跑**（只有 2 核）；改完在工作目錄拍「改後」，兩個資料夾（同名的 png）交給 `python3 -P scripts/shots_metrics.py <改後資料夾> <改前資料夾> <對照圖>`。拍完 `grep -c opengl3` 確認沒有退回 OpenGL。**差異的判讀**：同一份程式重拍一次約 0.05%（飄雪，700 個像素左右）；比這個大才是真的有變，這時候先用 PIL 算「不一樣的像素落在哪一格」，只裁那一塊、改前｜改後拼成 960 px 再看一張。
- **推之前看測試結果用 `grep -n 'FAIL\|通過\|SCRIPT ERROR'`，不要用 `tail`**（結束時的 leaked 警告會把「問題 N 個」那一行擠掉）。**一大片不相干的測試一起紅，先找最前面那個 `SCRIPT ERROR`**：測試中途出錯不會清掉場上的角色，後面的鏡頭／鎖定／HUD 測試會以為附近有敵人（第 80 輪 21 個問題其實是 1 個）。刪成員變數之前把賦值也搜一次（`grep -rn "\.名字 ="`）。
- **測試結束時印 `16 ObjectDB instances were leaked at exit`＋`3 resources still in use`**（不會讓 `check.sh` 失敗）：來源是 `test_status_effects.gd`（單獨跑 15 個）、`test_mist_and_status_hud.gd`（3 個）、`test_sfx.gd`（2 個）。不急；要修就看那三個檔裡哪個節點／`PlayerController` 沒有 `free()`。
- **新檔案記得連 `.uid` 一起 `git add`**；改名用 `git mv` 兩個檔一起搬。**要分開提交的東西不要先 `git rm`／`git add`**（會被下一個 commit 一起帶走），提交前看一眼 `git status`。文件裡很長的行（本檔、PROGRESS、DECISIONS）不要用 `cut -c`／`sed -n` 去看（`cut -c` 在這裡是照位元組切，中文會只看到三分之一），用 Python 讀。
- **掃「沒人用的翻譯 key」**：把 `game/` 底下 `.gd`／`.json`／`.tscn`／`.tres`／`project.godot` 與 `scripts/` 全部讀進來，用 `[A-Z][A-Z0-9_]{2,}` 抓出所有大寫字，csv 裡不在這個集合的 key 就是沒人完整提到的（程式裡沒有用字串拼 key 的地方；`step_` 那種拼法只有音效名）。`RB_SLOT_EMPTY`、`RB_TO_BE_CONTINUED` 沒人用但是新劇情的字，留著。
- 這個 session 可能沒有 `add_repo` 工具（第 80、81 輪 ToolSearch 都找不到）：repo 已經 clone 在工作目錄（detached HEAD），`git checkout main && git pull --rebase origin main` 之後 push 正常。本機抓不到 export templates 時，匯出版 smoke test 只能看 CI。
- CI 的 import 崩潰再出現（`check.sh` 重試也崩）就要查：以前兩次都在第一次 import 重新匯入翻譯 CSV 時。
- **盤點截圖（D-082）**：prerelease「screens」放 CI 拍的每一張（清單在 `.github/workflows/ci.yml` 的 `shot` 那幾行）；release 剛被新建置換掉時可能抓到舊檔，看 `unzip -l` 裡的時間確認是哪次建置。`curl -sSL -o screens.zip https://github.com/twjackysu/yuming-city/releases/download/screens/screens.zip`（GitHub 偶爾回 504，迴圈重試；**一次只下載一個檔**），解壓到 scratchpad、PIL 縮到 900 寬再看。screens job 是 `continue-on-error`：在 run 的 jobs 裡看「盤點截圖」有沒有綠燈，紅了看 log（多半是某個旗標組合拍不出來）。
- **本機拿不到 Godot 時（第 20 輪發生過，第 21 輪恢復）**：`scripts/get-godot.sh` 對 `godotengine/godot` 的 release 回 504（session 的 GitHub 存取範圍只有本 repo）。不要繞過：改成 push 前 `pip install gdtoolkit==4.* --break-system-packages` 後 `gdparse <檔案>` 檢查語法（抓不到型別錯誤，型別一律照 project 的警告規則寫）、幾何先用 Python 驗證，推上去看 CI；畫面看 latest／screens。先試一次 `scripts/get-godot.sh`，拿得到就照舊本機驗證。
- **字型下載 504（D-079）**：第 19 輪的 session 連不到 `notofonts/noto-cjk` 的 release（504／API 說沒有這個 repo 的存取），`scripts/check.sh` 會在 `gen_fonts.py` 掛掉。先試一次 `scripts/check.sh`；如果又是 504：`apt-get install -y fonts-noto-cjk fonts-noto-cjk-extra`，再用 D-079 的做法（從 `/usr/share/fonts/opentype/noto/Noto{Serif,Sans}CJK-*.ttc` 取 TC 那一套、照 `gen_fonts.collect_chars()` 子集化、寫 `game/assets/generated/fonts/` 與相同的 `.stamp`；`import gen_fonts` 會留下 `scripts/__pycache__/`，記得刪掉）。**不要改 repo 的 `gen_fonts.py`**，CI 照常下載。改了 i18n CSV 後要重跑。
- CI 有「匯出版 smoke test」（D-049）：紅了先看 artifact 裡的 `smoke-export.log`。
- **本機截圖會在真的 `user://saves`（`/root/.local/share/YumingCity/saves`）留下自動存檔**，之後標題畫面的「繼續」會變成可按；要拍新玩家的標題畫面先把 saves 移開。只有 2 核，150 幀的對話截圖要單獨跑（同時跑會超過 120 秒逾時）。
- 本機跑匯出版 smoke test：`scripts/get-godot.sh --templates`（第一次約 1 分鐘）→ `$(scripts/get-godot.sh) --headless --path game --export-release "Linux" ../build/linux/YumingCity.x86_64` → `scripts/smoke_export.sh`。
- 只跑部分測試：`TEST_FILTER=gamepad $(scripts/get-godot.sh) --headless --path game -s res://tests/run_tests.gd`（檔名含那段字）。改了 class_name 或新檔案要先跑一次 `--import`。
- **程式 commit 與 `[skip ci]` 文件 commit 要分開 push**（同一次 push 的 HEAD 帶 `[skip ci]` 會讓整個 push 不跑 CI）。工作區有未提交的文件時：**先 commit 程式**，再 `git stash push -- docs`（只收文件）→ pull/push → `git stash pop`。第 20 輪先 `git stash` 再 `git add` 結果程式改動被收走、commit 只帶到新檔（多補了一個 commit）。
- **玩家看得到的字一律白話**：新名詞先寫進 `docs/design/06-terminology.md` 再用；`test_i18n::test_no_obscure_terms` 會擋舊詞（九息、弔鐘、薪火、巡界、下城、爹…）。程式識別碼照舊（`nine_breath`、`kindling`）。
- Jacky 的概念圖在 `art-inbox/concepts/`（LFS）：`git lfs pull --include="art-inbox/concepts/frostbridge_winter/**"` 這樣指定資料夾下載（推 LFS 還是不行）。看圖前先用 PIL 縮到 900 寬。
- 全域 Theme（D-067、D-071）：`UiTheme.style()` 定義按鈕／滑桿樣式，`App` 同時套在 root 與引擎預設 Theme；新選單直接用 flat Button 就有暖金色焦點。設定頁新增一列：在對的分組底下呼叫 `_add_cycler`（多選一，自動有「‹ 值 ›」與小圓點）／`_add_toggle`（開關，不畫圓點）／`_add_slider`（音量，帶百分比）；新分組用 `_add_group`（D-076），新 key 先查 `06-terminology.md`。
- 截圖旗標（都接在 `scripts/screenshot.sh <輸出> <幀數>` 後面）：`--level=frostbridge`；`--rb-at=start|mist|pursuer|throw|flight|impact|guardian|spray|sprayed|hit|slam|potion|drank|market|lift`（跳到劇情的那一段，鏡頭固定；每個值的意思在 `frostbridge_opening.gd` 開頭 `dev_advance` 附近的註解）；地下市場是 `--level=market --rb-at=arrive|street|shop|board|board_read`（前三個＝檢查點的出生位置；`board`＝藥店裡櫃台前、已經跟彌夏講過話；`board_read`＝手放過了，指針在綠色、燈亮）；只看鎮（不掛劇情）用 `--at=plaza|main|steps|north|south|cross`、`--pos=x,z`、`--face=…`、`--face-off=度`、`--hide=noen`；`--open=settings|pause`、`--dialogue=<id> --dialogue-steps=N`、`--nohud`、`--perf`（左上角效能文字，也看得出是不是退回 `opengl3`）、`--quality=0..2`、`--locale=zh_TW|en`、`--device=pad`、`--difficulty=`。軟體渲染很慢：一般 30～40 幀。固定鏡頭組在 `scripts/shots/rb_opening.txt`（`scripts/shots.sh rb_opening`，`SHOTS_ONLY=<名稱>` 只拍一張）。
- 改了 `i18n/*.csv` 之後：`scripts/check.sh` 會重跑字型子集與 import。改 CSV 時**只改那幾行**（Python 讀一行插一行／改一行，保留原本的引號；整檔用 csv.writer 重寫會把 `" (confirmed)"` 前面的空白弄丟）。英文裡有逗號要整格加雙引號。

## 1. 霜橋鎮的技術備註（只在動到霜橋鎮的畫面時查；講已經刪掉的東西的條目第 81 輪拿掉了）

- **第三輪盤點（PLAN 階段 2 第三張表，D-099）全部完成**：第 23 輪第 1～4 項（D-095～D-098）＋木桶（D-100）；第 24 輪第 5 項送葬者輪廓（D-101）、第 6 項破屋頂雪堆（D-102：`SnowMound.build(長, 寬, 高, seed, bias)`，模型 X＝長、Z＝寬、底在 y=0；`bias` 讓最高點偏一邊）、柴堆與手推車（D-103）；第 25 輪木圍欄（D-104：`FENCE_PATH`、`_build_fence`）、街邊雪帶（D-105：`_snow_bank(牆腳線起點, 終點, 牆的方向, 伸出寬度)`、`snow_banks`）、推車淡出（D-106：`CameraFade.apply(節點, near, far)`）、屋瓦（D-107：`RoofMesh.build`、`look.roof_tiles()`、`ROOF_SNOW`）、接地陰影（D-108：`ContactShadow.attach(角色, 半徑, 強度)`）。
- **第四輪盤點（PLAN 階段 2 第四張表，D-109）**：第 26 輪完成第 1 項（D-110：`RoofMesh.slab(長, 厚, 寬)` 只有頂面 UV 是公尺、-X 端是屋簷；`SnowMound` 20 段、輪廓大起伏）、第 2 項（D-111：`Caravan` 的 `_box`／`_part`、常數 `BED_*`／`WHEEL_*`／`LANTERN_POS`）、第 3 項（D-112：`_roof_snow_lip`）、第 5 項（D-113：`Caravan._wrap_head`）、第 7 項（併入第 1 項）。
- 第四輪第 4、6 項第 27 輪完成：地上殘雪（D-114：`FrostbridgeLook.set_ground_marks(lanes, trodden, rut)`、`frostbridge.gd` 的 `ground_lanes()`／`TRODDEN`／`RUT_PATH`；fbm 的值大多在 0.3～0.65，門檻照這個抓）、角色淡出（D-115：`CameraFade.CHARACTER_NEAR/FAR`、`EnemyActor.camera_fade_range()`；自訂 shader 要淡就宣告 `fade_near`／`fade_far` uniform，照 `frame_iron.gdshader` 的寫法）。
- **第五輪盤點（PLAN 階段 2 第五張表，D-116）**：第 28 輪完成第 1 項冬夜天空（D-117：`night_sky.gdshader`，`FrostbridgeLook.night_sky()`、`SKY_FOG_AFFECT` 0.4；雲的亮度 `cloud_dark`／`cloud_lit`／`cloud_cover`、星 `star_energy` 與門檻 0.998、遠山 `ridge_height()`；**不能用 TIME**，`test_night_sky` 會擋）、第 3 項雪堆外圈變薄（D-119：SnowMound 的 UV2.x＝圈數，其他雪沒有 UV2、合併時補 0；同一個 `look.snow()`）、第 4 項提燈影子（D-118：`PlayerController.SELF_LAYER` 第 12 層、`LANTERN_SHADOW_CASTERS`）。
- 第五輪（第 29 輪）：石板鋪法（D-120：`wet_cobble.gdshader` 的 `arc_paving`／`arc_center`／`row_wave`／`clear_disc`；`FrostbridgeLook.wet_ground_arc`、`frostbridge.gd` 的 `plaza_ground()`；**shader 內建 `TAU`，不要自己宣告**）、鐘鈕（D-121：`BELL_DROP`、`_build_bell_crown`）、店招（D-122：door shader 的店招模式 r＝0.4＋0.1×圖案編號、a 標記大面朝 X／Z；`FrostbridgeLook.sign_icon`／`sign_tint`）。
- 第六輪（第 30 輪）：雪帶（D-126：`snow.gdshader` 的 `wind_dir`／`ripple_*`／`wall_shade`／`footprint_density`；`SnowMound.build(..., bias, street_bank, on_tiles)`，UV2.y：街邊雪帶 -1～1＝往牆那側多遠、屋瓦上的雪＝`TILES_MARK`＋模型 X 公尺數、其他 0）、破屋頂的雪（D-127：`RUIN_SNOW_H`、`tile_row`、`under_color`）、廣場的圈（D-128）。
- 第八輪（第 33 輪）：雪帶連成一整條（D-136：`SnowMound.build_strip`／`strip_height`／`strip_out`，`frostbridge.gd` 的 `SNOW_BANK_HEIGHT`；`build_bank` 已經沒有關卡在用，只剩測試）、石階的雪（D-137：`_step_snow`、`STEP_PATH_HALF`、`step_snow`）、石階前緣下的暗線（D-138）。
- 第八輪（第 34 輪）：破屋頂的雪（D-139：`SnowMound` 的 `TILES_RINGS`／`TILES_SEGMENTS`／`TILES_RAGGED`／`TILES_FALLOFF`；`snow.gdshader` 的 `tile_drape`／`tile_mottle`／`moon_to`／`backlit_shade`，沿斜面公尺數的世界梯度 `gm` 跟腳印一樣用螢幕空間導數解）、廣場的鐘（D-141：`PLAZA_BELL_H／R／FLARE／CLAPPER_R`；**地上的圖案從南邊看南北方向被壓成約四分之一**，改比例不要改方向——橫躺看起來像一支箭）。
- **「第一眼」盤點停止（第 35 輪，D-146）**：八張表做完（第七張第 7、8 項、第八張第 7 項是截圖構圖或等 Jacky，不改）。之後的打磨只做 Jacky 試玩回饋提到的，或做章節時順手修；不要再開第九輪盤點。
- 第七張表第 8 項 TAA 等 Jacky 看網點。廣場石板（D-144）：`wet_cobble.gdshader` 的 `sunken_share`／`dark_share`／`grit_amount`／`ring_gap_tighten`／`far_fade`（街道預設 1.2、廣場 `ARC_FAR_FADE`）。
- 看穿小卡（D-087）：`InsightCard` 在敵人自己的 CanvasLayer（layer 9），資料是 `EnemyIntel.rows()`；新敵人只要有 `intel_id()` 就自動有卡。卡片放在頭頂投影點右邊（`OFFSET`），字級在 `insight_card.gd`。
- 前兆範圍（D-088）：新的範圍招用 `Undertaker._decal(mesh, pos, SHAPE_*, extent, arc_deg)`；長條的敵人端在模型 +Z、扇形朝 -Z。
- 過肩鏡頭的後續：D-085 之後 SpringArm 不撞角色；D-115 讓席菈與敵人靠近鏡頭時淡掉（諾恩本身不淡）。鏡頭參數在 `player.gd` 的 `SHOULDER_*`。
- 雪粒閃點在實機會動的鏡頭下會不會太閃，等 Jacky 回饋（`sparkle_energy`）。選單的「叮」（`ui_tick`，-15 dB）太吵或太小聲也等回饋；要不要讓暫停／標題選單的焦點移動也有聲音，一起決定（D-078）。
- 新的互動點照做：加進 `interact_prompts` 群組、實作 `interact_hint()`（D-065）。
- 第 14 輪：燈的高光 1.0、石面 0.46、水窪細波紋（D-058）。還可以：亮窗的發光再亮一點（只在 probe 裡看得出差別）、廣場 probe 拍攝點再低（`PROBE_EYE` 0.6）。截圖 `--at=plaza`、`--at=main`、`--at=south`，高畫質 `--quality=2` 也看一下。
- **鐘的金屬度**（D-050）：鐘在台地北端，不在任何 probe 盒子裡；要提高金屬度得在鐘樓加一個小 probe（只拍倒影層），注意反射圖集上限 8 張（`project.godot`）。
- 半木構的立柱不一定對齊房子邊緣，近看不順就在 `_house` 加真的角柱幾何（深色木條 box，進 StaticBatch）。
- 程序人偶小幅輪廓：席菈白**短**斗篷＋寬斷劍（刃上一點冷光）。送葬者第 24 輪做完（D-101）。不要大改（正式模型由 Jacky 做）。
- 標題畫面（D-061）鐘樓第 16 輪加了簷口、石塊層、窄窗；霧堤速度在實機看（截圖是靜態）。

## 6. 角色模型（等 Jacky 交件）

- **86efa9b（11/10 15:35）席菈大劍收到世界座標 35 cm＋鋼材貼圖重新封裝**（非武器部分逐頂點不變、披肩照舊）第 65 輪看過 `blade_night_preview`／`blade_preview`／`night_preview`：比例對了；意見（暖燈下整片鍍金感 → 底色冷灰、白色斑點像雪 → 細長刮痕、護手頂面純白亮邊）寫在 FOR_JACKY 第 4 項。披肩這次沒動，之前的意見照舊有效。
- **ce168d5（11/10 00:50）席菈大劍漸窄＋諾恩 walk 衣襬修整**（回應 FOR_JACKY 第 4 項）第 50 輪看過 `blade_night_preview`、`coat_side_preview`：衣襬好很多；劍面在暖燈下像米黃色紙板、還是比背寬（意見寫在 FOR_JACKY 第 4 項）。
- **c3b30f7（11/10 00:34）諾恩 run**（`run_loop`＋`run_candidate.fbx`：ACCAD Male1_C03_Run 動捕、in place、約 0.63 秒一個週期、保留右前臂護傷；同一個 GLB 裡 idle／walk／run 三段）第 50 輪看過 `run_preview`／`run_night_preview`，意見寫在 FOR_JACKY 第 4 項（左臂抬到肩高、手腕往下折像爪子）。**正式接進遊戲時**：ACCAD 動捕要在 `docs/CREDITS.md` 註明出處（照 Jacky 製作紀錄寫的授權原文）；跑步速度參考 4.49 m/s，遊戲裡諾恩跑步是 `PlayerController` 的速度，接的時候照速度調播放速率。照舊沒放到 `art-inbox/characters/` 就不要接進遊戲。
- **c597dfa（11/9 23:57）諾恩護傷 idle**（`idle_loop`＋`walk_loop` 同一個 GLB，Godot 匯入成 `idle`／`walk`；右前臂夾板護在身前）與**席菈大劍重製＋三材質**（713e843，23:24）第 49 輪看過，意見寫在 FOR_JACKY 第 4 項。Jacky 新增 `docs/ART_DELIVERY_STATUS.md`（逐項交件狀態，正式驗收 0 件）——角色進度以這份為準。照舊沒放到 `art-inbox/characters/` 就不要接進遊戲；正式接諾恩時 `idle` 是護傷姿勢，只在有夾板（`Puppet.set_splint`）的時候用，沒夾板的段落要另一段一般待機。
- **c3059c8（11/9 14:58）諾恩三材質版本**（`M_Noen_Skin`／`M_Noen_Clothes`／`M_Noen_Hair`，各一組 2K base color＋normal＋ORM；三角面與 60 根骨骼不變）第 41 輪看過，意見寫在 FOR_JACKY 第 4 項（大衣前襬下緣還是像硬板往外翹、雙腳離地）。**正式接進遊戲時**：Godot 4.7.2 匯入 GLB 不吃 `KHR_materials_specular`，頭髮高光會回到 0.5——Jacky 的 `noen_material_import.gd` 把 `M_Noen_Hair` 設成 0.06；遊戲端在 `CharacterModels` 載入後照名字把這個材質的 `metallic_specular` 設 0.06（不用 import script）。照舊沒放到 `art-inbox/characters/` 就不要接進遊戲。
- 第 40 輪（11/9 14:45）Jacky 推了**諾恩綁帶修整**（左手移到前襟外、頭髮法線、頸部接縫；還是 11 材質）與**送葬者六個關節定位點**（`FrameJoint_L0/L1/L2`、`FrameJoint_R0/R1/R2`，由下往上、frame_root 底下的 Node3D，位置在 `art-inbox/studies/undertaker/joint_locators.json`），README 一樣是未驗收、**不要接進遊戲**；意見寫在 FOR_JACKY 第 4 項。正式交件時：`Undertaker` 的鐵架關節弱點改用這六個節點的位置（現在是程序鐵架上的固定位置）。

- 第 35 輪（11/9 09:29）Jacky 推了**送葬者綁骨架候選**（`art-inbox/studies/undertaker/`：53,259 面、71 骨骼、3 材質、walk、鎖鏈接地、弱點材質 `M_FrameJoint`）與 CMU 握劍研究（`docs/art-trials/cmu-sword/`），README 一樣寫明未驗收、**不要接進遊戲**；意見寫在 FOR_JACKY 第 4 項（橫桿頂面一條亮白、正式版請留關節骨骼或 Marker）。**之後真的用到 CMU 動捕時，`docs/CREDITS.md` 要照 cmu-sword README 的致謝原文加上去**（CMU 允許商業使用、要求致謝、禁止轉售資料本身）。
- 第 34 輪（11/9 08:27）Jacky 又推了**席菈試作**（`art-inbox/studies/sheila/`：GLB＋walk_loop、`docs/art-trials/sheila-rigging/` 製作腳本）與送葬者袍身試跑（`docs/art-trials/undertaker-rigging/`），README 一樣寫明未驗收、**不要接進遊戲**；意見寫在 FOR_JACKY 第 4 項（背劍像黑色看板、斗篷像圍巾＋肩內側米黃色、材質要合併）。遊戲端已認得 `walk_loop`（D-140）；她的 `weapon_socket` 骨骼正式交件時再決定要不要讓燃燒劍掛上去（`CharacterModels.HAND_BONES` 現在只找手骨骼）。
- 第 15 輪 Jacky 推了 `docs/art-trials/noen-rigging/`（本機 MPFB 分件角色＋ACCAD walk 試作，README 明寫「不是正式交件、未換遊戲內角色」）。**不要自己把它接進遊戲**，等他放 `art-inbox/characters/noen/noen.glb`。裡面的 `godot_review/` 是獨立的檢視專案，跟 `game/` 無關。

- 接入點已完成（D-041、04-architecture「角色模型接入點」）。Jacky 放 `art-inbox/characters/<id>/<id>.glb` 後：跑 `scripts/check.sh`（會先 `git lfs pull --include="art-inbox/characters/**"` 才拿得到檔案），看 `[characters]` 那幾行有沒有通過；通過就截圖對照 `--at=plaza`、`--rescue`、`--convoy`，檢查提燈／鐘錘掛點、走跑步頻、面向（-Z）。席菈的燃燒劍掛在 `hand("R")`，換模型後要確認火光位置。
- 之後：敵人（Undertaker、Ashwalker）走同一個入口；弱點位置（灰巡者左膝、送葬者鐵架關節）用骨骼名或 Marker 對齊；動作多了換 AnimationTree。傷者／受困者的躺姿只在程序人偶上（`Puppet.lying`），模型版要另外的躺姿動畫；送葬者倒地目前是轉整個 `_body`，模型版要倒地動畫。

## 備註

- 截圖一律在前景跑（本機一張約 1 分鐘）：Bash 工具裡 `( … &)` 背景跑的截圖會在工具呼叫結束時被收掉（第 30 輪）。
- 粒子一律用 `ParticleLook.material(color, additive)`（D-056）；`test_particle_look` 用 `ParticleLook.untextured(node)` 找沒貼圖的粒子，新的特效節點也加進去。

- **繞 X 軸負角度是往前倒／前傾**（頭在 -Z，D-052）。送葬者用 `FALL_FORWARD = -1.0`；寫新的姿勢時照這個常數，別再寫反。
- 水窪倒影（D-051）：新的靜態幾何要進倒影就放進 StaticBatch（`_build_reflection_probes` 會幫 Town 的 mesh 加倒影層）；動態物件不要加 `REFLECT_LAYER`（會被凍在倒影裡）。

- **霜橋鎮北段有高低差**（D-048）：主街 z < -24.2 開始上石階，z ≤ -29.2 是高 0.9 m 的台地。測試或開發旗標瞬移角色時用 `level.ground_y(pos) + 0.05`，不要寫死 y=0.05（會卡進台地）。新增北街的東西 y 用 `RISE`。
- 手把 UI：`ui_accept`＝A、`ui_cancel`＝B 是 `InputSetup.ensure_ui_pad()` 補的（D-047）；新選單照常用 `ui_*` 動作＋`grab_focus()` 第一個按鈕就能用手把。

- 目標指引（D-040）：任務每個階段都要有 `marker`（測試會擋）。新章節照填；`nearest:<前綴>` 會跳過 `is_available()` 回傳 false 的節點。
- 主線流程測試是 `tests/flow/test_story_playthrough.gd`：真的換場景（`Game.go_to_level`）＋每個檢查點 `Game.retry()`。新增段落時在這裡補一段；場景層面的斷言寫在 `[檢查點]` 前綴的訊息裡。
- 對話依狀態換台詞用 `text_if`（D-037）；`DialogueRunner.current_text()`。
- **測試裡別讓諾恩真的倒下**：`Game` 的倒下狀態會漏到後面的測試。只測某個招式時把敵人 `set_physics_process(false)`。測試裡生成敵人：**先設 `position` 再 `add_child`**。
- 連到 autoload 訊號（`Game.dialogue_ended` 等）用**方法**不要用 lambda（物件釋放時方法連線會自動斷開）。
- Godot 的骨骼名不能有冒號：Mixamo 的 `mixamorig:LeftHand` 匯入後是 `mixamorig_LeftHand`。
- `StaticBatch.build()` 之後不能再加東西（會被丟掉）：所有要合併的幾何都要在 `_batch.build(self, "Town")` 之前加。房子裝飾用位置雜湊決定，**不要多呼叫 `_rng`**（會改掉整個鎮的配置）。
- **自己畫字的 UI 元件一律用子節點 Label**，不要在 `_draw()` 裡 `draw_string`（遊戲裡這套子集字型會畫成缺字方塊，D-060；可能其實是 D-071 的 Theme 沒套到造成的，沒驗證前照舊用 Label）；Label 印的是鍵名而不是翻譯 key 時標 `set_meta("glyph", true)`。
- **HUD 上含按鍵的提示一律用 `GlyphLine`**（D-063）：翻譯字串保留 `{key}`，其他佔位符先 `format` 掉，再 `line.set_line(fmt, action, App.last_device)`；測試讀 `plain_text()`（文字版「[Y]」）、`uses_glyph()`、`parts()`。放在錨點或容器裡時設 `fit_content = false`。
- 新音效：加進 `scripts/gen_sfx.py` 的 `main()` 與 `src/core/sfx.gd` 的 `NAMES`（`test_sfx` 與打包驗證都讀 NAMES）。
- 打包驗證（D-044）：新增遊戲一定要有的資源時，把路徑加進 `scripts/verify_package.py` 的 `REQUIRED`。
- CI 有 Node 20 deprecation 警告（actions/checkout@v4 等），目前被強制用 Node 24 跑，不影響結果。
