# 決策紀錄

新的放最上面。格式：編號、日期（台北時間）、決策、理由、影響。

## D-235　2026-11-12　小戰檢驗（C 的後半第一輪）：護腕「打中人才給麻痺」、毒瓶的霧＝諾恩的補給；商人帶三個人堵在藥店門外，一個拿棍子的只追諾恩

- 決策：
  1. **新任務 `rb_trial`**（`MAIN_QUESTS` 第五條；`rb_bracer.json` 的 `on_complete` 直接 `start_quest`）：`leave_shop`（檢查點 `rb2_trial`＝店裡櫃台前）→ 走出藥店的門 → 對話 `rb2_trial_ambush`（商人：護腕還來、再賠四十枚，我帶了會丟毒瓶的人；諾恩：正好，我在找地方試）→ `trial_fight`（檢查點 `rb2_trial_fight`＝藥店門外、面向北）→ 三個都倒下 → `rb2.trial_won`（任務做完、自動存檔）→ 1.6 秒後對話 `rb2_trial_won`（席菈、諾恩、彌夏各一句；最後一句設 `rb2.trial_talked`、存一次）→「待續／乾運河」。第 88 輪「試戴完就待續」的存檔在 `GameSession.load_slot` 補開（條件：`rb_bracer` 做完）。
  2. **護腕怎麼持續給麻痺**：`PlayerController.on_hit_source`（戴上護腕時劇情設成 `"bracer_hit"`）——出手**打中人**（`strike()` 命中數 > 0）才 `apply_source`：1.35 倍、6 秒。同一來源只有一份、時間取長的，所以連打不會越來越快、也不會越來越久；停手 6 秒就退。**麻痺沒有裝在反轉欄位裡就不給**（不然打中一下就把自己麻到不能出手）。
  3. **丟毒瓶的**（`DemoGuard.KIND_THROWER`，數值 `tuning.json` 的 `demo_thrower`）：生命 70、站在 7～8.5 m 外，前兆 0.9 秒（瓶子舉過頭、越舉越亮）→ 瓶子沿弧線飛 0.55 秒 → 落地才有霧（`PoisonMist`，半徑 2 m、3 秒，來源 `poison_bottle`＝每秒 5 點、3 秒）。**這一下沒有直接傷害**；丟完 2.4 秒才掏得出下一瓶（一瓶 3.45 秒 > 霧 3 秒：場上最多一團）。他永遠瞄諾恩。
  4. **誰打誰**：三個人裡，第一個拿棍子的與丟毒瓶的 `focus_player`＝只追諾恩；第二個拿棍子的照舊追最近的人（多半是席菈）。席菈開打時喊「拿棍子的我來。丟瓶子的交給你。」
  5. **開打之前他們已經站在街上**：`leave_shop` 階段人還在店裡時就生出來，`set_waiting(true)`——不動、不在 `enemies`／`damageable` 群組裡（席菈不會先衝過去、鏡頭不會拉遠、鎖定不到）；商人喊完話才放開。商人自己（布景的那個人偶）站到他們後面指著人罵，打輸了兩手舉著退到街的北邊。
  6. 固定鏡頭 `67-rb2-trial`（`--rb-at=trial_hold`）。
- 理由：
  - 2：story-v2 寫「中毒回血＋連擊加速」——「連擊」就是打中才有；一直有的話 12 秒過了要嘛永久加速（沒有代價也沒有節奏），要嘛護腕變裝飾（第 88 輪結尾的樣子）。
  - 3：這一場的重點是讓玩家自己發現「敵人丟過來的東西是我的藥」。所以毒瓶不能有直接傷害（不然站進去是賭博）、霧要比守衛噴的淡（每秒 5 點：回得動，但擋不住兩個拿棍子的一起打）。
  - 4：**本機不停住任何人跑了兩次**（諾恩站在門口不動、生命 60）。第一版三個人都追最近的心跳：兩個拿棍子的一起圍席菈，她 160 → 0 只花 16 秒。改成一人一個之後：她 14 秒打倒自己那個、剩 94，回頭幫忙，29 秒三個都倒；諾恩一下都沒打中人、一直站在霧裡被打：生命 60 → 最低 38 → 結束時 77（一團霧的回血大約抵掉一個拿棍子的）。真人會還手，只會更快。
  - 5：走出門才生出來的話，三個人是在玩家眼前憑空出現的。
- 影響：
  - `UndergroundMarketStory`：`_tick_trial()`、`_spawn_trial_gang()`、`start_trial_fight()`、`trial_down()`、`outside_shop()`、`_dev_hold_trial()`；`_tick_bracer()` 最前面那一支改成接 `_tick_trial()`；`AFTER_BRACER_SPAWN` 拿掉（試戴完讀檔＝櫃台前）。「待續」的卡名改成 `RB2_END6_TITLE`（乾運河）；`RB2_END5_TITLE`（兩格一起用）沒人用了，key 留著。
  - `UndergroundMarket`：`TRIAL_POS`、`TRIAL_FIGHTERS`、`TRIAL_SELLER_POS`、`place_trial_seller()`、任務標記 `TrialStreet`。
  - `DemoGuard`：`KIND_THROWER`、`_toss()`／`_bottle_landed()`、`_bottle_node()`、`_add_bottle_belt()`、`set_waiting()`、`focus_player`（覆寫 `_nearest_heartbeat()`）。
  - `statuses.json` 多兩個來源（`bracer_hit`、`poison_bottle`）；`intel.json`／`tuning.json` 多 `demo_thrower`；`Game.CHECKPOINT_LEVELS` 多 `rb2_trial`、`rb2_trial_fight`；`dev_advance` 多 `trial|trial_fight|trial_hold|trial_won`（會設 `rb2.dev_equip`：兩格直接裝好）。
  - 測試 324 → 327。

## D-234　2026-11-12　試戴護腕（C 的前半）：麻痺是「不碰生命」的狀態——沒反轉不能出手、反轉＝只有出手變快（上限 1.5 倍）；在彌夏的測試板上試過才解鎖，裝進第二格

- 決策：
  1. **新任務 `rb_bracer`**（`MAIN_QUESTS` 第四條）：`back_to_shop`（走回藥店櫃台前 → 彌夏要他照規矩先在板子上試）→ `test_bracer`（按住互動 2 秒 → 麻痺解鎖、裝進第二格 → 3 秒後彌夏講結果）→「待續／兩格一起用」。**不是 `rb_demo` 做完就自動開**，而是拿到護腕的那一刻由劇情開（`_tick_demo_won()` 裡 `grant_once` 成功時）；第 87 輪「拿到護腕就待續」的存檔在 `GameSession.load_slot` 補開。
  2. **麻痺 `paralysis`**（`statuses.json`，新欄位 `kind: "action"`；沒寫 `kind` 的＝`"dot"`，就是中毒那種每秒扣血／回血）：
     - 不扣血也不回血；`StatusEffects.tick` 只幫它計時。
     - 沒反轉：這段時間**不能出手**（`blocks_attack()`）；走路、閃避照常。
     - 反轉：**只有「出手」這個動作播得快**（`attack_speed()` → `Puppet.attack_speed`）。倍率＝那一份麻痺的強度，上限 `max_reversed_rate`＝1.5；同一種狀態只有一份（沿用中毒的規則：強的蓋掉弱的、時間取長的、最長 20 秒）。測試板的那一份是 1.35 倍、12 秒。
     - **不會自動覺醒**：開場的中毒是唯一的特例（`ReversalSlots.FIRST_AWAKEN`）；麻痺要 `unlock` 之後才裝得進去。
  3. **「第二格」就是開場就有、一直空著的那一格**（`ReversalSlots.START_SLOTS`＝2）：這一輪沒有加格子，只是第一次有東西裝進去。`reverse_paralysis()` 指定裝進第二格（第一格留給中毒）；已經裝了再叫不會多佔。
  4. **看得到的回饋**：測試板的指針——按住的時候往紅的那邊擺，試完翻到綠的那邊、綠燈亮（沿用 A 的板子）；畫面中央兩行字「【麻痺】／【第二格反轉】麻痺 → 出手加速」（沿用開場覺醒的那個位置）；左下的狀態列（生命條上面）多一行黃色閃電的圖示＋綠字「麻痺 → 出手加速 12」；護腕戴到諾恩的右前臂（`NoenBracer`，跟守衛手上同一個做法：兩圈冷光，發光材質、不加燈）。
  5. **存檔**：試到一半（手放上去了、彌夏還沒講完）不存——讀檔回到櫃台前、還沒試過；講完的那一刻任務做完、自動存檔。做完之後讀檔站在藥店外面（`AFTER_BRACER_SPAWN`），走到櫃台前才是「待續」。
  6. 固定鏡頭 `66-rb2-bracer`（`--rb-at=bracer_read`）。
- 理由：
  - 1：`rb_demo` 在兩個守衛倒下的那一刻就做完了；如果那時候就開 `rb_bracer`，商人還在認輸、護腕還沒到手，畫面右上的目標已經寫「回彌夏的店」。
  - 2：status-reversal.md 麻痺那一列寫「攻速有上限，不加快世界所有計時」——所以倍率只乘在人偶的出手動作上，不動 `Engine.time_scale`、不動閃避的無敵時間、不動敵人的前兆。「不能出手」而不是「整個人不能動」：整個人不能動在動作遊戲裡等於直接死，而且那是「冰凍／定身」的位置（表格裡另外兩種狀態），麻痺留給「動作被打斷」。
  - 2（不自動覺醒）：status-reversal.md「首次遇見未裝備狀態會留下可研究的紀錄；戰後透過安全測試解鎖，不允許中招瞬間自動獲得所有免疫」。這一段就是第一次示範這條規矩：先看到別人被麻（守衛）→ 拿到東西 → 在安全的地方試 → 才裝進去。
  - 3：開場 UI 就畫了兩格（09 第 6 節），玩家從第一分鐘就看到一個空格；現在把它填起來，比「突然多一格」更有「終於」的感覺。
  - 5：試到一半不存，是因為解鎖與裝備寫在玩家身上、存檔時才寫回去；如果只存旗標不存欄位，讀檔會變成「旗標說試過了、第二格卻是空的」。等對話講完一起存最單純。
- 影響：`statuses.json`（`paralysis`、來源 `bracer_test`）、`StatusRules.kind()`、`StatusEffects`（`PARALYSIS`、`blocks_attack()`、`attack_speed()`、`tick` 只對 `dot` 動生命）、`Puppet.attack_speed`、`PlayerController`（每幀把倍率交給人偶；麻痺沒反轉不開始攻擊）、`StatusHud._draw_bolt()`、`GameSession`（`BRACER_QUEST`、`MAIN_QUESTS`、`load_slot` 的遷移）、`Game.CHECKPOINT_LEVELS`（`rb2_bracer`、`rb2_bracer_board`）、`UndergroundMarket.worn_bracer()`、`UndergroundMarketStory`（`_tick_bracer()`、`reverse_paralysis()`、`bracer_ready()`、`_wear_bracer()`、`_dev_bracer_read()`、`dev_advance` 多 `bracer|bracer_ask|bracer_read`、`END_TITLE_KEY` 換成 `RB2_END5_TITLE`）、`data/quests/rb_bracer.json`、`data/dialogue/rb2_bracer_ask.json`／`rb2_bracer_result.json`、`i18n/reboot.csv`（17 個新 key）、`scripts/shots/rb_market_level.txt` 與 CI 的 `66`。測試：`test_status_effects.gd`（＋2）、`test_puppet.gd`（＋1）、`test_story_market_level.gd`（＋1，另外兩個流程測試的結尾往後延）、`test_story_playthrough.gd`。**還沒做的（下一輪）**：戰鬥裡麻痺從哪裡來（護腕戴著的時候怎麼持續給）、小戰檢驗、彌夏圈出乾運河、補給；`RB2_END4_TITLE`（試戴護腕）這個 key 現在沒有人用了（任務標題 `Q_RB_BRACER_TITLE` 是同樣的字），留著不刪。

## D-233　2026-11-12　示範場的守衛戰：兩個人形守衛（`DemoGuard`），戴護腕的那個「出拳快、打完手就麻」就是騙局的證據；打贏拿到護腕，下一段才試戴

- 決策：
  1. **新敵人 `DemoGuard`**（`scenes/actors/demo_guard/demo_guard.gd`，`EnemyActor` 的子類別，身體是程序人偶，胸前斜掛紅白布條）。兩種，數值在 `tuning.json` 的 `demo_guard`／`demo_bracer`：
     - 拿棍子的（生命 120）：棍子橫掃（前兆 0.75 秒、130 度、12 點）與直刺（0.55 秒、36 度但伸到 2.9 m、10 點）輪流。
     - 戴護腕的（生命 100）：只有快拳（前兆 **0.32 秒**、9 點），但每打完一拳**右手垂著僵住 1.8 秒**（護腕從冷光變成一閃一閃的暗紅），這段時間失衡三倍（兩下鈍擊就跪）。他的左手從頭到尾垂著不動——對話裡諾恩說的「左手一次都沒動過」。
     - **沒有任何狀態攻擊**（story-v2：這一場席菈是主力，中毒回血幫不上忙）。
  2. **倒下之後躺在原地**，不沉進地裡、不釋放（是人不是怪物）；倒下那一刻就離開 `enemies` 群組（鎖定、席菈找目標、戰鬥 HUD 都不再算他）。
  3. **開打的方式**：聽完叫賣之後再走近（同一個 4.6 m）→ 席菈頭上一句「再示範一次。這次不准喝解藥。」＋畫面上方一行提示（戴護腕的出手快、打完手會麻、趁他僵住打）→ 布景的兩個守衛藏起來、同一個位置生出真的敵人（戴護腕的從台上跳下來）→ 看熱鬧的三個人跑到街的北邊（z≈13）回頭看、商人縮到台子後面兩手舉著。「開打了沒」不存檔：讀檔、倒下重試都是整個關卡重來，守衛滿血。
  4. **站著的人的碰撞盒從 `_batch` 改成各自的 `StaticBody3D`**（`demo_blocks`）：開打時台下守衛的那一個關掉、看熱鬧的人的三個直接搬到北邊——不然他們原本站的地方會留下三個看不見的柱子擋在戰場正中間。
  5. **打贏**：兩個都倒下 → `rb2.demo_won` → 任務 `rb_demo` 做完（自動存檔）→ 1.6 秒後對話 `rb2_demo_won`（商人：拿去、快走；諾恩：真正的副作用；席菈：你別戴；諾恩：回彌夏的店裡試）→ `rb2.bracer_taken` → `GameState.grant_once("rb2_demo_bracer")`，**拿到的那一刻再存一次檔**（「繼續」不會再聽一次、再拿一次）→「待續／試戴護腕」。護腕現在只是一筆「拿過了」的紀錄，還不是能裝的東西——C 才做。
  6. 「待續」的卡名 `RB2_END3_TITLE`（示範場的守衛）拿掉，換成 `RB2_END4_TITLE`（試戴護腕）。
- 理由：story-v2 這一段要玩家「看出騙局」——與其再用台詞講一次，不如讓戴護腕的守衛每打一拳就僵住，玩家打他的時候自己會發現（也順便預告 C：這個副作用到諾恩身上會反過來）。兩個敵人各 100 上下的生命是照 NEXT 的「先求打得起來」；本機不停住任何人跑了一次：諾恩完全不動的話席菈一個人 18 秒打完，生命 160 → 36（偏低，記在 NEXT，等真人玩過再調）。
- 影響：`demo_guard.gd`（新）、`underground_market.gd`（`begin_demo_fight()`、`_person_body()`、`DEMO_FIGHTERS`、`DEMO_CROWD_FLEE`）、`underground_market_story.gd`（`start_demo_fight()`、`guards_down()`、`_tick_demo_won()`、`--rb-at=fight|demo_won`）、`tuning.json`、`intel.json`、`rb2_demo_won.json`、`reboot.csv`；測試 316 → 320（`test_demo_guard.gd` 新增 4 個，`test_story_market_level`、`test_story_playthrough` 延長）；固定鏡頭 `65-rb2-fight`。

## D-232　2026-11-12　黑市示範場（B）：同一個關卡裡的一座示範台、新任務 `rb_demo`；第一版先做「走過去、聽叫賣、看出騙局」，守衛戰下一輪

- 決策：
  1. **示範場不另開關卡、也不在岩壁上開洞**：用街中段西側那個空位（`WEST_KINDS` 的 `KIND_GAP`，z＝19.5）搭一座示範台（`UndergroundMarket._build_demo_stage()`）。那一格原本的木箱與桶不放了，但亂數照抽（少抽一次後面的攤子全部會變，`60`～`62` 的基準要重拍）。
  2. **新任務 `rb_demo`（不是在 `rb_market` 後面加階段）**：已經做完 `rb_market` 的存檔不會自己多出階段；新任務由 `rb_market.json` 的 `on_complete` 開，舊存檔在 `GameSession.load_slot` 補開（跟 `rb_market` 當初同一個寫法）。`GameSession.MAIN_QUESTS` 變成三條。
  3. **兩個階段都先寫進資料**：`go_demo`（走到示範台、聽完叫賣）這一輪能玩；`stop_demo`（守衛戰）還沒做，現在走近示範台就是「待續／示範場的守衛」。先寫進資料的理由：這一輪存下來的進度停在 `stop_demo`／檢查點 `rb2_demo_fight`，下一輪戰鬥做出來之後直接接著打，不用遷移。
  4. **第一版不做戰鬥**：現成的敵人只有送葬者；人形守衛要新寫一個敵人，跟場景、流程、台詞擠在同一輪做不好。這一輪把場景做到看得過去、流程接起來。
  5. **騙局的寫法**：吊牌上有寫副作用，照這裡的規矩不算犯規；騙的是程度與價錢（護腕 15 枚、解藥 40 枚、每戴一次要喝一瓶）。證據做在場景裡：台上示範的守衛左手垂著不動。玩家畫面的用詞：示範台、高速護腕、護腕商人、麻痺（`06-terminology.md`）。
  6. **示範台中間有一截伸到街上 1 m，商人站在那裡**；台子兩端各掛一幅跟街垂直的直條紋布。理由：人是沿著街從南邊走過來的，貼牆的台子會被隔壁攤子擋住、貼牆的背景布只看得到斜斜一條（第一版就是這樣：整個台子在畫面上只有一小塊，還被席菈擋住）。
  7. **聚光燈投影（投影的燈 3 → 4，剛好到測試的上限）、顏色是暖白**；護腕的冷光與解藥的金色是發光材質，不是燈——「彩色的燈只有三種」不變。
  8. **人偶的固定姿勢用 `UndergroundMarket.PoseOverride`**（掛在人偶底下的小節點，排在人偶的 `_pose` 之後把幾個關節蓋掉）：不改 `Puppet`；換成角色模型時自動沒有作用。
  9. **談完的那一刻把席菈放到藥店門外**：她是直線跟人，停在 1.3 m 寬的門洞裡會把人堵在店裡（第 85 輪列的風險）。
  10. 翻譯 key `RB2_END2_TITLE`（「黑市示範場」那張待續卡）刪掉，換成 `RB2_END3_TITLE`（「示範場的守衛」）；任務標題 `Q_RB_DEMO_TITLE` 沿用「黑市示範場」。
- 理由：Jacky 要一次一段、做完一段就能從頭玩到尾；畫質優先——所以這一輪的時間花在場景上，戰鬥留一整輪。
- 影響：從標題玩到「待續」多一小段（出店門 → 示範台 → 對話，約 1 分半）；固定鏡頭多一個 `64-rb2-demo`；測試 314 → 316。下一輪：守衛（新敵人）＋戰鬥＋拿到護腕。

## D-231　2026-11-12　彌夏的藥店可以走進去：店蓋在門面後面（不換場景、不黑一下）；測試板是「按住互動 2 秒」，回饋做在板子上；這一段做完自動存檔

- 決策：
  1. **店內蓋在門面後面，門開著、直接走進去**（不做「門口按互動 → 黑一下 → 換到別處的房間」）。門面的牆在門洞那裡斷成三塊（門西、門東、門楣以上），門板整個推到底貼在店裡的牆上。房間 9.2 × 5.2 m、高 3.4 m（`SHOP_INNER_Z`～`SHOP_ROOM_S`、`SHOP_ROOM_HALF`、`SHOP_ROOM_H`），自己的牆、天花板與地板——洞的岩盤只到 `CAVE_S`，後面那一段補一塊一樣高的碰撞；**`CAVE_S` 不動**（動了街面與岩壁的盒子都會變，`60`～`62` 的基準全部要重拍）。
  2. **店裡的東西全部寫死位置、用位置雜湊決定大小與顏色（`_hash01`），不抽 `_rng`**：櫃台（`COUNTER_*`）、南牆三層藥架（八十瓶上下：綠的發光最多、幾瓶琥珀色、深色的空瓶）、西牆抽屜櫃（4×6 格、銅鈕）、東牆蒸餾台（銅壺＋三顆發光的大燒瓶）、樑上倒掛的藥草、櫃台上的研缽與帳本。
  3. **店裡的燈都不投影、彩色的還是只有綠**：櫃台上方一盞暖色吊燈、抽屜櫃頂一盞小燈、藥架與蒸餾台各一團綠光（顏色就是 `SHOP_GREEN`，「彩色的燈只有三種」不變；投影的大燈上限不變）。
  4. **測試板與彌夏不放在門的正對面**（`BOARD_POS` x＝0.7、`MISHA_POS` x＝0.05；門在 x＝-1.7）。
  5. **測試板＝按住互動鍵 2 秒（`BOARD_HOLD_SEC`），放開或走開就歸零**；累計寫在 `UndergroundMarketStory._tick_test_board()`，提示走現成的 `interact_prompts`（`interact_hint()` 回傳 `progress` 0～1，HUD 本來就會畫進度條）。**回饋做在板子上**：按著的時候指針慢慢往紅色（受傷）偏——板子在下毒，照理說該往那邊走；按滿之後指針甩到綠色（回復）、板上的綠燈亮（`set_board_progress()`／`set_board_healing()`，`_animate_board()` 追上去、到位後微微抖）。
  6. **測試板的毒是資料表裡的來源 `test_board`（中毒、1／秒、6 秒）**，走 `StatusEffects.apply_source()`：同一來源不疊加、反轉欄位照舊。
  7. **生命是滿的才扎針（直接傷害 3 點，`NEEDLE_PRICK`），而且彌夏會先說**：開口前記下 `rb2.full_health`，`rb2_misha_meet` 最後一句用 `text_if` 換成有「我先扎一針」的版本，對話結束才真的扣。
  8. **指針甩過去之後等 3 秒（`BOARD_READ_SEC`）彌夏才開口**（`rb2_misha_deal`）→ `rb2.first_shop_done` → 任務 `rb_market` 做完 →「待續／黑市示範場」（`RB2_END2_TITLE`；`RB2_END_TITLE`「彌夏的藥店」拿掉）。
  9. **兩條主線任務做完都自動存檔**（`GameSession._on_quest_completed`：`quest_id in MAIN_QUESTS`，以前只有 `rb_main`）。做完之後讀檔：回到藥店前幾步（檢查點還是 `rb2_shop`），不會一讀檔就黑掉；走進店裡到櫃台前才再看到「待續」，彌夏不會從頭再講。
  10. 任務 `test_board` 階段的標記從門口（`MishaShopDoor`）改成測試板（`MishaTestBoard`）；目標文字改成「走進藥店，把手放到測試板上」。固定鏡頭多一個 `63-rb2-board`（`--rb-at=board`：講過話、站在測試板東邊半步）；`--rb-at=board_read`＝手放過了（本機看燈與指針用，CI 不拍）。
- 理由：
  - 1：地下市場是招牌場景，從街上隔著開著的門就看得到店裡一排發光的瓶子，比一扇關著的門有吸引力；直接走進去也不用另外做轉場與鏡頭處理。店只有 5 m 深，鏡頭的彈簧臂會自己縮短，站在櫃台前剛好是過肩看彌夏的距離。
  - 4：第一版把測試板放在門的正對面（x＝-1.2），人站在板子前、鏡頭在他右後方——剛好卡在門框與往裡開的門板後面，畫面左半邊是黑的、彌夏與板子都看不到（亮度 6.6、死黑 67%）。板子往東移 1.9 m、門板改成貼牆之後亮度 47、死黑 0.1%。
  - 5：設計稿寫「按住互動 2 秒」。現成沒有「按住」的互動元件，但提示列本來就支援進度條，所以只要自己累計秒數；不為一個互動新做一套 HUD。指針先往紅色偏再甩到綠色，是把彌夏的預期（「指針往紅色那邊跑，你付解藥錢然後回家」）做成看得到的東西。
  - 7：滿血時中毒回血補不到東西，生命條與身上的綠色光點都不會出現（D-213）。不說一聲就扣 3 點，玩家會以為被攻擊。
  - 8：馬上開口的話，對話框會蓋住剛開始往上的生命條；3 秒可以回 3 點，看得到綠色段。
  - 9：以前只有前十分鐘做完會存。這一段談完如果不存，「繼續」會回到進店之前，整段對話與測試板要重做一次。
- 影響：`underground_market.gd`（`_build_shop()` 門面斷開、`_build_shop_interior()`、`_bottle()`、`_build_test_board()`、`_animate_board()`、`set_board_*()`、`misha`、`test_board`、`shop_bottle_count`）、`underground_market_story.gd`（`_tick_test_board()`、`at_counter()`、`board_ready()`、`interact_hint()`、`dev_advance` 的 `board`／`board_read`、`SPAWNS["dev_board"]`、旗標 `rb2.full_health`／`rb2.misha_met`／`rb2.pricked`／`rb2.board_done`／`rb2.first_shop_done`／`rb2.dev_spawn`）、`game_session.gd`、`data/reboot/statuses.json`、`data/quests/rb_market.json`、`data/dialogue/rb2_misha_meet.json`／`rb2_misha_deal.json`、`i18n/reboot.csv`（`SPK_MISHA`、`RB2_BOARD_HINT`、`RB2_END2_TITLE`、`DLG_RB2_MISHA_*` 十句）、測試（`test_story_market_level.gd` 多一個場景測試、流程與讀檔的測試改寫；`test_story_playthrough.gd` 的結尾延到店內；共 314 個）、`scripts/shots/rb_market_level.txt` 與 `ci.yml`（`63-rb2-board`）、README、`playtest.md`、`design/10`、`06-terminology.md`。
- **沒有驗證過的**：真人玩的時候席菈跟不跟得進門、會不會擋在門口或鏡頭前（測試裡她是停住的；截圖用的站位是寫死的）；扎針那一下諾恩的受擊反應看起來合不合理；店裡的亮度在一般螢幕上夠不夠（只看過軟體渲染的截圖）。都請 Jacky 看了（FOR_JACKY 第 2 項）。

## D-230　2026-11-12　地下市場的第一眼補完：高台西半邊有人有燈、藥店門面整片綠玻璃（遠看用顏色變濃補償）、店前的紙燈籠換成綠的；市場有自己的底噪

- 決策：
  1. **高台西半邊（鏡頭朝南時的畫面右邊）不再是空的**：欄杆前兩個背對貨梯看街的人（`WATCHERS`：位置、朝向、身高比例；有碰撞盒、不轉頭、不算在六個顧攤的人裡）、靠西牆三箱等貨梯的行李、箱子上一盞提燈（`TerraceRestLamp`）、西牆靠高台那一段多一盞掛燈（`WALL_LAMPS` 四盞 → 五盞）。位置一樣寫死，不抽 `_rng`。
  2. **藥店的門面幾乎整片是綠玻璃**：主窗 4×3 → 4×4 格、東邊多一扇 2×4 的窄窗、門與西半邊上面一排 5×2 的氣窗（壺形招牌逆著它是剪影），玻璃約 7.3 → 19 平方公尺（`shop_glass_area`，測試在驗）。窗前那盞綠光不動（D-229 的 2.4／8 m）。
  3. **遠看的補償放在窗的 shader，不放在燈**：`window_glass.gdshader` 加 `far_boost`／`far_saturate`（預設都是 0，其他的窗不受影響）——離鏡頭 10 m 以內不變，40 m 以外發光 ×(1＋far_boost)、顏色每個分量取 (1＋far_saturate) 次方（變濃）。藥店用 2.0／2.0。
  4. **藥店前面兩條繩子上的紙燈籠換成綠的**（`SHOP_PAPER`，離門面 `SHOP_PAPER_REACH`＝9 m 以內的掛燈繩）。只是發光的紙，不加燈：「彩色的燈只有三種」不變。顏色的亂數照舊先抽再蓋掉，`_rng` 的順序沒有變。
  5. **市場的環境音換成 `market_murmur`**（`gen_sfx.py` 新做，可循環 12 秒，-14 dB）：六個遠處的人聲（鋸齒波的聲帶＋一個共振峰，音節一個個起伏、句子之間停頓）疊成聽不出內容的嗡嗡聲＋岩洞低低的空氣聲＋兩道短回音＋偶爾很小的碰撞聲。以前借霜橋鎮的風（-24 dB，幾乎聽不到）。
  6. **`cave_rock.gdshader` 補保險**：細凹凸的法線在 `det` 是 0 的像素（面幾乎側對鏡頭）會算出 NaN，那些像素改用原本的面法線。畫面沒有變。
- 理由：
  - 1：第 83 輪結束時 `60`（貨梯下來的第一眼）右邊三分之一是黑的（CI 那張右三分之一的平均亮度只有 4.8）。招牌鏡頭有三分之一是空的，其他地方再怎麼修都沒用。放人比只放燈好：有人在看街，玩家的視線會跟著往街上走。
  - 2、3：從高台到門面 45 m，原本的窗在畫面上是 40 px 寬的小方塊。先只把窗變大——綠色為主的像素變成兩倍，但還是灰黃的。接著試了三種：①門面上方加一盞「幾乎不照東西、只進霧」的綠燈：從高台看數字一模一樣（45 m 外體積霧的光暈看不到），站在門口的畫面反而變亮變綠——拿掉；②只把發光加亮三倍：變白不是變綠（偏綠的程度 44 → 36；暖色的霧加上 AgX 會把很亮的顏色洗白）；③發光加亮＋顏色變濃：偏綠的程度 44 → 61，留這個。
  - 4：綠燈籠從高台幾乎看不到（街尾的燈籠在畫面上只有幾個像素），但站在街上與藥店門口看得到——頭上的燈從暖色變成綠的，知道快到了。
  - 5：整條街有十四個攤子、六個顧攤的人，卻只有風聲，畫面再好也像沒有人的佈景。人聲不用真的語音（沒有授權的問題、也不會聽出是哪一國話）。
- 影響：`underground_market.gd`（`_build_terrace`、新的 `_watcher`、`_build_shop`、`_build_ropes`、`paper_color()`、常數 `WATCHERS`／`SHOP_PANE_H`／`SHOP_WINDOW_ROWS`／`SHOP_TRANSOM_ROWS`／`SHOP_GLASS_FAR_*`／`SHOP_PAPER*`／`MURMUR_*`；`DRAFT_DB` 刪掉）、`window_glass.gdshader`、`cave_rock.gdshader`、`gen_sfx.py`、`sfx.gd`（`NAMES` 多一個）、`test_story_market_level.gd`、`test_ambience.gd`。固定鏡頭 `60`、`62` 變了（`60` 死黑 24% → 7.5%），基準等 CI 重拍。霜橋鎮沒有動（它的窗 `far_boost` 是 0）。

## D-229　2026-11-12　地下市場的畫面修一輪：岩壁換成不規則的岩面、布棚抬到頭頂上、街面換大塊石板、藥店的綠光只照窗前

- 決策：
  1. **岩壁、洞頂、高台的側面用新的 `cave_rock.gdshader`**（不再借霜橋鎮的石塊牆）：世界座標的 Voronoi 切成一大塊一大塊的岩石（寬約 1.7 m、橫向比較長），每一塊的面朝向偏一點、邊緣往外鼓、塊與塊之間是深色裂縫，上面疊細的凹凸（很斜、很遠的地方自動收掉，不閃）、黃褐的礦物色、一片片潮濕。牆是軸向的方塊，直接挑法線最大的那一軸投影，不做三向混合（軟體渲染的 CI 截圖也拍得動）。
  2. **岩面要有光才看得出來**：布棚上面的岩壁掛四盞小燈（`WALL_LAMPS`，左右交錯、不投影、深琥珀色），各照出一小圈岩面。光的原則不變（彩色還是只有三處、投影的燈沒有增加）。
  3. **布棚前緣從 2.15～2.45 m 抬到 2.75～3.05 m，而且不伸到街上**（`AWNING_FRONT_Y`／`AWNING_BACK_Y`／`AWNING_FRONT_OUT`）。攤子的燈不跟著抬高：吊在棚子前緣底下 0.6 m、移到攤桌正上方（離街心遠一點），玻璃的亮度 5.0 → 2.4。吊牌縮成 8.5×12 cm。
  4. **街面從小塊的濕石板（`wet_cobble`）換成大塊石板**（`InteriorLook.flagstone`，0.6 m、粗糙度 0.4），跟高台同一種石板。先試過把濕石板調小、倒角調淺、每塊的傾斜調小（一輪圖），還是每一塊都在反光；換成大石板之後拍同兩個鏡頭並排比，地板安靜下來、攤子與人才是主角。水窪沒有了，燈在地上是一片柔的反光。
  5. **藥店窗前的綠光 4.5／12 m → 2.4／8 m**（`SHOP_GLOW_ENERGY`／`SHOP_GLOW_RANGE`），霧裡的份量提高一點（3.0 → 4.5）：遠看的綠靠窗本身的發光與霧，不靠這盞燈照亮半條街。
  6. **高台**：門架的柱子外側掛一盞小燈（`GatePostLamp`），底下是四個木箱與一個桶（剛從貨梯卸下來的貨）。位置寫死、不抽亂數（多抽一次，後面十四個攤子的配置全部會變，跟基準就不能比了）。
- 理由：
  - 第 82 輪自己列的「第一眼最差的三樣」第一名是岩壁（暖燈一照就是一面磚牆）；走在街上最差的是右邊三分之一被一片貼著鏡頭的布擋住、藥店門口整個畫面是綠的、地板比攤子搶眼——這些是實際玩的時候一直在畫面上的東西。
  - 3：過肩鏡頭的支點 1.6 m、鏡頭約 2 m 高。布棚的垂邊最低處現在 2.3 m 以上（測試在驗）。
  - 4：小石板的問題不在參數，在「每一塊都有自己的邊、自己的反光」；塊數少一半以上，問題就不見了。水窪的倒影是代價——市場在地底，不下雨，石板潮而不積水也說得通。
- 影響：`underground_market.gd`（`_make_materials`、`_build_cave`、`_build_terrace`、`_stall`、`_build_shop`、新的 `_build_wall_lamps`；`_wet_floor()` 刪掉）、新檔 `src/world/cave_rock.gdshader`、`test_story_market_level.gd`（多 1 個測試＋原本的場景測試多驗五件事）。固定鏡頭三張都變了（`60` 死黑 31.5% → 24%、`62` 亮度 76 → 58），基準要等 CI 重拍。霜橋鎮沒有動。

## D-228　2026-11-11　地下市場 A 的第一步：新關卡 `market`、任務 `rb_market`；「待續」移到藥店門口；招牌鏡頭＝貨梯下來的第一眼

- 決策：
  1. **關卡與任務**：新關卡 id `market`（`scenes/levels/underground_market.tscn`；`underground_market.gd` 只蓋場景、`underground_market_story.gd` 管劇情，跟霜橋鎮同一個分法）。任務 `rb_market` 一次把三個階段寫進資料（`arrive`／`find_shop`／`test_board`，檢查點 `rb2_arrive`／`rb2_street`／`rb2_shop`），這一輪只做前兩個；`test_board` 的完成條件 `rb2.first_shop_done` 還沒有東西會設。**不先只寫一個階段**：任務做完會變成「完成」狀態，之後再加階段，已經玩過的存檔就卡在完成、進不了新階段。
  2. **主線有兩條之後**：`GameSession.MAIN_QUESTS`＝`[rb_main, rb_market]`，`main_quest()` 回「第一條還沒做完的」（HUD 的目標與任務標記都靠它）。`rb_main` 做完時由資料開下一條（`on_complete.start_quest`），不寫在程式裡。
  3. **舊存檔的遷移**：前十分鐘做完、但存檔裡沒有 `rb_market` 的（這一輪以前玩到「待續」的存檔），讀檔時補開——檢查點跟著變成 `rb2_arrive`，「繼續」直接到地下市場的貨梯高台。不補的話會回到霜橋鎮南街口、任務全部做完、什麼都不會發生。
  4. **貨梯**：站上去不再是「待續」，是黑一下「貨梯往下／地下市場」（沿用 `ChapterCard`，不另外做轉場）→ 換關卡。換關卡之前就存檔（進 `rb2_arrive` 的那一刻），生命、藥、工錢照存檔帶過去，不補滿。
  5. **「待續」現在在藥店門口**（卡上寫「待續／彌夏的藥店」，配樂 `RbEndMusic` 照搬）。讀 `rb2_shop` 的存檔出生在門口前 7 m，要再走過去才會黑——不會一讀檔就結束。店內做好之後再往後移。
  6. **招牌鏡頭的構圖**：貨梯在高台最北邊、只有後面兩根柱子；諾恩出生在離高台南緣 1.6 m 的地方、面向南，席菈站在斜前方。街從 40 m 縮成 28 m；最北邊兩排攤子放在坡道兩旁、高台底下；掛燈繩從高台邊就開始。
  7. **光**：暖色燈籠是主光（攤子下、繩上，都不投影）；投影的只有三盞（井口的冷光、兩盞樑下的大燈）；彩色只有三處（街底藥店的綠、詛咒物攤的紫、鐵匠的橘紅）；環境光偏冷藍。布棚、三角旗、樑下的長布用會透光的布（`awning_cloth.gdshader` 的 `BACKLIGHT`）。岩壁就是暗的大石塊牆，不做凸出來的岩塊。
- 理由：
  - 4：Jacky 要「做完一段就能從頭玩到尾」。貨梯到新關卡如果是硬切，第一眼的反差（暗巷 → 暖色市場）會被載入的那一下吃掉；一張寫著地名的黑卡把兩邊隔開。
  - 6：第一版照草稿做（貨梯四根柱子、街 40 m、攤子從街口才開始）拍出來：右邊一根柱子擋掉 15% 的畫面、整條街只佔中間一小塊、街底的綠窗只有幾個像素、畫面上半全黑。鏡頭在諾恩背後、幾乎水平，所以**近處一定要有東西**（頭上的燈籠、腳下的布棚），遠處的東西要夠大。
  - 7：第一版環境光是暖的，整張圖只有橘色一種顏色。岩塊（歪的方塊）在暖燈下一眼就是方塊，拿掉之後暗下去反而像岩壁。
- 影響：`Game.LEVELS`／`CHECKPOINT_LEVELS` 多了 `market` 與三個 `rb2_*`；截圖旗標 `--level=market --rb-at=arrive|street|shop`；固定鏡頭組 `scripts/shots/rb_market_level.txt`（`60`～`62`）與 CI 同名的三張；`FrostbridgeOpening.play_end_card()` 改成 `ride_lift()`，`END_MUSIC*` 搬到 `UndergroundMarketStory`；翻譯 key 多 9 個（`Q_RB_MARKET_TITLE`、`Q_RB2_OBJ_*`、`RB_LIFT_NUMBER`、`RB2_END_TITLE`、`DLG_RB2_RULES_*`）；`docs/design/10` 開頭記了做好的部分與跟草稿不同的地方。

## D-227　2026-11-11　舊版清理收尾：名字裡的 reboot 拿掉；存檔資料夾、`mode` 的值、`rb_*` 不改；「兩個存檔資料夾」的機制留著

- 決策：
  1. **識別字與檔名改掉**（64368c5）：`rb_frostbridge.gd`／`RebootOpening` → `frostbridge_opening.gd`／`FrostbridgeOpening`；`GameSession.new_reboot_game()`／`is_reboot()`／`load_reboot_slot()`／`has_reboot_save()`／`reboot_save_dir()`／`REBOOT_SAVE_DIR`／`REBOOT_MAIN_QUEST`／`REBOOT_CHAPTER` → `new_game()`／`in_story()`／`load_story_slot()`／`has_story_save()`／`story_save_dir()`／`STORY_SAVE_DIR`／`MAIN_QUEST`／`FIRST_CHAPTER`；`Game.new_reboot_game()`／`continue_reboot_game()`／`has_reboot_continue()` → `new_game()`／`continue_game()`／`has_continue()`；測試檔 `test_reboot_*` → `test_story_*`。
  2. **不改的（玩家的存檔與截圖基準裡有）**：存檔資料夾 `user://saves_reboot` 與 `user://saves_dev_reboot`、存檔裡 `mode` 的值 `"reboot"`（程式裡改用常數 `GameState.STORY_MODE`）、任務 `rb_main`、旗標 `rb.*`、檢查點 `rb_*`、節點名 `Rb…`、翻譯 key `RB_*` 與 `i18n/reboot.csv`、`data/reboot/`、截圖旗標 `--rb-at` 與盤點截圖的檔名。改這些要嘛讓 Jacky 試玩的存檔讀不到，要嘛白動幾百行又讓基準圖對不上。
  3. **「兩個存檔資料夾」的機制不收成一個**（上一輪的 NEXT 寫要收）。`user://saves` 是以前舊劇情的資料夾，玩家可能還有檔案在那裡；現在的規則是「劇情存檔一律寫到另一個資料夾」，有三個測試在驗（新遊戲不寫舊資料夾、舊資料夾的檔案一個字都不變、開發旗標不寫玩家的資料夾）。收成一個要刪掉或改鬆這些斷言，換來的只是少 10 行程式——不划算。`GameState.mode` 同理留著（`in_story()` 看它；預設 `"classic"`＝沒有開劇情的空鎮）。
  4. **`Undertaker.phase` 拿掉**（永遠是 1，D-225 留下的）。守衛戰的測試原本兩行 `assert_eq(g.phase, 1)`，改成驗行為：開打時下砸前兆是 1 秒、打到殘血之後招式輪替不變、下砸前兆也沒有縮短（2 個斷言變 3 個）。這是這一輪**唯一改到內容的斷言**；其他測試檔只有識別字不同（做法：改之前的測試檔套同一份 sed 對照表，跟改之後 `diff -r`——除了這裡與第 5 點的改名，只差一個參數名）。斷言 2290 行 → 2291 行（多的就是這裡的一行）、測試 307 個不變。64368c5 的 commit 訊息寫「斷言 2290 行前後一樣」是改 `phase` 之前數的，差這一行。
  5. **順手改名**：`struggle_mode` → `no_charge`（它的意思是「輪替裡沒有衝撞」，追擊的那一隻與守衛都是 true，跟已經刪掉的「掙脫」無關）、`begin_struggle()` → `begin_pursuit()`、`tuning.json` 的 `pattern_struggle`／`struggle_stagger_max` → `pattern_pursuit`／`pursuit_stagger_max`。
  6. **沒人用的東西刪掉**（8636a03）：`half_timber.gdshader` 的 `arch_*`（拱圈的放射縫，D-132）、`glow_*`（石縫冷光，D-043）、`obj_pos`／`obj_normal`——都是舊劇情「重現的石拱」用的，現在沒有材質會設；`Hud.override_objective()`／`objective_overridden()`（D-169，沒有人呼叫）。
  7. **設計文件收成三份、檔名不變**：`02-gameplay.md`（操作與戰鬥）、`04-architecture.md`（架構＋原本 `docs/technical-direction.md` 的技術決定，後者刪掉）、`06-terminology.md`（用詞）都重寫成只講現在的劇情；`03-art-audio-direction.md` 只刪掉講「重現」、燃燒劍、日記的行。檔名不變是因為有 24 處程式註解指到它們——改檔名就要再動一次程式檔，沒有好處。
- 理由：Jacky 11/11：「舊版本的東西可以全部砍掉，包括 code 和 README……現在這樣太亂我有點看不懂」。名字裡的「reboot／新版」暗示還有另一個版本，是最後一個會讓人以為「還有舊版」的地方。
- 影響：舊版清理（D-220 起的三步）全部做完，NEXT 的「000」節拿掉；`docs/NEXT.md` 66 KB → 41 KB（各輪「做好的」識別字清單收成一張「現在有哪些東西、在哪個檔」的表）。畫面沒有變：動到 shader 的那個 commit，固定鏡頭 `40-rb-start`、`45-rb-guardian`、廣場（`--at=plaza`）改前改後差異都是 0.0%。

## D-226　2026-11-11　北街的房子併進整個鎮的合併 mesh；藏起來的破屋頂刪掉，樓上亮著的窗因此換了位置

- 決策：
  1. **北街的房子不再每棟一個節點**。原本為了舊劇情的「陷落」，北街兩排房子各自一個 `NorthHouseN` 節點、各自的 mesh，屋頂另外放一個 batch，還多蓋一份永遠 `visible = false` 的破屋頂（`_roof_ruin`，約 130 行）。陷落的流程第 77 輪就刪了，這些只是多出來的節點與 draw call。現在跟其他房子一樣進 `StaticBatch`；`_roof_ruin`／`RUIN_SNOW_H`／`_ruin_hash`／`_slope_frame`、`StoryLevel._north_houses`、只有破屋頂在用的 `RoofMesh.slab` 都刪掉。
  2. **北街跟其他街道的兩個差別照舊**：煙囪不冒煙、門口不掛招牌（參數從 `collapsible` 改名 `quiet`）。原因已經不存在（會陷落的屋頂上不放煙），但拿掉會改變開場第一個畫面（多幾道煙、多幾塊招牌，還會把別條街的冒煙名額用掉——最多 8 根），那是「改畫面」不是「清理」，要改就另外做、另外拍圖。
  3. **接受一個小的畫面變化**：樓上的窗亮不亮、門的色差、窗簾，是用「位置」算雜湊決定的。以前北街的房子用自己的座標（每棟都從 0 起算），現在用整個鎮的座標（跟其他街道一致），所以北街樓上亮著的窗換了幾扇。一樓的窗（用 `_rng`，會打燈的那些）沒有變，燈的數量也沒變。
- 理由：Jacky 11/11 說舊版全部砍掉（D-220）。不想為了「跟改之前一模一樣」而特地保留一套每棟房子自己的座標。
- 影響：`frostbridge.gd` 少約 165 行。固定鏡頭（同一台機器、軟體 Vulkan，改前＝`b2f4567`、改後＝`7f796e0`）：`40-rb-start` 差異 0.5%、北街遠景（`--at=north`）0.1%，亮度、過曝、死黑的數字沒有變；不同的像素都在兩排房子的二樓以上。看了一張裁切的對照圖：屋頂、牆、門、門邊的燈都一樣，左邊那棟樓上多了一扇亮窗、右邊那棟亮著的窗換了位置——不好也不壞。CI 的 `screens` 下一次會跟著換，之後拿 `40-rb-start` 當基準要用 `7f796e0` 以後的。測試 308 → 307。

## D-225　2026-11-11　送葬者只留新劇情用到的四招；第二階段、抓取、連續下砸刪掉，「連段」與「讀不懂的招」的機制留著

- 決策：
  1. **刪掉**：送葬者的第二階段整條線（`enter_phase_two()`、第二階段輪替、優先追車隊、鐵架拋擲的觸發與 `slice.frame_thrown` 旗標、扯斷右邊鐵鏈）、抓取（`_grab()`／`_guard_for()`、地面的小扇形）、連續下砸（`double_slam`／`double_slam_2`、「諾恩近處沒挨打看過一次才算已證實」的判定）、三個沒人接的訊號。諾恩那一側「被抓住、連按掙脫」的整套（`begin_grab()`／`struggle_press()`／`release_grab()`）、沒有人設的 `held_in_place`、戰鬥 HUD 的掙脫提示與三行翻譯。數值表與看穿資料裡對應的條目。
  2. **抓取與連續下砸不留骨架**（第 79 輪留下來要決定的事）。`story-v2.md` 第一、二章沒有「被抓住掙脫」的頭目；留著等於 300 多行沒人跑的程式，還讓諾恩的 `_physics_process` 多一條分支。之後真的要用，從 git 歷史（`b2f4567` 的上一個 commit）拿回來，比現在留著一份沒人驗證的好。
  3. **`EnemyBrain` 的「連段」（招式資料的 `chain`）、「讀不懂的招」（`unreadable`）、`intel_move()` 留著**，`EnemyIntel` 的 `hidden` 也留著。這幾個是引擎層的通用機制，一共不到 30 行；`hidden` 現在就有人用（南街守衛的噴毒），連段與讀不懂的招之後的頭目用得到。但遊戲資料裡目前沒有招式用到連段——所以測試改成用檔內的小招式表驗（`test_enemy.gd` 的 `_chain_brain()`），不靠遊戲資料，跟第 79 輪對話系統的做法一樣。
  4. **`Undertaker.phase` 留著，永遠是 1**。它已經沒有意義，但 `test_reboot_guardian.gd` 有兩行在驗它（「打到殘血也不會進第二階段」），而新劇情的測試這幾輪的規矩是一個字都不改。第 3 步改名字的時候（那一輪本來就要動這些測試檔裡的識別字）一起拿掉，並把那兩行換成驗「輪替與下砸前兆不變」。`struggle_mode` 同理：現在只是「用哪一套輪替」的記號。
  5. **`Caravan`（推車）這一輪不動**。它是新劇情的推車（`RbCart`），「被打到會停下、多一名傷者」與席菈「站在傷者旁邊不肯閃開」不是舊劇情專用的。只剩檔頭註解還提到第二階段，第 3 步順手改。
- 理由：Jacky 11/11 說舊版全部砍掉（D-220）。新劇情用到送葬者的地方只有兩個：追擊的那一隻（橫掃＋下砸、舉燈柱）與南街守衛（再加噴毒）。
- 影響：`game/` 淨少約 490 行（刪 603、加 112，加的大部分是改寫的測試）。測試 315 → 308：第二階段專用的 10 個刪掉；新增 3 個（連段、讀不懂的招、「守衛的噴毒在看穿裡出現過才列」——原本靠第二階段的測試順便驗 `hidden`，現在單獨驗）。新劇情的 13 個測試檔 `git diff` 是空的（70 個函式）。畫面：刪掉的都是不會出現的東西（抓取的扇形只在出那一招的前兆才顯示），沒有拍圖。音效：`rubble_scrape`、`iron_clang` 刪完之後還有人播（藥桶、燈柱、跪地、倒地），18 個都留著。

## D-224　2026-11-11　v3 以前的存檔不再遷移，讀到回「太舊」；燃燒劍、油燈、夾板、木樁與 7 個音效刪掉

- 決策：
  1. **`SaveCodec` 新增 `Status.TOO_OLD` 與 `MIN_VERSION`＝3**。v0～v2 的存檔（已經刪掉的舊劇情：切片、第 1～3 章）不遷移、不刪檔、不覆寫，讀到就回 `TOO_OLD`，呼叫端跟「沒有存檔」一樣處理（`GameSession.load_slot()` 回傳非 OK、狀態不換）。遷移的骨架（`migrate()`／`_migrate_step()`）留著，下一次改格式（v3 → v4）照舊加一段。
  2. **`GameState.memories_paid`（記憶代價）與 `guide`（攻略筆記）刪掉，不升存檔版本**。v3 存檔裡這兩個 key 的值一定是空的（新劇情從來沒寫過），`from_dict` 不讀它們、再存一次就沒有了。`StoryLogic` 的 `memory_paid` 條件一起刪：資料裡再出現會被 `validate_condition` 擋下來（不會默默當成不成立）。
  3. **`GameState.mode` 的預設值 `"classic"` 這一輪不動**：舊劇情留在 `user://saves` 的 v3 存檔靠它跟新劇情分開，標題的「繼續」不認它（`test_title_entry`、`test_reboot_session` 在驗）。第 3 步跟「兩個存檔資料夾」一起收。
  4. **角色身上只有舊劇情用到的刪掉**：諾恩的油燈（`ch1.lamp_received`）與夾板（`slice.sheila_talked`，連 `Puppet.set_splint()`）、席菈的燃燒劍（`ignite_sword()`／`burn_strike()`／劍上的 `FireLight` 與 `FireSparks`）、`dash_to_point()`、`face_toward()`、`facing_yaw()`；送葬者四個沒人呼叫的函式。木樁照 D-223 刪掉。
  5. **音效再刪 7 個**：D-223 留下的 6 個（`bell`、`bell_ninth`、`daylight_ambience`、`canal_ambience`、`frost_wind_indoor`、`hearth_crackle`）加上只有燃燒劍在播的 `ignite`。`gen_sfx.py` 的 `bell()` 合成函式留著（標題與「待續」的配樂裡遠遠的鐘在用）。`Ambience.play_at()`（有位置的循環環境音）現在沒有人用，但地下市場的火盆、滴水會用到，留著，測試改拿 `frost_wind` 驗。
  6. **對話系統的測試不再靠遊戲裡的舊對話**：遊戲資料用 `rb_sheila_meet` 驗；目前劇情還沒用到的功能（選項的 `if`、`text_if`）用測試檔裡的小對話驗——功能留著（之後的章節會用），驗證的強度不變。
- 理由：Jacky 11/11 說舊版全部砍掉（D-220）。舊存檔對應的章節已經不存在，遷移進來也沒有地方可以繼續玩；留著遷移程式只是讓「存檔格式」看起來比實際複雜。不刪檔是因為那是玩家的檔案，我們只是不讀。
- 影響：`game/` 與 `scripts/` 這一輪淨少約 820 行（刪 1048、加 225，加的大部分是改寫的測試）；音效 25 → 18 個；測試 317 → 315 個（少的兩個是「付出記憶讓選項消失」併進新的條件測試、燃燒劍的火星）。新劇情的 70 個測試一個字都沒動。畫面：刪掉的節點本來就看不見（火光 `visible = false`、火星 `emitting = false`、夾板與油燈的旗標沒有人設），沒有拍圖。

## D-223　2026-11-11　灰巡者留著當「一般的敵人」、木樁刪掉；沒有人播的 12 個音效先刪

- 決策：
  1. **灰巡者（`Ashwalker`）留著**。它已經沒有任何關卡會生成，但它是目前唯一的「一般敵人」：10 個測試檔拿它驗證鎖定、看弱點、戰鬥 HUD、鏡頭、同伴指令；`story-v2.md` 第 2 章（乾運河「不同敵人」）與後面的「物理攻擊部隊」都需要小兵。到時候改名、換外觀與招式沿用這個骨架，比現在刪掉、把 10 個測試檔改成拿送葬者（480 生命、會噴毒的頭目）當靶再重做一次划算。地下市場 A 沒有戰鬥（`docs/design/10-reboot-underground-market.md`），所以最近幾輪不會碰它。
  2. **木樁（`TrainingDummy`）刪掉**（下一輪做）：只有 `test_combat.gd` 在用，開發沙盒第 77 輪就刪了。
  3. **音效分兩批**：這一輪先刪「整個 `game/` 找不到任何地方提到名字」的 12 個——`water_splash`、`child_laugh`、`brace_creak`、`slap`、`deep_rumble`、`cloth_knock`、`chain_creak`、`stair_ambience`（第 1～3 章）、`aftermath_theme`、`after_dinner_theme`、`bell_far`（舊收束與第 2 章）、`heartbeat`（重現的心跳）；`gen_sfx.py` 裡它們專用的產生函式一起刪。**只有測試還提到的 6 個**（`bell`、`bell_ninth`、`daylight_ambience`、`canal_ambience`、`frost_wind_indoor`、`hearth_crackle`）下一輪連同測試裡的例子一起換掉再刪。腳步聲 `step_snow`／`step_stone`／`step_wood`／`step_heavy` 是用字串拼出名字的，在用，不刪。
- 理由：Jacky 說的是「除非有東西要在新版本沿用」——灰巡者的 AI 骨架與那 10 個測試是會沿用的；木樁與那些音效不是。音效分兩批是因為第一批完全不用動測試，風險最低。
- 影響：音效 37 → 25 個（每次建置少產生 12 個 wav，安裝檔小一點）。`data/combat/intel.json` 裡灰巡者的說明文字還是舊劇情的口吻，做運河時重寫。

## D-222　2026-11-11　南街的斷拱改成單純的場景物件；「重現」整套與日記資料刪掉

- 決策（接 D-220 第 2 步的後半）：
  1. **南街的斷拱＝`frostbridge.gd` 的 `_build_south_arch()`**：節點名照舊 `SouthArch`（底下 `Ruin`：`Stump0`／`Stump1` 兩截有碰撞的斷柱＋`Rubble0`～`Rubble6`）。形狀、位置、亂數種子（7）跟原本停用的 `NineBreathSite` 畫出來的廢墟一塊不差，還是 `CSGBox3D`——目的是南街的固定鏡頭一個像素都不變，不是趁機改造型。`StoryLevel.arch_site` 改名 `south_arch`（`Node3D`，沒有腳本）。
  2. **「重現」整套刪掉**：`NineBreathSite`、`NineBreath`、`RestorePrompt`（HUD 的重現提示）、`RestoreMix`（重現期間的低通與壓低配樂）、`restore_ghost.gdshader`、輸入動作 `nine_breath`（V／手把 Y）與按鍵設定裡那一列、翻譯 `ACT_NINE_BREATH`／`NB_*`、音訊匯流排 `Heart`（只給重現的心跳用）與 `Settings.MIRROR_VOLUME`、`Sfx.HEART_BUS`、`InteractPrompt.avoid`（互動提示讓位給重現提示的邏輯）。
  3. **日記的資料與類別刪掉**：`Journal`、`data/journal/slice.json`、`Game.journal`。日記畫面第 77 輪就刪了，剩下的唯一使用者是重現的預覽。
  4. **舊設定檔不用遷移**：玩家的 `settings.cfg` 裡如果還留著 `nine_breath` 的按鍵，`InputSetup.from_saved()` 只看現有的動作，多的那一筆直接略過（有測試）。V 與手把 Y 現在是空的，之後新能力要用可以直接拿。
  5. **GlyphLine／InteractPrompt 的測試改用新劇情的字串**（`RB_CRATE_HINT`「按 {key}　拿走藥瓶」＋`interact`），不再靠舊劇情的 `NB_HOLD_HINT`、`RESCUE_HOLD_HINT`。
- **沒有**動、留給之後的：`GameState.memories_paid`／`pay_memory()` 與 `SaveCodec` 的 v0～v2 遷移（動到存檔格式，單獨一步做）；只有測試還提到的六個音效（見 D-223）；石牆 shader 裡給拱石用的 `arch_*` 參數（預設值不作用，跟鎮上的牆共用同一支 shader，改它要重拍全鎮，不值得）；`slice.csv` 裡 `JOURNAL_*` 幾行（第 4 項整個檔一起處理）。
- 理由：新劇情的能力是「負面狀態反轉」，沒有代價、沒有記憶、沒有日記（`story-v2.md`、`status-reversal.md`）；「重現」留在程式裡只會讓人以為 V 鍵還有用。斷拱本身是南街守衛戰的場景（守衛從拱後面走出來、吊燈掛在它南邊），要留。
- 影響：`game/` 少約 1,900 行；測試數的變化寫在 PROGRESS 第 78 輪。畫面：南街兩個固定鏡頭（`45-rb-guardian`、`49-rb-potion`）改前改後的差異寫在同一則。

## D-221　2026-11-11　舊版清理第 2 步的切法：入口只剩一種、霜橋鎮的關卡檔只蓋鎮、過場與成就系統整套刪；開發旗標的存檔另外放

- 決策（接 D-220 的第 2 步，這一輪做了前半）：
  1. **入口只剩一種**：`GameSession.new_game()`（舊劇情）、`MAIN_QUEST`／`MAIN_QUESTS`、`is_slice_complete()`，以及 `Game.new_game()`／`continue_game()`／`has_continue()` 刪掉；`main_quest()` 固定回傳 `rb_main`；倒下重來沒有存檔時一律重開這個劇情。
  2. **`frostbridge.gd` 只蓋鎮**：梨販、敲鐘、北街陷落與救援、席菈會合、灰巡者、車隊戰、石拱回憶、收束、地窖木板、攤子後面的剪影，以及它們的開發旗標（`--convoy`、`--rescue`、`--arch`、`--throw`、`--felled`、`--phase2`、`--insight`）全部拿掉。`StoryLevel` 只剩地面高度與腳步聲材質。劇情全部在 `RebootOpening`。
  3. **沒有開新遊戲的 session ＝ 只有鎮**：`frostbridge.gd` 只在 `Game.session.is_reboot()` 時掛 `RebootOpening`。benchmark 與「只看鎮」的測試（`test_frostbridge.gd`）用這個狀態，不會被開場對話、推車、送葬者干擾。
  4. **過場系統整套刪**（`CutsceneRunner`、`CutsceneView`、`RingTally`、`data/cutscenes/`、`Game.play_cutscene()` 等）：只有敲鐘在用，新劇情沒有過場。之後真的需要再做新的，不留一套沒人用的。
  5. **成就系統整套刪**（`AchievementTracker`、`AchievementToast`、`SteamBridge`、`data/achievements.json`、`ACH_*` 翻譯、成就圖示與 Steam 膠囊圖的腳本與 CI 步驟）：八個成就的條件全是舊劇情的旗標（敲九下、救三人、車隊通過…），新劇情一個都解不到。Steam 暫緩（Jacky 11/10）；之後要做成就，照新劇情重新訂條件，接 Steam 的那一層到時候再寫。
  5b. **一起刪的**：開發沙盒（`scenes/dev/`，只有舊流程的測試在用）、`RescueSite`、`CoalPile`、`ConvoyEncounter`、`ThrownFrame`、`FrameThrowEvent`、`JournalView`、Steam 商店截圖腳本（`store-shots.*`、`store_shots.txt`、`check_store_shots.py`，拍的全是舊劇情的畫面）。
  6. **開發旗標的存檔另外放**：`--level=frostbridge [--rb-at=…]` 開的遊戲寫到 `user://saves_dev_reboot`（`Game.DEV_SAVE_DIR`），不碰 `user://saves_reboot`；`--benchmark` 不開新遊戲、不寫任何存檔。
  7. **`--level=frostbridge` 不帶 `--rb-at`＝從開場開始的新遊戲**；要拍鎮本身就用 `--rb-at=market --at=plaza|main|steps…`（守衛打完之後、安靜的鎮）。`--at`／`--pos`／`--face`／`--hide` 改成在劇情擺好場面之後才套用。
  8. Tab／手把 Back 的功能本來就只剩「再看一次目前的目標」（日記畫面刪了）：按鍵設定裡的名字從「日記」改成「看目前的目標」。動作的內部名稱 `journal` 第 3 步再改。
- 這一輪**沒有**刪、留到下一輪的（都已經沒有入口，玩家碰不到）：南街石拱還是停用的 `NineBreathSite`（要先換成單純的場景物件，不然南街的畫面會變）、`NineBreath`／`RestorePrompt`／`RestoreMix`、`Journal` 與日記資料、灰巡者、送葬者與席菈身上車隊戰專用的招式、舊的對話／任務／翻譯資料、北街房子的「陷落後破屋頂」。清單在 NEXT「000」。
- 理由：第 6 點是這次改動帶出來的——以前 `--level=frostbridge` 開的是舊劇情、寫到舊資料夾；入口統一之後它會寫到玩家真正的存檔。Jacky 照 playtest.md 用 `--rb-at=…` 跳段落或跑 benchmark 時，不應該把自己玩到一半的進度蓋掉。第 3 點讓「鎮的測試」不用跟著劇情每次改動而壞。
- 影響：測試 409 → 344 個（少掉的是被刪內容自己的測試；新劇情的 69 個測試一個沒少，其中 2 個「舊版沒有某某」改成「沒有開新遊戲時沒有某某」，另外加 1 個「開發旗標不會寫到玩家的存檔」）。`game/` 再少約 5,500 行。CI 的截圖少 `bell.png`、`combat.png`、`ninebreath.png`、`street.png` 與盤點的 `04`、`06`～`09`、`11`；`02`、`03`、`05`、`10` 改成拍新劇情裡的鎮；「latest」不再附 Steam 膠囊圖與成就圖示。

## D-220　2026-11-11　舊版全部刪掉（Jacky 11/11 的指示），分三步做，每一步 main 都是綠的

- 決策：照 Jacky 在 FOR_JACKY 回覆區 11/11 寫的「舊版本的東西可以全部砍掉，包括 code 和 README 內的，除非有東西要在新版本沿用」，把舊劇情（霜橋鎮敲鐘、「重現」與記憶代價、第 1～3 章）從 repo 移除。這一則取代排程提示裡「舊劇情凍結、程式與資產保留、舊存檔不壞」那一條，也取代 D-211 的「舊版」選項。
- 分三步（每一步各自 `check.sh` 全綠才 push）：
  1. **第 76 輪（做完）**：標題拿掉「舊版」選項；刪掉第 1～3 章（酒館、一百七十二階、白晝城、鐘院、乾運河五個關卡，連同只有它們用的程式、shader、對話、任務、過場、翻譯、測試、CI 截圖）與攻略筆記、白天版的霜橋鎮；README 與試玩指南改成只講新版；純舊劇情的設計文件刪 6 份（`design/00`、`01`、`05`、`07`、`08`、`vertical-slice.md`）。
  2. **下一步**：刪掉舊切片的流程（梨販、敲鐘、北街救援、灰巡者、車隊戰、石拱「重現」、日記與記憶代價、舊成就、舊的收束），`frostbridge.gd` 只留「蓋出霜橋鎮」，流程全部在 `RebootOpening`；`GameSession` 的新遊戲／繼續只剩一種，不再分 classic／reboot。
  3. **最後**：把名字裡的 `rb_`／`reboot`／「新版」拿掉（它就是唯一的版本），刪掉舊的設計文件、Steam 素材腳本、用不到的音效，NEXT 與 PLAN 重寫成只有現在的東西。
- 保留的：新版有在用的一律留（霜橋鎮的場景與材質、送葬者、席菈、推車、戰鬥、HUD、對話與任務系統、存檔、設定、手把）；原作小說 `docs/story/`（排程提示明寫不要動，也不是程式）；Jacky 交付的美術與試作紀錄（`art-inbox/`、`docs/art-trials/`、`docs/ART_*.md`）。
- 舊存檔：舊版的存檔不會再被讀取（標題的「繼續」只看 `user://saves_reboot`）；檔案留在玩家電腦上不會被刪。
- 理由：Jacky 說現在太亂、看不懂，連怎麼開始玩新版都不知道。兩套劇情並存讓每個檔案都要分「新版／舊版」兩條路；舊內容都在 git 歷史裡（`f7a3b50` 以前），要看隨時找得回來。
- 影響：測試從 497 個變成 409 個（少掉的都是被刪內容自己的測試）；CI 的盤點截圖少 29 張（一次 CI 少拍約半小時）；`game/` 少了約 1.7 萬行。

## D-219　2026-11-11　「待續」那張卡接上現有的收尾配樂

- 決策：`RebootOpening.play_end_card()` 在卡出來時播 `part_end_theme`（`Ambience.music`，節點 `RbEndMusic`、Music 匯流排、-14 dB、2.5 秒淡入、循環）；回標題時跟著關卡一起釋放。
- 理由：站上貨梯之後畫面黑掉、只有兩行字，沒有任何聲音（第 72 輪起一直列在缺點裡）。先用現有的程式生成配樂，不另外做一段：新版還會往後接地下市場，「待續」的位置會往後移，到時候再決定要不要專屬的曲子。
- 影響：測試加在 `test_reboot_market.gd`（卡出來之前不播、只有一個播放器、從小聲進來）。之後把「待續」往後移時，這一行跟著 `play_end_card()` 走，不用改。

## D-218　2026-11-11　下砸打在地上要看得見：雪塵、碎石、砸痕，上身往前壓

- 決策：送葬者（含南街守衛）的下砸在出招那一刻呼叫 `Undertaker._slam_fx(center, radius)`，在落點留一組 `SlamFx`（掛在關卡上）：`Ring`＝84 顆從落點邊緣貼地往外推的雪塵（`radial_accel`＋只在前四分之一用力的曲線，靠阻力停在傷害半徑外緣）、`Plume`＝中間往上湧的一團（32 顆、每顆很淡）、`Chunks`＝28 顆有稜角的小石塊（低面數的球、最大約 16 cm、吃場景的光）、`Scar`＝貼地的砸痕（`slam_scar.gdshader`：中間一塊砸碎的暗色、九道長短不一的裂縫、外圈斷斷續續的霜粉；吃場景的光）。砸痕留 5 秒、2 秒淡掉，整組自己收掉。
- 決策：雪塵用吃光＋透光的材質（`slam_dust_material()`：`ParticleLook` 的柔邊圓點改成 per-pixel 受光、`backlight` 0.7），不用不受光的白點。
- 決策：出招與收招的上身姿勢 `slam_follow_lean()`：砸下去那一下往前壓 26 度，收招期間用 smoothstep 直起來。
- 理由：下砸是牠最重的一招（40 傷害），但之前只有一聲悶響與鏡頭震動，地上什麼都沒發生；而且前兆的後仰一結束上身就瞬間彈回直立，砸下去的那一刻牠反而站得直直的。砸痕留在地上幾秒，玩家退開之後還看得到「剛才那一下打在哪」。
- 理由（材質）：南街現在是暖燈逆光（D-216），不受光的冷白圓點在暖霧前面像貼上去的；受光之後暖燈下偏暖、暗處是暗的。第一版石塊用方塊，放大之後像一口飛起來的木箱；第一版中間那一團只有 22 顆、每顆很實，擋在牠身體前面像泡泡——改成很多顆很淡的。
- 影響：舊版的送葬者（切片、掙脫戰）出下砸也會有，數值與判定沒動。截圖旗標 `--rb-at=slam`（`debug_hold_slam`，每 26 個物理幀重砸一次）＋固定鏡頭與 CI 的 `55-rb-slam`（粒子每次不一樣，只給人看）。測試 `tests/unit/test_slam_fx.gd`（5 個）＋`test_reboot_guardian.gd::test_live_slam_scars_the_street_and_misses_noen_who_backed_off`。

## D-217　2026-11-11　打中敵人要有東西飛出來：霜屑、弱點的火星、一下閃光、命中點的亮斑

- 決策：`EnemyActor._on_damaged` 每次扣到血都呼叫 `_hit_fx(info)`：命中點（朝攻擊者那一側、胸口高度；`hit_point()`，體型用 `_hit_radius()`／`_hit_height()` 覆寫）噴一把冷白的霜屑（`Chips`，往攻擊者那邊斜上飛、往下掉），打中弱點（鐵件）再多一把橘色火星（`Sparks`）；同一點一盞 0.14 秒的閃光（`Flash`，一般冷白、弱點偏暖），和一片 0.12 秒放大淡掉的加法亮斑（`Pop`，不做深度測試）。
- 決策：整組掛在敵人的上一層（關卡），0.64 秒後自己收掉；持續扣血（中毒那一類走 `status_damaged`）不噴；倒下之後打不到也不噴。
- 理由：第 73 輪看守衛戰的結論是「打中牠沒有東西飛出來」——命中只有聲音、頓一下、鏡頭晃。牠們是霜裡的東西，飛出來的用霜屑（冷白）不用血；火星留給鐵件（弱點），看得出這一下比較重。只有小亮點時在 1600 px 的畫面上只是幾顆點，所以加了亮斑。
- 影響：所有 `EnemyActor`（灰巡者、送葬者、守衛）都有；席菈打中也會噴。截圖旗標 `--rb-at=hit`（每 14 個物理幀重打一次弱點，`debug_hold_hit`）＋固定鏡頭與 CI 的 `54-rb-hit`（粒子每次不一樣，只給人看）。測試 `tests/unit/test_hit_fx.gd`（3 個）。

## D-216　2026-11-11　南街的吊燈：守衛背後的暖霧與逆光（牠變成亮背景前的黑剪影）

- 決策：新版在南街 z＝23.6 掛一盞大燈（`RebootOpening._build_south_lantern()`，節點 `RbSouthLantern`）：鐵鏈從西牆拉到東牆（釘在二樓、高 5.4 m，8 段直鏈接成下垂的弧）、中間吊一盞燈（燈底 4.0 m，牠連鐵架 3.2 m 從底下走得過去）。暖光、能量 5、範圍 13.5 m、體積霧亮度 3.2、**投影子**；燈後面那一段多一團橢球形的霧（`Haze`，密度 0.05、邊緣淡出）。
- 理由：`45-rb-guardian` 裡牠整個是暗藍綠色，跟背後的藍霧同一個明度，輪廓不見（第 73 輪的結論，守衛戰最大的問題）。牠從南端走過來、站定開打的位置（z 17.5）都在燈的北邊，所以從諾恩這邊看牠永遠背光：背景是暖霧與燈，牠是深色的剪影，兜帽的兩點霜光與胸口的綠管子在暗的身體上更跳。
- 決策：用暖光不用冷光——街上本來就是「暖燈＋藍夜」，暖霧跟牠的冷光、毒霧的綠分得開；光源本身（燈）要在畫面裡，所以掛高到從 8 m 外看在牠頭頂上方。
- 決策：這一盞投影（麵包店門燈 D-207 不投影的理由是太貴）：它是守衛戰的主光，牠的影子往諾恩這邊拉長是畫面的一部分。實機效能如果不夠，先關這一盞的影子。（這一輪的固定鏡頭裡，牠腳前的地面被諾恩擋住，影子有沒有真的拉過來還沒在圖上確認——下一輪讓牠動起來時看。）
- 影響：只在新版（舊版的南街照舊，有測試）。`45`～`47`、`49`、`50` 的基準要換成這一輪 CI 拍的。測試 `tests/flow/test_reboot_south_lantern.gd`（2 個：鏈子兩端真的在牆上、一段接一段、燈比牠高、位置在牠出場的路上；舊版沒有）。

## D-215　2026-11-11　下一段（地下市場）的範圍與做法：另開新關卡、先做 A（貨梯 → 攤販街 → 彌夏的測試板）、當招牌場景做

- 決策：story-v2 第二章切成 A／B／C 三段（`docs/design/10-reboot-underground-market.md`），一次只做一段；A 沒有戰鬥（走路、看攤子、一段對話、按住測試板），做完把「待續」卡移到 A 的最後。
- 決策：**另開新關卡 `rb_market`，不沿用舊版的 `daylight`**——那一關是「沒有影子的白城」，氣氛跟「擠、暖、有顏色的黑市」相反，而且石碑、柯德家是舊劇情的東西；只搬它的做法（穹頂燈的 MultiMesh、細節合併 draw call）。
- 決策：地下市場當「招牌場景」的候選——前十分鐘是暗巷與霧，這裡是第一個亮、暖、擠的地方，反差最大。先把從貨梯走出來的第一眼（固定鏡頭 `60-rb2-arrive`）做到滿意，再擴充。
- 決策：測試板在滿血時自己要有回饋（指針＋綠燈），而且滿血進店時彌夏先用採樣針扎一下（直接傷害 3 點）再測——滿血時 `Health.heal` 補不到東西，D-213 的綠色段與光點不會出現。
- 這是草稿：動手的那一輪可以改，改了更新 design/10。先後順序仍是「守衛戰的輪廓與打擊感 → 地下市場」（NEXT「00」）。

## D-214　2026-11-11　貨梯底下＝打開的井口（石框、黑的洞、底下的暖光、兩片掀開的木門）；新版不蓋舊版那塊關著的木板

- 決策：第 72 輪的貨梯吊在一塊貼地的木板上方，看不出「這是往下的」。新版把地窖口換成打開的井口（`RebootOpening._build_shaft_mouth()`，全部程式生成）：一圈 26 cm 高的石框（切成幾塊、高低差一點；兩根柱子就立在東西兩條短框上）、框裡一塊不受光的黑面 `ShaftDark`（比貨板大一圈，四周各露 20 cm）、洞裡一盞往上照的暖光 `ShaftGlow`（能量 2.8、範圍 2.7 m、不投影、`light_specular` 0）、兩片掀開的木門（北邊 `HatchNorth` 立著往後靠、南邊 `HatchSouth` 整片翻開躺在雪上；門板＝底板＋三條木條＋兩條鐵帶＋拉環）、橫樑／石框／最大那口木箱上的積雪。
- 決策：`frostbridge.gd` 的 `_build_cellar_hatch()`（那塊關著的木板）新版不蓋（`is_reboot()` 時跳過）；舊版照舊。
- 理由：地面是一整片碰撞與網格，挖不了洞——用「石框的高度＋不受光的黑面＋框內側的暖光」讓它讀成往下的洞。暖光打在立著的那片門板與石框內側，從梨攤走過去第一眼就看得到「底下有光」。
- 已知的限制：固定鏡頭 `52-rb-lift`（諾恩背後、離 5 m）鏡頭很低，南邊的石框剛好擋住黑的洞，**看得到的是石框、暖光、門板、積雪，看不到洞本身**；要看到洞得走到框邊往下看。石框、門板、柱子都沒有碰撞（站得上去才算到貨梯；`test_lift_stands_over_an_open_shaft` 檢查整座吊架沒有 `CollisionObject3D`）。
- 影響：`RebootOpening.SHAFT_HALF`／`SHAFT_CURB_H`／`SHAFT_CURB_T`／`SHAFT_GLOW_ENERGY`、`_hatch_leaf()`。測試 `test_reboot_market.gd::test_lift_stands_over_an_open_shaft`。

## D-213　2026-11-11　回血要看得見：身邊往上飄的綠色光點、喝藥那一下的一小團、生命條的綠色段與紅色段

- 決策（光點）：`HealMotes`（`src/world/heal_motes.gd`，掛在諾恩底下、聽 `Health.healed`）。**任何來源的回血都會亮**（毒霧、守衛噴的毒、自己帶的毒劑）：最後一次回血後 0.45 秒內，身體周圍一圈冒出淡綠光點慢慢往上飄（常駐粒子 18 顆、world 座標——人走開光點留在原地、加法混色的圓點、淡入淡出）；停止回血就收掉。滿血時沒有實際補到東西（`Health.heal` 回傳 0、不發訊號）所以不亮。
- 決策（喝藥那一下）：`PlayerController.use_potion()` 回傳 `used` 時 `heal_fx.burst()`——胸口一小團 30 顆光點往上散開（一次性粒子，照 D-208 先建好、擺好位置才開始噴）＋一下 0.9 秒的綠光（能量 1.3、範圍 2.8 m、不投影、`light_specular` 0：濕石板上不多一顆亮點）。
- 決策（生命條）：`BarTrail`（`src/ui/bar_trail.gd`，純邏輯）。回血時剛長出來的那一段畫成綠色、前緣一條更亮的細線（落後線用 2.5 秒的時間常數追上來；回得很慢時也至少 6 px 寬；停止回血就併回原色）。被打時剛扣掉的那一段先留成紅色，停 0.35 秒再縮回去。只有諾恩的生命條用（席菈的之後要再加）。讀檔、換場景的第一幀直接對齊，不演「從 0 回上來」。
- 理由：這個遊戲的賣點是「中毒卻回血」，但之前回血只有一個小圖示和慢慢變長的生命條——玩家眼睛在角色身上時看不出來。design/09 第 6 節「回血時是綠色往上的段、直接傷害是紅色往下的段」一直沒做。
- 影響：`PlayerController.heal_fx`；`CombatHud.noen_trail`、`COL_HEAL`／`COL_HEAL_TIP`／`COL_LOSS`、`_bar_span()`。沒有新的玩家文字。測試 `tests/unit/test_heal_feedback.gd`（6 個）。固定鏡頭 `50-rb-drank`、`41-rb-mist` 會看到光點與綠色段。

## D-212　2026-11-11　新版前十分鐘的一條龍流程測試：中間重來兩次、重來之後直接接著走完

- 決策：`tests/flow/test_reboot_playthrough.gd`（2 個測試）。①從標題按「新遊戲」（`boot.load_levels = false`）→ 自己載入霜橋鎮 → 開場對話 → 藥桶破 → **第一次重來**（生命改成 9 → `Game.retry(false)` → 重新載入：生命照存檔的 55，不是 9、也不是補滿）→ 覺醒 → 再踏回去確認 → 推車到南街口 → 席菈 → 守衛倒下 → 拿兩瓶 → **第二次重來**（藥退回 0 → 重新載入 → 再拿也只有兩瓶、不能拿第三次）→ 喝一瓶 → 艾妲的工錢 → 貨梯 → 待續卡 → 回標題。②只用手把事件（`Input.parse_input_event`）：左搖桿走到藥箱 → A 拿藥 → A 讀完對話 → 十字鍵左喝一瓶。
- 理由：每一段各有測試，但都是用 `dev_advance` 直接跳到那一段開始——「上一段留下的狀態接不接得上下一段」沒有人驗。重來兩次放在流程中間（不是另開測試），重來之後是從檢查點接著走到結尾，所以同時驗了「讀檔之後還走得完」。
- 細節：守衛用 `_engage_guardian()`＋一次打完（打多久是手感問題，不在流程測試裡）；席菈在測試裡被停住（不讓她的 AI 影響位置）。手把的「按一下」要等物理幀跑過才放開（拿藥、喝藥都在 `_physics_process` 裡看 `just_pressed`）。
- 影響：design/09 第 10 節第 5 步完成。之後每加一段（地下市場…）就把這個測試的結尾往後延。

## D-211　2026-11-11　標題畫面的「新遊戲／繼續」＝新版；舊版收進「舊版」選項；副標題換成新版的名字（暫名）

- 決策：新版前十分鐘能從頭走到「待續」了（D-210），照 D-206 直接換成標題的預設入口，不等試玩。標題選單＝**新遊戲／繼續／舊版／設定／離開**：「新遊戲」＝`Game.new_reboot_game()`、「繼續」＝新版的自動存檔（`Game.continue_reboot_game()`；沒有新版存檔時不能按，`GameSession.has_reboot_save()`）。「舊版」（`MENU_CLASSIC`）打開另一頁（`%ClassicMenu`）：一行說明「之前的劇情。不再更新，舊存檔照樣能讀」＋舊版的新遊戲／繼續／返回（Esc／B 也是返回）。
- 決策（副標題）：標題的副標題從「霜橋鎮的第九聲鐘」換成新版的名字「這些詛咒對我太有用了」（`RB_GAME_SUBTITLE`，暫名，Jacky 定名後只改這一個 key）；打開「舊版」那一頁時換回「霜橋鎮的第九聲鐘」——看得出那一頁是另一個故事。遊戲名「餘命城」不動。
- 決策（存檔）：兩邊照 D-202 分開——新版 `user://saves_reboot/`、舊版 `user://saves/`。標題的「繼續」只看新版；舊存檔只能從「舊版」那一頁讀，新版不會寫到它（`test_title_entry` 驗證）。玩完前十分鐘再按「繼續」＝回到最後一個檢查點 `rb_market`（梨攤之前），可以再走一次結尾。
- 決策（09 第 1 節原本寫「標題多一個入口『新版試玩：前十分鐘』」）：沒有做那個入口，直接換預設（`RB_TITLE_ENTRY` 這個 key 留著沒用到）。
- 理由：Jacky 11/10 17:53「新劇情是唯一主線」「先把新版前十分鐘做完並成為標題畫面的預設入口，舊版移到標題畫面的『舊版』選項」。
- 影響：`Game.new_game()`／`continue_game()`／`has_continue()` 仍是舊版的（多一個 `load_level` 參數給測試用）；`boot.gd` 的 `load_levels`（測試設 false：按鈕只改狀態、不換場景）、`open_classic()`／`close_classic()`／`is_classic_open()`；截圖旗標 `--open=classic`、CI `53-title-classic`。舊的標題測試（`test_boot_to_title`、`test_title_menu_uses_theme_focus`）不用改、照樣過。

## D-210　2026-11-11　前十分鐘的結尾：艾妲站在梨攤前給一半工錢 → 貨梯＝地窖口上的吊架 → 站上去就「待續」回標題

- 決策（艾妲）：新小說裡她是從麵包店抱著帳本出來的；遊戲照 09 第 2 節放在**梨攤**（玩家從南街走回廣場，攤燈是整個廣場最亮的地方，一眼知道往哪走）。夜裡的攤子原本只有一個黑色剪影，新版換成人偶（`Ada`：暗紅外套、左手夾著帳本 `Ledger`、不拿敲鐘的槌子），站在攤子西南角（`ADA_POS` (3.3, 0.1)），諾恩走到 9 m 內才轉頭看人。整段前十分鐘她都在那裡（逃跑時經過廣場也看得到）。
- 決策（觸發）：不用 `Area3D`，每幀量距離（`_update_market()`）——上一段對話結束時諾恩可能已經站在攤子前，`body_entered` 不會再響。走到艾妲 3.2 m 內 → `rb_ada_wages`；講完（`rb.ada_talked`）之後站上貨梯（離平台中心 1.25 m）→ `rb.market_reached` → 任務完成。**沒講話就站上貨梯不會結束**（要先拿到工錢、聽到「地下市場的貨梯」）。任務標記照 `rb_main.json`：`PearSellerTrigger`（在艾妲身上）、`CellarTrigger`（在貨梯上）——現在是 `Marker3D`，不是切片那兩個會開對話的觸發區（`test_reboot_opening` 改成檢查「不是 Area3D」）。
- 決策（工錢）：對話結束時 `pay_wages()`——`GameState.grant_once("rb.ada_wages")`＋`items["coins"] += 12`＋上方一行「拿到工錢了。只有一半」。一次性發放：死亡重試回 `rb_market` 時跟著退回，再聽一次也只有一份。**錢現在沒有用途、HUD 也不顯示**（前十分鐘沒有商店）；數字 12 是暫定，地下市場那一段做買賣時再定價。
- 決策（貨梯）：舊關卡的地窖口只是一塊貼地的木板，夜裡從梨攤看過去什麼都沒有。新版在它上方加一座木吊架（`RbLift`：兩根柱子、橫樑、斜撐、鐵滑輪、主繩＋四條繩子吊著貨板、貨板上三口木箱、繞到西柱繫繩樁的拉繩、西柱上一盞提燈——暖光、不投影、`light_specular` 0.3）。全部程式生成（方塊＋圓桿 `_beam()`）。柱子沒有碰撞（很細，站上平台才算到）。
- 決策（結尾）：`play_end_card()`＝`ChapterCard`（小字「待續」＋大字「地下市場」，`RB_END_NUMBER`／`RB_END_TITLE`）→ 播完或按確認跳過 → `Game.back_to_title()`。黑幕底下諾恩 `PROCESS_MODE_DISABLED`。沒有「感謝試玩」頁、沒有配樂（先求能走完；之後補）。`RB_TO_BE_CONTINUED`（「待續：地下市場」一行字）留著沒用到。
- 影響：`rb_main` 六個階段都走得完，`rb.first_ten_done`。截圖旗標 `--rb-at=market|lift`（`dev_advance` 也給測試用）；固定鏡頭組 `scripts/shots/rb_market.txt`、CI `51-rb-market`、`52-rb-lift`。測試 `tests/flow/test_reboot_market.gd`（3 個）。

## D-209　2026-11-11　藥箱＝守衛背上摔下來的瓶架箱；「先收著」有三條路；滿血的確認框會暫停遊戲

- 決策（藥箱是什麼）：照新小說第三章「怪物背上的箱子還有一排沒摔破的藥瓶。大部分都是空的，只有角落兩瓶留著綠色液體，封口完整」——不是路邊多出來的木箱，是**牠背上的瓶架箱**：牠倒下（跪下 → 往前倒）1.2 秒後從背上摔下來，落在牠側邊 1.5 m、靠街心的那一側（`RebootOpening.crate_spot()`；x 夾在 ±2.4、z 夾在 12～25.5，不會進牆或擋到推車）。位置在牠沉下去之前記進旗標 `rb.crate_x`／`rb.crate_z`，讀檔、死亡重試都擺回原地；旗標沒有位置時（截圖旗標直接跳段）用 `CRATE_DEFAULT` (-0.6, 17.5)。
- 決策（外觀，全部程式生成，`scenes/world/potion_crate.gd`）：舊木板箱（`plank_wood.gdshader`，顏色壓暗）、正面三片橫板摔斷兩片（露出裡面，斷板躺在箱子前）、鐵條／直角／鉸鏈、往後掀開的蓋子（內側一層深色的氈：瓶子的綠光襯在深色上）、2×5 的瓶架與乾草、三支空瓶＋兩支破瓶、**角落兩支封蠟的滿瓶**（車床旋轉體 `Lathe`；瓶裡的藥自己發光 `LIQUID_ENERGY` 2.6——4.5 會曝成白色看不出是綠的）、雪上的碎玻璃與斷掉的背帶、一盞很弱的綠光（能量 1.1、範圍 2.8 m、**`light_specular` 0**：第 70 輪「霧裡加綠光 → 濕石板上一顆刺眼高光」的教訓）。整個放大 1.3 倍（牠兩公尺半高，箱子比人用的大一號，鏡頭在 5 m 外才看得到瓶子）。拿走之後兩支滿瓶消失、綠光熄掉（空箱留在原地）。
- 決策（「先收著」有三條路，不強迫喝）：①滿血時按「使用道具」→ 確認框選「先收著」；②確認框按 Esc／B／暫停鍵；③**撿了藥、沒喝就走離藥箱 9 m**（`POTION_KEEP_RANGE`）也算先收著。三條都設 `rb.potion_kept` → 席菈「你要留著那個？」（`rb_potion_kept`）。原因：生命沒滿時按鍵會直接喝（沒有確認框），如果「先收著」只存在於確認框裡，受了傷又不想喝的人會卡在這一段。席菈是跟班、一直在身邊，所以不能用「走到席菈旁邊」當條件。
- 決策（確認框）：`PotionConfirm`（`src/ui/potion_confirm.gd`，掛在 Hud）——開著的時候 `get_tree().paused = true`（敵人不會趁機打人、身上狀態的秒數不走，符合 09 第 3 節「暫停不推進」），預設焦點在「先收著」。沒有用對話系統做：對話的每個選項後面一定要接一句台詞，而且守衛戰裡對話不會讓敵人停手。之後任何時候滿血按使用道具都是同一個框。
- 決策（喝了之後）：`rb.potion_tried` 之後等 2.6 秒（`POTION_TALK_SEC`）才播 `rb_potion_tried`——先讓玩家看到生命條往上爬、狀態圖示亮起來，席菈才開口。喝藥與拿藥的聲音用新音效 `glass_clink`（原本喝藥借用選單的 `ui_tick`）。
- 決策（HUD）：`PotionHud`（生命條右上方：瓶子圖示＋「×2」＋快捷鍵）平常跟著生命條一起出現（戰鬥中、身上有狀態）；「撿到藥 → 席菈講完」這一段由 `RebootOpening._pin_potion_hud()` 釘住，生命條也跟著亮（`CombatHud.force_bars`）——玩家看得到「現在沒滿血」，才知道喝了有用。探索時照舊沒有 HUD。
- 影響：`rb_main` 的 `portable_poison` 階段可以完成，進到 `market_lead`（艾妲與貨梯還沒做：新版的梨攤觸發點下一輪）。截圖旗標 `--rb-at=potion|drank`；固定鏡頭組 `rb_guardian` 與 CI 盤點截圖多 `49-rb-potion`、`50-rb-drank`。喝藥本身還沒有畫面上的特效（只有聲音、狀態圖示、生命條）——排在 NEXT「00」第 4 步。

## D-208　2026-11-10　毒霧＝貼地流動、邊緣不規則的一團霧；噴毒前兆＝空心的虛線圈；一次性粒子要先擺好位置才開始噴

- 決策（毒霧的體積）：`PoisonMist` 的 `MistVolume` 從 `FogMaterial` 換成 fog shader（`src/world/poison_mist_volume.gdshader`）：底濃上淡（地面 1.55 倍 → 1.3 m 高 0.3 倍）、輪廓用雜訊往裡外咬（±0.35 m，越高咬越兇）、裡面的濃淡慢慢流動。雜訊只用大塊的（約 1～2 m 一團）：體積霧的格子很粗，更細的拍不出來。密度、顏色的常數照舊（`VOLUME_DENSITY` 1.2）；淡出改成 shader 的 `fade`（跟霧盤同一個值）。
- 決策（霧盤的邊）：`poison_mist.gdshader` 拿掉那一圈正圓的亮線，改成用雜訊咬的不規則邊＋一道跟著雜訊走的淡亮緣（`edge_strength` 0.3）。面片比毒霧的範圍大一圈（`PoisonMist.DISC_OVERSCAN` 1.14），咬出去的地方不會被面片切出硬邊。**規則範圍（`MistZone` 的半徑）不變**——畫面上的邊大致在規則邊界 ±10% 內晃。設計 09 第 6 節「邊界有一圈淡淡的亮線」跟著改寫。
- 決策（噴毒的前兆）：`telegraph.gdshader` 多一種形狀 3＝落點標記（`Undertaker.SHAPE_RING`）：空心的虛線圈（16 段、慢慢轉、線比其他前兆粗）＋從中心往外擴的一道細圈（擴到邊＝要噴了），裡面不填色。大小＝毒霧的半徑、位置＝落點。下砸照舊是霜色實線的圓。
- 理由：第 69 輪的對照圖裡，前兆（`46-rb-spray`）跟噴完的毒霧（`47-rb-sprayed`）地上都是「一個綠色的圓＋一圈亮線」，分不出「要噴了」和「已經噴了」；主街的毒霧（`41-rb-mist`）是一顆均勻的綠色氣球加地上一道幾何弧線。「記號」用幾何形狀（虛線、圈）、「霧」用不規則的邊與濃淡，兩者才不會混在一起。第 69 輪單獨改霧盤試過兩版都看不出進步——這次跟體積一起改才成立。
- 決策（一次性粒子）：`EnemyActor._ground_puff` 拆成 `puff_build()`（建好、`emitting=false`、還沒進樹）＋`puff_start(ps, at)`（進樹 → 擺位置 → 才 `emitting=true`）。原因：`CPUParticles3D` 預設 `emitting=true`，**一進場景樹就在當下的位置噴出第一批**；一次性、`explosiveness` 0.9 的粒子第一批就是全部。原本「先 `add_child` 再設 `global_position`」→ 整團粉噴在敵人的原點（倒地偏 0.8 m、跪地偏 0.35 m 看不出來；第 68 輪燈柱砸藥桶偏了 8 m、在鏡頭後面，所以「四個時間點都拍不到」）。用最小場景驗證過：一次性粒子在 xvfb＋軟體 Vulkan 拍得到，**不是截圖環境的問題**。D-205、D-207 裡「一次性粒子拍不到 → 不用粒子」的前提不成立了：之後打擊感可以用粒子，但一律走 `puff_build`→調參數→`puff_start`。
- 決策（燈柱砸藥桶）：補回木屑（細長小面片 0.34×0.075 m、`BILLBOARD_PARTICLES`＋隨機角度與轉速、往上炸開、重力 9）＋從桶裡湧出來的綠色藥霧（56 顆很淡的大圓點疊成一團、慢慢往上）。第一版兩種都用實心的柔邊圓點，看起來像彩色泡泡，改過才留下。
- 影響：舊版敵人倒地／跪地／送葬者下砸的粉也跟著噴在該噴的地方（位置差 0.35～0.8 m，外觀幾乎不變，測試照舊）。舊關卡裡其他自己建 `CPUParticles3D` 的地方（`canal.gd`、`thrown_frame.gd`、`nine_breath_site.gd`）沒有檢查是不是同樣的順序——舊版凍結，不主動改。沒有體積霧的畫質（低）毒霧只剩霧盤，邊緣一樣是不規則的。

## D-207　2026-11-10　南街守衛戰：單階段送葬者＋「噴毒」；噴毒是近身輪替裡的一招、沒有直接傷害；推車停到街邊、麵包店加門燈

- 決策：守衛（`RbGuardian`）＝`Undertaker.begin_guardian()`：招式輪替 `pattern_guardian`＝橫掃、噴毒、下砸、橫掃（沒有衝撞、不進第二階段），生命 480（切片的送葬者 900）、失衡上限 140。牠是北街追擊的那一隻繞過來的：席菈接應的對話結束才出現在南街南端，用 `scripted_walk` 走過來（不出招、打不動），離諾恩 8.5 m 內或走到定點就 `end_scripted()` 開打。
- 決策（噴毒）：前兆 1.1 秒（管口綠光＋嘶聲＋地上綠圈＋挺胸），噴在前方 2.6 m、半徑 2 m、留 3 秒（`guardian_spray` 每秒 8）。**沒有直接傷害**；**射程 3.4 m（跟橫掃 3.2 差不多）**，只在近身的輪替裡出現、不連噴。
- 理由：第一版把噴毒射程設成 5.5 m——諾恩站在 3.2～5.5 m 時只有噴毒在射程內，牠會站著一直噴、諾恩一直回血、完全沒有風險（設計 09：「站著吃連擊會輸，毒只讓你有本錢犯一次小錯」）。改成近身才噴：站在霧裡回血的同時也在橫掃與下砸的範圍裡。一輪約 8 秒：最多回 48（霧裡 3 秒＋離開後 3 秒 × 8）、全吃是 96。噴毒不帶直接傷害，是要讓「毒＝回血、打擊＝扣血」分得一清二楚。
- 決策（噴霧不用粒子）：管口到地面那一道用錐形面片＋shader（`spray_jet.gdshader`）。一次性的 `CPUParticles3D` 在截圖／慢幀下拍不到（D-205 的木屑），驗證不了的畫面不留。
- 決策（席菈）：她沒有逆轉體質，不走進毒霧——`CompanionBrain.steer_clear()`（純邏輯、可單獨測試），`Sheila._avoid_mist()` 每幀餵場上的毒霧。目前毒霧只對玩家上狀態（席菈站進去不會掉血），所以這是行為上的示範（NPC 不會跟著免疫），不是保命。
- 決策（推車與門燈）：推車最後停在南街口西側、麵包店門邊（原本停在街心，守衛戰時擋路也擋鏡頭）；麵包店側門加一盞不投影的門燈（南街口西側原本近看整面死黑：固定鏡頭 `45-rb-guardian` 死黑 27.8% → 0.16%）。只在新版建立（`RebootOpening`），舊版霜橋鎮不變。
- 決策（毒霧的體積）：`PoisonMist` 在霧盤之上加一個 `FogVolume`（橢球，高 1.7 m、密度 1.2、綠色＋一點自發光，跟 `fade` 一起淡掉）。霧盤從鏡頭看只是一個平的綠圓盤；體積霧那一團讓霧有厚度、站在裡面的人與後面的牆被染綠。試過「霧盤加層＋雜訊咬邊＋霧裡一盞綠色 `OmniLight3D`」：霧變淡、濕石板上出現高光點，對照圖看不出進步，退回。沒有體積霧的畫質（低）只剩霧盤。
- 影響：倒下之後牠噴的霧會跟著散（那一帶是下一步藥箱的安全試用區）。守衛的排氣管、噴毒只在 `guardian_mode`；舊版的送葬者（切片、第 3 章掙脫戰）外觀與招式不變。

## D-206　2026-11-10　截圖改用固定鏡頭組 `scripts/shots.sh`；新劇情是唯一主線、舊版凍結（Jacky 11/10 17:53 的目標更新）

- 決策：動到畫面的輪次一律用 `scripts/shots.sh <組名>`：鏡頭清單在 `scripts/shots/<組名>.txt`（名稱、幀數、旗標；名稱跟 CI 盤點截圖同名），一次拍完，`scripts/shots_metrics.py` 每張印一行（跟基準的像素差異比例、平均亮度、過曝 ≥250 的百分比、死黑 ≤4 的百分比，過曝 >1.5%／死黑 >30% 會標出來），並拼成一張 960 px 寬的「基準｜這次」對照圖 `build/shots/<組名>-sheet.png`——要判斷好不好看時只 Read 這一張（或裁其中一列）。基準放 `build/shots-baseline/<組名>/`（不進 git）：改畫面之前先 `--save-baseline`，或 `--fetch-baseline` 從 prerelease「screens」下載 CI 拍的同名圖。第一組 `rb_opening`（5 個鏡頭：`40-rb-start`、`42-rb-pursuer`、`43-rb-throw`、`44-rb-flight`、`41-rb-mist`）。
- 理由：Jacky 要求截圖省 token 但前後對照不能省。實測：對話鎖住的靜態鏡頭（`40-rb-start`）本機跟 CI 的圖差異 0.0%，可以直接拿 CI 的圖當基準；有粒子、霧、鏡頭平滑的鏡頭每次都會差一點，所以差異只算「任一色版差超過 24」的像素。這一輪數字抓到一個沒預期的變化：`41-rb-mist` 差異 47%——看圖才知道是附近有敵人時鏡頭拉遠、生命條出現（見 D-205）。
- 影響：新版（《這些詛咒對我太有用了》暫名）是唯一主線；舊劇情（重現、敲鐘、記憶代價、舊切片與第 1～3 章）凍結——程式、資產、存檔、測試都留著，不再擴充。新版前十分鐘做完後要變成標題畫面的**預設入口**，舊版移到標題的「舊版」選項（取代 D-201「先放專用入口、試玩通過再換」）。Steam 文案與素材、成就、新語言、舊內容修補暫緩。畫質優先於新系統。

## D-205　2026-11-10　新版開場追擊的送葬者：從屋頂跳下來、拖著折斷的燈柱、扔燈柱砸破藥桶、堵住北街；追擊期間不出招也打不動

- 決策：開場對話一結束，送葬者（`RbPursuer`）從鐵門邊的屋頂落下（北街兩側的房子之間只有 0.15～0.4 m 的縫，沒有巷子可以走出來；直接出現在地上＝憑空冒出來），起跳點比落地點靠牆 0.8 m、下墜時往街心飄（一道弧線）；落地有雪塵、鐵響、鏡頭震動，門邊留一截歪掉的燈柱（`RbLampStump`）。牠左手拖著折下來的那截燈柱（`RbLampChunk`：鐵桿＋還亮著的燈頭，暖光打在雪地上；用左手是因為牠面向諾恩時燈在畫面右邊，不會被過肩鏡頭裡的諾恩擋住）。牠用新的劇情走位 `Undertaker.scripted_walk()`（`EnemyActor._held_velocity`：照樣 `move_and_slide`、有腳步聲與轉向，不是 tween 搬位置）跟在推車／諾恩（取比較北邊的）後面 5.5 m，每秒 1.45 m（推車 1.7）。推車到北街轉角：站住 → 舉過頭 0.9 秒（沿用舉鐵架的前兆姿勢）→ 扔出去 0.7 秒（拋物線，燈在空中還亮著）→ 砸在石階下的藥桶上（一閃暖光），藥桶才破、毒霧才出來。之後牠往前堵在北街中段（`PURSUER_BLOCK`，不下石階、不進毒霧），到 `meet_sheila` 時離場。讀檔／重試回到 `rb_before_mist`：牠已經堵在北街、燈柱躺在藥桶旁、不會再丟一次。
- 決策（追擊期間不出招、打不動）：`Health.invulnerable_check` 在走位期間回傳 true，狀態機不跑。
- 理由：開場生命只有 55、還沒有席菈、玩家剛拿到操作——橫掃兩下就死（28×2），開場 30 秒內死兩次不是這一段要教的事；這一段只教「帶波克往南走」。牠打得動的話，站著不還手會被慢慢磨，失衡跪地之後狀態機沒在跑也站不起來。小說裡牠「堵住原本的路」，所以丟完之後堵在北街。藥桶由牠砸破（小說：鐵架掃過、藥桶炸開），取代「推車一到就自己破＋一行字」。
- 決策（生命條）：`CombatHud.bars_shown`＝戰鬥中，或諾恩身上有狀態。之前離開戰鬥後生命條會收起來，中毒回血時看不到生命往上爬（設計 09 第 6 節要求看得到）；有敵人在 20 m 內時鏡頭本來就會拉遠到戰鬥距離，所以追擊段與第一次進霧都是戰鬥鏡頭。
- 影響：南街守衛戰（下一步）用 `end_scripted()` 把牠交回狀態機；到時候在南街另外生一隻（`RbGuardian`）或讓這一隻走過去都可以。截圖旗標 `--rb-at=pursuer|throw|flight`（`debug_hold_throw` 把丟燈柱停在舉到最高／飛到三分之一）。

## D-204　2026-11-10　新版前十分鐘在霜橋鎮的控制器 `RebootOpening`：推車停在石階上、毒霧蓋滿主街、確認後霧散

- 決策：`frostbridge.gd` 在 `Game.session.is_reboot()` 時不建切片的觸發點（梨販、石拱回憶、車隊、鐘樓、地窖都會在新版誤觸舊對話）、石拱 `set_dormant(true)`、`_physics_process` 不跑切片段落，改掛 `RebootOpening`（`scenes/levels/rb_frostbridge.gd`）。開場：北街北端一道鐵門（灰盒鐵條，擋人）、門後雷德（對話 `rb_opening` 後往北跑掉）、推車沿用 `Caravan`（只留一名傷者＝波克）、新遊戲生命 55。推車只有諾恩在 6 m 內才往前（1.7 m/s），推到北街轉角（或諾恩自己走到石階中段）→ 三個藥桶倒下、主街上一片半徑 4.4 m 的毒霧（大於街的半寬：繞不過去）→ `rb_before_mist` 檢查點。推車停在石階中段（高處，波克不進毒霧）。第一次中毒 → `ReversalSlots.awakened` → HUD 新的 `show_center_lines`（畫面中間兩行字，第二行綠色、晚 0.9 秒）＋`rb.reversal_awakened`；離開毒霧且毒效結束 → `rb_mist_test`；再踏進去 → `rb.mist_reentered`＋`rb_mist_confirmed`；說完霧在 5 秒內縮小散掉，推車才往南街口走，到了 → `rb.reached_south` → 席菈從南街西側的側門出來，走近 → `rb_sheila_meet` → 波克進店（車上的人偶藏起來）→ `guardian_fight`（`rb_guardian` 檢查點）。`Game.retry()` 在新版沒有存檔時重開新版（不是舊版新遊戲）；`Game.CHECKPOINT_LEVELS` 列出 `rb_*`。截圖旗標 `--level=frostbridge --rb-at=start|mist`。
- 理由：小說裡諾恩「把車推到較高的石階邊，想從霧旁繞過去」、傷者不進毒區（handoff）；霧蓋滿整條街確保每個玩家都會第一次中毒，不會走到南街還沒覺醒卡住。確認後霧散，推車才過得去，也對上小說「霧散了一點」。這一步還沒有追在後面的怪物（藥桶目前是推車到轉角時自己破、跳一行字）。
- 影響：下一步是追擊的送葬者（砸藥桶、在身後逼近）、南街的單階段守衛＋噴毒。新版的流程都在 `RebootOpening`，舊版霜橋鎮的行為不變（`test_classic_frostbridge_has_no_reboot_controller`）。

## D-203　2026-11-10　新版毒霧先做灰盒霧盤（PoisonMist），不用體積霧

- 決策：`PoisonMist`＝`MistZone`（規則：直立圓柱、在裡面每 0.25 秒用來源刷新狀態）＋三層貼地的綠色霧盤（`src/world/poison_mist.gdshader`：不受光、fbm 流動、往外淡、景深接近地面時淡掉；只有貼地那層畫一圈淡亮邊界）。守衛噴的霧有壽命，最後 0.6 秒淡掉後自己移除。沙盒截圖旗標 `--mist`。
- 理由：handoff 要「好認的灰盒」；FogVolume（體積霧）在低畫質會關掉，毒霧是玩法必須看得到的東西，不能隨畫質消失。邊界那圈亮線讓玩家看得出在哪裡進出（覺醒後要自己再踏回去一次）。
- 影響：之後要更像霧再加粒子或體積霧當「加分」，灰盒這層照留著當保底。

## D-202　2026-11-10　新版前十分鐘的狀態邏輯、任務與存檔（`docs/design/09-reboot-first-ten-minutes.md`）

- 決策：
  - `Health` 分成直接傷害 `apply_damage`（照舊）、狀態傷害 `apply_status_damage`（不被閃避擋、獨立訊號、不觸發受擊演出）、治療 `heal`（`healed` 訊號）；不用負數傷害代表治療。
  - `StatusEffects`：同一種只有一份；較強的來源換強度、時間取較長者、上限 30 秒；反轉在扣血之前（每幀直接變回血）、回血上限 8／秒；擁有者在遊戲時間推進且沒在對話時才 `tick`。數值在 `data/reboot/statuses.json`：破藥桶毒霧 6／秒 4 秒、守衛噴毒 8／秒 3 秒、霧蛇毒劑 3／秒 20 秒（自備藥弱但久）。守衛橫掃 28、約 2 秒一輪 → 站著吃連擊會輸（單元測試鎖住）。數值不隨難度變。
  - `ReversalSlots`：開場兩格；第一次中毒自動覺醒並裝進第一格（只一次）。`PotionBelt`：滿血時先問（`confirm_full`）；`grant_once` 讓藥箱與欠薪讀檔重試不重複領。
  - 存檔 v3：`mode`（classic／reboot）、`statuses`、`reversal`、`items`、`grants`、`vitals`；v2→v3 一律 classic、`memories_paid` 不映射。新版存檔在另一個資料夾 `user://saves_reboot`（`GameSession.new_reboot_game()`／`load_reboot_slot()`），標題的「繼續」固定讀舊版。讀檔／重試生命照存的、至少一半。
  - 任務 `rb_main` 六階段（每階段 marker＋檢查點，第一次進霧前 `rb_before_mist`）；覺醒後要自己再踏回霧裡一次才往下（`objective_if` 換目標字，新功能）；`portable_poison` 喝過或「先收著」都能完成。九段對話 `rb_*`、文字 `i18n/reboot.csv`。
  - 可攜藥劑快捷鍵新動作 `use_item`：鍵盤 1、手把十字鍵左（Q／十字鍵上已經是席菈的「打弱點」）。狀態圖示 `StatusHud` 在左下生命條上方：原類型圖示＋反轉箭頭＋「中毒 → 回血 N」。
- 理由：照 `claude-handoff.md` 的開場規則與驗收 7 條；先把規則做成純邏輯＋測試，場景接上時不用邊做邊猜。
- 影響：舊流程完全沒有狀態來源，行為不變（全部舊測試照舊綠）。治療封鎖轉盾、第二種狀態、換欄位的畫面留到前十分鐘試玩通過之後。

## D-201　2026-11-10　接手劇情重寫：新版「前十分鐘」用獨立入口與存檔槽，舊版保留

- 決策：Jacky 合併 PR #1（`docs/story-reboot/`：負面效果反向增益、暫名《這些詛咒對我太有用了》）。照 `claude-handoff.md`：下一輪起最優先做新版前十分鐘（任務 `escape → poison_discovery → meet_sheila → guardian_fight → portable_poison → market_lead`、一種狀態（中毒）一種藥、反轉欄位最小版、HUD 狀態圖示保留原類型＋反轉標記），新版用獨立入口與存檔槽；舊的切片、第 1～3 章、舊測試照舊保留、舊存檔照舊讀得到，新流程經 Jacky 試玩通過再換正式入口、改 PLAN 與舊改編文件。`docs/story/` 原作不動。
- 理由：Jacky 的明確指示（覺得現有第一章不清楚、不吸引人）；handoff 要求先驗證中毒反轉與主動喝藥，不一次做二十種、不先全面重製。
- 影響：第 64～65 輪的程序美術（碎石、鐵鏈、煤堆）與場景、角色、敵人照舊沿用。「九息／重現」、記憶代價只留在舊流程（`NineBreath.activate()` 會扣記憶，新版不能拿來改名當反轉）。參考作品只當方向，角色、名字、情節一律原創。D-200（送葬者手上的鐵鏈）新版的守衛戰也沿用。

## D-200　2026-11-10　送葬者手裡拖著兩條看得到的鐵鏈

- 決策：`undertaker.gd` 的 `_build_chains()`：兩手（`CHAIN_HAND`）各垂一條 `ChainMesh`（`CHAIN_LINK`，鐵架材質）到地面（`Torso/ChainL`／`ChainR`），地上往身後拖一段（`_body/ChainTrailL`／`R`，`CHAIN_TRAIL` 0.9 m，不跟上身前傾後仰）。`enter_phase_two()` 藏起右邊那條；倒下時、第 3 章吊著時 `set_chain_trails(false)`。
- 理由：腳步聲裡有鐵鏈擦地、第二階段寫「扯斷一條鐵鏈」，畫面上卻沒有鏈子；精英敵人是切片的第一眼。
- 影響：Jacky 的正式送葬者模型有「鎖鏈接地」，換模型時這段程序鏈子跟程序人偶一起拿掉。

## D-199　2026-11-10　鐵鏈是一節節的鏈環（`ChainMesh`）

- 決策：新增 `src/world/chain_mesh.gd`：`ChainMesh.build(長度, 一節外長, 外寬, 鐵條半徑)`＝橢圓鏈環（中心線 12 段、圓管 6 段，法線照圓管算），相鄰兩節繞 Y 轉 90° 互相套住（中心距＝外長減兩倍線徑），從 y=0（掛鉤）往 -Y 排到指定長度。乾運河吊住牠的兩條鏈（`HANG_LINK` 16×10 cm、半徑 1.8 cm）、閘道小油燈（`LAMP_LINK`）、酒館吧台吊燈、鐘院飯廳白燈都改用它；位置改成掛鉤那一點（不再是圓柱的中心）。
- 理由：之前是素色圓柱／方條，從岸上看吊住牠的是兩根棍子；鏈子是第 3 章開場就看得到的東西（「吊樑下掛著胸口有鐘舌的送葬者」）。一節 144 個三角形，最長的一條約 30 節，加起來不到一萬個三角形。
- 影響：之後要掛東西的鏈子（送葬者拖地的鐵鏈若要換、鐘的吊鏈）照用。垂下來的鏈子是直的（不會跟著擺動彎曲）；要擺就整條轉（照 `SluiceLampPivot` 的做法）。

## D-198　2026-11-10　乾運河河床的碎石是有稜角的石塊

- 決策：`canal.gd` 河床 26 個 `Debris` 裡的 17 塊石頭從「`BoxMesh`＋方石 shader」改成 `CoalPile.lump_mesh(DEBRIS_LUMP_R=0.85, DEBRIS_SEED＋3.7×i)`＋`scale`＝原本方塊大小（D-197 的做法），材質是新的 `debris_stone_mat()`：`StandardMaterial3D`、`DEBRIS_STONE`（牆石 × 舊水位線下的偏綠灰再亮一點）、粗糙度 0.93。9 根泡爛的木頭照舊方塊。`_rng` 的呼叫次數不變（其他配置不動）。新截圖旗標 `--canal-at=bed`（站在南段河床往北看）。
- 理由：方石 shader 是照世界座標畫灰縫的，貼在小方塊上每塊都是「一小截磚牆」，頂面還會拉成條紋；不規則多面體＋素色石頭在燈下看得出切面就夠了。
- 影響：河床的碎石大多只在 `--canal-at=bed` 這種近景看得到（正式流程只從岸上往下看）。

## D-197　2026-11-10　切片救援點的瓦礫是有稜角的碎石（`CoalPile.lump_mesh`）

- 決策：`rescue_site.gd` 的 7 塊石頭從 `BoxMesh` 改成 `CoalPile.lump_mesh(0.85, 種子)`（不規則八面體、平面著色），`scale` 照原本的方塊大小；材質、亂數順序、位置、救出來時往外推的動畫都不變；木樑照舊是方塊。
- 理由：切片是 Jacky 最先看到的地方；方塊壓在受困者身上像一堆木箱，看不出是崩下來的石牆。不規則多面體一個 mesh 就有碎石的稜角，平面著色讓每個切面各自接到路燈。半徑 0.5 時（跟方塊同一個名目大小）八面體體積小很多、蓋不住人，放大到 0.85 才跟原本的範圍差不多。
- 影響：之後的碎石、瓦礫照這個做（乾運河河床的 `Debris` 是下一個）。測試不用改（救援的邏輯沒變）。

## D-196　2026-11-10　截圖旗標跳段落時收掉前一段的提示（`Hud.hide_banner()`）

- 決策：`Hud` 新增 `hide_banner()`（停掉淡出的補間、立刻透明；之後 `show_banner` 照常）。`canal.gd` 的 `--canal-at=map` 在擺好諾恩前呼叫，收掉 `finish_cut()` 顯示的「整車煤傾下去…」。
- 理由：第 63 輪 NEXT 記的「`33-ch3-map` 上方多一行煤車那段的橫幅」查過了：只是旗標直接從割繩子跳到段落 6，4 秒的提示還沒淡出；正式流程中間隔著倒吊、泥裡的對話與走回去的路，不會疊在一起，所以不改遊戲本身的提示規則（也不讓對話一開始就收掉提示：流程測試在對話前後讀 `banner_text()`）。
- 影響：之後其他截圖旗標如果直接跳過會顯示提示的段落，照這個收掉。單元 `test_hud_banner`。

## D-195　2026-11-10　倒下來的煤是一顆顆的煤（`CoalPile`）：錐形高度場＋平面著色＋散落的小煤塊

- 決策：新增 `src/world/coal_pile.gd`（`CoalPile.build(長, 寬, 高, seed)`、`lump_mesh(size, seed)`、`material()`、`profile(k)`）。堆：極座標網格 10 圈 × 40 段（一個切面約一塊煤大）、`PROFILE` 1.6 的錐形（頂上圓、往外越來越陡）、`LUMP_AMP` 0.06 m 的塊狀起伏、頂點在平面上錯開；`set_smooth_group(-1)` 平面著色；26 顆不規則八面體小煤塊（9 顆滾到堆外的河床）；頂點色煤黑＋外圈與凹處的煤粉，材質 `vertex_color_is_srgb`、粗糙度 0.3、鏡面 0.75。`canal.gd`：閘道的 `CoalHeap/Mound`（`COAL_HEAP_SIZE` 2.7×0.62×2.3、`COAL_HEAP_SEED`）、煤車裡的 `CartCoal`（`CART_COAL_SIZE`）、車上與落下途中的小塊都用它。
- 理由：第 55 輪的「還可以」：原本是壓扁的光滑球（`SphereMesh`）＋方塊，暖燈下是一整片發亮的灰殼，倒吊時從上往下看像一個灰色圓頂。NEXT 原本寫「照 `SnowMound` 的高度場」，但雪是平滑的、煤是一塊塊的：另寫一個比較省事（不用在雪的 UV2 標記上再加一種），平面著色＝每個切面各自反光，在暗處只看得到零星的暖色亮點，才像煤。第一版頂點色沒設 sRGB，0.09 被當成線性值，煤變淺灰——自訂頂點色的材質一律記得設。
- 影響：之後要一堆碎石、煤渣、瓦礫（例如崩塌的鐘樓、礦坑）可以重用 `CoalPile`（換顏色常數或加參數）。`_grab_clapper()` 壓扁 `CoalHeap` 的 `scale.y` 照舊。單元 `test_coal_pile`；主線流程測試看煤堆是 `CoalPile`、蓋得住陷下去的牠。

## D-194　2026-11-10　「給我一晚」之後的時間跳躍：黑一下，「第五夜」出現在黑幕上

- 決策：`canal.gd` 的 `talk_misha()` 開 `ch3_decoy_make` 之前先 `_night_pass()`：`NightFade`（CanvasLayer 12，HUD 10 之上、對話框 20 之下）0.35 秒變黑、停 1.4 秒、1.3 秒亮回來後自己釋放。對話照常立刻開始，第一句旁白「（第五夜。…）」出現在黑幕上。
- 理由：第 47 輪的「還可以」：之前時間跳了一夜，畫面完全沒變，玩家會以為彌夏一轉身就做好了。黑一下是最便宜、最清楚的時間跳躍；對話不等黑幕（流程與測試不用改時序）。
- 影響：之後章節內的時間跳躍照這個做法（或抽成共用的 helper：`daylight.gd` 的 `_cut_from_black` 是「已經黑、慢慢亮」，這個是「變黑、停、亮」）。主線流程測試看有黑幕、層級對。

## D-193　2026-11-10　倒吊切開胸口的時候有火星（`CutSparks`）

- 決策：`canal.gd` 在 `_begin_hang()` 掛一個 `CutSparks`（CPUParticles3D，位置 `cut_point()`＝鐘舌的光）：40 顆 0.09 m、加法混色的銅色火星（`ParticleLook.material(CUT_SPARK_COLOR, true)`），往上迸、重力 -7、0.55 秒；只在 `hang.cutting()`（按住、在正中附近）時 `emitting`，放開、擺太開、抓到鐘舌（`_grab_clapper`）就停。截圖 `--canal-at=hang` 改成按住、擺盪 0.3（切得到的狀態）。
- 理由：NEXT 第 5 節段落 5 的「還可以」：之前倒吊時看不出「現在正在切」，只有每 0.55 秒一聲 whoosh；HangRope 的玩法是「穩住才切得到」，切得到的那一刻要有一眼就看得到的回饋（簡單但吃技巧的戰鬥，回饋要清楚）。
- 影響：主線流程測試看沒按住沒有火星、火星在鐘舌那裡、切得到時有、切完停了。正式模型的「倒吊＋揮劍」動作照舊等 Jacky。

## D-192　2026-11-10　轉角換班的鐘聲是隔著石頭的遠鐘（`bell_far`）

- 決策：`gen_sfx.py` 多 `bell_far`（8 秒）：同一口鐘（G3，跟鐘樓的 `bell` 一樣），三道低通把高頻幾乎濾掉、60 毫秒慢起音（沒有敲擊的「叮」）、三個越來越晚越悶的回音。`canal.gd` 的 `SHIFT_BELL_SFX`／`SHIFT_BELL_DB`（-11 dB），播過記在 `shift_bell_sound`。
- 理由：NEXT 第 5 節段落 7 的「還可以」：之前是一般的 `bell` 壓到 -17 dB，聽起來跟地面上一樣、只是小聲；人在地底城，鐘在上面很遠的地方，應該是「聽得出是那口鐘，但隔著石頭」。
- 影響：之後地底城、室內聽到外面的鐘都可以用 `bell_far`。主線流程測試在轉角對話看換班鐘聲是 `bell_far`。

## D-191　2026-11-10　敵人跪地有「膝蓋落地」的重音

- 決策：`EnemyBrain` 多 `signal knelt`，在 `_enter()` 從別的狀態進入 STAGGERED 時發（跪著再被逼跪不發、死掉不算）。`EnemyActor._on_kneel()` 接上：致命的一擊不算（`health.is_dead()`，接著是倒下的聲音），其餘交給子類別的 `_play_kneel(parent) -> PackedStringArray`；記 `kneel_count`／`last_kneel_sounds`。一般敵人（灰巡者）：腳下地面的腳步聲 ×0.62 音高、-6 dB＋`blunt` -15 dB、一小團雪粉；送葬者：`step_heavy` ×0.78、-1 dB（比走路響）＋`iron_clang` -12 dB（鐵架晃一下）、鏡頭小震 0.14。聲音掛在關卡上；雪粉 `KneelPuff` 噴完自己釋放（`_ground_puff` 改成回傳粒子、`_kneel_puff`）。
- 理由：NEXT 第 5 節的小項目。跪地＝破綻開了，是席菈「打弱點」與玩家追擊的時機；之前完全無聲，只能盯著畫面。聽得到「咚」就知道現在可以打（簡單但吃技巧的戰鬥：回饋要清楚）。
- 影響：新敵人照 `_play_kneel()` 覆寫自己的聲音。單元 `test_knelt_signal_once_per_kneel`、`test_enemy_kneel_thud`。

## D-190　2026-11-10　第 1 章晚餐之後、往鐘院的路上有配樂（`after_dinner_theme`）

- 決策：`gen_sfx.py` 多 `after_dinner_theme`（24 秒循環）：B♭2＋F3 的長音（加一點 D3）、12 秒一次漲落，上面很輕的撥弦（加法合成）——標題往下走的三聲 D4、C4、A3 在這裡變成 D4、C4、B♭3（同樣往下走、落在暖的音）；第一句停在 C4，第二句往下到 F3 再回 B♭3。`daylight.gd` 在 `leave_home()`（晚餐結束）與從檢查點 `ch1_after_dinner` 重來時 `Ambience.music(..., -18 dB, 淡入 6 秒, "AfterDinnerMusic")`，鐘擺聲壓到 -15 dB；`reach_bell_yard()` 時在章節卡底下 3.5 秒淡出（`after_dinner_music_out`）、鐘擺聲回 -12 dB。
- 理由：03「配樂放在哪裡」（D-185）剩下的候選。照同一條判斷：五片麵包、小女兒的問題講完，走出門是「說完、安靜下來」的地方；接著是席菈讓小女孩看劍柄上妹妹刻的兔子（關係節點），是第 1 章的收尾。進城、找爐子、看石碑時（探索）照舊只有鐘擺聲。撥弦而不是鐘：這一段是一家人與一個小女孩，不是城。比切片收束（-16 dB）小聲，不搶對話。
- 影響：03 的候選清單清空（之後新增配樂照同一條判斷）。正式配樂照舊等 Jacky 決定（FOR_JACKY 第 1 項）。主線流程測試：進城與吃飯時沒有配樂、吃完與重來都在播、走到鐘院門口開始淡出。

## D-189　2026-11-10　柯德家（白晝城）不開窗、不共用結霜窗；樓梯底的門維持往樓梯井那側開

- 決策：NEXT 的兩個小項目不做——(1)「結霜窗共用到柯德家」：柯德家在白晝城，D-154／D-174 的設定是「白晝城的窗都關著」（沒有影子、無方向的光），開一扇看得到雪街的結霜窗會破壞設定，窗板照舊關著；結霜窗只留給霜橋鎮的室內（酒館；之後霜橋鎮別的屋子要窗外景再共用）。(2)「柯德的門開到 170°」：樓梯井這一側有凸出的木門框，而且 D-175 讓 `daylight.gd` 的 `BackDoorLeaf` 靠在通道西牆、跟 `stairs.gd` 的 `DOOR_OPEN_DEG` 同一個方向；只改樓梯這邊會讓同一扇門兩邊對不上。照舊 -82°，等 Jacky 試玩說擋到再兩邊一起改（門軸移到門框內側）。
- 理由：兩項都是第 61 輪列的「有空再做」，這輪讀過程式後判斷做了反而出錯（設定矛盾、兩個關卡對不上）。
- 影響：NEXT 第 5 節拿掉這兩項，改記在這裡；FOR_JACKY 不另外問。

## D-188　2026-11-10　第一部前半的收尾配樂：結尾卡＋感謝試玩頁（`part_end_theme`）

- 決策：`canal.gd` 的 `play_end_card()` 一出結尾卡就 `Ambience.music(self, "part_end_theme", -14 dB, 淡入 4 秒, "PartEndMusic")`，一路墊到感謝試玩頁（關掉回標題時跟著關卡一起結束、標題配樂接手）；乾運河的低風（`Ambience`）同時在 4 秒內壓到 -24 dB。`gen_sfx.py` 的 `part_end_theme`（28 秒循環）回答標題的鐘聲：標題往下走（D4、C4、A3，第二次落到 F3），這裡從 F3 往上（F3、A3、C4），第二次 A3、C4 停在 D4（標題開頭那個音）；底下 F2＋C3 長音＋很小聲的 A3，14 秒一次漲落。
- 理由：D-185「配樂放在哪裡」的第一個候選。轉角講完、結尾卡出來是 12/31 版本最安靜、最該收束的一刻；之前只有低風，結尾卡像斷電。往上走、停在 D4 是「後半還沒完」的感覺，跟標題往下落的那三聲成對。
- 影響：03「配樂放在哪裡」的現況多一項（剩下候選：第 1 章柯德家晚餐之後走在白晝城）。主線流程測試在結尾卡與感謝試玩頁看配樂（`_assert_music`）、低風壓下去。正式配樂照舊等 Jacky 決定（FOR_JACKY 第 1 項）。

## D-187　2026-11-10　敵人的腳步聲：灰巡者照地面、音高壓低；送葬者是很重的拖步

- 決策：`Footsteps` 多 `sound`（固定音名，空＝照地面 `step_雪／石／木`）、`pitch_base`、`stomp(owner, sprinting, sound_parent)`（不看距離直接踏一步）、`tick(..., sound_parent)`（聲音掛在哪個節點）。`EnemyActor` 在 `move_and_slide()` 之後用實際速度踏步（`_make_footsteps()` 由子類別回傳，null＝不出聲；比 `move_speed` 快 1.5 倍算跑步）。灰巡者：步子 0.85 m、-15 dB、音高 0.8（佝僂著拖步，比諾恩小聲）。送葬者：新音 `step_heavy`（72 → 38 Hz 的重「咚」＋高八度泛音＋落地碎響＋拖在後面的鐵鏈擦地＋三下鐵環碰撞，0.66 秒），不分地面；步幅 1.3 m（衝撞 2.2 m）、-7 dB（衝撞 -3 dB）、`unit_size` 7。乾運河裡牠的步態是關卡演的（`_update_follow` 直接設位置、`process_mode` 停著）：`canal.gd` 的 `_gait` 每半個步態週期身體落回河床時 `stomp()`，聲音掛在關卡上（掛在停著的節點底下 3D 音不會播）。**腳步聲預設掛在 owner 的父節點（關卡）**，不掛在人身上：掙脫戰撞回運河時送葬者被停掉、敵人倒下被釋放，正在播的那一步照樣播完。
- 理由：第 61 輪補了諾恩、席菈的腳步，敵人卻完全無聲——送葬者 2.6 m 高、拖著鐵架，從背後逼近應該是「先聽到再看到」；乾運河段落 3 的假心臟本來就是聽聲音的段落，牠走過來的每一步都該聽得到。
- 影響：新敵人照 `_make_footsteps()` 給自己的一份。死掉（`_begin_death` 停掉 physics）不再踏步。單元 `test_enemy_footsteps`、`test_stomp_plays_on_given_parent`；主線流程測試在 [ch3_decoy] 看牠走過來有拖步、停下來聽時沒有。

## D-186　2026-11-10　酒館東窗是結霜玻璃，隔著霜看得到模糊的對街

- 決策：窗玻璃（`Window`，CSGBox）改用 `src/world/frost_window.gdshader`（unshaded、不投影子；面內座標用物件座標，`pane_size`＝(沿 Z 的寬, 沿 Y 的高)，從屋裡往 +X 看 +Z 在右邊）：畫一條模糊的對街——雪地、對面房子的暗牆＋屋簷下的陰影、積雪的人字屋頂與煙囪、陰天；入夜（`noon` 0）換成暗藍、對街一扇窗點著暖光；四邊結霜（fbm 不規則邊＋細冰晶，下緣比較厚）、整片輕微霧化（`haze`）。`tavern.gd` 只切 `noon`。不在窗外放真的幾何。
- 理由：第 53 輪起 NEXT 的小項目「酒館窗外沒有景（中午是一片白光）」。窗外放真的房子要避開 D-177 光束的路徑（聚光燈在窗外 7 m、高 4.35 m，對面屋頂很容易擋到），還要另外打光；霜窗本來就看不清楚，畫在玻璃上便宜、日夜都對，也合冬天的感覺。
- 影響：酒館的光束與窗櫺影子不變。之後別的室內窗（柯德家的窗板、鐘院的窗簾）要外景時可以共用這個 shader（調 `wall_*`／`sky_*`）。主線流程測試在酒館中午與入夜檢查窗的 shader 與 `noon`。

## D-185　2026-11-10　關卡配樂只放在「打完之後安靜下來」的地方：先做切片收束

- 決策：新的程序配樂 `aftermath_theme`（32 秒循環：D2＋F2 小三度長音、高八度 D3／F3 小聲墊著、16 秒一次很淺的漲落、兩聲很遠很悶的鐘＋長回音，不成旋律）。霜橋鎮在主線進入 `aftermath`（車隊過去、回梨販攤）時 `Ambience.music(..., -16 dB, 淡入 8 秒, "AftermathMusic")`；從 aftermath 檢查點重來也播；白天版本不播。打的時候、探索的時候一律只有環境音。
- 理由：03 的方向是「環境音為主」；整段切片唯一需要音樂托住情緒的是打完之後——北街陷落、車隊過去、要去見艾妲與死者名單。音樂太多會把「重現」時的心跳和鐘聲沖淡。
- 影響：之後要加配樂的地方先照這條判斷（候選：第一部前半的結尾卡／感謝試玩頁、第 1 章柯德家晚餐之後）；不要每個關卡都放。正式配樂要不要找人作曲是 Jacky 的決定（FOR_JACKY 第 1 項）。流程測試 `_assert_music(關卡, tag, 音名, 節點名)`。

## D-184　2026-11-10　席菈的腳步聲；腳步邏輯抽成 `Footsteps`；鐘院飯廳與柯德家是木板地

- 決策：`src/core/footsteps.gd`（`Footsteps.new(步幅, 跑步步幅, dB, 跑步 dB)`、`tick(owner, 走了幾公尺, 跑步, 著地)`、`count`／`last_surface`、static `surface_at(owner)`：先問父節點、再問目前場景的 `footstep_surface(位置)`）。諾恩照舊（`footstep_tick`／`step_count`／`last_step_surface` 轉給 Footsteps）；席菈在 `move_and_slide()` 之後用實際速度算步數（撞牆原地踏不算），步幅 0.72／1.0 m、-18／-14 dB（比諾恩小聲）。鐘院 `footstep_surface`：內室（`is_inner_room`：北牆門後）石板、其他木板；白晝城：柯德家（`in_kord_house`）木板、街上石板。
- 理由：D-182 只做了諾恩；席菈一路跟著卻完全無聲，兩個人並肩走時聽起來像只有一個人。鐘院飯廳、柯德家看得到木板地，踩下去卻是石頭聲。
- 影響：敵人（灰巡者、送葬者）還沒有腳步聲——要做時照 Footsteps（送葬者該是很重的拖步，另做音）。其他角色人偶（彌夏、柯德）沒有物理移動，不加。

## D-183　2026-11-10　重現期間的混音：SFX 低通＋Music 壓低，心跳走自己的匯流排

- 決策：新的 `RestoreMix`（`src/core/restore_mix.gd`，`Game.restore_mix`，`PROCESS_MODE_ALWAYS`）每幀輪詢 `RestoreMix.GROUP`（`restore_sources`）群組裡有 `restore_mix_active()` 的節點：`NineBreathSite`（倒數中）與乾運河（送葬者醒著時按住重現）。有一個在重現就在 `ATTACK_SEC` 0.25 秒內把 SFX 匯流排的 `AudioEffectLowPassFilter` 從 `OPEN_HZ` 20 kHz 收到 `CLOSED_HZ` 900 Hz（對數內插；平常效果整個關掉）、Music 匯流排的 `AudioEffectAmplify` 壓到 `MUSIC_DUCK_DB` -8 dB，放開後 `RELEASE_SEC` 0.9 秒回來；暫停中一律放開。新的 `Heart` 匯流排（直接接 Master、音量跟著「音效」滑桿＝`Settings.MIRROR_VOLUME`）：重現的心跳用 `Sfx.play_flat(..., Sfx.HEART_BUS)`。效果在 `Settings.ensure_buses()` 建（`RestoreMix.ensure_effects()`，只建一次）。`heartbeat` 補進 `Sfx.NAMES`。
- 理由：03 寫了「九息期間 SFX 低通＋Music 壓低，讓心跳最清楚」，第 60 輪補了環境音之後更需要：重現的 9 秒裡風雪、打擊、腳步跟平常一樣大聲，心跳被蓋掉。用輪詢而不是訊號，換關卡、回標題時來源自己消失，不會卡在悶住的狀態。
- 影響：新的「重現」玩法（之後章節的可重現物）只要是 `NineBreathSite` 就自動有；別的「重現中」狀態要加進 `restore_sources` 群組並實作 `restore_mix_active()`。乾運河假心臟自己的心跳是世界裡的聲音（走 SFX，會被悶住）。UI 的「叮」走 UI→SFX，重現中也會悶（重現中不會開選單，暫停時已經放開）。

## D-182　2026-11-10　諾恩的腳步聲：照走過的距離踏步，聲音照關卡的地面

- 決策：`PlayerController.footstep_tick(走了幾公尺, 跑步, 著地)`：每 `STRIDE` 0.8 m（跑步 `SPRINT_STRIDE` 1.1 m）踏一步，閃避與騰空不算，-13 dB（跑步 -9 dB）再隨機 ±1.5 dB、音高 ±10%。地面由關卡的 `footstep_surface(位置)` 決定（`StoryLevel` 預設 `stone`；霜橋鎮 `snow`，白天也是；酒館 `wood`），只認 `STEP_SURFACES`，其他一律石頭。三段程序音 `step_snow`／`step_stone`／`step_wood`（`gen_sfx.py`）。
- 理由：03-art-audio-direction 的音效表裡有「腳步（雪、石）」，但 59 輪都沒做：走路、跑步完全無聲，是試玩時第一分鐘就會注意到的空白。跟著距離（不是時間）踏步，跑起來自然變快、撞牆停住就不響。
- 影響：鐘院飯廳、柯德家是木板地但現在算石頭——要分區域時在那個關卡覆寫 `footstep_surface(p)` 照位置回傳。席菈與敵人還沒有腳步聲（之後照同一個做法）。正式角色模型接進來後可以改成動畫事件觸發。單元 `test_ambience::test_footsteps_follow_distance_and_surface`、流程測試看切片開頭與酒館的地面。

## D-181　2026-11-10　標題畫面的配樂（Music 匯流排第一次有東西）

- 決策：程序生成 `title_theme`（24 秒循環）：D2＋A2＋D3 長音鋪底（每個音兩個差零點幾 Hz 的聲部拍頻、12 秒一次漲落；波形表合成）＋霧裡遠遠的鐘聲動機（D4、C4、A3 往下走；12 秒後 D4、C4 再落到 F3），鐘聲低通＋三個回音。`Ambience.music(父節點, 名稱, 音量, 淡入秒數, 節點名)` 走 **Music 匯流排**；標題 2.5 秒淡入到 -4 dB（`boot.gd` 的 `MUSIC_DB`／`MUSIC_FADE_IN`）。
- 理由：設定頁一直有「音樂」音量，但沒有任何聲音走 Music——調了沒反應像壞掉；標題畫面是玩家第一個畫面，冬夜剪影配上無聲很空。03 的方向寫「先用長音鋪底＋鐘聲動機，正式配樂列在 ART_REQUESTS」，這是那個佔位版本。
- 影響：關卡裡還沒有配樂（只有環境音），要加的話照同一個 `Ambience.music`，重現期間壓低（03 的混音規則）還沒做。正式配樂需要 Jacky 找作曲或授權素材時，換掉 `title_theme.wav` 的來源就好（檔名不變）。單元 `test_ambience` 兩個。

## D-180　2026-11-10　霜橋鎮的風雪、酒館的壁爐聲；環境音統一走 `Ambience`

- 決策：新的 `Ambience`（`src/core/ambience.gd`）：`looped()` 複製一份音檔設成整段循環（不改 `Sfx` 快取裡共用的那份）、`play()` 不分位置、`play_at()` 3D、`sfx_of()` 給測試看在播哪一段；白晝城與乾運河的 `_start_ambience` 改用它。新的程序音：`frost_wind`（12 秒：低風＋滑動的帶通呼嘯＋雪粒沙沙，跟著陣風起伏）、`frost_wind_indoor`（同一段風隔著牆：再低通、去掉雪粒）、`hearth_crackle`（7 秒：火焰呼嚕＋每秒約 9 下劈啪＋三聲爆裂）。霜橋鎮那一夜 -13 dB、白天 -17 dB；酒館牆外的風中午 -26／入夜 -21 dB，壁爐的柴火 3D（`unit_size` 3，從爐膛發出來）中午 -10／入夜 -5 dB（`_apply_time_of_day` 跟著換）。
- 理由：垂直切片的整座霜橋鎮沒有任何環境音（只有打擊與鐘聲），酒館的火是無聲的；聲音是「第一眼」質感裡最便宜、最被忽略的一半（03 的音效表本來就有「風雪」）。
- 影響：一百七十二階、鐘院還沒有環境音（樓梯有小孩的笑聲、鐘院有伊薩的支架聲），之後照 `Ambience.play` 加。流程測試 `_assert_ambience(關卡, tag, 音名[, 節點名])`：切片開頭、白天的霜橋鎮（比那一夜小聲）、酒館中午與晚餐（柴火從壁爐來、入夜比較大聲）。

## D-179　2026-11-10　遊戲時間開始累計；「感謝試玩」多一列「遊戲時間」

- 決策：`Game._process` 在目前場景是關卡（`StoryLevel`）時把 `Game.playtime_step(delta, Engine.time_scale)` 加進 `GameState.playtime_sec`（存檔本來就有這一欄）：用**真實時間**（打擊停頓把時間放慢到 0.05 時換回真實秒數）、一幀最多 `PLAYTIME_MAX_STEP` 0.25 秒（換場景卡住的那一幀不算）；暫停時 Game 跟著停、標題畫面不是關卡，都不算。**倒下重來不退回檢查點**（`Game.retry` 保留比較大的那個），讀檔（標題的「繼續」）用存檔裡的時間。`ThanksPage` 的「你的這一趟」第五列「遊戲時間」：四捨五入到分鐘，`THANKS_TIME_MIN`「42 分鐘／42 min」、`THANKS_TIME_HM`「1 小時 5 分鐘／1 h 5 min」（`ThanksPage.time_text`）。
- 理由：NEXT「下一步」2 的小項目；D-176 因為沒在累計而沒放。試玩版的結算頁有時間，Jacky 也能從試玩者回報的數字知道切片到第 3 章實際要玩多久（目標 20～30 分鐘＋三章）。
- 影響：`test_playtime`（真實時間、上限、不在關卡不算、重來不倒退＋讀檔用存檔的）、`test_thanks_page::test_time_played_text`（中英、進位）、流程測試每次 `_retry()` 確認時間沒倒退、感謝試玩的時間跟狀態一致。之後要加「最快通關」之類的成就可以直接用這個值。

## D-178　2026-11-10　「重現」與記憶代價在第 1～3 章的一致性：停用的可重現物、付出的記憶一律看得到、每個關卡的流程檢查

- 決策：
  - **`NineBreathSite.set_dormant(true)`**（＋`is_usable()`、`ring_visible()`）：之後的章節回到同一個地方、這裡已經不能重現——沒有提示、地上那圈霜藍鐘紋不亮、按住或直接呼叫 `activate()` 都不會發動、日記不標亮。第 1 章白天的霜橋鎮（`_build_day`）改用它：之前只是 `set_physics_process(false)`，**燃燒劍路線（沒用過石拱）白天回到南街時那圈鐘紋還亮著**，看起來像能重現。
  - **日記：付出過的記憶一律看得到**（`Journal.is_unlocked` 先看 `has_paid_memory`）：就算解鎖它的對話被跳過或沒走到，也不會付了一段日記裡找不到的記憶。
  - **白天不再播切片的「石拱回憶」**（`frostbridge.gd` 的 `_on_arch_memory` 先看 `day`）：正常路線旗標一定設過，但 `--day` 直接進白天時會播「爸以前放學都在這裡等我」；付掉那段記憶的路線不該再說出來。
  - **流程檢查 `_assert_restore(關卡, tag, 能重現的物件 id)`**（`test_slice_playthrough.gd`）：每進一個關卡（切片開頭、酒館、白天的霜橋鎮、一百七十二階、白晝城、鐘院、乾運河）都跑——現在能重現的地方剛好是那幾個、每處的記憶是日記條目且提示有翻譯、停用／用過的沒有提示也沒有圈、付出的記憶都在日記裡看得到；沒有可重現的地方時按住重現鍵 12 幀：HUD 不出提示、日記不標亮、不付記憶、`ninebreath.*` 狀態不變。乾運河開頭（送葬者還掛著）按住也不會設 `ch3.heard_noen`。
  - 第 1～3 章照原作（小說第一部第四～六章）**沒有新的可重現物**：乾運河的「重現讓心跳變快」是按住重現鍵本身（`canal.noen_restoring()`），不是一個 `NineBreathSite`，不付記憶。
- 理由：NEXT「下一步」1。切片之後的章節一直沒有人檢查「重現」會不會在不該出現的地方出現；用流程測試把規則寫死，之後新增可重現物（第一部後半、第二部「借來的九息」）一定要在 expected 裡列出來、記憶一定要進日記。
- 影響：新的可重現物：放進關卡後在那個關卡的 `_assert_restore` 的 expected 加上它的 `object_id`；之後章節回到同一個地方要 `set_dormant(true)`。單元 `test_nine_breath_site::test_dormant_site_cannot_restore`、`test_journal::test_paid_memory_is_always_visible`；拿掉白天的停用或白天的擋，流程測試會紅（都試過）。

## D-177　2026-11-10　酒館中午窗外照進來的光束：東牆拆出真的窗洞＋窗外遠處一盞投影子的聚光燈

- 決策：
  - **東牆**（`tavern.gd` 的 `_build_east_wall`）：一整塊 → 窗的北、南、下、上四塊（`WallE_N`／`WallE_S`／`WallE_Sill`／`WallE_Head`），中間是真的窗洞。**不用 CSG 減法**（第 53 輪試過：減法的洞沒有進陰影，地上完全沒有光）。牆的 shader 用世界座標，拆開看不出接縫。窗玻璃 `cast_shadow` 關掉。
  - **光束 `SunBeam`**：SpotLight3D 放在窗外、沿「窗中心 → `SUN_TARGET`（地圖桌那一帶的地板）」往回 `SUN_DISTANCE` 7 m（第一版 3 m：光線發散，地上的光斑拉成 8 m 長一條；放遠＝接近平行，像太陽），`SUN_ANGLE_DEG` 12°（整扇窗在錐裡，多的被牆擋掉），`spot_attenuation` 0.5、中午 40／入夜很淡的藍 4.5，開陰影＋體積霧。窗邊的 OmniLight `WindowLight` 中午 2.2 → 1.8（光束補上）。
  - 光從東北斜照、窗洞中心的光從吧台南端旁邊過；窗北下角一小片會照到吧台側面（不擋路、反而像真的）。
- 理由：NEXT「下一步」2（第 53 輪記的試法）。酒館中午原本只有一扇發白光的窗、屋裡均勻地暗；地上一塊窗形的光斑＋窗櫺的十字影子＋桌腳拉長的影子，是「第一眼」最便宜的質感來源（只多一盞投影子的燈）。
- 影響：酒館多一盞投影子的聚光燈（中午與入夜都開；效能在實機 benchmark 看，太重的話入夜關掉）。`test_tavern_art::test_sun_beam_through_window`（光的方向、不被天花板擋、光斑不拉長、四塊牆剛好圍出窗洞）、流程測試 `[ch1_tavern]`／`[ch1_dinner]`（沒有 `WallE`、玻璃不擋光、光束投影子、中午亮／入夜淡藍）。

## D-176　2026-11-10　「感謝試玩」一頁：結尾卡之後、回標題之前；附「你的這一趟」與後半預告

- 決策：
  - 第一部前半的結尾卡（D-168）播完或跳過 → **`ThanksPage`**（`src/ui/thanks_page.gd`，CanvasLayer 41，蓋在停在全黑的結尾卡上）→ 關掉才回標題。`canal.gd` 的 `show_thanks()`；`end_card_done` 現在是「結尾卡＋感謝試玩都關掉之後」。
  - 內容（中英，`i18n/ch3.csv` 的 `THANKS_*`）：小字「這一版到這裡」、明體「感謝試玩」、這一版的範圍（《霜橋鎮的第九聲鐘》＋第一部「死去的攻略」前三章）、**「你的這一趟」四列**（北街救出幾個人／那一夜霜橋鎮的死者＝跟死者名單 `DeadListBoard.dead_count` 同一套／為了重現忘掉的記憶＝`memories_paid`／被推翻的攻略筆記）、**後半預告＝原作第七章的第一句「第五天，我撕了自己的地圖。」**（不劇透後半的結局）、回饋（GitHub Issue＋「開啟回饋頁面」按鈕，`OS.shell_open`）、「回到標題畫面」。
  - 操作：焦點預設在「回到標題畫面」（確認鍵／A），取消鍵（Esc／B）也回標題，十字鍵左右切換兩個按鈕，滑鼠可以點（打開時把滑鼠放出來）。**剛出現 1 秒內按鈕不能按**（連按跳過結尾卡時不會順手跳掉這頁）。暫停選單開著時不處理取消鍵。黑幕底下諾恩停住（`Player.process_mode` 停用）。
  - 「你的這一趟」只放切片與第 1～3 章都有的結果；遊戲時間沒放（`playtime_sec` 目前沒有在累計）。
- 理由：NEXT「下一步」1。原本結尾卡播完直接回標題，試玩的人不知道「這一版到這裡了」也不知道去哪裡回饋；四列結果讓玩家看到自己的選擇真的留下了數字（Fallout 式的結算感），預告用原作的句子保留小說的語氣。
- 影響：**上架 Steam 的版本要換回饋管道**（Steam 討論區，或拿掉「開啟回饋頁面」）——GitHub Issue 只適合現在的試玩版。截圖旗標 `--level=canal --canal-at=thanks`（CI 盤點截圖 `39-part1-thanks`）。`test_thanks_page`（文字都是翻譯 key、數字跟狀態一致、輸入延遲、只關一次）、流程測試 `_chapter3` 結尾。

## D-175　2026-11-10　白晝城剩下的白盒：後門的通道（AO 壓掉環境光）、開放式門房、晾衣繩的布、磨亮的黑石碑；樓梯底的門；彌夏的座鐘

- 決策：
  - **後門**（`daylight.gd` 的 `_build_back_door`）：一塊黑板 → 門洞（深色木門框＋石門楣＋門檻石）＋牆後 1.1 m 平台＋六階往上的石階（`PASSAGE_*`、`STEP_*`），柯德打開的門板靠在通道西牆（跟 `stairs.gd` 的 `DOOR_OPEN_DEG` 同一個方向：往樓梯井那一側開）。門洞照舊走不回去（看不見的 `BackDoorBlock`）。
  - **通道的黑＝新 shader `src/world/dark_passage.gdshader`**：白晝城的光是無方向的環境光，門洞裡本來會跟廣場一樣亮。用 `AO`（`AO_LIGHT_AFFECT = 0`）從門口往裡 `PASSAGE_DARK` 公尺把環境光壓到 3%：**油燈的直接光照常照得到**（諾恩走近時看得到台階），不違反「只有油燈投影子」（沒有加光）。粗石方塊＋暗縫在 shader 裡（物件座標）。
  - **門房**（`_build_gatehouse`）：兩塊方石板 → 靠在西牆的開放式小屋：北牆開一扇關著窗板的小窗（白晝城的窗都關著；第一版放鐵條，看起來像一個白色「Π」字）、前面兩根石柱＋一根木樑、矮牆（比桌面低：桌子與孩子從廣場看得到）在靠後門那端留入口、往東斜的木板屋頂＋屋簷＋椽子＋石簷口。中間不放柱子（會擋住桌子）。
  - **晾衣繩**（`_build_laundry`）：一根直的細方塊 → 十段往下垂的繩子（`rope_point(t)` 拋物線），四件衣服＝輪廓三角化後起伏的薄布（`garment_mesh`：上衣、褲子、毛巾、小裙子，雙面），每件兩個木夾子。地底沒有風：不動。
  - **壽命石碑的黑石＝新 shader `polished_stone`**：真的反射在均勻背景色下看不出來（一塊死黑），改成假造「映著穹頂」：越往上越亮的一層很淡的冷白光澤＋菲涅耳邊緣＋直向擦痕。第一版光澤 0.1 太亮（像灰色的金屬板、字變不清楚），降到 0.035／0.08。
  - **樓梯底的門**（`stairs.gd`）：素色木板 → 直排木板＋兩道鐵帶＋鐵環把手（跟著門板轉）＋樓梯井這一側的木門框與石門楣。
  - **彌夏的鐘**（`tavern.gd` 的 `_build_clockless_clock`）：小木箱 → 座鐘（木殼、半圓頂、底座、米白鐘面＋黃銅圈、十二道刻度，中間只剩一根空的軸＝指針不見了）。
  - 截圖旗標 `--level=daylight --daylight-at=gate|backdoor|laundry`（回頭看後門與門房／站在後門口／淨化爐與晾衣繩：從廣場北邊看，晾衣繩剛好被爐子擋住）。
- 理由：NEXT 第 5 節「下一步」1、2：12/31 版本最後幾塊素色方塊。兩個新 shader 都很小、不加任何光；白晝城「白、平、亮得不舒服」的說法不變，只讓「後門通往很深的樓梯」「有人住在門房」「石碑是磨亮的黑石」看得出來。
- 影響：12/31 版本的場景沒有白盒了（人物還是程序人偶）。之後任何「照不到環境光的凹處」（地窖口、深門洞）都可以用 `dark_passage`。`test_daylight_art`（通道、門房、晾衣、石碑）、`test_stairs_art`（門的鐵帶與門框）、`test_tavern_art`（座鐘沒有指針）＋流程測試 `_assert_daylight_art` 擋住退回白盒。

## D-174　2026-11-10　白晝城街道與一百七十二階的美術：石頭砌的房子、木板窗、石板路、拱肋；樓梯井整面方石

- 決策：
  - **白晝城的房子**：`InteriorLook.wall` 的室內版（`exterior` 0：地底城沒有雪）——牆腳 0.9 m 方石（`STREET_STONE_H`，淺灰縫 `STREET_MORTAR`）＋白灰泥，**沒有木框、不燻黑**（地底城的房子是石頭砌的、白晝城沒有火；跟柯德家屋內同一個說法）。廣場、路口的牆同一個材質。牆腳石頂一條淺色壓頂石（門的地方斷開；不然 8 cm 寬的頂面被 shader 畫成深色斜紋）。
  - **窗與門**：窗板直排木板（板縫不要太深：第一版 `seam_dark` 0.85 看起來像鐵窗）＋下面一塊淺色石窗台、上面一條石楣；門直排木板＋深色木門框＋石門楣＋門檻石。地面沿街（南北）鋪石板。盡頭的牆、門房、石柱、石碑座＝整面方石（**縫要深**：淺縫＋小塊看起來像水泥空心磚）。穹頂每 7 m 一道拱肋（看得出是蓋起來的天花板，不是天空）。
  - **壽命石碑**：兩側方石立柱＋頂上兩層淺色石蓋，黑石嵌在中間（字不動）。
  - **淨化爐**：爐身三道帶鏽的鐵箍、一圈石座、爐門鐵框與門閂、煙管接頭箍；全部不發光（冷了很多年）。
  - 小細節（窗台、窗楣、門框、門楣、壓頂石、拱肋）合併在 `StreetTrim`（`StaticBatch`，每種材質一個 draw call）。**白晝城只有油燈投影子（D-154）不變**：這次沒有加任何光。
  - **一百七十二階**：井壁、中間的石柱、頂層擋牆＝整面方石（深縫，跟乾運河河道牆同一套參數、沒有水位線）；轉角平台、井底、天花板＝石板；台階三種深淺輪流（位置雜湊，不動 `_rng`）。
- 理由：第 1 章段落 5～9（樓梯、門、沒有影子的城、晚餐、兔子）都在這兩個場景，是 12/31 版本最後一塊白盒。白晝城刻意保留「白、平、亮得不舒服」：灰泥還是很白、沒有影子，只加看得出「有人住、石頭砌」的結構（窗台、門框、石板、拱肋），不加顏色與髒污。
- 影響：12/31 版本的場景都不再是素色方塊（剩下的白盒是人物＝程序人偶）。`test_daylight_art`、`test_stairs_art` 擋住材質參數與常數關係；流程測試 `_assert_daylight_art` 擋住街上再出現素色白灰牆或窗板。

## D-173　2026-11-10　乾運河的美術：方石河道＋舊水位線、岸頂石板、龜裂的乾泥河床（新 shader dry_mud）

- 決策：
  - **河道牆**：`InteriorLook.wall(stone_h 99)`、`block_scale` 1.7（一排約 0.6 m、比鐘院內室大）、深灰縫；**舊水位線**＝半木構 shader 新參數 `tide_amount`／`tide_y`（預設 0＝鎮上、室內不變）：河床上 2.3 m（`TIDE_Y`）以下偏暗偏綠灰、邊緣不規則、往下幾道水痕——不用台詞就說「這裡以前有水」。
  - **岸**拆成看得到的兩塊：河道牆（頂在 -6 cm）＋岸頂一層沿運河鋪的石板（`flagstone`，`along_z`、輕微磨亮）；碰撞照舊一整塊（`BankE/WBody`），玩家站的高度不變。壓頂石、矮牆、橋欄、閘道矮牆頂、水溝邊、轉角護角石是比較淺的條石（`coping_mat()`）；最外側高牆、南北端牆、頭頂石樑是很大的暗色石塊（`outer_wall_mat()`，一排約 1.2 m，只有縫裡的光掃過才看得出來）。
  - **河床：新 shader `src/world/dry_mud.gdshader`**（世界座標、只畫朝上的面）：兩層 Voronoi（大塊裡再裂成小塊；格子先用雜訊扭過）＝龜裂的乾泥，每塊深淺不同、邊緣翹起（法線往裂縫倒）、一層淡淡的乾土霜；中間一條還沒乾的濕泥（`wet_x`＝`PUDDLE_X`、`wet_half`）暗而亮，跟原本的水窪同一條。遠處裂縫淡掉避免閃。
  - **段落 5 摔下來的泥**：東岸 `MUD_SPOTS` 一帶一大片不規則濕泥＋六滴泥點（`mud_blob_mesh()` 平的扇形 mesh，同一個 shader 整片是濕的），之前旁白說「摔在泥裡」但地上是石板。
  - 木架、吊樑＝整根舊木頭（`timber`）；煤車底下的木板、木閘門、車身＝一片片木板（`plank`）；河床碎石＝河道牆的方石、爛木頭＝舊木頭。
  - **縫裡斜照下來的光（D-163）不動**：所有新材質都是不透明、照常接影子；體積霧的光條照舊。
- 理由：第 3 章整章（觀察、假心臟、煤車、倒吊、轉角、掙脫戰）都在乾運河，是 12/31 版本最後、也是最長的一段，原本是素色方塊。全部用程序 shader＋方塊，跟 D-171、D-172 同一套，CI 能驗證；龜裂泥是唯一新 shader，因為河床是倒吊與煤車兩段鏡頭裡佔最大面積的東西。
- 影響：之後的地底城石頭場景（樓梯、白晝城街道）可以照用 `canal_wall_mat` 的參數與 `dry_mud`（乾掉的水溝、爛泥地）。`test_canal_art` 擋住舊水位線的高度、泥裡的落點、泥塊三角形朝上；流程測試 `_assert_canal_art` 檢查每個材質都換上了。

## D-172　2026-11-10　鐘院的美術：飯廳＝講究但東西都賣掉了的城主家、內室＝整面方石的機器房；石板沿用木板 shader

- 決策：
  - **飯廳**（城主的家，比酒館講究）：深色寬木板地（沿南北＝往內室的門延伸、擦得亮、很少磨損）；牆腳 1.1 m 磨平的方石（灰縫用淺色 `mortar_color`，預設的深灰縫像磚牆）＋冷白灰泥＋每 3 m 一根深色壁柱（**沒有斜撐、不燻黑**：這裡沒有爐火）；天花板深色木板＋四根橫樑落在東西牆的壁柱上；兩扇門直排木板＋深色門框；白燈有鏈子、鐵環、發白光的燈球（白晝城的燈，不投影子）；桌子厚桌面＋裙板＋方腳＋橫撐，椅子有靠背立柱與直條，**伊薩自己的椅子多扶手但同一套木頭**（他不是暴君）；粥鍋加鍋緣與提耳。
  - **原創細節：掛畫留下的白印**（`FADED_FRAMES`，五塊）：灰泥上比四周乾淨一點的長方形＋上緣一根釘子＝原本掛畫與掛毯的地方，東西都換成糧食了。呼應原作「三盤煮豆、一鍋稀粥、四個缺口不一樣的碗」，不用台詞說。白印只比四周亮約兩成（太白會像白紙或窗）。
  - **內室**：整面大方石（`stone_h` 99、`block_scale` 1.4，一排約 0.5 m）、地板與天花板錯縫大石板；全章唯一的暖光、鐘盤、細管、主椅都不動。牆上四塊紋路換成嵌在牆裡的石板＋深色石框（之前像貼在牆上的紙）。
  - **石板＝`plank_wood.gdshader` 關掉木紋**：新 uniform `grain_amount`（預設 1，酒館與柯德家不變；0＝沒有木紋與節疤，改成每片自己的大片斑駁＋細碎石粒）；`InteriorLook.flagstone(key, 顏色, 寬, opts)`（長＝寬 × 1.4 上下浮動）。試過街上的 `wet_cobble.gdshader`（關掉水窪與雪）：圓石的倒角與寬灰縫在室內像一顆顆麵包，調小倒角後灰縫變成不規則的黑帶，放棄。
- 理由：第 2 章整章都在鐘院（飯桌、內室、紋路、窗簾），是 12/31 版本裡停最久、白盒感最重的場景。全部用程序 shader＋方塊，跟 D-171 同一套、CI 能驗證。
- 影響：之後的石頭室內（樓梯底的門房、地底城的屋子）用 `flagstone()`＋`wall(stone_h 99)`。`test_bell_hall_art` 擋住常數之間的關係（橫樑落在壁柱上、白印在壁柱之間、不壓門框、離天花板有距離）。

## D-171　2026-11-10　室內美術的做法：世界座標木板 shader＋半木構牆的室內版（InteriorLook），先做酒館與柯德家

- 決策：
  - **新 shader `plank_wood.gdshader`**（世界座標，不靠 UV：CSGBox／BoxMesh 一面一張 UV，十幾公尺的地板會變成三公尺寬的板子）：每排接縫錯開、板長上下浮動、每片深淺與冷暖不同、木紋與偶爾的節疤、板縫凹下去（法線）；`along_z`（水平面的板子方向）、`vertical_planks`（門板、吧台正面直排）、`wear`（常走的地方磨亮、變滑）、`wet_spot`（門口一片雪水）；板寬拉大＝整根木頭（橫樑、桌腳、門框）。
  - **半木構 shader 加 `exterior`（預設 1＝室外不變）與 `soot`／`soot_top`／`soot_depth`**：室內牆不積雪、牆腳不濕，天花板下燻黑；鎮上房子、石拱的畫面不變（測試擋住預設值）。
  - **`InteriorLook`**（`src/world/interior_look.gd`）：`plank()`／`wall()`／`timber()`，同 key 共用材質；之後的室內（鐘院、樓梯底的門房…）照用。
  - **酒館**：地板（門口雪水）、天花板南北向木板、牆腳石塊＋灰泥＋木框斜撐、窗框窗櫺（六格）、門板與門框、壁爐石塊與爐口上方燻黑、桌子（桌面＋裙板＋方腳）、長凳與圓凳、晚餐桌上三碗湯＋麵包＋陶壺＋**入夜才點的蠟燭**（小點光）、吧台（直排木板正面＋亮面台面）、吧台後兩層瓶架、吊燈（鏈子＋燈罩，不投影子）、草蓆長椅。截圖旗標 `--pos=x,z`／`--face=<節點名>`／`--face-off`，CI 盤點截圖多 `38-ch1-tavern-table`。
  - **柯德家**（白晝城）：同一套材質，但**牆沒有木框**（地底城的房子是石頭砌的：牆腳石塊＋舊灰泥＋天花板下燻黑），木板地、天花板木板、門板窗板櫥櫃直排木板。
- 理由：酒館是第 1 章第一個新場景、停最久（中午、晚餐、畫地圖三段）；白盒的素色方塊在第一眼最傷。用程序 shader＋方塊，不需要模型或貼圖，跟鎮上的做法一致（D-066、D-070），CI 與 session 都能驗證。柯德家順手套上同一套，證明 InteriorLook 能重用。
- 影響：新增室內場景的木頭／牆一律用 InteriorLook；碗、瓶子這種小東西用 MeshInstance3D（不擋人、比 CSG 便宜），要擋人的才用 CSG／StaticBody。蠟燭與吊燈的燈罩不投影子（不然窗光會把燈罩的圓影投在牆上像汙漬）。

## D-170　2026-11-10　白天的霜橋鎮：死者名單（張數＝切片結果）、沒救出來的人蓋著毛毯、白天只留三成亮窗

- 決策：
  - **死者名單**（07 段落 4 原本寫的，第 38 輪白盒省略）：梨販攤西北邊、廣場中央石圈外立一塊木板（`DeadListBoard`，`DEAD_LIST_POS`，正面朝北偏西＝從北街走回廣場時迎面看到），貼滿紙、一張一個名字；**張數＝切片結果的死亡人數**（`dead_count`：跟收束時艾妲那句同一套條件 D-037，29／30／31／33）。紙上的字是墨痕（遠看像字，不用字型）。走近按互動鍵 → 對話 `ch1_dead_list`：數張數 →「攻略上只有一行：『霜橋鎮事件，死亡三十一人。』」→ 跟攻略比（一樣／少一兩張「那個人今天早上還活著」／多兩張「是車上那兩個人」）→ 北街那幾張（一張都沒有／一張／幾張）→ 席菈：「艾妲說，名字要有人寫下來。不然最後只剩一個數字。」→ `ch1.read_dead_list`。**可以不看**，不影響主線。
  - **攻略上的「死亡三十一人」是改編加的**：原作只有艾妲說「霜橋鎮死了三十一個人」。讓攻略也寫這個數字，玩家救人／護送的結果才有比較的對象（第一部的主題＝攻略死了）；救滿或車隊沒被打時「比攻略少一張」是整個切片的回報。
  - **沒救出來的受困者**：隔天早上已經挖出來（瓦礫推到旁邊），躺在原地、**蓋著一條暗紅褐的舊毛毯**（`RescueSite.set_aftermath`／`shroud_mesh`：頭、胸、腰、兩條腿、腳尖撐起的人形高度場，往街中間挪 0.7 m）；掉在一旁的提燈收掉。米白的布在雪地上幾乎看不見，所以用暗紅褐。全年齡：只有布的輪廓。
  - **白天的窗**：晚上亮的窗只留 30%（`DAY_LIT_KEEP`，`_day_window` 用位置雜湊、不動 `_rng`）——屋裡有人點燈說得通，但整條街都亮著像晚上。
- 理由：「白天看昨晚的現場」要有份量（D-151），名單和毛毯讓切片的選擇在第 1 章被看見；都用既有系統（text_if、InteractPrompt、RescueSite），成本低。
- 影響：開發旗標 `--level=frostbridge --day=ada_lamp --at=list --face=list`（名單前）、`--at=north --face=shroud`（北街的毛毯）；CI 盤點截圖 `37-ch1-dead-list`；字串 `CH1_DEAD_LIST_HINT`、`DLG_CH1_LIST_*`（ch1.csv）；`frostbridge.day_unlit_windows`；單元 `test_dead_list.gd`、主線流程測試 `_chapter1_day` 看名單、`_assert_day_town` 檢查名單張數／毛毯／亮窗。

## D-169　2026-11-10　第 3 章段落 4 的掙脫戰：爬上東岸、少一招（不衝撞）、打到跪下就把牠撞回運河、回到檢查點再來一次；閘道掛一盞小油燈

- 決策：
  - **在哪打**：割太早／太晚、煤沒壓住 → 牠甩開煤，從河床攀上**東岸**（諾恩站的那一側，翻過矮牆）。不讓諾恩跳下河床：岸上才看得到前兆、也才有席菈並肩；東岸寬 6 m、一邊是矮牆一邊是岩壁，窄而緊。落點沿運河照牠爬的位置、離諾恩不到 3.2 m 就往牠那一側讓開（`struggle_land_z`），不會一爬上來就壓在臉上。
  - **少一招**（08 寫的）：拿掉**衝撞**——岸太窄，衝撞幾乎每次撞牆跪地，戰鬥會變成「等牠自己撞牆」。招式輪替 `undertaker.pattern_struggle` ＝橫掃、下砸；只有第一階段（`Undertaker.struggle_mode`：打到一半生命也不進第二階段、不會丟鐵架），換難度後照樣。
  - **打到失衡**：失衡上限從 200 降到 140（`undertaker.struggle_stagger_max`）——這是失敗分支，不該比切片的 Boss 戰還長；跪下（失衡滿或撞到）或打掉一半生命都算贏（後者是保險）。跪下之後牠不再是敵人（席菈停手、戰鬥 HUD 收起來），停一秒、**席菈用肩膀把牠撞回運河**（翻過矮牆摔回河床）。
  - **回到煤車**：撞回去之後回到檢查點 `ch3_lured`（煤車、假心臟、牠的位置全部復原），開頭一行提示「過了一會兒。彌夏把煤重新裝上車，假心臟又把牠引回閘道口。再來一次。」、不再重講煤車的對話。不在原地把煤車、繩子、煤堆、假心臟一一復原：重讀檢查點最不容易漏狀態，黑一下也正好蓋過「重新裝煤」的時間。**戰鬥中倒下**也回到 `ch3_lured`（一樣不重講對話）。
  - **HUD 目標**：掙脫戰中換成「跟席菈一起把牠打到跪下」（關卡用 `Hud.override_objective` 暫時覆寫，不另開任務階段：失敗分支不該留在任務紀錄裡），打贏換回煤車那一句。
  - **彌夏**不打：掙脫戰中跑到諾恩背後（離牠那一側的反方向）、貼著外側岩壁躲著看（`misha_hide_spot`）。
  - **閘道的小油燈**：木架南邊橫樑下用 1.4 m 的鏈子垂下一盞暖色小油燈（投影子），一次解決第 48、49 輪截圖「煤堆、倒吊都太暗」；煤落地時跟著晃。跟轉角的油燈同一套做法（鐵件＋自發光燈罩＋暖色點光）。
- 理由：08 的設計（「早割、晚割 → 跟切片送葬者一樣的戰鬥，少一招，打到失衡再回到煤車」）；理想路線完全不打，戰鬥是失敗的代價，要短、要能贏，但不能讓玩家覺得「失敗比較好玩」。
- 影響：`Undertaker.begin_struggle()`／`struggle_mode`、`EnemyActor.set_facing()`；`canal.gd` 的 `_climb_out`／`finish_climb`／`_begin_struggle`／`_update_struggle`／`_struggle_kneel`／`_push_back_into_canal`／`_struggle_retry`、`STRUGGLE_META`、`_build_sluice_lamp`；`ch3.csv` 三句；旗標 `ch3.struggle_won`（檢查點會蓋掉，只在當次有效）；截圖 `--canal-at=struggle`、CI 盤點截圖 `36-ch3-struggle`。

## D-168　2026-11-10　第 3 章段落 7「轉角」＝第一部前半（12/31 版本）的結尾：牆角、兩個選項、湯匙那一句、結尾卡、完成後讀檔

- 決策：
  - **轉角在哪**：乾運河東岸回程路上加一道從外側岩壁伸出來的舊牆（擋住半個岸），牆端掛一盞暖色小油燈（回程唯一的暖光、投影子）；席菈在牆角的另一邊等，站好了就看著諾恩走過來。不另做一段回白晝城的路（少而精，12/31 前把時間留給掙脫戰鬥與打磨）。
  - **彌夏先走**：原作「她離開後」——段落 6 講完她往南走、過了牆角就不見（`misha_gone`）；檢查點 `ch3_map` 之後都不在。
  - **兩個選項**（Jacky 喜歡有份量的關係）：「你打算偷偷換成自己？」→「是我敲的鐘。」（原作）／不說話（「我沒有說不是。」）；「你最好不要鬆手」→不敢動（原作）／「我沒有鬆手。」（字面上他真的沒鬆開繩子；她的手往下壓了一點，像在試繩結）。記 `ch3.corner_answer`、`ch3.collar_reply`，第二部用；拉衣領一律記 `ch3.collar_fixed`（08 寫的 `ch3_collar`）。
  - **原作最後一句**「別替我決定，我比較喜歡一個死掉的你。」照意思寫成「別替我決定。好像我會比較喜歡一個死掉的你一樣。」（原句少了「好像」很容易讀反）。第 1 章替她拿過湯匙（`ch1.sheila_soup_helped`）的話前面多一句「上次是一支湯匙，這次是主椅。」（08 寫「湯」，改成湯匙：第 1 章她是用湯匙柄敲你的手背）；不收圖的話「我沒回答」那句多半句圖壓在胸口。
  - **對話用固定鏡頭**：她走近到 0.7 m 時過肩鏡頭會把她淡掉（D-115），改成從河道那一側斜斜看兩個人的 `CornerCam`；抓住領口那一句她走近、鬆開手那一句退回一點、換班鐘聲是遠遠的一聲 `bell`。
  - **日記多一條記憶「轉角的衣領」**（殘留「有人替我把衣領拉好過。是誰，想不起來了。」）：跟「乾運河的泥」一樣，之後可以被重現當代價付掉。
  - **結尾**：講完 → 第 3 章完成（任務完成本來就會自動存檔，D-161）→ 2.4 秒後重用章節卡顯示「第一部　死去的攻略」「前半　完」→ 回標題。存檔的檢查點還是 `ch3_map`，所以**標題的「繼續」**會回到乾運河，`ch3_main` 已完成 → 站在牆角、橫幅「第一部前半完。下一章還在製作中。」，不會再講一次。
- 理由：08 的段落 7 是整個 12/31 版本的最後一場戲，原作就是兩個人站著講話；選項只改諾恩怎麼回應、不改她說什麼，保住原作的節奏又讓玩家參與。
- 影響：`canal.gd` 段落 7 一節（`CORNER_*`、`_build_corner`、`_sheila_waits`、`talk_corner`、`_on_corner_end`、`play_end_card`、`end_card_done`、`_settle_after_clapper`）；`Sheila.face_toward`／`facing_yaw`；對話 `ch3_corner`；日記 `ch3_collar`；截圖 `--canal-at=corner|end`、CI 盤點截圖 `34-ch3-corner`、`35-part1-end`；流程測試 `_chapter3_corner`。之後加第 4 章時：`ch3_main` 的 `on_complete` 加 `start_quest`＋`chapter`、`CHAPTER_CHAIN` 加一列，`_on_corner_end` 的結尾卡改成第 4 章章節卡。

## D-167　2026-11-09　第 3 章段落 5「倒吊」與段落 6「彌夏的圖」：拉繩子的手感、固定鏡頭、第一次笑記成記憶、圖一定會被塞進手裡

- 決策：
  - **拉繩子＝純邏輯 `HangRope`**：席菈的擺盪是有阻尼的單擺（自然週期約 3.5 秒）＋一個固定的外力（壓在煤堆下的牠在掙扎，兩個週期疊在一起，抓得到節奏但不完全重複）；玩家**按住互動鍵＝拉住**、**左右（A／D、左搖桿）＝把她往那一邊推**。離正中 0.35 以內才切得到，一直穩住 5 秒切開；放開她就往下滑、進度慢慢退；擺過頭撞到鐵架扣 12% 進度、反彈一半。**不會失敗重來**（原作這一段不是會死的地方；「簡單但吃技巧」＝穩得好就快）。原本 08 寫「重用切片抓取時的掙扎輸入」，掙扎是連按，跟「拉住＋修正擺盪」的手感不同，所以另外做。
  - **倒吊時換固定鏡頭**：站在東岸的過肩鏡頭往下看會被岸緣擋住（截圖看過：只看得到諾恩和彌夏），改成從東岸邊上斜斜往下看閘道的 `HangCam`；擺盪的軸跟著鏡頭的水平方向，左右晃就是畫面左右。摔進泥裡那一下換成從頭頂那一側往下看三個人並排仰躺。
  - **席菈怎麼倒吊**：真的把席菈（不是另做一個人偶）停用、每幀對齊到繩子末端倒過來的掛點，所以之後換成 Jacky 的正式模型也一樣；繩子從諾恩手上拉到閘道木架南邊的橫樑、再垂下去綁在她腰上。
  - **「諾恩第一次笑」寫成日記的一條記憶**（`ch3_first_laugh`「乾運河的泥」，鐘舌拿到才出現）：08 寫「日記寫一條」，日記本來就是記憶條目，這一條之後可以被重現當成代價付掉（殘留「泥的味道還在。為什麼笑，想不起來了。」）——跟記憶代價的主題接得上。結尾補原作那句「那是敲鐘以來，我第一次笑。」。
  - **段落 6 的觸發**：鐘舌拿到之後往南（回程）走過閘道南邊 7 m 那條線，彌夏拉住諾恩、席菈走在前面幾步。選項「收下／不收」照 08：不收的話她把手指一根根扳開塞進去（圖一定會拿到），只記 `ch3.map_accepted`（第二部用）。「燒城」照第 2 章紋路的白話寫成「燒掉整座城的命令」，「九息」照對照表寫「九秒」。紙角戴眼鏡的塗鴉那句「前一晚跟她說過前世的自己戴」遊戲裡沒有演那一晚（段落 3 的「給我一晚」），先照原作留著當暗示。
  - 新階段：`hang` 完成 → `misha_map`（檢查點 `ch3_clapper`，重來站在摔倒的地方、面向回程）→ `corner`（檢查點 `ch3_map`，段落 7 待續）。
- 理由：段落 5 是席菈主線第一次往前（段落 7 她會說「我掛在那根繩子下面的時候……你最好不要鬆手」），所以「拉住、別鬆手」要是玩家手上真的在做的事；做成會失敗的 QTE 反而會打斷這一刻。
- 影響：玩家多一個 `held_in_place`（關卡要他站著不動，移動／閃避／攻擊都不吃）。截圖 `--canal-at=hang|mud|map`、CI 盤點截圖 `31-ch3-hang`、`32-ch3-mud`、`33-ch3-map`。流程測試 `_chapter3_hang`、`_chapter3_map`（兩條路線），單元 `test_hang_rope`。

## D-166　2026-11-09　第 3 章段落 4「煤車」：閘道與煤車的擺法、割繩子的時機、失敗先回檢查點

- 決策：
  - **閘道＝河道裡兩道矮石牆**（從河床算高 2 m，比送葬者矮）：原本第 45 輪的石墩一路高到岸上 2.2 m，站在岸上完全看不到閘道裡面，時機題變成猜謎。石牆之間 |x| ≤ 1 m，牠穿過閘道時先往石牆中間的出口走（`steer_through_sluice`，目標在閘道另一邊才轉）。
  - **煤車在閘道正上方**：兩岸各兩根木柱撐兩根橫樑、樑上鋪木板，煤車停在木板南緣、微微往南斜，車尾一條繩子拉到東岸北側木柱的繩樁（原作「割斷上方堆煤車的繩索。煤傾下去」）。煤落在閘道正中（`CART_Z = SLUICE_Z`），正好一道縫的光照在那裡（陷阱在哪一眼看得到）。
  - **怎麼讓牠走到煤車下**：照段落 3 的規則——東岸多一個第 3 點（閘道另一邊，z -34），把假心臟垂下去牠就穿過閘道走過去；走過頭可以把心臟收上來改垂第 2 點，把牠拉回來（往南走時太早／太晚前後顛倒，`CoalDrop` 本來就吃方向）。割繩子的位置在東岸北側木柱旁（離第 2、3 點都 2.5 m 以上，互動鍵不會搶）。
  - **時機**：割的那一刻就照 `CoalDrop` 判定（煤 0.5 秒後落地時牠在哪），牠走路的速度從每幀實際位移算（`walk_vz`）。按住重現 → 牠停下來轉向諾恩（速度 0）→ 在正下方割一定壓住（段落 3 的規則延伸成解法，不另外寫說明）。
  - **失敗先回檢查點**：太早／太晚 → 煤落地、牠甩一下轉向諾恩、提示「太早了／太晚了——牠掙脫了」→ 4.5 秒後回到 `ch3_lured`（段落 3 結束的檢查點，08 寫的「失敗回到段落 3 的檢查點」）。重來時不再重講煤車的對話（記在 GameSession 物件的 meta，不進存檔；試過 static var，會讓整個關卡腳本在結束時漏掉）。08 寫的「掙脫 → 跟切片送葬者一樣的戰鬥（少一招）→ 打到失衡再回煤車」**下一輪做**，插在「牠掙脫」和「回檢查點」之間。
  - 目標指引：新的 `MarkerPoint`（`src/world/marker_point.gd`，`is_available()` 問關卡 `marker_available(query)`），同一個階段 `nearest:CartTask` 依情況指向「放心臟的點」（在牠的另一邊）或「繩子」。
  - 壓住之後：新階段 `hang`（檢查點 `ch3_pinned`，marker 指向牠，done_when `ch3.clapper_taken` 還沒有人設）＝段落 5 倒吊待續。
- 理由：時機題要看得到才公平；用同一顆假心臟、同一條重現規則把牠帶到煤車下，不用新系統、玩家用段落 3 學到的東西解段落 4。失敗先回檢查點讓理想路線先完整可玩，戰鬥分支是加法。
- 影響：`canal.gd` 的 `_build_sluice()` 改寫（石墩變矮、多了木架／煤車／繩子／煤堆）、`DECOY_ZS` 多一點（`LURE_SPOTS` 3、`CART_SPOTS` [2, 3]）、`reached` 4 格；新對話 `ch3_cart_plan`、i18n 10 條、任務多一個階段、`Game.CHECKPOINT_LEVELS` 多 `ch3_pinned`。截圖 `--canal-at=cart|pinned`，CI 盤點截圖 `30-ch3-pinned`。測試：流程 `_chapter3_cart`（兩條路線：照走路時機割／先割太早回檢查點再用重現）、單元 `test_canal_sluice`。

## D-165　2026-11-09　第 3 章段落 3「假心臟」：一顆假心臟、三個點一段一段帶、重現會讓牠轉向諾恩；段落 4 的時機判定

- 決策：
  - **只有一顆假心臟**（原作「彌夏依照那個速度，做出一枚跳動的假心」），08 的「放在閘道沿線的三個位置」改成：東岸三個點（`DecoySpot0～2`，矮牆上一根小木樁），站上去按互動鍵用繩子把它**垂到東牆腳的河床上**，再按一次**收上來**、換下一點。玩家不下河床（岸邊矮牆照舊擋人）。
  - **距離決定順序，不是寫死順序**：送葬者用 `HeartTargets`（聽得到 9 m）跟著聽起來最近的心跳。第 0 點離吊樑 3.5 m；第 1、2 點從吊樑都超過 9 m（垂下去會提示「牠沒有動。太遠了，牠聽不到。」）。牠走到假心臟旁邊 0.9 m 就停下來聽，不會踩壞它——收上來換下一點，一段一段帶到閘道口（z ≤ `SLUICE_REACH_Z`）＝ `ch3.decoy_done`。第一次聽到就**鬆開鏈子掉到河床上**（0.6 秒補間＋落地悶響），之後還是不在敵人名單裡（段落 4 失敗分支才開打）。
  - **重現＝心跳變快**：乾運河裡沒有可重現的物件，所以「按住重現鍵」本身就算諾恩在重現（`noen_restoring()`）；牠醒著時按住 → 牠停下來轉向諾恩（有效距離 ×0.5，所以只要在附近就比假心臟近），第一次提示「重現的時候我的心跳會變快——牠聽得到」（`ch3.heard_noen`），同時諾恩自己的心跳聲每 0.48 秒一聲。只會讓牠停下來看你，**不會讓牠走過來**：諾恩在岸上，走過來只會撞牆，而且會變成不用假心臟也能帶路的捷徑。這個「讓牠停住」正好是段落 4 煤車的技巧（停在正下方一定壓得住）。
  - 流程：找到速度 → 攻略筆記提示 → 4.3 秒後、彌夏在 3.2 m 內 → 對話 `ch3_decoy_make`（「第五夜」，跳過也算拿到）→ `ch3.decoy_received` → 新階段 `lure`（檢查點 `ch3_decoy`，marker `nearest:DecoySpot`：`DecoySpot.is_available()` 問關卡 `spot_actionable()`，所以指引只指向現在能動手的點）→ `coal_cart`（檢查點 `ch3_lured`，marker `node:SluiceBeam`，done_when `ch3.cart_dropped` 還沒有人設）。`ch3_lured` 重來時送葬者已經站在閘道口的河床上。
  - **段落 4 的時機判定先寫好純邏輯 `CoalDrop`**：看「煤落下那一刻（0.5 秒後）牠在哪裡」，離煤車正下方 0.8 m 內＝壓住，還沒走到＝太早、走過頭＝太晚。
- 理由：一顆假心臟、拉上放下比「三顆一次放好」更貼原作，也讓每一段都有一個小動作（垂、等、收、走、垂）；距離規則讓玩家自己發現「要一段一段」，不用寫說明。重現讓牠停住而不是追過來，保留 08「不是禁止，是自己會發現的規則」，又不會破壞解謎。
- 影響：新檔 `data/dialogue/ch3_decoy_make.json`、`src/world/decoy_spot.gd`、`src/core/coal_drop.gd`、`tests/unit/test_coal_drop.gd`；`ch3_main` 多兩個階段；`Game.CHECKPOINT_LEVELS` 多 `ch3_decoy`／`ch3_lured`；截圖 `--canal-at=heart`（從西岸往下看，東岸看會被岸緣擋住）、CI 盤點 `29-ch3-heart`；主線流程測試 `_chapter3_decoy()`。

## D-164　2026-11-09　第 3 章段落 2「趴在水溝裡（觀察）」：選節奏、RhythmTrial 判定、觀察提示音

- 決策：
  - **觀察＝選節奏**：吊樑旁的東岸一道淺水溝（`Drain`），走進去三個人並排趴下（Puppet 新增趴姿 `lying = "front"`）→ 對話 `ch3_rhythm`：席菈「多快？」，六種節奏（很慢 40／慢一點 56／不快不慢 72／快一點 96／很快 120／忽快忽慢，每分鐘幾下）。**試過的從選項消失**，「不快不慢」一直都在（對話驗證規則要求一個沒有條件的選項，而且試了就結束迴圈）。
  - **判定在純邏輯類別 `RhythmTrial`**：離人的心跳（72）差 8 以內轉頭、26 以內偏頭、其他不動；忽快忽慢一律不動（「牠跟的不是聲音」）。只有一種會轉頭；慢一點／快一點都偏頭，玩家可以從兩邊夾出答案（簡單但要想）。
  - **對話與關卡怎麼接**：選項的 `do` 記 `ch3.tempo_<id>`、`ch3.last_tempo`、`ch3.rhythm_tries`；關卡聽 `DialogueRunner.line_shown`，在「敲」那一句（`DLG_CH3_RHY_KNOCK`）呼叫 `RhythmTrial.try_last()` 把結果寫進 `ch3.react`，下一句用 `text_if` 換旁白、選項用 `if` 決定有沒有「就是這個速度。」（沒轉頭只有「再試一次。」）。送葬者的動作同時演：偏頭＝上半身繞 Z 歪 13° 又回來、轉頭＝上半身轉 62° 對著銅片停住、胸口銅光改跟敲的速度亮；不規則＝鏈子抖一下。
  - **觀察提示音（D-143）**：轉頭之前 0.7 秒鏈子先響（`chain_creak`），設定頁「遊戲」分組新開關「觀察提示音」（`Settings.observe_cue`，預設開）。只有轉頭前會響，偏頭、不動都不響（不誤導）。
  - 找到之後 `ch3.rhythm_found` → 攻略筆記空白條目變成證實；**證實的文字不寫死「第七次」**（原作是第七次，但玩家可能兩三次就找到），改成「不快不慢，跟人的心跳一樣。這是我們趴在水溝裡自己看到的。」主線新階段 `decoy`（檢查點 `ch3_rhythm`，marker `node:Misha`，done_when `ch3.decoy_done` 還沒有人設）→ 段落 3 待續。
  - 「按鍵自己敲出來」的模式先不做（要另外的輸入畫面、跟對話的確認鍵衝突）；`RhythmTrial.reaction_for_bpm()` 已經吃任意速度，之後要做就是算按鍵間隔。
- 理由：08 的設計是「玩家選節奏、每次反應不同、自己找到速度」；選項版能在一輪內做完並完整測試，判定與演出分開也方便之後換成按鍵版。水溝第一版只有 0.9 m 寬，橫著趴的人整個伸出溝外，改成 2.3 m 寬、三個人沿 Z 並排、頭朝運河。
- 影響：新檔 `src/core/rhythm_trial.gd`、`data/dialogue/ch3_rhythm.json`、`tests/unit/test_rhythm_trial.gd`；音效 `cloth_knock`、`chain_creak`、`canal_ambience`（乾運河 10 秒循環環境音）；截圖 `--canal-at=drain|turn`、CI 盤點 `28-ch3-drain`。

## D-163　2026-11-09　第 3 章開頭：新關卡乾運河（只有這裡有影子）、送葬者掛在吊樑下、攻略筆記的「空白」條目

- 決策：
  - 第 2 章看完眼睛 → `ch2_main` 的 on_complete 開 `ch3_main`（章節 `ch3`、檢查點 `ch3_start` 自動存檔）→ 鐘院播第 3 章章節卡（`bell_hall.to_chapter3()`）→ 新關卡 `canal`。第 2 章完成之後重來是在乾運河，不再回鐘院。
  - **乾運河的光**：頭頂一排排石樑（間距 2.4 m、縫 0.85 m），一盞**投影子的方向光**從縫裡斜斜照下來（俯角 57°），光切成一條條。這是地底城「只有油燈投影子」（D-154）的**第一個例外**——原作的理由：這裡離穹頂最遠，光是斜的。體積霧、SSAO 開著。
  - **掛著的送葬者**：重用 `Undertaker` 的外觀，但 `PROCESS_MODE_DISABLED`、移出 `enemies`／`damageable` 群組（不會被鎖定、不打），掛在一根橫跨運河的舊吊樑下（樑高 2.6 m、鏈子 1 m，腳懸在河床上方三公尺多），整個掛點慢慢晃。胸口的鐘舌＝一根自己發光的銅棒＋小銅光，**亮度照心跳（一次兩拍，每分鐘 46 下）**——伏筆段落 2「牠跟著心跳走」。另加一盞跟斜光同方向、不投影子的窄聚光，讓牠剛好落在一道縫的光裡。原作是「掛在乾涸的運河下」；本來放在橋底，截圖整隻在橋的影子裡、又被河道牆緣擋住，從岸上完全看不到，改成吊樑。
  - **攻略筆記的空白條目**：`notes.json` 新欄位 `"blank": true`、新效果 `guide_blank`、新狀態 `blank`（日記小標「攻略沒有寫」）。空白條目不能標我不確定、不會被推翻，只照 `confirmed_when` 變成證實，證實後日記多一行 `GUIDE_<ID>_CONFIRMED`（自己觀察到的）。第 1 章畫地圖時寫下的是 `GuideNotes.remembered_ids()`（不含空白）。第一條：`clapper_heartbeat`「鐘舌在一隻送葬者的胸口。牠跟著什麼走？多快？」，證實條件 `ch3.rhythm_found`（段落 2 設）。
  - 段落 1 的選項只有「不行。」與「……」（記 `ch3.refused_lure`），沉默時席菈多一句「你不說話，我就當你在想。」；兩條都接「那你有什麼方案？」→（我說不出來。）。跳過對話也照樣寫下空白條目、進下一階段。
  - 岸邊的矮牆 0.45 m（擋人的碰撞 1.8 m）：0.8 m 時從岸上看不到河道裡的東西。對話開始時鏡頭轉向吊樑、往下看（pitch -0.55）。
- 理由：08 的段落 1 寫「攻略筆記這一條是空白」，原本的狀態（確定／我不確定／被推翻／證實）都是「攻略寫了什麼」，沒有「攻略沒寫」；段落 2 要讓玩家自己寫下第一條證實的事，空白條目就是那個位置。光的例外照原作，也讓第 3 章的第一眼跟白晝城完全不同。
- 影響：`canal.gd`／`canal.tscn`、`ch3_main.json`、`ch3_bank.json`、`i18n/ch3.csv`（登記在 project.godot 與 verify_package）、`GuideNotes`（`BLANK`、`write_blank`、`remembered_ids`、`is_blank_entry`、`confirmed_key`）、`StoryLogic`（`guide_blank`）、`JournalView`、`GameSession.MAIN_QUESTS`／`CHAPTER_CHAIN`、`Game.LEVELS`／`CHECKPOINT_LEVELS`、bell_hall 的過場結束、CI 盤點截圖 `26-ch3-canal`、`27-ch3-bank`、測試（單元＋主線流程延伸到第 3 章段落 1）。

## D-162　2026-11-09　諾恩的幾何只放在 SELF_LAYER（修正 D-118）；一百七十二階的油燈影子打開

- 決策：`PlayerController._mark_self_layer()` 與之後加到身上的幾何改成 `layers = SELF_LAYER`（取代原本的 `|=`）。一百七十二階 `_brighten_lamp()` 的 `shadow_enabled` 改回 true。
- 理由：`Light3D.shadow_caster_mask` 的判斷是「物件的任何一層在遮罩裡就投影」；D-118 讓諾恩同時留在第 1 層，遮罩又包含第 1 層，所以提燈／油燈照樣被諾恩自己擋住——NEXT 記了好幾輪的「樓梯右側一整條黑帶」「內室右半邊很暗」「白晝城右後方一片楔形」都是這個（第 44 輪內室前後對照：地上那一大片黑楔形消失）。鏡頭的 `cull_mask`、燈的 `light_cull_mask`、月光的 `shadow_caster_mask` 預設都是全部 20 層，所以只放 SELF_LAYER 一樣看得到、照得到、投月光與路燈的影子；倒影探針只拍 `REFLECT_LAYER`，諾恩本來就不在裡面。
- 影響：`player.gd`、`stairs.gd`、`test_lantern_shadow`。之後新的「某個光不要照出某個東西的影子」照這個做：那個東西只放在專用的層。

　第 2 章段落 5：窗簾在鐘院內室東牆（不是飯廳）；窗外的眼睛是一張程序 shader；問辦法的對話是「問過就消失」的選單；第 2 章完成會自動存檔

- 決策：窗簾從飯廳西牆搬到**內室東牆的高窗**（寬 2.8 m、窗台 1.2 m、窗頂 4.6 m，銅框十字窗櫺、兩半有直褶的厚布）。牆上的紋路看完，伊薩自己走到窗邊（`ISA_WINDOW`）等；諾恩走到他 2.2 m 內 → 對話 `ch2_curtain`：席菈「把人撤走。」→ 伊薩「七千多人，出口一次只能過兩個……登記還在」→ 諾恩的選單：「那毀掉鐘。」（→「深層的東西就會上來。」）／「地上的王國呢？叫他們派人來。」（→「十七年前，他們說等援軍來就能停。」「援軍沒有來。」）／「……」；問過的那條會消失，「……」隨時可以選 → 伊薩「你們想得到的，我十七年來都想過。」「你們該親眼看看。」→ 過場 `ch2_eye`（可跳過）：拉開窗簾 → 「玻璃之外，一堵黑色的牆動了一下。」（低沉的隆隆聲 `deep_rumble`）→「那不是牆。」（眼睛慢慢睜開）→「那是一隻眼睛，正在隔著屏障看我們。」（瞳孔收成一道縫）→「我認得它。」→「最終章的災厄，吞日獸。」→ 九支滿級隊伍 → 「我們只有一個不能握劍的騎士，一個鐘匠，和一個害死三十一個人的高手。」→ `ch2.curtain_opened` → `ch2_main` 完成（`ch2.complete`）→ 待續（第 3 章下一輪做）。
- 第一眼：窗外兩層不受燈光影響的四邊形——前面一層疊加的冷光六角網格（屏障，`barrier_grid.gdshader`，一道道斜斜掃過的光、大塊明暗）、後面一整面黑色皺褶皮膚＋杏仁形眼眶＋暗金放射紋的虹膜＋直立收縮的瞳孔＋反射屏障冷光的濕亮（`deep_eye.gdshader`，動作由腳本推 `eye_open`／`pupil`／`shift`）。打開窗簾時一盞不投影子的冷光照進來（全章唯一的暖光房間裡，第一次有冷光）。兩個 shader 都 `fog_disabled`：關卡的體積霧（QualityPreset 開的預設密度）會把黑牆洗成灰的（第 44 輪第一張截圖）。
- 「援軍」這個問題是新加的（原作只有撤離、毀掉鐘兩條）：08 寫「對話選項＝玩家想得到的方案」，玩家看完紋路最自然的下一個念頭就是「地上的人呢」，答案在紋路第 2 塊已經講過（地上沒有人來），這裡讓伊薩親口說一次。沒有加「換人坐主椅」：那是第 3 章彌夏的方案，不在這裡用掉。
- 存檔：主線任務完成也自動存檔（`GameSession._on_quest_completed`）。第 2 章是目前最後一章，沒有下一章的第一個檢查點；不存的話看完眼睛再重來／讀檔會回到窗簾之前。之後第 3 章接上時，`ch2_main` 的 on_complete 照 D-149 加 `start_quest`／`chapter`，舊存檔由 `CHAPTER_CHAIN` 補開。
- 理由：原作伊薩是在內室講完紋路之後拉開窗簾的；走回飯廳會打斷「看完紋路 → 問辦法 → 被擋下 → 看見」這一口氣，也浪費內室的暖光（冷光從窗外照進暖色房間的對比是這一段的第一眼）。
- 影響：`bell_hall.gd` 的「段落 5」一節（`WINDOW_*`、`ISA_WINDOW`、`NOEN_WINDOW`、`_build_window()`、`curtain_mesh()`、`_set_curtain()`、`_reveal_eye()`、`talk_curtain()`、`_play_eye_cutscene()`、`eye_open`／`pupil`／`wall_shift`、鏡頭 `EyeCamWindow`／`EyeCamClose`／`EyeCamGroup`）；內室東牆拆成四段；新 shader `src/world/deep_eye.gdshader`、`src/world/barrier_grid.gdshader`；新音效 `deep_rumble`；對話 `ch2_curtain`、過場 `ch2_eye`；開發旗標 `--hall-at=curtain|eye [--hall-shot=N]|eye-after`；CI 盤點截圖 `24-ch2-eye`、`25-ch2-eye-after`；主線流程測試 `_chapter2_curtain()`／`_assert_window()`。

## D-160　2026-11-09　第 2 章段落 4：牆上的紋路是 4 塊可互動的浮雕，順序不限，看完第 4 塊才接諾恩的獨白

- 決策：內室西牆 4 塊浮雕白盒，站到前面（1.5 m 內）按互動 → 伊薩解說那一塊（十七年前的封印／壽命轉成屏障、地上沒有人來／每三年有人坐主椅、黎歐三個月前接了位置／拆下鐘舌之後鐘不再控制一次收多少、敲滿九聲＝王國留下的緊急命令：燒掉整座城），看過的那塊刻痕亮起暖光。**順序不限**；4 塊都看完（不管最後是哪一塊）才接諾恩的獨白「我終於理解，自己的攻略為什麼那麼有效。／怪物不是被玩家燒死的。／是整座城替玩家付了那一擊的費用。」→ `ch2.read_wall_carvings`（跳過也算）→ 攻略筆記「焚城路線最快」被推翻 → 檢查點 `ch2_carvings` → 段落 5 窗簾待續。
- 用詞：原作「緊急焚城命令」「限流」改成白話（「王國留下的緊急命令：燒掉整座城」「鐘就不再控制一次收多少了」）；「援軍」改成「地上派人來救」。照 D-035／06。
- 理由：08 寫的是 4 塊可互動浮雕；原作是伊薩一路講下來，拆成 4 塊讓玩家自己走過去、自己把四件事拼起來，最後那句是玩家「看完」得到的，不是被告知的。限定順序會讓人覺得在找正確的那塊，所以不限。
- 影響：`bell_hall.gd` 的 `CARVING_X`／`READ_RANGE`／`nearest_carving()`／`read_carving(i)`／`carvings_read()`／`carving_lit(i)`；對話 `ch2_carving_0～3`、`ch2_carvings_end`；`ch2_main` 的 `curtain` 階段（done_when `ch2.curtain_opened` 還沒有人設）；開發旗標 `--hall-at=carved`；CI 盤點截圖 `23-ch2-carvings`。看穿伊薩的提示只在飯桌那兩個階段出現（進內室後不再搶互動提示）。

## D-159　2026-11-09　第 2 章段落 3：鐘院內室蓋在同一個關卡的北邊；全章唯一的暖光用「內室氣氛」切換；黎歐的過場可跳過

- 決策：內室蓋在 `bell_hall` 飯廳北牆後面（x -4.5～4.5、z -5.3～-14.3、高 6.5 m），北牆留門洞（門是轉軸 `InnerDoor`，`InnerDoorBlock` 碰撞在推開前擋住）。走到門前 → 門的吱聲 → 黑一下 → 大家站進內室（彌夏停在門口）→ 過場 `ch2_leo`（可跳過；狀態只靠 on_end 的 `ch2.leo_met`，跳過也一樣）→ 檢查點 `ch2_inner`。
- 第一眼：牆上的巨大鐘盤（銅框、深色盤面、內圈、中心軸、**九道微微發光的刻痕**＝九聲）、主椅（銅椅，面向門）、十二條細管從椅背垂下再接進鐘盤，管子裡一團團暖色的光慢慢往鐘盤流（新 shader `life_tube.gdshader`：UV.y＝從椅背量起的公尺數、UV2.x＝每條的相位）。四盞暖光都不投影子（還在白晝城：只有油燈投影子）。環境只有一個，所以用 `mood`（0～1）在諾恩走進內室時把背景、環境光換成暗暖色、把飯廳天花板的白燈關小（不投影子的光會穿牆），走回飯廳就換回來。
- 黎歐用程序人偶的新坐姿 `Puppet.sitting`（骨盆 0.5 m、大腿往前、小腿垂直、手放在膝上、外套下擺蓋在腿上）。彌夏的一巴掌用新的程序音效 `slap`（不重：很短的帶通噪音＋一點肉聲），不用鐘錘的打擊聲。
- 理由：第 2 章幾乎都在這座建築裡（D-157），同一個關卡的門洞讓玩家「推門進去」的空間感成立，也讓之後的窗簾（段落 5）可以回到飯廳；換關卡會多一次讀取、也要再同步一次大家的位置。
- 影響：`bell_hall.gd` 的「段落 3」一節（`enter_inner_room()`、`_place_inner(after)`、`INNER_SPOTS`、`mood`／`_apply_mood()`、`_build_inner_room()`／`_build_dial()`／`_build_main_seat()`／`_build_tubes()`／`tube_ends(i)`、過場鏡頭 `InnerCam*`）；`ch2_main` 多 `meet_leo` → `wall_carvings`；`Game.CHECKPOINT_LEVELS` 加 `ch2_inner`；開發旗標 `--hall-at=inner [--hall-shot=N]`、`--hall-at=leo`；CI 盤點截圖 `21-ch2-inner`、`22-ch2-inner-after`。

## D-158　2026-11-09　第 2 章段落 1～2：看穿伊薩用「劃字小卡」、劃線時間固定；段落 2 由「看穿劃完放開」或「沉默 12 秒」開始；道歉選項

- 決策：坐下吃飯（`ch2_table` 講完）之後，伊薩附近出現提示「按住 V　看穿伊薩」。按住時頭旁跳出一張跟看穿小卡同外觀的小卡 `StrikeCard`：先是攻略的字（「食歲的僭王」「弱點：心臟」），按住 1 秒後**一個字一個字被劃掉**（固定 1.4 秒劃完，不照字數——英文字數是中文的四倍），劃完換成暖色的真話「伊薩，城主。右腿金屬支架。問了席菈的手。」並設 `ch2.usurper_crossed_out`（攻略筆記「城主＝食歲的僭王」被推翻）。只在按住時往前、放開停住；讀檔後維持劃完的樣子。
- 段落 2「他自願的」：看穿劃完、放開之後開始；**沒去看穿的玩家**坐著沉默 12 秒也會開始（原作「伊薩沒有立刻回答」的停頓，不讓人卡住）。選項「鐘的事……是我做的。對不起。」／（什麼都沒說）記 `ch2.noen_apologized`（08 說的第 5 章伊薩交出城主印時的台詞）；伊薩回「……先吃吧。湯要涼了。」→「桌上的湯慢慢涼了。」→「跟我來。妳該見他一面。」→ 檢查點 `ch2_volunteer` → 鐘院內室待續。
- 刪除線自己畫（Label＋ColorRect）：RichTextLabel 的 `[s]` 在截圖裡畫不出線（字型子集的刪除線粗細大概是 0），第一次截圖只看到字變淡。
- 理由：08 定的「看穿第一次看錯」是第 2 章唯一的新玩法，要在按住的手感裡發生（不是過場）；D-143 說不給「我殺過你四百多次」的選項，所以原作那句獨白也不放進飯桌的對話，讓劃字自己說。
- 影響：`src/ui/strike_card.gd`；`bell_hall.gd` 的 `update_isa_insight()`、`interact_hint()`、`SILENCE_SEC`、`silence`；對話 `ch2_volunteer`；開發旗標 `--hall-at=seated`、`--hall-insight=秒`；CI 盤點截圖 `20-ch2-isa-insight`。「桌上的湯慢慢涼了」：粥鍋上幾縷熱氣（`PorridgeSteam`），坐下之後 24 秒內淡到 0.12，「他自願的」講完就是涼的（03b132a）。

## D-157　2026-11-09　第 1 章在鐘院門口結束；第 2 章「城主的飯桌」另開關卡「鐘院」（bell_hall）

- 決策：白晝城街尾走到鐘院門口（`BELL_YARD_POS`）→ `ch1.reached_bell_yard` → `ch1_main` 完成（on_complete：`ch1.complete`、章節 `ch2`、開 `ch2_main`，照 D-149）→ 第 2 章章節卡「第二章　城主的飯桌」→ 換到新關卡 `bell_hall`。第 2 章幾乎都在鐘院這座建築裡（城主的飯廳 → 鐘院內室的主椅與鐘盤 → 牆上的紋路 → 窗簾後面的眼睛），所以另開關卡，不再往 daylight 裡塞（daylight 已經 1000 行）。飯廳 10×10 公尺：長桌、三盤煮豆、一鍋稀粥、四個缺口不一樣的碗（碗緣一小塊深色）、北牆鐵條釘著的內室門（段落 3）、西牆拉著的窗簾（段落 5）。還在白晝城裡：照第 1 章的規則只有油燈投影子、接地陰影拿掉、天花板一盞不投影子的白燈。
- 伊薩：程序人偶，右小腿外側兩根細鐵條＋膝蓋圓鉸鏈（金屬支架）；走到桌邊他替諾恩拉椅子（椅子往後滑＋新音效 `brace_creak`），然後每個人站到桌邊、開 `ch2_table`。伊薩站在桌子北邊面向鏡頭（第一版站西端被席菈擋住）。
- 第 2 章的文字放新的 `i18n/ch2.csv`；「待續」沿用 `CH1_TO_BE_CONTINUED`（字面是通用的「下一段還在製作中」）。
- 影響：`Game.LEVELS["bell_hall"]`、`CHECKPOINT_LEVELS`（`ch2_start`、`ch2_volunteer`）、`GameSession.MAIN_QUESTS`／`CHAPTER_CHAIN`；`daylight.reach_bell_yard()`；`bell_hall.dev_start_chapter2(s)`（static，照正式流程把第 1 章走完）；開發旗標 `--level=bell_hall [--hall-at=table]`；CI 盤點截圖 `18-ch2-table`、`19-ch2-hall`；主線流程測試 `_chapter2()`／`_assert_bell_hall()`。

## D-156　2026-11-09　第 1 章段落 9「兔子」：在白晝城街尾演；撞柱子是真的碰撞，靠近到碰得到就算撞

- 決策：吃完飯（`bell_yard` 階段）往街尾的鐘院走：走過 `RABBIT_Z`（柯德家門口往前約 1 公尺）就開對話 `ch1_rabbit`——旁白「小女孩摸了席菈背上的斷劍、被母親拉回去」「席菈蹲下讓她看劍柄上耳朵長短不一的兔子」→「妳刻的？」「我妹妹。」「她畫得——」「很醜。我知道。」→ 旁白「她嘴角微微動了一下……」→「看路，攻略先生。」（設 `ch1.rabbit_seen`，跳過也算）。街中間立一根**通到穹頂的石柱**（`StreetPillar`，有碰撞，正好擋在門口往鐘院的直線上）：看過兔子之後諾恩走到碰得到柱子的距離（`PILLAR_RADIUS + BUMP_REACH`）就算撞上——咚一聲（`blunt_weak`）＋彌夏的笑聲（`child_laugh`）＋兩句旁白「我撞上了柱子。」「彌夏在後面笑得扶住鐘箱。」（`ch1.bumped_pillar`，只撞一次）。玩家繞開柱子就不會撞（可玩）。小女孩與母親是程序人偶，席菈「蹲下」先只用旁白（程序人偶沒有蹲姿）。鐘院門口（`BELL_YARD_POS`）照舊顯示「待續」。
- 用詞：「攻略先生」英文 **Mr. Guidebook**（攻略筆記是 Guide Notes；記進 06-terminology）。
- 理由：07 段落 9 的重點是席菈的一個表情和一個笑點；撞柱子要「真的撞到」才好笑，所以用真的碰撞體擋人，判定用距離（測試裡瞬移不會產生滑動碰撞紀錄，距離判定在實機和測試都一樣）。
- 影響：`daylight.gd` 的 `RABBIT_*`、`PILLAR_*`、`bump_pillar()`、`_build_rabbit_street()`；柯德在 `bell_yard` 站的位置、鐘院門口範圍往街尾移（不跟兔子、石柱重疊）；開發旗標 `--daylight-at=yard`；CI 盤點截圖 `17-ch1-bell-yard-road`。第 1 章結尾（`ch1.reached_bell_yard` → 第 2 章章節卡）下一輪做。

## D-155　2026-11-09　第 1 章段落 8「柯德家的晚餐」：屋內蓋在 daylight 關卡裡（不另開關卡）；玩家的兩個選項記成旗標

- 決策：柯德家的屋內**不另開關卡**，蓋在 `daylight` 關卡的街區外面（`HOUSE_ORIGIN` x = 40，7×6 公尺、高 3.2 公尺）：走到柯德家門口 → 畫面黑一下（`_cut_from_black`，0.7 秒）→ 每個人站到桌邊（`SEATS`）→ 對話 `ch1_kord_dinner`；講完黑一下回到柯德家門口，柯德往鐘院走。屋裡跟街上同一個環境（**沒有影子，只有油燈投影子**：天花板一顆白燈只是發光球）；全域的體積霧在小房間裡像起霧，用一個負密度的 `FogVolume` 扣掉。諾恩站在桌子東南角斜看整張桌子（站正中間擋住桌面）。桌上：孩子各兩片麵包、太太一片、柯德面前一杯水、切剩的麵包頭。
- 對話照原作：「柯德把自己那份切成五片……他自己喝水。」→ 小女兒「外面也用這種錢嗎？」「不一樣。」「那你們買東西，不會變老？」→ 選項：**回答**（「不會。我們用銅板。」→「那銅板用完了怎麼辦？」→「這一題我答不出來。」）／**不回答**（「我張了張嘴。」，原作）→ 旁白「席菈把自己的乾糧掰開，放到桌子中央。」（`ch1.sheila_shared`，一定發生）→ 選項：**跟著放**（柯德「……說謝謝。」小女兒「謝謝。」）／**不動**（「吃吧。麵包冷了就硬了。」）→「吃完我帶你們去鐘院。」（`ch1.kord_dinner_done`）。旗標 `ch1.answered_daughter`、`ch1.shared_rations`（07：第 4 章盤點時柯德多一句提到那頓飯）。桌上的乾糧跟著旗標出現（`RationsSheila`／`RationsNoen`）。
- 理由：段落 8 是 4 分鐘的一場對話，另開關卡要多一套 tscn、檢查點、換場景；放在同一個關卡最省，也保證屋裡跟街上同一套「沒有影子」的光。回答的選項不是原作，加上去是讓「回答」本身變成一個更難的問題（銅板用完了呢？），兩邊都不給獎勵。
- 影響：`ch1_main` 多 `bell_yard` 階段（檢查點 `ch1_after_dinner` → `daylight`；重來出生在柯德家門口；done_when `ch1.reached_bell_yard` 下一輪設）；`daylight.gd` 的 `enter_home()`／`leave_home()`／`in_house`／`_build_house()`；新講者 `SPK_KORD_DAUGHTER`（柯德的小女兒，沒有名字，原作沒給）；開發旗標 `--daylight-at=dinner`；CI 盤點截圖 `16-ch1-dinner`。跳過對話也照樣算吃完、席菈照樣放乾糧。

## D-154　2026-11-09　第 1 章段落 7「沒有影子的城」：新關卡 daylight；樓梯底的門是白晝城的後門；壽命石碑的天數存在旗標

- 決策：跟柯德說完話（最後一句補上原作「那先吃點東西。空肚子修的鐘不準。」）直接換到新關卡 `daylight`（`ch1.entered_daylight`；讀檔停在 `daylight_city` 時走到門口也一樣）。**樓梯底的門＝白晝城的後門**：柯德一家在門房裡吃飯（樓梯底看到的桌子、兩個孩子），門房旁邊就是攻略說「入口有一座淨化爐」的爐子——空的、冷了很多年、晾著小孩的衣服、爐腳一盆種在半個頭盔裡的蔥（07 寫的「空的淨化爐旁邊孩子的蔥盆」）；柯德家在街的另一頭（段落 8 的晚餐）。白晝城的第一眼照 07：沒有 DirectionalLight、環境光 1.0 的冷白、穹頂一片淡灰白＋約 1,900 盞白燈（一個 MultiMesh）、窗戶全關（灰藍的木窗板）、**只有諾恩的油燈開影子**（射程 7 m、亮度 3.0，四周很亮要夠強才讀得出；截圖裡席菈的影子落在牆上就是這一章唯一的影子），人物腳下的接地陰影（D-108）也拿掉。畫質設定（`QualityPreset`）會照等級開體積霧與 SSAO：霧改成會發光的白（不然沒有燈打進霧裡，遠處一片暗褐色）、SSAO 強度歸零。主線多三個階段：`daylight_furnace`（檢查點 `ch1_daylight`，走到爐子旁邊設 `ch1.saw_empty_furnace` → 推翻攻略「入口的淨化爐」）→ `daylight_stele`（跟著柯德走到路口，瑪菈把手按在石碑上，數字 19 → 18、壺裡多半壺水；「那是什麼數字？」「（彌夏沒有回答。）」「還能活幾天。」）→ `kord_home`（`ch1.kord_dinner_done`，段落 8 做；現在走到柯德家門口顯示「待續」）。壽命石碑 `Residents`：資料 `data/daylight/residents.json`（每塊 4～6 人、名字 key `RES_<ID>`），**剩下的天數存在旗標 `life.<id>`**（沒有旗標＝資料的天數），之後章節的抉擇照同一個旗標改；石碑正面用 Label3D（子集字型、`STELE_LINE`「{name}　還能活 {n} 天」）。諾恩按在石碑上只有「上面沒有你的名字。」。居民名字是自創的（瑪菈、歐文、蘇妲、老葛、黛恩、莉亞、班恩、妮卡、洛特、卡爾＋柯德自己）。
- 理由：原作這段（「白晝城沒有天空……我們經過時，一個女人把手按在石碑上」）是走過一座城看到的事，07 已經把「沒有影子」定成這一章的第一眼；樓梯底的門在原作是一家人的門，攻略又說入口有淨化爐，把兩件事放在同一個入口廣場最省、也讓「燒掉下層最快」對上一盆孩子的蔥。天數放旗標而不是另開存檔欄位：存檔、讀檔、重來都不用改格式，第 4 章盤點時也只是改旗標。
- 影響：`Game.LEVELS` 加 `daylight`、`CHECKPOINT_LEVELS` 加 `ch1_daylight`；開發旗標 `--level=daylight [--daylight-at=stele|home]`；CI 盤點截圖加 `15-ch1-daylight`；環境音 `daylight_ambience`（07「鐘走得很慢的滴答＋遠處的水聲」，程序生成 8 秒、頭尾交叉淡化後循環）；`CH1_TO_BE_CONTINUED` 改成通用的「待續——下一段還在製作中」。場景斷言（流程測試 `_assert_daylight`）：除了油燈以外沒有投影子的光、沒有 DirectionalLight、接地陰影都藏起來——之後在白晝城加燈要記得關影子。

## D-153　2026-11-09　第 1 章段落 6「不可互動的門」：在一百七十二階的樓梯底演；諾恩的回答記成柯德的第一印象

- 決策：不另做「白晝城入口」關卡——原作裡門就在樓梯深處（「樓梯深處傳來小孩的笑聲……一個男人舉著叉子走出來」），直接放在 stairs 關卡的最底：走到門口（`daylight_gate` 階段）→ 門往外開（`GateDoorPivot`）、柯德（程序人偶＋叉子）走出來 → 對話 `ch1_kord_door` 照原作（「地上來的？」→ 看見徽章笑容消失 →「我們今年已經交過了」→ 門後的桌子、兩個孩子、碎頭盔裡的蔥 → 地圖上那扇門標「不可互動」→ 席菈摘下銀徽「我們來修鐘」），中間加一個柯德問「那你呢？」的三選一（攤開空手／來幫忙的／地圖上說這扇門打不開），記成 `ch1.kord_first`＝`hands|help|map`；最後一句「把叉子放低了一點」設 `ch1.met_kord`。開門設 `ch1.door_opened`（推翻「不可互動的門」），見到柯德推翻「全城是怪物」（`notes.json` 原本的條件）。主線 `daylight_gate` 改成 `ch1.met_kord` 才完成，新階段 `daylight_city`（跟著柯德走進白晝城，`ch1.entered_daylight` 還沒有人設）。
- 理由：07 設計的段落表把門寫成獨立地點，但原作是同一場戲的連續動作，拆開反而要多一次換關卡；樓梯底已經有門與門縫的光。第一印象選項是 07「選項影響柯德的第一印象」的落實：不做好感度數字，只記一個字，第 4 章盤點時柯德的台詞再用。
- 影響：樓梯底的出生點往回 2.2 m（重來時不會一出生就開門）；讀檔時照 `ch1.met_kord` 把門開好、柯德站在門口；截圖旗標 `--stairs-door`；白晝城（段落 7，新關卡）做好之前，跟柯德說完話顯示「待續」。

## D-152　2026-11-09　第 1 章段落 5「一百七十二階」：方形螺旋的白盒關卡；丟石頭或踩絆線都會推翻射箭陷阱

- 決策：新關卡 `stairs`（`scenes/levels/stairs.gd`）。不做 172 級：繞中間石柱的**方形螺旋**，10 段（兩圈半），轉角是平台、轉角之間是斜坡（看不到的斜坡碰撞＋看得到的 6 級台階，跟霜橋鎮北段石階同一招），每圈下降 3.4 m（頭頂留得出空間），走道寬 2.4 m（1.5 m 時過肩鏡頭一直撞牆）。路線用參數 `s`（沿路線的水平公尺數）描述：`path_point(s)`／`path_param(p)`（螺旋疊好幾圈，用高度挑最近的一段）／`ground_y` 覆寫。燈：環境光很低（0.16）＋霧，只有地窖口漏下來的白天（SpotLight）、樓梯底門縫的白光、諾恩的油燈（地底下照遠一點：range 6.5；**影子先關掉**，開著時畫面右側一整條黑帶，原因待查）。陷阱在第 6 個轉角：走近時諾恩攔住大家（`ch1_stair_warn`，標過我不確定的那條諾恩自己說「這條我標了不確定」）→ 互動「往前丟一塊石頭試探」（D-065 的 `interact_prompts`）→ 石頭落在平台上、木桶翻倒、髒水潑在空平台；不丟就走上去會踩到絆線、水從諾恩頭上淋下來（`ch1.stair_trap_soaked`）。兩種都設 `ch1.stair_trap_sprung`（攻略筆記推翻）→ `ch1_stair_trap`：「沒有箭」→ 水 →（標過不確定）「……果然」／（沒標）「席菈看了我一眼」→ 小孩的笑聲（`child_laugh`，在那一句播）→「下面有人」「攻略上，下面只有怪物」「那就下去看看，什麼樣的怪物會笑」。席菈的 `leader` 換成沿路線移動的 `SheilaLead`（直線追人會被石柱擋住），彌夏是程序人偶、直接放在路線上；兩人都走在鏡頭後面（4.2／5.6 m）。
- 理由：原作這段只有五行（扔石頭 → 沒有箭 → 髒水 → 笑聲 → 喝斥），重點是「攻略說會有怪，結果是人」的反轉，不放戰鬥（07 已定）。讓玩家可以選擇不試探：被淋濕本身就是「我剛剛很有把握」的回饋，不懲罰。方形螺旋比圓形螺旋好做碰撞（每段都是一個斜坡盒子），霧裡看不出是方的。
- 影響：`Game.LEVELS` 加 `stairs`；檢查點 `ch1_lamp`、`ch1_stairs_bottom` → stairs；霜橋鎮走進地窖改成換關卡；`stairs` 階段的目標指引改 `node:StairsDown`（兩個關卡都有這個點）；新音效 `water_splash`、`child_laugh`；開發旗標 `--level=stairs [--stairs-at=trap|mid|bottom] [--stairs-sprung] [--stairs-door]`；CI 盤點截圖 `14-ch1-stairs`。「換手的小動作」（提燈換到右手再換回來）還沒做。

## D-151　2026-11-09　第 1 章段落 4「白天的霜橋鎮」：重用切片關卡的白天版本；艾妲交油燈；油燈取代提燈

- 決策：走出酒館門（`to_cellar` 階段）設 `ch1.left_tavern` → 主線進 `day_north`（檢查點 `ch1_day_town`、自動存檔）→ 換到霜橋鎮。`frostbridge.gd` 在 `is_day_chapter()`（章節 ch1 且主線在 `day_north`／`ada_lamp`／`stairs`）時走白天版本：`FrostbridgeLook.build_environment(parent, true)`（陰天 ProceduralSky、太陽 `SKY_MODE_LIGHT_ONLY` 不畫在天上、`light_angular_distance` 4 讓影子軟、霧薄、曝光 1.0）、所有 OmniLight 關掉（玩家的燈除外）＋`look.unlight(LAMP)` 讓燈玻璃不亮、攤子後面的艾妲剪影不放、南街石拱停用（白天不能再重現）、席菈跟著、艾妲（Puppet）站在地窖門口。切片的任務判斷照舊用 `MAIN_QUEST`（切片完成後都不成立），白天的邏輯另寫在 `_update_day()`／`_on_day_cellar()`，不碰切片的分支。流程：一進來顯示「隔天早上。」→ 走上北街（z ≤ -30.6）自動開對話 `ch1_north_day`（「在攻略裡，這條街只是一段過場動畫。」「那就記住它不是。」）→ `ada_lamp`：走到艾妲 3 m 內開 `ch1_ada_lamp`（付了石拱記憶 → 第一句換成「你連你爸都忘了，別把我忘了。你回來的時候，我要告你。」，`text_if memory_paid`）→ 設 `ch1.lamp_received` → `stairs`（檢查點 `ch1_lamp`）→ 走進地窖顯示「待續」。油燈：`PlayerController._update_lamp()` 在讀到旗標時把提燈換成圓肚銅油燈（壓扁的球＋發光燈罩＋提把，光 `OIL_LAMP_COLOR`、0.8、範圍 3.8），對話結束與進場時檢查。
- 理由：07 設計 D-143 已定「重用切片關卡」；白天看昨晚的現場最有份量，成本是一個環境變體。原作這段只有三句（「你回來的時候，我要告你」「我知道」「別死在下面，死人不會替人重建房子」），北街那段是改編加的，用來接「攻略是遊戲、這裡不是」的主題線。死亡人數依切片結果不同（29～33），所以北街的台詞不提數字。
- 影響：開發旗標 `--level=frostbridge --day[=ada_lamp|stairs]`、`--face=ada`；`Game.CHECKPOINT_LEVELS` 加 `ch1_day_town`／`ch1_lamp` → frostbridge（**一百七十二階做好後把 `ch1_lamp` 換成那個關卡**，地窖觸發改成換關卡）；主線流程測試兩條路線從酒館門口走到地窖（在 `ch1_day_town`、`ch1_lamp` 各重來一次，斷言白天版本沒有敵人／車隊、路燈不點、受困者不能再救、油燈保留）；`test_chapter1::test_day_town_stages_and_dialogue`；CI 盤點截圖加 `12-ch1-tavern`、`13-ch1-day-north`。新字串 `Q_CH1_OBJ_DAY_NORTH／ADA_LAMP／STAIRS`、`DLG_CH1_NORTH_*`、`DLG_CH1_ADA_*`、`CH1_NEXT_MORNING`（ch1.csv）。

## D-150　2026-11-09　第 1 章段落 3「標記畫面」：一張舊紙、逐條點選，按「就這樣」才寫進攻略筆記

- 決策：`GuideMarkView`（`scenes/ui/guide_mark_view.gd`）是 CanvasLayer：暗底上一張舊紙（明體標題「桌上的地圖」＋席菈的那句話），列出已寫下、還沒有結果的攻略條目，每列是 flat Button（全域 Theme 的暖金色焦點）＋子節點 Label（條目文字、右邊「確定／我不確定」），點一下切換、標了我不確定的整列淡一點、換值有選單的「叮」；按「就這樣」才用 `GuideNotes.set_unsure` 寫進狀態並發 `confirmed`。打開時暫停（跟日記一樣），被釋放時解除暫停。流程：`ch1_map` 對話最後一句（席菈）設 `ch1.guide_marking` → 酒館在 `draw_map` 階段看到這個旗標就打開畫面（同一階段不再重講畫地圖的對話）→ 確認後開 `ch1_map_end`，最後一句照標了幾條換：六條全標＝原作「整張地圖都被圈起來」、一條都沒標＝「一個圈也沒畫」、其他＝「圈了幾個地方，席菈什麼也沒說」，並設 `ch1.map_drawn`。
- 理由：07 設計的系統 1。原作的這一刻是諾恩「最後整張地圖都被我圈了起來」；讓玩家自己決定圈幾條，最後一句誠實反映玩家的選擇（不懲罰），之後被推翻時「果然」／席菈看一眼的差異才有意義。用按鈕＋Label 而不是設定頁的「‹ 值 ›」，因為這裡是兩個值的切換、要能用滑鼠直接點一整列。
- 影響：截圖旗標 `--level=tavern --ch1-stage=draw_map --guide-mark`；`test_chapter1::test_guide_mark_view_toggles_and_confirms`；主線流程測試兩條路線各走一種標法、重來後標記保留。新字串 `GUIDE_MARK_*`、`DLG_CH1_MAP_007_SOME／_NONE`（ch1.csv）。

## D-149　2026-11-09　章節銜接：切片完成 → 第 1 章主線；章節卡；酒館白盒

- 決策：①切片主線 `slice_main` 的 `on_complete` 加 `{"chapter": "ch1", "start_quest": ["ch1_main"]}`；StoryLogic 新效果 `chapter`（改 `GameState.chapter`）。②`GameSession.MAIN_QUESTS`（依章節順序）與 `main_quest()`（最後一個已開始的）：HUD 目標、目標指引、暫停選單跟著它；切片專屬的程式照舊用 `MAIN_QUEST`（slice_main）。③舊存檔（切片完成、沒有第 1 章）讀檔時 `upgrade_chapters()` 依 `CHAPTER_CHAIN` 補開下一章並換章節（不另升存檔版本：這是任務資料改版，不是格式改版）。④`Game.CHECKPOINT_LEVELS`：第 1 章的 `ch1_tavern`／`ch1_dinner`／`ch1_map_done` → 新關卡 `tavern`。⑤走進地窖後 `ChapterCard`（淡黑 → 「第一章」＋明體章名「攻略之外的門」→ 約 4.8 秒後換關卡，確認鍵可提早結束）掛在關卡底下：關卡被釋放時不會換場景。⑥酒館（`scenes/levels/tavern.gd`，繼承 StoryLevel）先做白盒：CSG 房間、壁爐／窗／吧台油燈、程序人偶（席菈、彌夏、老闆、兩個傷者）；劇情照霜橋鎮席菈的做法依任務階段輪詢「說話點」距離開對話（中午：席菈旁邊；入夜：晚餐桌；畫地圖：小桌子；出門：顯示「待續」）。中午／入夜由窗光、窗玻璃、壁爐亮度切換。⑦英文名：彌夏 **Misha**、黎歐 **Leo**、酒館老闆 Innkeeper；第 1 章旗標一律 `ch1.` 開頭（07 草稿寫的 `ch1_sheila_soup_helped` 改成 `ch1.sheila_soup_helped`）。
- 理由：NEXT 第 5 節的順序；D-143 已定酒館先白盒＋對話（對話是重點）。章節卡讓「切片結束」變成「故事繼續」，也是之後每章開頭共用的元件。舊存檔補開避免玩家讀到一個沒有目標的完成存檔。
- 影響：主線流程測試從切片結尾接到第 1 章出門（中間在酒館重來兩次）；新測試 `test_chapter1`（6 個）；開發旗標 `--level=tavern`（直接進來時照正式流程把切片走完）＋`--ch1-stage=dinner|draw_map|to_cellar`。對話 `ch1_noon`／`ch1_dinner`（灑湯選項）／`ch1_map`／`ch1_map_end`，文字在 `i18n/ch1.csv`。

## D-148　2026-11-09　攻略筆記先做邏輯層；存檔版本 2

- 決策：第 1 章系統 1「攻略筆記」先做不依賴關卡與 UI 的部分。條目定義 `game/data/guide/notes.json`（6 條：射箭陷阱、全城是怪物、不可互動的門、入口的淨化爐——第 1 章推翻；食歲的僭王、焚城路線——第 2 章推翻），每條 `wrong_when`／`confirmed_when` 用 StoryLogic 條件。狀態存在新欄位 `GameState.guide`（id → `{"unsure", "result"}`）：可信度 確定／我不確定／被推翻／證實（`GuideNotes.SURE`…），被推翻後仍記得當初有沒有標「我不確定」（台詞「果然」vs 席菈看他一眼）。StoryLogic 加條件 `{"guide": id, "is": ..., "was_unsure": bool}` 與效果 `{"guide_write": [...]}`；`GameSession.advance()` 在任務推進前後各檢查一次推翻，發 `guide_changed`。存檔 `CURRENT_VERSION` 1 → 2，遷移補空的 `guide`（切片存檔照樣停在原檢查點）。文字放新的 `i18n/ch1.csv`（`GUIDE_<ID>`／`GUIDE_<ID>_WRONG`、可信度、日記分頁名）。
- 理由：PLAN 階段 2 的順序是成就做完就開始第 1 章；攻略筆記是第 1～3 章共用的核心系統，又是純邏輯、好測，先做穩再接關卡（推翻用的旗標 `ch1.stair_trap_sprung` 等由之後的關卡設）。存檔欄位一開始就定，之後的章節不用再改格式。「焚城路線」照 08 草稿算第 2 章推翻、是諾恩自己寫的那條；第 3 章鐘舌那條是玩家自己觀察後寫下（之後加 `confirmed_when` 的條目）。
- 影響：新檔 `src/core/guide_notes.gd`、`tests/unit/test_guide_notes.gd`（資料與翻譯、狀態機、條件與效果、session 推翻＋存讀檔、v1 → v2 遷移）；`verify_package.py` 加 ch1 翻譯與 notes.json；07 草稿系統 1 的資料路徑改成 `data/guide/notes.json`。日記先在記憶卡下面加一段「攻略筆記」（`JournalView._add_guide_section`：可信度小標＋那句攻略，被推翻的整句一條紅褐墨線劃掉、下面是現實；沒寫下任何條目時整段不出現，切片畫面不變；截圖旗標 `--guide-demo`）；等條目變多再拆成真的分頁。段落 3 的標記畫面下一步做。

## D-147　2026-11-09　成就：帳號層級、只算「這一局做到的」、Steam 有就同步

- 決策：切片 8 個成就照 `docs/steam/achievements.md`，條件寫在 `game/data/achievements.json`（StoryLogic 格式）。`AchievementTracker`（`src/core/achievement_tracker.gd`）存在 `user://achievements.json`（`{"version": 1, "unlocked": {id: 時間}}`，跟存檔槽分開；不認得的 id 保留）。**邊緣觸發**：新遊戲／讀檔／重試時 `baseline()` 記下已成立的條件不算，之後條件從不成立變成立才解鎖——讀別人的存檔不會解鎖，已解鎖的永遠不取消。`GameSession.advance()` 與 Game 每 0.5 秒各檢查一次（有些旗標直接寫進 state，例如鐵架拋擲）。灰巡者被打中弱點而跪下記 `stats.ashwalker_weak_kneels`（`GameSession.add_stat`：不推進任務、不存檔）。解鎖小卡 `AchievementToast`（右上角、對話／過場／暫停中排隊、1.5 秒淡出）；`SteamBridge` 在有 "Steam" singleton（GodotSteam）時 `setAchievement`＋`storeStats`、啟動時補同步，有 Steam 時不畫自己的小卡。開發旗標（`--level`、`--screenshot`、`--benchmark`…）與測試（`run_tests.gd` 開頭換掉）只用記憶體的 tracker，不寫玩家的檔案。圖示替代版 `scripts/achievement_icons.py`（256×256 PNG，`<ID>_ACHIEVED`／`_UNACHIEVED`，CI 打包成 zip 附在 latest）。
- 理由：Steam 成就是帳號層級，跟存檔混在一起會讓「讀舊存檔」誤解鎖或取消；邊緣觸發讓條件仍然只看遊戲狀態（資料驅動、好測），又不會因為讀檔就送成就。「第九聲鐘」的說明改成「把那口舊鐘敲滿九下」（跳過演出也會敲滿，跳過不該被懲罰）。圖示規格照 Steamworks 文件：建議 256×256 PNG（JPG 也可）、正方形，未解鎖圖示可由後台自動產生灰階版。
- 影響：project 的 Game autoload 多 `achievements`／`achievement_toast`；截圖旗標 `--achievement=<id>`；`test_achievements`（資料與翻譯、邊緣觸發、讀舊存檔、檔案版本與保留、壞檔、記憶體模式、灰巡者計數、小卡排隊與淡出、Steam 沒有時不做事）、`test_slice_playthrough` 兩條路線跑完檢查各自解鎖的成就。

## D-146　2026-11-09　看穿小卡依敵人寬度讓開身體；「第一眼」盤點到第八輪停止

- 決策：`InsightCard.place(cam, 頭頂, side_m)`：卡片左緣取「頭頂投影＋`OFFSET`」與「頭頂沿鏡頭右方 `side_m` 公尺的投影＋`EDGE_GAP`（14 px）」較右的那個（`InsightCard.card_anchor`）；`EnemyActor.insight_side()` 預設 0.45 m，送葬者覆寫 0.85 m（鐵架橫桿 0.55 m、手臂約 0.75 m）。遠處身體比 `OFFSET` 窄時照原本。另外：八輪「第一眼」盤點到此停止，之後的打磨等 Jacky 試玩回饋，或做章節時順手修；下一步照 PLAN 階段 2 的順序做 Steam 準備（成就系統，不依賴 GodotSteam）與第一部第 1 章。
- 理由：第八輪盤點第 8 項。固定 44 px 在送葬者近距離時蓋到鐵架右柱；照寬度讓開，新的大型敵人只要覆寫 `insight_side()`。盤點已經八輪、剩下的都是小問題，邊際效益低。
- 影響：截圖 `11`；`test_insight` 加 `test_card_anchor_clears_wide_body`、場景測試多一條「小卡讓開身體右緣」。

## D-145　2026-11-09　Steam 商店截圖：一份清單，Windows 實機一鍵拍

- 決策：商店截圖清單放在 `scripts/store_shots.txt`（每行：檔名、幀數、遊戲旗標），7 張：廣場（無 HUD）、敲鐘、救援、看穿送葬者、石拱重現（無 HUD）、燃燒劍斬鐵架、日記。Windows 版 zip 附 `store-shots.ps1`：在 Jacky 的實機用匯出版跑，自動加 `--quality=2`、1920×1080、英文與繁中各一套，輸出到 `store-shots/en`、`store-shots/zh_TW`。雲端用 `scripts/store-shots.sh`（軟體渲染）只確認構圖；`screenshot.sh` 的解析度改成可用 `SHOT_RES` 指定。`check.sh` 用 `check_store_shots.py` 檢查清單的旗標都有被遊戲程式讀（打錯字截圖模式會默默忽略）；CI 打包時用 pwsh 檢查 ps1 語法。第 4 張「看穿」從沙盒改成霜橋鎮送葬者戰（跟 screens 的 `11` 同一組）：沙盒是測試場景，不適合放商店。
- 理由：NEXT 第 4 節原本打算在 CI 每次都拍商店截圖，但雲端只有軟體渲染（沒有好的霧、反射，品質不夠上架），CI 也已經 15 分鐘；真正要上架的截圖必須在獨顯實機拍，所以重點是讓 Jacky 一個指令拍完、而且構圖跟雲端看到的一樣。
- 影響：Windows zip 多兩個檔；`docs/steam/asset-specs.md` 的截圖清單改指向 `store_shots.txt`；FOR_JACKY 第 2 項加一行指令。

## D-144　2026-11-09　廣場的石板每顆不一樣、一圈圈的縫中距離就淡掉

- 決策：`wet_cobble.gdshader` 加 `sunken_share`（0.16：微微下陷、積薄水的石板，整顆暗、像鏡子）、`dark_share`（0.1：補的深色石頭）、`grit_amount`（0.45：石縫一段段被砂土填平，填平處縫不暗不濕、旁邊石板的倒角也被埋住）、`ring_gap_tighten`（0.025：弧形鋪時排與排之間的縫比石板之間的縫窄）、`far_fade`（遠處淡成平均值的速度，預設 1.2；廣場 `FrostbridgeLook.ARC_FAR_FADE`＝1.9）；每顆石板傾斜幅度 ×0.4～1.9、亮度範圍 0.68～1.18。街道也套用前三項（同一個 shader）。
- 理由：第八輪盤點第 5 項。從遊玩高度看，廣場前景一圈圈每顆一樣亮，排與排之間連成圓的縫像靶心；真的老廣場石板有新有舊、有的下陷積水、縫裡卡砂土。
- 影響：截圖 `03`、`04`（廣場、梨販攤）；`test_frostbridge::test_plaza_arc_paving` 加檢查廣場的 `far_fade` 比街道快、shader 有這幾個參數。

## D-143　2026-11-09　第 1～3 章草稿的「待定」先定案

- 決策：①第 1 章段落 4「白天的霜橋鎮」重用切片關卡，`FrostbridgeLook` 加一個白天光照變體；②酒館先做白盒＋對話，美術在階段 2 後段；③攻略筆記做成日記的分頁；④第 2 章不給玩家「說出我殺過你四百多次」的選項，只在看穿劃字時讓玩家自己懂；⑤第 3 章節奏觀察不做難度模式，送葬者轉頭前一律有提示音，設定頁「遊戲」分組加「觀察提示音」開關（預設開）；⑥做不完時的保留順序：第 3 章 > 第 1 章段落 7～9 > 第 2 章段落 4 的浮雕（可縮成過場）。
- 理由：都照草稿裡的傾向；先定下來，12/14 開工時不用再停下來想。⑤用一個開關取代難度模式：切片沒有難度設定，多一套難度要多一倍調整與測試。FOR_JACKY 第 3 項的意見題還開著，Jacky 回覆不同意就照他的改。
- 影響：`07-chapter1-door.md`、`08-chapter2-3.md` 的「待定」改成「決定」。

## D-142　2026-11-09　第 1～3 章的新名詞先進對照表

- 決策：`06-terminology.md` 加上攻略筆記（`guide_notes`，每條標「確定／我不確定／被推翻」）、壽命石碑（`life_stone`）、鐘舌（`clapper`，第一次出現時說明「鐘裡面那根撞鐘的鐵棒」，不叫鐘錘）、主椅（`main_seat`）、白晝城（地名照原作，英文暫定 Daylight City）。
- 理由：07／08 草稿要求「新名詞實作前補進對照表」；12/14 起實作，先定好名字，i18n key 與程式識別碼照這張表取。Jacky 對用詞有意見（FOR_JACKY 第 3、5 項）就照他的改。
- 影響：只有文件；`test_i18n::test_no_obscure_terms` 的舊詞清單不變。

## D-141　2026-11-09　廣場石盤上的鐘改成又高又窄、鐘口外翻、加鐘舌

- 決策：`bell_inlay_mesh` 的鐘從 1.15 m 高／鐘口半徑 0.5 改成 1.4／0.42（`PLAZA_BELL_H／R`）；外輪廓下半段往外翻（鐘口最寬 `PLAZA_BELL_FLARE`＝1.14 倍）；鐘口外面（南邊）加一顆鐘舌（半徑 `PLAZA_BELL_CLAPPER_R`×鐘口直徑的圓球，一半露在鐘口外）＋一小段舌桿；整個圖案置中。鐘頂照舊朝北。
- 理由：第八輪盤點第 6 項。從南邊進廣場（主要路線）的遊玩高度看，南北方向被透視壓扁成約四分之一，矮胖的鐘＝帽簷＋帽頂。試過橫躺（鐘頂朝西），從南邊看反而像一支箭／匕首，退回朝北、改比例。
- 影響：截圖 `--at=plaza`（`03`、`02` 遠景）；測試 `test_frostbridge::test_plaza_bell_inlay_faces_up` 改成檢查又高又窄、鐘口外翻、鐘口外有鐘舌。

## D-140　2026-11-09　角色模型的循環動作也認 `_loop` 結尾

- 決策：`CharacterModels.ANIM_MAP` 的 idle／walk／run 各加一個 `_loop` 結尾的名字（`idle_loop`、`walk_loop`、`run_loop`），排在原本名字後面；照樣設成循環播放。
- 理由：Jacky 11/9 推的席菈試作（`art-inbox/studies/sheila/`）走路動作叫 `walk_loop`。正式交件時不用改名就接得上；試作本身照 README 不接進遊戲。
- 影響：測試 `test_character_models::test_loop_suffixed_animations_are_found`。`art-inbox/README.md` 的動作表不變（照舊建議 `walk`）。

## D-139　2026-11-09　破屋頂的雪不再像一張平的白布

- 決策：`SnowMound.build(..., on_tiles=true)` 用比較細的網格（`TILES_RINGS` 6 圈 × `TILES_SEGMENTS` 40 段，一般雪堆 4 × 20）、輪廓多兩個細的起伏（7、11 倍頻）、往內凹最多 `TILES_RAGGED` 0.28、高度往邊緣變薄的次方 `TILES_FALLOFF` 1.5（一般 0.7：中間平、邊上一圈陡坡），雪面再乘一個約 1.2～2 m 的 ±35% 起伏。`snow.gdshader` 屋瓦上的雪：每排屋瓦把雪撐出一道道起伏（`tile_drape`：沿斜面的公尺數對世界 xz 的梯度用螢幕空間導數解，排裡大部分緩坡、下緣那一小段陡坡）、每排亮度不同＋排裡往下緣變暗、大片的亮暗 `tile_mottle` 0.3、整體 0.93、外圈提早 0.18 開始變薄、背對月光的面偏藍暗（`moon_to`＝Moon 旋轉 (-38°, 35°) 往月亮的方向，`backlit_shade` 0.5）。
- 理由：第八輪盤點第 4 項。救援畫面左半的破屋頂雪亮度很均勻、邊緣看得出一段段直線、邊上一圈發亮的厚度，像一張平的白布／床墊。
- 影響：截圖 `--rescue`（`06`）；測試 `test_snow_mound::test_on_tiles_mesh_is_fine_and_feathered`。一片屋頂兩團雪、每團頂點數從 81 變 241，小鎮合併 mesh 數不變（同一個 `look.snow()`）。

## D-138　2026-11-09　石階每一級前緣下一道暗線

- 決策：`_build_rise` 每一級的踢面頂端（踏面前緣下）加一條 4 cm 高、1.2 cm 厚的深色條，材質沿用廣場石框的溝（`look.mat(Color(0.05, 0.055, 0.065), 0.35)`，不多一個合併 mesh）。
- 理由：第八輪盤點第 3 項。踢面只有 18 cm，石牆 shader 只畫得出一排石塊，霧裡是一條灰白的平帶，四級石階讀起來像四條淺色帶。前緣下的陰影是石階最重要的線。
- 影響：純外觀（截圖 `--at=steps`）。踢面本身還是偏灰白；要更暗得另開一個材質（小鎮合併 mesh 上限 24，現在接近上限），先不做。

## D-137　2026-11-09　石階上的雪積在人不走的地方

- 決策：拿掉每一級前緣一條 12 cm 寬、橫跨整條街的薄雪（方塊）。改成 `_step_snow`：每一級兩側靠牆各一個 `SnowMound`（寬 0.8～1.25 m、深約一級的 70～92%、高 6～10 cm，最高點偏向牆與踏面後緣），加上 75% 的機率在後緣靠踢面的角落一小團（偏左或偏右、在路的外面）。中間 `STEP_PATH_HALF`（1.1 m）內不放雪，露出濕石板。位置、大小都用位置雜湊（不動 `_rng`）；`step_snow` 給測試看。
- 理由：第八輪盤點第 2 項。前緣那條雪是完美的直線，從主街往上看是四條發亮的白線（像日光燈管）；真實的石階上，雪會被走掉，只留在兩側與角落。
- 影響：截圖 `--at=steps`；測試 `test_frostbridge::test_step_snow_leaves_path_clear`。

## D-136　2026-11-09　牆腳的雪帶連成一整條

- 決策：`_snow_bank` 每段牆不再沿牆放一串重疊的 `build_bank` 雪堆，改成一整條 `SnowMound.build_strip(長, 伸出, 埋進牆, 高, seed, toward_wall, along0)`：沿牆每 0.3 m 一列、橫切面 9 個點（牆裡到牆腳線一樣高，往街 `(1 - k^1.6)^1.4` 慢慢薄到 0，最外一列稍微低於 0）。高度 `strip_height`＝`SNOW_BANK_HEIGHT`（0.24）×（0.6～1.0 的約 4 m 起伏＋約 1.1 m 的細起伏），伸出寬度 `strip_out`＝reach ×（0.78～1.04 的約 3 m 起伏＋約 0.7 m 的小缺口），兩端 1 m 內收口。UV／UV2 跟 D-134 的 `build_bank` 同一套（腳印、靠牆的角落照舊）。腳印再淡一點：變暗 0.22 → 0.14、踩實的灰 0.45 → 0.3。`snow_banks` 改成沿每條雪帶每 1.8 m 一個樣本。
- 理由：第八輪盤點第 1 項。一串雪堆各有一個最高點，送葬者戰、石拱預覽（南街）的低角度鏡頭看過去是一節一節的枕頭／沙包；雪帶連成一整條後腳印更顯眼，原本的暗度又像一排黑點。
- 影響：每段牆一個 mesh（原本十幾個），頂點數差不多；`build_bank` 留著（測試還在用，之後沒用就可以刪）。截圖 `--convoy --phase2 --face=undertaker`、`--at=steps`；測試 `test_snow_mound::test_strip_is_continuous_bank`（沿牆中段相鄰兩列最高點差不到 2.5 cm、兩端收口、正面朝上、UV 是牆的公尺數）。

## D-135　2026-11-09　預覽輪廓還沒長到的拱圈也淡淡畫出放射縫

- 決策：`restore_ghost.gdshader` 在 `fill` 以上（還沒長到、只剩淡輪廓的部分）也加 `0.14 ×` 拱圈的放射縫（D-132 的 `arch_joint`），石牆部分照舊只有 fresnel 輪廓。
- 理由：CI 的 `08-arch-preview` 拍在按住一半左右，拱圈還沒長到，看不到 D-132 的拱石；這張是重現的關鍵一刻（README／商店截圖）。淡淡的一塊塊拱石讓預覽一開始就讀得出「這是一座拱」（延續 D-125）。
- 影響：純外觀（截圖 `--convoy --arch=preview`）。

## D-134　2026-11-09　雪帶上的腳印排成一串

- 決策：街邊雪帶改用 `SnowMound.build_bank(長, 寬, 高, seed, toward_wall, along0, from_wall0)`：跟 `build(..., street_bank=true)` 一樣，另外把 UV 換成雪帶自己的公尺座標——UV.x＝`BANK_MARK`（1000）＋沿著牆的公尺數（`along0`＝這段中心在整條雪帶上的位置＋每條雪帶一個位置雜湊偏移，前後重疊的兩段算出來一樣）、UV.y＝離牆腳線多遠（往街那側為正）。`snow.gdshader` 在 UV.x > 500 的雪上畫一串左右交錯的腳印：每步 `step_len` 0.36 m、一串 8 步、`footprint_density` 的機率出現、偶爾一步被風吹平、走的線離牆 `trail_from_wall` 0.5 m 慢慢偏 ±0.1 m、左右腳各偏 9 cm 且腳尖稍微朝外。凹痕內壁的法線方向用螢幕空間導數把雪帶座標換回世界 xz（雪帶座標對世界是線性的）。凹痕變暗 0.3 → 0.22、踩實的灰 0.55 → 0.45。
- 理由：第七輪盤點第 6 項。D-126 的腳印是 50 cm 格子裡散落的單一凹痕，看不出「有人走過」；一串腳印才有故事（鐘聲前有人沿著牆走）。一串的腳印比散落的多，原本的暗度看起來像一排黑洞。
- 影響：其他雪（屋頂、破屋頂、雪堆）的 UV 在 0～1，不受影響；台地上的雪帶也是街邊雪帶，也有腳印。截圖 `--at=main --nohud`、`--at=south --nohud`。

## D-133　2026-11-09　破屋頂每片屋簷那端的一小團雪拿掉

- 決策：`_roof_ruin` 每片塌下來／滑開的屋頂上原本有三團雪（一大塊薄的、偏一邊的一塊、屋簷那端 0.42×0.48×0.1 的一小團），拿掉屋簷那端那團。`RUIN_SNOW_H` 只剩兩個值。
- 理由：第七輪盤點第 5 項。北街救援（`--rescue`）諾恩腳邊一團發亮的白色雪塊浮在瓦礫上、像白色石膏——先實驗拿掉確認是這團。試過改成橫跨屋瓦的一條薄雪（0.3 m × 屋頂寬的 45～70%、高 0.045），離鏡頭太近，還是一團亮白；「正要滑下去」的故事在畫面上也讀不出來。
- 影響：破屋頂的雪少一團；屋瓦露出的部分多一點（D-131 的橫條照舊）。

## D-132　2026-11-09　重現的石拱拱圈畫放射縫

- 決策：`half_timber.gdshader`、`restore_ghost.gdshader` 加 `arch_voussoirs`／`arch_center`／`arch_inner`／`arch_outer`／`arch_key_extra`（預設 0＝沒有拱圈，鎮上的牆不受影響），用物件座標（vertex 存 `VERTEX`、`NORMAL` 到 varying）判斷片段在不在拱圈裡：正面（物件法線 ±Z）用「到最近的放射縫或內外緣弧線的距離」取代水平錯縫，每塊拱石顏色不同、邊緣沿半徑／沿拱圈往外倒；拱洞內面只有放射縫＋每塊沿牆厚度一道接縫（位置每塊不同）。`NineBreathSite` 兩個材質都設成跟幾何同一組常數（`VOUSSOIRS`、`ARCH_SPRING`、`ARCH_INNER`、`ARCH_OUTER`、新的 `KEYSTONE_RISE`）。
- 理由：第七輪盤點第 4 項。D-129 做出了一圈楔形拱石的幾何，但 CSG 合併後是一個 mesh、shader 用世界座標畫水平錯縫，拱石上是橫的石縫，近看像牆上挖洞不像拱。
- 影響：截圖 `--arch=restored --face=arch --nohud`（諾恩站在石拱前）看得到 11 塊拱石＋拱心石、石縫的冷光沿半徑；預覽輪廓長到拱圈時也是放射縫。測試 `test_arch_shaders_get_voussoir_ring`。

## D-131　2026-11-09　破屋頂露出屋瓦的地方一排排對齊屋瓦

- 決策：`snow.gdshader` 的 `bare`（D-127）雜訊每排屋瓦（`floor(slope_m / tile_row)`）各自位移一次，露出的地方變成沿著屋瓦的一段段橫條、邊界是屋瓦的橫線；露出的屋瓦上也畫每排下緣的暗線（`lip_line × bare`）。門檻 0.37～0.41。
- 理由：第七輪盤點第 3 項。CI 的 `06-rescue` 破屋頂的雪上一團團不規則的暗斑，像迷彩或髒污，不像「雪薄、透出屋瓦」。斜屋面上的雪是一排一排滑落的。
- 影響：純外觀（截圖對照 `--rescue`）。CI 的渲染對比比本機強，下一輪看 screens 的 `06` 再調門檻或 `0.45` 這個暗線強度。

## D-130　2026-11-09　廣場中央的鐘紋：石盤＋鐘的剪影，不是四圈

- 決策：`_build_plaza_ring` 的鐘紋從「淺色外圈、深色溝、淺色內圈、深色圓點」四個圓柱，改成一塊偏暖的淺色圓石盤（沿用地窖門把的 `look.mat(Color(0.4, 0.36, 0.3), 0.4)`，小鎮合併 mesh 已經 24 個、不能開新材質）＋嵌在上面的深色鐘剪影（`bell_inlay_mesh`：`Lathe.bell_profiles` 的外輪廓左右鏡射＋鐘冠，三角化成平面，鐘頂朝北邊的鐘樓）。`plaza_ring_parts` 7 → 5。
- 理由：第七輪盤點第 2 項。`03`、`04`、`02`、`10` 的廣場中央是淺／深／淺／深同心圓，加上外面的淺色石緣，整個看起來像靶心（D-128 只解決了石板的圈）。鐘的剪影一眼看得出是「敲鐘的鎮」，也不再是同心圓。
- 影響：`test_frostbridge::test_plaza_bell_inlay_faces_up`。**踩到的坑**：①`StaticBatch` 的 SurfaceTool 先接了有索引的 CylinderMesh，沒有索引的三角形接上去不會被畫出來——自己做的 mesh 要先 `st.index()`；②Godot 的正面是順時針（CylinderMesh 頂蓋的右手定則法線朝下），測試照這個檢查。

## D-129　2026-11-09　重現的石拱是圓拱：48 邊拱洞＋一圈拱石

- 決策：`NineBreathSite._build` 的拱洞 `CSGCylinder3D.sides` 從預設 8 改成 48；新增 `_build_arch_trim()`：11 塊楔形拱石（`CSGPolygon3D`，正中拱心石外緣高 0.16 m、多凸 0.05 m）、兩側拱腳線腳（impost）、柱腳（plinth）、頂上壓頂（coping），都凸出牆面 0.07 m。形狀常數 `ARCH_SPRING`、`ARCH_INNER`、`ARCH_OUTER`、`VOUSSOIRS` 等。
- 理由：第七輪盤點第 1 項。`08-arch-preview`（重現的關鍵一刻、README 與商店截圖）的預覽輪廓拱頂是尖的多邊形，看起來像五角形的屋子，不像石拱；原因是 CSG 圓柱預設只有 8 邊。凸出的拱石與線腳讓預覽的 fresnel 輪廓和重現後的石頭都讀得出「拱」。
- 影響：`test_nine_breath_site::test_arch_has_round_vault_and_voussoirs`（CSGPolygon3D 從 z=0 往 -Z 擠出，所以位置設在 `depth / 2`；測試檢查前後對稱）。拱石上的石縫還是 shader 的水平錯縫（世界座標），沒有沿拱圈放射——列在第七張表第 4 項。

## D-128　2026-11-09　廣場的一圈圈石板不是正圓

- 決策：`wet_cobble.gdshader` 弧形鋪（D-120）的跨排座標 `p.y` 加上 `noise(xz × 0.11)` 的起伏（`row_wave × 1.3`，約 ±0.7 塊），從石框外 0.5 m 到 4 m 漸漸加上；貼著石框的幾圈還是正圓。
- 理由：第 29 輪留下的疑慮「同心圓太像靶心」。screens 的 `03` 看起來整個廣場是一圈圈完美的同心圓、圓心是石框的鐘紋，像靶或唱片。真的廣場弧形鋪也不會是正圓。改了之後還是看得出繞著石框鋪，但圈是有機的起伏。
- 影響：純外觀（截圖對照 `--at=plaza`）。起伏太大會讓圈在某處擠在一起，調 1.3 這個數；`test_plaza_arc_paving` 不變。

## D-127　2026-11-09　破屋頂的雪：變薄、看得到屋瓦的橫紋、薄的地方露出屋瓦

- 決策：`SnowMound.build` 新增 `on_tiles`：UV2.y＝`TILES_MARK`（10）＋沿模型 X 的公尺數（跟街邊雪帶的 -1～1 分得開，shader 用 > 5 分辨）。破屋頂每片上的三團雪設 on_tiles，高度改成 `RUIN_SNOW_H`（0.065／0.085／0.1，原本 0.1／0.14／0.16）。`snow.gdshader`：屋瓦上的雪每 `tile_row`（0.26 m，跟 `roof_tiles` 的 `row_h` 一樣）一道暗的橫紋（遠處依 fwidth 淡掉），外圈與雜訊低處一塊塊露出屋瓦（`under_color`）；`under_color` 從 (0.13, 0.14, 0.17) 調暗成 (0.1, 0.105, 0.125)，接近屋瓦與濕石板。
- 理由：第六輪盤點第 4 項。`06-rescue` 左上破屋頂的雪是幾個又大又亮的白色圓頂，像棉被。斜屋面上的雪本來就薄、會透出底下一排排屋瓦。改了之後看得出是「屋瓦上的一層薄雪」。
- 影響：`test_snow_mound::test_on_tiles_marks_slope_meters`。橫紋沒有跟屋瓦真的對齊（模型 X 的原點是雪堆中心），近看不明顯；要對齊得把雪堆在瓦片上的位置傳進來。完整屋頂的屋簷雪堆（D-112）沒有設 on_tiles。

## D-126　2026-11-09　雪面細節：風吹的紋、靠牆的角落、腳印

- 決策：`snow.gdshader` 加三樣：①風吹的紋——順著 `wind_dir` 的細波（`ripple_freq` 4.5，波長約 22 cm、一邊緩一邊陡、相位被大尺度雜訊扭曲、一片一片出現、同一道紋強弱不一），只動法線（`ripple_strength` 0.45）與一點亮暗，遠處依 fwidth 淡掉；所有朝上的雪都有。②`SnowMound.build` 新增 `street_bank`：UV2.y＝往牆那側多遠（-1 靠街、+1 靠牆），只有街邊雪帶設 true；靠牆的角落暗、偏藍（`wall_shade` 0.55）、少反射天光（SPECULAR 0.45 → 0.12）、閃點少。③靠街那側 50 cm 格子裡約四成有一個橢圓腳印凹痕（26×11 cm、踩實偏灰、內壁法線往中心）；台地上的雪帶靠街那側也有髒雪。
- 理由：第六輪盤點第 3 項。`05`、`07` 牆腳的雪帶是一個個光滑的白枕頭，月光下靠牆那條邊還是亮藍色（天光的反射）。不動幾何、只改 shader，小鎮合併 mesh 數不變。
- 影響：`test_snow_mound::test_street_bank_lean_in_uv2`。紋太明顯（像木紋）調 `ripple_strength`；腳印太多調 `footprint_density`。腳印方向是格子雜湊（沒有順著街），近看像散落的單一腳印，不是一串。

## D-125　2026-11-09　重現預覽：還沒長到的部分留一層淡輪廓

- 決策：`restore_ghost.gdshader` 在 `fill` 以上不再 `discard`，改畫淡淡的邊緣輪廓（`0.05 + 0.3 × fresnel`，加法混合）；已長到的部分照舊（石縫、邊緣亮、往上長的亮線）。
- 理由：第六輪盤點第 2 項。查了才知道石拱的幾何是完整的：`08` 截圖是按住 60%（`debug_preview`）的樣子，D-046 的預覽從地面往上長、上面整個看不到，所以只看到兩根柱子與拱腳往內彎。按住的前幾秒玩家也只看到柱子、看不出「會變回一座拱」。改了之後一按下去就看得到整座拱的淡輪廓，亮的部分再往上長滿。
- 影響：沒有新測試（`test_nine_breath_site` 的 fill 斷言不變）。輪廓太亮會搶走「往上長」的感覺，調 0.05／0.3 這兩個數。

## D-124　2026-11-09　石縫的雪只有牆腳約 0.6 m 內連成線

- 決策：`wet_cobble.gdshader` 的 `in_gap`：石縫雪「連成線」的權重從 `near`（離牆多近，0～1）改成 `smoothstep(0.85, 1.0, near)`（約牆腳 0.6 m 內），其他地方跟空地一樣用雜訊打散成一段段。`lodge`（有多少雪）與靠牆石板上的薄雪（`on_stone`）不變。
- 理由：第六輪盤點第 1 項。南街半寬 3.5 m、`wall_reach` 2.6 m，整條街幾乎都算靠牆，月光照到的地方石縫雪連成一片淺灰格子（D-120 之後本機截圖還是看得出來）。改了之後 `--convoy --phase2 --face=undertaker` 右下的石縫大多是暗的，靠牆的石板上一層薄雪，看起來是「雪地上的石頭」而不是「白色格線」。
- 影響：沒有新測試（純外觀，截圖對照）。要調連成線的寬度改 0.85 這個門檻（越大越窄）。

## D-123　2026-11-09　「第一眼」第六輪盤點

- 決策：用 screens 的 11 張（下載到的還是 448c67e 建置：release 的 screens.zip 剛換過時可能抓到舊檔，要看 zip 裡的時間）＋本機 D-120 之後的截圖（廣場、攤子、石階、主街、南街口、送葬者戰）排了 6 項，寫進 PLAN 階段 2 第六張表：窄街靠牆的石縫雪連成淺灰格子 → 石拱預覽的拱頂 → 雪帶像光滑的白枕頭 → 破屋頂雪堆 → 廣場街口的鋪法分界 → TAA（從第五張表第 7 項移過來，等 Jacky）。
- 理由：第五輪除了 TAA 都完成了。最顯眼的是送葬者戰（`07`、`11`）南街靠牆那一大片石縫雪（窄街整條都算靠牆；D-120 之後本機再拍一次還是格子），以及石拱預覽（`08`）的鬼影看不出拱頂。
- 影響：第 29 輪順手做了第 1、2 項（D-124、D-125）；下一輪從第六張表第 3 項開始。

## D-122　2026-11-09　店招畫上店家的剪影（靴子、壺、鑰匙）

- 決策：`door.gdshader` 多一個店招模式：頂點色 r＝0.4／0.5／0.6（介於木箱 0 與門 1 之間；門的門檻改成 r ≥ 0.75）分別是靴子、壺、鑰匙；長得跟木箱一樣（橫排木板＋四邊角條），兩個大面多畫一個褪色淺黃漆的剪影（距離場，舊的斑駁掉色）；a＝1 表示大面朝 ±X、0 朝 ±Z（vertex() 傳模型空間法線，只在大面畫，薄邊不畫）。`FrostbridgeLook.sign_icon(pos)`（位置雜湊，不動 `_rng`）、`sign_tint(pos, faces_x)`；`frostbridge.gd` 記下 `shop_sign_icons`。不用文字。
- 理由：第五輪盤點第 6 項。店招原本只是一塊深色木板，夜裡遠看是剪影；畫上圖案後近看看得出是哪種店（南街口截圖左上那塊是壺），鎮上的生活感多一點，而且不需要翻譯。
- 影響：`test_frostbridge::test_upper_floors_have_windows_and_signs` 多了圖案的斷言（不只一種、shader 解得回同一個編號）。新的圖案在 `sign_icon()` 的 shader 函式加分支、`SIGN_ICONS` 加一，r 的編碼照 0.4＋0.1×編號（不要超過 0.7）。

## D-121　2026-11-09　鐘鈕：鐘身往下移，鐘頂一個鐘冠＋兩個交叉的環穿過鐘架

- 決策：`frostbridge.gd` 的鐘：`BELL_DROP` 0.22 m——鐘身與三道紋帶往下移，鐘頂與鐘架之間多一個車床做的圓頂鐘冠（`BellCrown`，蓋住幾乎平的鐘頂）＋兩個交叉的青銅環（`BellLoop0/1`，TorusMesh 立起來，往上穿進鐘架）；兩條鐵箍加長到鐘肩。鐘的擺動支點不變（還是橫樑）。`Lathe.bell_profiles` 沒改（`test_lathe` 的頂點數照舊）。
- 理由：第五輪盤點第 5 項。敲鐘過場（README 第三張）裡鐘頂直接頂著橫樑，看起來平平的、像黏在木頭上；真的鐘是用鐘鈕吊在鐘架上。敲鐘鏡頭是從下往上看，鐘冠大半被鐘肩擋住，所以環做得比實物粗一點（管徑約 3.7 cm、環半徑 16.5 cm），截圖裡才看得出鐘頂有東西往上接到鐘架。鐘室兩側現在看得到 D-117 的夜空（雲與星），不用另外調。
- 影響：`test_frostbridge` 的鐘室斷言加上鐘鈕（環頂穿進鐘架、環底埋在鐘冠裡、鐘身在 `-BELL_DROP`）。之後換正式的鐘模型時，鐘鈕的高度照 `BELL_DROP`。

## D-120　2026-11-09　地上的石板不像磁磚：廣場弧形鋪、街道的排微微起伏、每塊石板形狀不同、石框裡不蓋雪

- 決策：`wet_cobble.gdshader` 的排列改成（D-095 的「平的石板＋只有邊緣倒角＋每塊小傾斜」不變）：①**廣場繞中央石框一圈圈弧形鋪**（`arc_paving`、`arc_center`；每圈剛好整數塊，接縫處不會切出半塊；外側的石板比內側寬一點，倒角的法線轉成徑向／切向）；②其他地方（街道、台地、石階踏面）還是直排，但排會隨低頻雜訊微微起伏（`row_wave` 1.1 塊）；③每排的石板長度乘 0.8～1.25；④每塊石板四邊縮進不同（石縫寬窄不一）、中心偏一點、圓角 0.06～0.24（有的方正、有的圓）、邊緣多一層石板大小的鼓出凹進；⑤石縫裡的雪減到 0.75、顏色暗三成（在陰影裡）；⑥`clear_disc` 圓裡不蓋殘雪與薄雪（廣場石框裡）。新增 `FrostbridgeLook.wet_ground_arc(color, size, puddles, center, clear_radius)`（key 也是 `wet/` 開頭，殘雪設定照樣套上）、`frostbridge.gd` 的 `plaza_ground()`（廣場與石框內圈同一個材質，合併 mesh 數不變）。遠處淡成平均值的 `aa` 改用連續的世界座標量（弧形鋪的 p.x 在排與排之間不連續）。
- 理由：第五輪盤點第 2 項（與第 8 項）。`03`、`04`、`05` 下半畫面是一樣大的長方形排成一條條直的錯縫，像磁磚；石縫的殘雪像白格子。概念圖是小而不規則、圓一點的石頭。截圖對照（廣場、攤子、石階、主街）：廣場繞石框一圈圈鋪開、街道的石頭圓而不規則，石縫是暗的、不再是白格子；石框裡是乾淨的深色鋪石。
- 影響：`test_frostbridge::test_plaza_arc_paving`。Godot shader 內建 `TAU`，自己再宣告會編譯失敗。弧形鋪的接縫在廣場西邊（z＝0、x＜0），每圈整數塊所以看不出來。廣場與主街、南街的交界是一條弧形鋪與直排的分界線（實際的鎮也是這樣），之後要的話可以在分界加一排收邊石。

## D-119　2026-11-09　雪堆的外圈變薄（SnowMound 的 UV2 放圈數）

- 決策：`SnowMound` 每個頂點多一個 UV2，UV2.x＝圈數（0＝最高點、1＝外圈）；`snow.gdshader` 用它讓外圈（跟著雪的起伏不規則）漸漸混成底下的暗色（`under_color`，從 `edge_start` 0.5 開始），雪粒閃點跟著消失。其他的雪（屋頂稜柱、方塊）沒有 UV2，跟雪堆合併時 SurfaceTool 補 0＝不變薄——**同一個雪材質，合併 mesh 數不變**（本來想用另一個「雪堆專用材質」，小鎮合併 mesh 會變 25 個、超過上限 24，破屋頂 batch 也多一個，改用 UV2）。街邊雪帶、屋簷雪、柴堆、木箱、圍欄、院子、破屋頂的雪堆全部一起變。
- 理由：第五輪盤點第 3 項。`06-rescue` 左邊三分之一的破屋頂雪堆還是一塊塊發亮的白板。先試了只改幾何（6 圈＋圓頂往邊緣變薄），截圖幾乎沒差、中心反而變尖，已還原：問題在明暗（白雪跟深色屋瓦之間是一條硬邊），不在厚度。改完雪堆有體積、邊緣柔和；石階的街邊雪帶靠街那側也跟地面接得比較自然。
- 影響：`test_snow_mound::test_ring_in_uv2`、`test_batch_with_plain_snow_keeps_rings`（驗證合併時方塊補 0、雪堆保留圈數）。新的雪堆照樣 `SnowMound.build`＋`look.snow()`。**合併時頂點色不能這樣用**（缺的會補成黑色），所以這裡用 UV2。

## D-118　2026-11-09　提燈照不出諾恩自己的影子

- 決策：諾恩身上所有幾何（人偶、提燈、之後加上的夾板、換上的角色模型）多放一層 `PlayerController.SELF_LAYER`（第 12 層，`1 << 11`；第 11 層是水窪倒影的 `REFLECT_LAYER`），提燈的 OmniLight 設 `shadow_caster_mask = LANTERN_SHADOW_CASTERS`（全部減掉這一層）。之後才加到 `Body` 底下的幾何靠原本的 `node_added` 連線補上。提燈照樣投牆、席菈、敵人的影子；月光與路燈照樣投諾恩的影子。
- 理由：第五輪盤點第 4 項。提燈掛在左手、離身體只有幾公分，走路與揮擊時手一擺，身體擋住提燈的那一大片影子就在地上甩來甩去（第三人稱遊戲的手持燈通常都排除玩家自己）；也少一個要畫進 cube 陰影圖的角色。**注意**：`03-plaza` 右下那一大片黑楔形不是提燈造成的，是廣場西邊有影子的路燈（-8, 7.5）把諾恩拉出一道 12 m 的長影子——那是對的，保留。
- 影響：`test_lantern_shadow::test_lantern_does_not_shadow_noen`。之後要排除別的東西（例如席菈手上的火）照同一個模式。

## D-117　2026-11-09　冬夜天空：雲、月光、遠山稜線

- 決策：背景從一片平的顏色（`BG_COLOR` 0.03, 0.04, 0.07）改成 sky shader `night_sky.gdshader`（`FrostbridgeLook.night_sky()`，radiance 128、`PROCESS_MODE_QUALITY`）：天頂暗、地平線亮一點；一層投影在高空平面的雲（fbm 兩層，蓋住大半個天空，邊緣略亮；背月的雲也有被照亮的正面，靠月亮的更亮）；雲縫裡零星的星（不畫進反射用的 cubemap）；月亮與月暈在月光（LIGHT0）的方向；地平線一圈遠山稜線（用方位角的 cos／sin 取噪聲，一圈沒有接縫；北邊鐘樓後面比較高；靠稜線那段是月光照到的雪）。體積霧與低畫質深度霧對天空的影響降到 `SKY_FOG_AFFECT` 0.4（原本 1.0 會把天空整片蓋成霧色）。環境光照舊用顏色，整體亮度不變。**不用 TIME**：用了每幀都要重算反射的 radiance；雲要動之後再做（`AT_CUBEMAP_PASS` 分開、或改 `PROCESS_MODE_INCREMENTAL`，要在實機看成本）。
- 理由：第五輪盤點第 1 項。幾乎每個遊玩鏡頭（`03`、`04`、`05`、`07`、`08`、`10`、`11`）上面三分之一都是一片平的深藍；概念圖是月光照亮的雲、遠山與鐘樓剪影。改了之後鐘樓第一次在廣場的畫面裡有清楚的剪影（霧在鐘樓前面發亮、天空比較暗）。月亮在月光方向：平常的鏡頭朝北，月亮在背後（陰影方向才對），看到的是雲與山。
- 影響：`test_night_sky`（背景是天空、霧不整片蓋掉、shader 不用 TIME）。濕石板反射遠處的天空時會帶到雲的亮度；之後若要讓月亮出現在主街畫面裡，要連月光方向一起轉（影子會改成朝鏡頭），在實機看過再說。

## D-116　2026-11-09　「第一眼」第五輪盤點

- 決策：用 screens 的 11 張（ee3a0ee 建置，已含第 27 輪的殘雪、車轍、角色淡出）對照概念圖 `art-inbox/concepts/frostbridge_winter/`，排了 8 項，寫進 PLAN 階段 2 第五張表。順序依畫面被看到的程度：天空 → 地上石板太像磁磚 → 破屋頂的雪堆像白色平板 → 提燈的自身影子 → 鐘鈕 → 店招圖案 → 高畫質 TAA → 石框裡的薄雪。
- 理由：第四輪盤點全部完成；概念圖跟遊戲畫面差最多的是天空（月光雲、遠山、鐘樓剪影）與地面（小而不規則的圓石 vs. 大而整齊的方石板）。
- 影響：第 28 輪做第 1、3、4 項；下一輪從第 2 項開始。

## D-115　2026-11-09　席菈與敵人擋在鏡頭前時抖動淡掉

- 決策：`CameraFade` 新增 `CHARACTER_NEAR` 0.4／`CHARACTER_FAR` 1.0，並支援宣告了 `fade_near`／`fade_far` uniform 的 ShaderMaterial（其他 shader 不動）；送葬者的 `frame_iron.gdshader` 加上跟 StandardMaterial3D `DISTANCE_FADE_PIXEL_DITHER` 同一套的抖動淡出。`Sheila._ready` 與 `EnemyActor._ready`（`_build_body` 之後）套用；敵人用 `camera_fade_range()`，送葬者覆寫成 0.9～1.9 m（`BIG_FADE_NEAR`／`BIG_FADE_FAR`）。諾恩本身不淡。
- 理由：第四輪盤點第 6 項。D-085 之後 SpringArm 不撞角色，送葬者／席菈站到鏡頭與諾恩之間時鏡頭會在他們身體裡；送葬者又高又寬，離鏡頭 1.5 m 還擋掉畫面三分之一（截圖 `--convoy --phase2 --face=undertaker --face-off=200` 對照：鐵架與大衣變成網點、看得到後面的牆）。
- 影響：`test_camera_fade::test_apply_sets_shader_fade`、`test_characters_fade_near_camera`。正式角色模型（glb）匯入的材質也會被設定；同一個 glb 的材質是共用資源，換模型後要確認不會影響到別的角色。抖動在沒有 TAA 時近看有網點（跟推車淡出一樣，D-106）。

## D-114　2026-11-09　廣場地上的殘雪、髒雪與車轍（濕石板 shader）

- 決策：`wet_cobble.gdshader` 新增三組資料（都是 uniform，沒設定時跟原本一樣，沙盒不受影響）：①`lanes[8]` 街道範圍（中心 xz、半寬 xz）：離邊越近（`wall_reach` 2.6 m，兩個方向都靠邊的角落更多）石縫裡卡的雪越多、靠牆的石板上蓋一層薄雪；空地上石縫的雪是一段一段的（細雜訊打散），另外偶爾一片被風吹散的薄雪；點在好幾個範圍裡取離牆最遠的那個，主街／南街的範圍伸進廣場，街口不會積成一道雪。②`trodden[4]` 踩實的灰褐髒雪（圓心、內外半徑）：井邊一圈、梨販攤前一片，斑駁、石縫裡最髒、粗糙度 0.62。③`rut_pts[8]` 車轍中心線：兩道相距 1.37 m（手推車的輪距）的濕亮輪溝（粗糙度 0.08、溝壁法線朝溝心）＋兩側被推開的雪，兩端淡出、中間斷斷續續。水窪不蓋雪。`FrostbridgeLook.set_ground_marks(lanes, trodden, rut)` 套到所有已建立與之後建立的濕石板材質；霜橋鎮的資料在 `frostbridge.gd` 的 `ground_lanes()`、`TRODDEN`、`RUT_PATH`（西側手推車往東出來、繞過井與中央石框、進主街）。原本的 `snow_amount` 低頻積雪門檻 0.82 幾乎不會出現（fbm 大多在 0.3～0.65），新的門檻照這個範圍抓。
- 理由：第四輪盤點第 4 項。廣場（`03`、`04`、`02` 暫停背景）下半畫面是一大片空的暗石板；概念圖的地上有踩過的雪、髒雪與車轍。全部在 shader 裡：不擋人、不進碰撞、不多 draw call、不多頂點。街邊雪堆的邊緣也跟地面接起來了（主街截圖）。
- 影響：`test_frostbridge::test_ground_snow_and_ruts`（每個濕石板材質都拿到資料、街口不是牆、髒雪在廣場裡、車轍不壓到井／石框／路燈／圍欄／木桶、最後進主街）。新的段落要殘雪，就在那一關呼叫 `set_ground_marks`；街道範圍的盡頭會被當成牆，所以要一路伸到對面那條街的牆（第 27 輪南街口一道雪就是只伸進路口 1 m 造成的，ee3a0ee 改成伸到路口南邊）。

## D-113　2026-11-09　車上的傷者包著頭巾

- 決策：`Caravan._wrap_head(傷者, 繃帶)`：在傷者的 `joint("neck")` 下加「HeadWrap」（SphereMesh 半徑 0.148、往後腦偏 0.035 m，臉中間露出一小塊，`HEAD_WRAP` 深色毛布），第一名傷者額頭再纏「Bandage」（TorusMesh、淺色、微微歪斜）。只改傷者，不動 Puppet 本體；CameraFade 照樣套到。
- 理由：第四輪盤點第 5 項。推車經過鏡頭底下時，畫面最清楚的是兩顆光滑的球形頭；頭巾＋繃帶一眼看得出是「傷者」。淡出的網點維持（不透明畫法、沒有排序問題）。
- 影響：`test_caravan::test_cart_is_built_like_a_cart`。正式角色模型接進來後，傷者要另外的躺姿與頭巾（模型版）。

## D-112　2026-11-09　屋頂雪的下緣：沿屋簷一串扁雪堆

- 決策：`_roof_snow_lip(batch, 屋頂旋轉, origin, center, 底寬, 高, 長, 屋簷高)`：每片斜面沿屋簷方向約每 1.5 m 一個 `SnowMound`（長 1.1～1.45 倍間距、寬 0.55～0.9 m、高 0.08～0.12 m、`bias` (0, 0.4) 最高點偏向屋脊），模型 X 沿屋簷、Y 是斜面法線、Z 往屋脊；雪堆的上半埋在雪稜柱底下，下緣往下伸出 0.06～0.45 m（不超過露出瓦的長度減 0.35 m）。位置雜湊（不動 `_rng`）；北街會陷落的房子放在完整屋頂那份 batch。`roof_snow_lips` 計數。
- 理由：第四輪盤點第 3 項。`ROOF_SNOW` 雪稜柱的下緣是一條直線，廣場往北看每棟屋頂都是「雪＋一道直邊的深色帶」（D-107 影響欄）。
- 影響：`test_frostbridge::test_roofs_use_tiles`。約 25 棟 × 2 面 × 3～5 個雪堆，合併進原本的雪材質。

## D-111　2026-11-09　車隊推車重做（不再是 CSG）

- 決策：`Caravan._build` 全部改成 MeshInstance3D（`_box`／`_part` helper）：兩根深色縱梁（`WOOD_DARK`）上鋪 `PLANKS` 5 片木板（寬度、長短、厚薄不一、板縫 2 cm）；兩側下寬上窄兩道邊板＋三根立樁；前後擋板；輪子 `WHEEL_R` 0.42、`WHEEL_X` 0.74、`WHEEL_Z` 0.3：鐵輪框（TorusMesh）＋木輪框＋輪轂＋`SPOKE_BARS` 3 條（六根輻條）、鐵車軸；兩根往前翹 6° 的車把＋橫把、前端兩根撐腳；提燈 `LANTERN_POS` 掛在前右角燈柱的鐵橫桿下。做完照舊 `CameraFade.apply`。第一個子節點是縱梁「Bed」（測試從這裡拿木頭材質）。
- 理由：第四輪盤點第 2 項。送葬者戰的主角之一是 CSG 方塊＋實心圓柱輪、提燈浮在半空，比廣場的手推車（D-103）粗糙很多。
- 影響：`test_caravan::test_cart_is_built_like_a_cart`、`test_cart_fades_near_camera`。傷者仍是程序人偶（頭是光滑的球，第四輪第 5 項）。

## D-110　2026-11-09　破屋頂的屋面也有瓦；SnowMound 輪廓變圓

- 決策：新增 `RoofMesh.slab(長, 厚, 寬)`：外形跟 BoxMesh 一樣，只有頂面 UV 是公尺（u＝z＋寬/2、v＝x＋長/2，-X 那端是屋簷），其他面 (-1, -1)。`_roof_ruin` 的背面、朝街那面沒掉光的每一片、掉進屋裡的碎片都改用它＋`look.roof_tiles()`（山牆維持素面）。`SnowMound`：`SEGMENTS` 14→20；輪廓往內凹改成 `0.6 sin(2θ+φ1) + 0.3 sin(3θ+φ2) + 0.1 雜訊`（原本每段各自亂數 → 鋸齒）；每個頂點的高度抖動 ±10%→±5%。破屋頂那一大片雪 0.08→0.1 m。
- 理由：第四輪盤點第 1 項。`06-rescue` 左邊三分之一是破屋頂：完整屋頂有瓦（D-107）以後，素面的屋面很突兀；雪堆的鋸齒輪廓＋同一個亮度，近看像潑上去的白漆；中心一根根放射狀的稜。
- 影響：`test_roof_mesh::test_slab_tiles_only_on_top`、`test_frostbridge::test_collapsed_houses_show_broken_roofs`（屋瓦材質、`tiled` 等於片數）。SnowMound 每個 81 個頂點（原本 57），街邊雪帶約 110 個也一起變圓。

## D-109　2026-11-09　第四輪「第一眼」盤點

- 決策：用 screens 的 11 張（646e4a9 建置）＋本機截圖排了 7 項（PLAN 階段 2 第四張表）：①破屋頂素面＋雪像白漆、②車隊推車 CSG、③屋頂雪的下緣直線、④廣場下半畫面一大片空的暗石板、⑤傷者的頭是光滑的球（推車經過鏡頭時最顯眼）、⑥角色站進鏡頭時（D-085 後續）用 CameraFade 淡掉、⑦SnowMound 段數（併入 ①）。
- 理由：第三輪 10 項做完；照「每個畫面被看到的程度」排序。06 的破屋頂佔畫面三分之一、07 推車是送葬者戰主角，所以先做。
- 影響：第 26 輪完成 ①②③⑤⑦；下一輪從 ④ 開始。

## D-108　2026-11-08　諾恩、席菈、灰巡者的接地陰影

- 決策：把送葬者腳下那片接地陰影（D-101，`ground_shadow.gdshader`）抽成 `ContactShadow.attach(角色, 半徑, 強度)`（`src/world/contact_shadow.gd`）：一片貼地 PlaneMesh、透明度畫、不投影、`render_priority` -1（畫在前兆範圍底下），掛在角色本身。諾恩、席菈半徑 0.55、灰巡者 0.65、強度 0.5。送葬者維持自己那一片（倒下時要拉長、淡掉）。
- 理由：第三輪盤點做完後的第四輪候選（D-101 影響欄、NEXT）。夜裡月光的影子被霧吃掉、路燈大多不投影，人物像浮在濕石板上；一片柔和的黑把人「放」到地上，成本是一個透明平面。
- 影響：`test_contact_shadow`。在石階上會被台階邊緣切掉一部分（深度測試），可以接受。正式角色模型接進來後照樣掛在角色本身。

## D-107　2026-11-08　屋瓦：RoofMesh＋roof_tiles.gdshader

- 決策：新增 `RoofMesh.build(寬, 高, 長)`：外形跟 PrismMesh 一樣，但兩片斜面的 UV 是公尺（u 沿屋簷、v 從屋簷沿斜面往上），山牆 UV (-1, -1)，不畫底面、平面法線。新增 `roof_tiles.gdshader`（`FrostbridgeLook.roof_tiles()`，全部屋頂共用）：排高 0.26 m、瓦寬 0.34 m、每排錯開，下緣淺色瓦邊、上一排的影子、瓦縫、每片深淺／粗糙度、偶爾偏暖偏冷、瓦邊薄霜；`fwidth` 超過約半片瓦就淡回平均色。屋頂的雪 `ROOF_SNOW` 0.82→0.7（雪蓋住屋頂高度的上 70%），雪的下緣露出最下面三四排瓦。
- 理由：第三輪盤點第 10 項。屋頂原本平塗深色＋雪稜柱，近看沒有瓦。合併後的 mesh 不能用模型座標排瓦（StaticBatch 把變換烘進頂點），PrismMesh 的 UV 是圖集排法、不是公尺，所以自己產生幾何。
- 影響：`test_roof_mesh`、`test_frostbridge::test_roofs_use_tiles`。小鎮多一個材質（仍在 24 以內）。遠看（廣場對面）只看得出雪下一道有橫紋的深色帶；陷落的破屋頂（D-091）還是素面材質，之後可以換成同一個 shader（要給碎片 UV）。

## D-106　2026-11-08　車隊推車靠近鏡頭時抖動淡掉（CameraFade）

- 決策：新增 `CameraFade.apply(節點, near, far)`：把一棵節點樹裡所有 StandardMaterial3D（CSG、mesh、material_override）設成 `DISTANCE_FADE_PIXEL_DITHER`；已有淡出設定的材質不動。`Caravan` 的推車、布、兩名傷者 `CART_FADE_NEAR` 1.6 m、`CART_FADE_FAR` 3.4 m（戰鬥時鏡頭在諾恩身後 4.2 m）。提燈燈罩維持原本 0.8～2.2 m。
- 理由：第三輪盤點第 9 項。推車每秒 1.1 m、沒有碰撞，從後面追上諾恩時會經過鏡頭底下，整台推車擋住畫面下半（`07-convoy-fight`）。實際遊玩時（南街口觸發）推車從 10 m 後面追上來，一樣會經過；所以不是改截圖站位，而是讓擋在鏡頭與諾恩之間的推車淡掉（很多第三人稱遊戲的做法）。抖動是不透明畫法，沒有半透明排序問題。
- 影響：`test_camera_fade`、`test_caravan::test_cart_fades_near_camera`。近看有網點（螢幕門效果）；之後如果送葬者／席菈站在鏡頭裡（D-085 的後續）也可以用同一個 helper（near 0.4～far 1.0）。

## D-105　2026-11-08　街邊雪帶改成靠牆堆高的一串雪堆

- 決策：`_snow_bank(牆腳線起點, 終點, 牆的方向, 伸出寬度)`：沿牆每約 1.8 m 一個 SnowMound（長 1.3～1.6 倍間距、互相重疊），模型 Z 軸對著牆、最高點往牆偏（`SnowMound.build` 新增 `bias` 參數，這裡 0.5），雪堆有 0.3 m 埋進牆裡（看不到），靠街那側伸出原本雪帶的 0.75～1.1 倍；高 0.13～0.24 m；長短、寬窄、高低用位置雜湊。廣場兩側、主街、北街、南街、路口南側都換掉（原本的平板拿掉），石階上不放；沒有碰撞。`SnowMound` 每一圈改成輪廓對最高點的縮放（k²），最高點偏很多也不會翻面（原本的雪堆外形幾乎不變）。
- 理由：第三輪盤點第 8 項。原本是 4 cm 高的平板，低角度看是一條直邊的淺色帶；靠牆高、靠街緩又不規則的雪堆在路燈斜照下有明暗，也更像概念圖。
- 影響：`test_snow_mound::test_peak_bias_leans_toward_wall`、`test_frostbridge::test_street_snow_banks`。約 110 個雪堆、每個 57 個頂點，合併進同一個雪材質。角色走過時腳會陷進雪堆（沒有碰撞，像踩在雪上）。

## D-104　2026-11-08　廣場西北角的木圍欄（第三輪盤點第 7 項的最後一步）

- 決策：`FENCE_PATH`（(-4.7, -10) → (-4.7, -8.3) → (-7.25, -8.3)）：北排最東那棟（主街口）門前圍出一小塊院子。立柱 0.11 m 見方、高 0.95 m ±、微微歪向一邊、頂上一小團雪；上下兩道橫木（0.36／0.76 m）釘在朝廣場那側、上面那道頂上一條雪；最西那一格的上橫木斷了一頭、斜垂到地上；院子裡一整片沒人踩過的雪（深色圍欄襯在白雪前面才看得出來）。每段一個細長方塊碰撞。沿用木頭與雪的材質。
- 理由：第三輪盤點第 7 項的最後一步（概念圖的廣場邊有圍欄）。放在主街口西邊、廣場北排門前：從廣場往北看（`03-plaza`）就在畫面左邊；不擋主街口、路燈、井、木桶。第一版沒有院子裡的雪，深色圍欄貼著深色牆幾乎看不見。
- 影響：`test_frostbridge::test_plaza_fence`（數量、位置、斷掉的橫木、兩段都擋人、主街口沒被擋）。第三輪盤點第 7 項完成。

## D-103　2026-11-08　廣場的柴堆與手推車（第三輪盤點第 7 項的第二、三步）

- 決策：東牆、地窖北邊（`WOODPILE_POS` 10.2, -7.7）一落柴：5 排橫放的圓木（CylinderMesh 轉 90°、7 段、上面幾排少一根往中間縮）、每根粗細與前後突出用位置雜湊、底下兩根墊木、朝廣場那端一片淺色斷面（新材質 `LOG_END`，小鎮 mesh 數仍在 24 以內）、頂上一層 SnowMound；西牆（`HANDCART_POS` -9.3, 0.9）停一輛兩輪手推車：車斗＋低車欄、把手朝廣場＋兩根撐腳、木輪（TorusMesh 鐵輪框＋木輪框＋輪轂＋六根輻條）、鐵車軸、車斗裡一個木箱（木箱模式）與雪堆，整台斜放幾度。兩者各一個方塊碰撞。
- 理由：概念圖的廣場邊有木桶、柴堆、推車、圍欄；D-100 做了木桶，這輪補柴堆與推車（都在主要路線以外，不影響流程測試走位）。柴的斷面是「一眼認得出是柴」的關鍵，所以多一個材質；推車沿用木頭／鐵件／木箱／雪。
- 影響：`test_frostbridge::test_plaza_woodpile`、`test_plaza_handcart`。第 7 項只剩木圍欄。

## D-102　2026-11-08　SnowMound：破屋頂上的雪改成低面數雪堆

- 決策：新增 `src/world/snow_mound.gd`（`SnowMound.build(長, 寬, 高, seed) -> ArrayMesh`）：中心一點＋4 圈 × 14 段的極座標網格，超橢圓（次方 3.2）的圓角長方形輪廓、每段往內凹最多 22%、最高點偏一點、高度 `(1-k²)^0.7` 到外圈 -0.012（貼進斜面）；有法線與 UV、正面朝上（順時針）。`_roof_ruin` 每片斷屋頂的三塊雪與洞底那團都換成雪堆。
- 理由：第三輪盤點第 6 項。box 的雪四邊是垂直白牆、輪廓是長方形，北街救援（`06-rescue`）近看像屋頂上擺著冰板；雪 shader 用世界座標（D-068），合併後沒有可靠的 UV 做邊緣淡出，所以改幾何。
- 影響：`test_snow_mound`（大小、中間厚邊緣 0、法線與正面朝上、同 seed 一樣）。柴堆、推車的雪也用它（D-103）；之後街邊雪帶（第 8 項）、屋頂完整的雪也可以用。截圖近看輪廓仍看得出多邊形，要更圓可以把 `SEGMENTS` 調到 18。

## D-101　2026-11-08　送葬者在霧裡的輪廓

- 決策：兜帽前加一片壓扁的黑色橢球（`HoodVoid`，看不見臉的黑），兩點霜光移到它前面（原本在頭巾球裡面被擋住）；兜帽冷光從頭巾正前方移到胸口、範圍 2.4→1.2 m、`light_volumetric_fog_energy` 0.15；大衣底色 0.11→0.055（保留燈下邊緣光 D-054）；鐵架改用 `frame_iron.gdshader`（看出去越斜的面越亮的霜色邊緣光＋世界座標朝上的面結薄霜），背上的與擲出去的 `ThrownFrame` 共用 `Undertaker.frame_iron_material()`；腳下一片貼地的接地陰影（`ground_shadow.gdshader`，黑色＋透明度、照樣被霧蓋住，掛在送葬者本身不跟著身體跪下，`render_priority` -1 畫在前兆範圍底下；倒下時往前拉長、下沉時淡掉）。
- 理由：第三輪盤點第 5 項。截圖裡送葬者是一團灰藍：冷光把頭巾照成一顆亮球、整件大衣正面照成霧藍、還在體積霧裡亮成一團。換成「兜帽裡一片黑＋兩點霜光」之後一眼看得出他在看你，也更像原作裡的送葬者。不新增燈、不新增投影。
- 影響：`test_undertaker::test_silhouette_reads_in_fog`、倒地測試加接地陰影。大衣本身在 8～10 m 外仍被霧染成灰藍（霧是整條南街的），要更分明得調南街的霧或等正式模型。接地陰影之後可以給灰巡者、席菈、諾恩（同一個 shader）。

## D-100　2026-11-08　廣場牆邊的木桶（第三輪盤點第 7 項的第一步）

- 決策：`BARREL_SPOTS` 三處（西牆南段、東牆南段、西北角），每處 2～3 個立著的木桶（位置雜湊決定個數與小偏移）：上下兩段錐台（半徑 0.25→0.3）＋中段、兩道鐵箍、桶蓋上薄雪；木頭、鐵件、雪都用既有材質（小鎮 mesh 數不變）。`StaticBatch.add_shape(xform, shape)` 新增：只加碰撞、不畫（每個木桶一個圓柱碰撞）。
- 理由：概念圖的廣場邊有木桶、柴堆、推車、圍欄；我們的廣場除了井和攤子是一大片空地。先做最簡單、最常見的木桶，放在主要路線（中間、攤子、地窖、井）以外，不影響任何流程測試的走位。
- 影響：`test_frostbridge::test_plaza_barrels`。第 7 項還剩柴堆、手推車、圍欄（下一輪可以接著做；柴堆的木頭端面可以用 Lathe 或 CylinderMesh 轉 90°）。

## D-099　2026-11-08　第三輪「第一眼」盤點

- 決策：用 prerelease「screens」的 11 張（fed0dfb 建置）＋本機截圖（廣場、石階、送葬者戰＋看穿）對照概念圖 `frostbridge_winter.png`，排了 10 項寫進 PLAN 階段 2 第三張表；依「每個畫面被看到的程度」排序：地面（每個遊玩畫面的下三分之一）＞上層牆面＞天際線＞戰鬥前兆＞送葬者輪廓＞破屋頂雪＞廣場空地＞街邊雪帶＞車隊戰開場鏡頭＞完整屋頂的屋瓦。
- 理由：第二輪 10 項做完（D-083 的做法：每輪從最上面拿）。第 23 輪本機截圖最刺眼的是地面：整片一樣大的鼓起方塊、每塊遠端一條亮邊，像氣泡紙，而且出現在每一張遊玩截圖。
- 影響：第 23 輪完成第 1～4 項（D-095～D-098）。

## D-098　2026-11-08　前兆範圍的裡面減半

- 決策：`telegraph.gdshader` 裡面的底色 0.04→0.02、填滿 `0.07＋0.16p`→`0.035＋0.085p`；亮邊線 `rim × (0.5＋0.5p)` 與填滿前緣亮線 0.45 不變。
- 理由：D-088 收尾時就記了「軟體渲染下內部偏亮，實機看過再調」；但加法混合與 AgX 色調映射在實機與 lavapipe 是同一套數學，盤點截圖（`11-convoy-insight`）裡一整片亮扇形蓋住畫面下三分之一、底下的石板都看不到，不用等實機。範圍與「還剩多久」靠邊線與前緣，裡面只要看得出是範圍內就夠。
- 影響：只改常數，截圖前後對照（`--convoy --insight --pos=2.2,9.5 --face=undertaker --face-off=18`）。Jacky 試玩若覺得太淡，先調 `filled` 那一項。

## D-097　2026-11-08　煙囪石帽與炊煙

- 決策：原本 35% 的房子有一根素面煙囪（`_rng` 決定，不變）。煙囪頂加一圈 0.76 m 寬的石帽（`stone_wall` 材質）；北街以外、位置雜湊 < 0.6、最多 `MAX_SMOKE`＝8 根冒煙：`CPUParticles3D` 每根 14 顆、壽命 7 秒（預熱 7 秒，一進場就有煙）、0.3～0.45 m/s 往上、微風往東、面片 1.6 m 從 35% 長到 100%、顏色偏藍的灰（月光下）、透明度最高 0.26；沒冒煙的石帽上積一小塊雪。北街（會陷落）的不冒煙。
- 理由：第三輪盤點第 3 項。概念圖的屋頂有炊煙，「有人住」的生活感與天際線的動態；原本每棟屋頂剪影都一樣、而且是靜止的。粒子很淡（0.26），不搶燈光，也不會在暗處變成灰塊。
- 影響：粒子一律用 `ParticleLook.material`（柔邊圓點，D-056）。8 根 × 14 顆、大面片透明疊加，全在屋頂高度，視角通常只看到 2～3 根；實機效能等 Jacky 的 benchmark（低畫質可以關掉）。`test_frostbridge::test_chimney_smoke`。

## D-096　2026-11-08　樓上的窗與門邊的店招

- 決策：`_house` 原本的窗不動（`_rng` 決定亮不亮）；另外 `_upper_windows`：每一層「窗頂離屋簷 ≥ 0.4 m」放得下就開窗（原本沒有窗的樓層左右兩扇；寬 > 5.2 m 的房子樓上每層中間再一扇；第三層的窗小一點 0.6×0.75）。約四分之一的房子（北街以外）門的另一側（掛燈的反方向）伸出鐵臂＋斜撐，用兩條短鏈吊一塊垂直於牆的木招牌（`door()` 的木箱模式、頂上一條雪），高 2.3～2.8 m 不擋人。新的窗與招牌一律用位置雜湊 `_house_hash`，不動 `_rng`、不打燈、不新增材質。
- 理由：第三輪盤點第 2 項。高的房子 4.5 m 以上、矮的房子 2 m 以上是整片灰泥，主街、石階兩側的上層牆面大片空白，看起來像沒蓋完的模型；招牌從街上斜看是一塊突出的剪影，打破一整排平的牆面。
- 影響：小鎮的窗多了二十幾扇（亮的約三成，`test_frostbridge` 的亮窗比例照樣通過）。`test_frostbridge::test_upper_floors_have_windows_and_signs`（`upper_window_count`、`shop_sign_count`）。招牌之後可以在木頭上畫簡單的圖案（梨、麵包、鐵錘），得改 door shader。

## D-095　2026-11-08　濕石板路：平的石板、長短不一

- 決策：`wet_cobble.gdshader` 的石塊從「一樣大的圓角方塊、整塊往外鼓」改成：每兩排一組、組內在 38%～62% 處分開（排寬 0.76～1.24 塊）；每排隨機錯開，約一半的格子再切成長短不一的兩塊（長寬比 `STONE_LEN`＝1.35）；圓角矩形距離場算石縫（寬約 0.09 塊、邊緣微鋸齒）；法線只在最邊緣一圈（`bevel_width`＝0.09 塊）往外倒（`bevel_strength`＝0.8），每塊石板另有自己的小傾斜（`stone_lean`＝0.2）與表面細微起伏；粗糙度每塊 ±0.08；少數偏暖或偏冷。水窪、波紋、積雪、遠處淡化（`aa`）照舊，`stone_size`（0.34／0.42）不變。
- 理由：第三輪盤點第 1 項。原本整塊鼓起，每塊遠端一條燈的亮邊，整片地面像氣泡紙／一顆顆枕頭，出現在每一張遊玩截圖的下三分之一；概念圖是平的、大小不一的濕石板。平石板＋每塊不同的傾斜，濕路上有的石板反光、有的暗，比較像真的。
- 影響：只改 shader。`test_frostbridge` 從原始碼讀 uniform 預設值（headless 的 RenderingServer 讀不到）檢查倒角寬度與每塊傾斜。截圖對照：廣場、石階。

## D-094　2026-11-08　README 的「重現」圖改拍石拱撐住鐵架

- 決策：CI 的 `ninebreath.png`（README 與 latest）從 `--convoy --arch=restored` 改成 `--convoy --throw=arch --throw-t=0.8 --pos=2.6,10.5 --face=arch --face-off=14`。
- 理由：第三輪盤點的第一眼（latest 圖）：D-088 之後送葬者下一招的前兆扇形是亮邊，在舊構圖裡佔掉畫面左下一大塊，送葬者被諾恩擋住，石拱小小的在遠處，看不出「重現」做了什麼。新構圖：亮起的石拱在畫面中間、鐵架砸在石拱上、席菈在旁、字幕「鐵架砸在石拱上。石拱撐住了。」——一張圖講完這個能力。
- 影響：只改 CI 截圖指令（`|| true`），本機截圖驗證過。商店截圖清單（`docs/steam/asset-specs.md`）的重現那張之後也用這組旗標。

## D-093　2026-11-08　暫停選單：章節名、左下角目前目標與按鍵提示

- 決策：暫停選單標題上方一行小字章節名（沿用 `GAME_SUBTITLE`「霜橋鎮的第九聲鐘」，18 號淡藍灰）；左下角一塊「目標」（沿用 `HUD_OBJECTIVE`，暖金小標題）＋目前目標一行（24 號、520 寬自動換行，沒有目標時整塊藏起來）；最底下一行 `GlyphLine`「[Esc]　繼續遊戲」（新 key `PAUSE_HINT_RESUME`，動作 `pause`，手把換成 Start 鍵名／圖示，裝置一換就更新）。每次打開時更新。暫停時把 `hide_when_paused` 群組裡看得到的 CanvasLayer（目前是 `Hud`）藏起來，繼續時只恢復這次藏的。
- 理由：第二輪盤點第 5 項的後續（D-090 只做了暗帶與細線）。暫停時 HUD 被暗幕蓋住，玩家暫停回來常常是想確認「我現在要做什麼」；按鍵提示讓手把玩家不用猜怎麼回去。右邊大片保留給場景（不放日記，日記有自己的畫面）。
- 影響：`test_ui::test_pause_menu_pauses_and_resumes` 改成用 `Title` 的位置找 `Rule`，並檢查章節名、提示、目標。新增翻譯一行（字型子集由 `check.sh` 重跑）。

## D-092　2026-11-08　標題畫面的窗與鐘室裡的鐘

- 決策：`title_fog.gdshader` 近排屋頂的亮窗加十字窗櫺（直 0.14、橫 0.1 窗寬）、每扇亮度 0.42～0.95 與色溫（暖黃到橘）用格子雜湊決定、約一半的窗以 0.35～0.85 rad/s 的慢正弦明暗 ±14%（再乘一層較快的小起伏，像燭火）、窗內下半稍亮、窗外一圈很淡的暖光；「整扇窗都在 0.875 以下」才亮（之前逐像素切，最上面一排是半扇）。鐘室開口裡畫深色的鐘形剪影（肩、細腰、外翻鐘口）、吊桿與橫梁，開口的光下亮上暗、左右收暗。
- 理由：第二輪盤點第 7 項。標題是玩家第一眼，原本的窗是平的小方塊、鐘室是一塊平的橘色——鐘是遊戲副標題，剪影裡就該看得到它。
- 影響：只改 shader（沒有 GDScript 測試），靠截圖前後對照（`scripts/screenshot.sh … 30`）。窗的閃爍在截圖看不到，實機確認不會太跳。

## D-091　2026-11-08　北街陷落後換上破屋頂

- 決策：北街每棟可陷落的房子在建造時就多蓋兩份屋頂：`Roof`（原本的三角屋頂＋屋頂雪，陷落前顯示）與 `Ruin`（破屋頂，陷落後顯示，`StoryLevel._break_roof`；動畫時在那棟開始往下掉 0.35 秒後換）。破屋頂：朝街那面斷成 3～4 片（屋頂寬 < 5.8 m 三片），一片整個掉光（露出斷成兩截的椽子——屋脊那截往屋裡垂 22～48°、屋簷那截翹出屋面 8～26°；屋內近黑、地上四片屋瓦碎片與一團雪），其他片隨機「塌陷」（以屋脊為軸、屋簷端往屋裡掉 10～24°、長度 82～95%）或「滑開」（往下滑 0.4～0.75 m、稍微翹起，上緣的縫露出完整的椽子）；每片上的雪是一大塊薄的＋一塊偏一邊的厚一點＋屋簷端一小團，邊緣露出深色屋瓦；背面完整有雪、兩端補三角山牆、露出屋脊梁。所有亂數用位置雜湊 `_ruin_hash`（不動 `_rng`）。
- 理由：第二輪盤點第 9 項。救援段落（`06-rescue.png`）一開場左邊就是陷落房子完整的屋頂斜面——一大片平的淺色，佔掉畫面三分之一，看不出「陷落」。斷片、黑洞、斷椽讓災難一眼看得出來，也讓街道兩側有層次。
- 影響：每棟北街房子多 2 個 batch 容器（`Roof` 2 個 mesh、`Ruin` 4 個 mesh，陷落前 `Ruin` 隱藏，不畫）；小鎮 `Town` 的 mesh 數不變。`test_frostbridge::test_collapsed_houses_show_broken_roofs`。破屋頂都不撞人（跟原本的屋頂一樣）。截圖對照：救援出生點（`--rescue`）與石階往北看（`--rescue --pos=0.5,-24 --nohud`）。

## D-090　2026-11-08　暫停選單的左側暗帶與標題細線

- 決策：暫停選單在全畫面暗幕之上加一條左側直向暗帶（`Band`，GradientTexture2D 由 0.82 經 0.6 到 0 的透明度，寬 760），標題「暫停」下一條往右淡出的暖金細線（`Rule`，320×2），取代原本的空白間隔。
- 理由：第二輪盤點第 5 項。第 21 輪截圖：三個選項直接疊在整片變暗的廣場上，沒有底、標題下沒有線，跟 D-076 的設定頁（分組小標題＋細線）不像同一套。
- 影響：`test_ui::test_pause_menu_pauses_and_resumes` 檢查暗帶與細線。章節名、按鍵提示、右側空白放目標或日記留待後續（NEXT）。

## D-089　2026-11-08　梨販攤正面的小補光

- 決策：攤桌前低處（桌前 1.25 m、高 0.75 m）加一盞 `StallFill`：暖色 `LAMP`、能量 0.55、範圍 2.2 m、不投影、不進體積霧、低高光。
- 理由：第二輪盤點第 6 項。布篷下那盞（1.85 m）只照到桌面與梨子，從廣場走過來看到的桌子正面與木箱一片黑，D-077 的木板紋要貼很近才看得到。梨販是第一個對話，攤子是新玩家最早停下來看的東西。
- 影響：小鎮燈數 +1（`test_frostbridge` 的上限 40 仍成立）；`test_stall_fill_light`。前後截圖對照（`--pos=3.0,3.2`）：桌面木板、木箱邊角與梨子輪廓都出來了，整體仍是夜裡。

## D-088　2026-11-08　送葬者招式前兆的地面範圍改用 telegraph.gdshader

- 決策：四種前兆範圍（橫掃與抓取＝扇形、下砸＝圓、衝撞＝長條）從 `StandardMaterial3D` 平塗加法色塊（透明度 0.15～0.75 隨前兆變大）改成 `src/world/telegraph.gdshader`：邊緣 7 cm 亮的霜藍細線、內部淡底（0.04）、前兆進度從敵人那一端往外填滿（0.07＋0.16×進度）、填滿的前緣一條亮線；形狀用模型座標算（mesh 沒有 UV），`shape`／`extent`／`half_arc` 照招式資料。
- 理由：本機截圖（第 21 輪）看到送葬者每一招前兆都是一大片淺藍色的平板，蓋住半個畫面、看不出邊界也看不出還剩多久——戰鬥截圖最搶眼的就是它。亮邊讓範圍一眼看得出來，往外填滿讓「什麼時候打下來」可讀（簡單但吃技巧的戰鬥）。
- 影響：`test_undertaker::test_telegraph_decals_use_shader_and_fill`。灰巡者沒有地面範圍（爪擊靠動作前兆）；之後的敵人有範圍招也用這個 shader（`Undertaker.SHAPE_*`、`TELEGRAPH_SHADER`）。在軟體渲染下內部仍偏亮，實機看過再調。

## D-087　2026-11-08　看穿改成畫面上的暗底小卡（InsightCard）

- 決策：看穿資訊從敵人頭上的 `Label3D`（一串白字）改成畫面上的 `InsightCard`（`src/ui/insight_card.gd`，PanelContainer）：暗底＋左側霜藍細邊、名字一行（24、暖白）＋細線、「弱點」「招式」兩段小標題（新 key `INSIGHT_SEC_WEAK`／`INSIGHT_SEC_MOVES`）；已證實畫小勾（不再寫「（已證實）」），未證實是空心圈＋淡色「（未證實？）」，正在出的招整列暖金色＋小三角。記號只畫線與多邊形（D-060）。卡片在敵人頭頂投影點的右邊、從頭的高度往下（OFFSET 44, -14），夾在畫面內，在鏡頭後面就藏起來；每個敵人自己一層 CanvasLayer（layer 9，HUD 是 10）。資料用新的 `EnemyIntel.rows()`；`lines()` 與 `insight_text()` 保留（測試與舊呼叫）。
- 理由：第二輪盤點第 3 項。看穿是 02-gameplay 的核心（攻略可能是錯的），原本的白字沒有底、沒有層次，跟過場字幕擠在一起，「已證實／未證實」要讀字才分得出來。小勾與淡字讓玩家一眼看出哪些資訊靠得住。
- 影響：`test_insight` 兩個新測試（卡片版面、場景內位置）。一群灰巡者同時被看穿時每隻一張卡，可能疊在一起——等實際遭遇看情況，必要時只給鎖定或最近的那隻。卡片在 HUD 底下，戰鬥開場的目標橫幅會壓在卡片上（橫幅幾秒後消失）。

## D-086　2026-11-08　石拱預覽的截圖：送葬者停在諾恩背後；`--face=arch`

- 決策：`--convoy --arch=preview` 時呼叫新的 `dev_park_boss()` 把送葬者移到諾恩背後 5.5 m、鏡頭後面並停住（`set_physics_process(false)`），畫面裡是石拱預覽＋代價卡＋車隊戰 HUD；`--face` 多一個 `arch`（南街石拱）。盤點截圖 `11-convoy-insight` 與 README 的 `combat.png` 都改成 `--convoy --insight --pos=2.2,9.5 --face=undertaker --face-off=18`（從東側拍，送葬者不被席菈擋住；combat.png 不再是沙盒）。
- 理由：第二輪盤點第 8 項的後續與第 2 項。預覽提示要站在石拱 5 m 內，送葬者卻生在石拱前（z=15），鐵架一定擋住預覽；試過 `--pos` 從側面拍，南街太窄，鏡頭會卡進牆或送葬者身體。遊戲裡本來就可以背對送葬者預覽石拱，這樣拍不算造假。
- 影響：`test_frostbridge::test_dev_face_arch_and_park_boss`。`dev_park_boss` 只給截圖用。

## D-085　2026-11-08　角色不擋鏡頭的 SpringArm

- 決策：諾恩的鏡頭 SpringArm 原本只排除諾恩自己；現在所有 CharacterBody3D／RigidBody3D（席菈、敵人）都加進排除清單（`_ready` 掃一次現有的，`SceneTree.node_added` 補上之後生成的），跟過肩射線 `shoulder_room` 的規則一致（D-072）：只有牆與場景會讓鏡頭收回。
- 理由：第二輪盤點第 8 項。screens 的 `08-arch-preview.png`（重現石拱的預覽，切片最關鍵的一刻）鏡頭貼在諾恩後腦，畫面左下一大塊深色人影——身後的席菈（或送葬者）擋在鏡頭與諾恩之間，SpringArm 把鏡頭拉近。遊戲中只要有人走到諾恩背後就會發生，鏡頭會突然往前跳。
- 影響：`test_camera_shoulder::test_body_behind_does_not_pull_camera_but_wall_does`。角色本身可能會出現在鏡頭與諾恩之間（被看穿過去）；需要的話之後讓離鏡頭 < 1 m 的角色淡出（NEXT 過肩鏡頭的後續）。

## D-084　2026-11-08　敲鐘刻度（RingTally）

- 決策：過場等待輸入、而且鏡頭有 `counter` 時（敲鐘九下），提示上方顯示一排圓點：敲過的實心暖金色＋淡光暈（剛敲的那一下光暈多亮 0.4、約半秒退掉），還沒敲的淡灰色空心圈，最後一個（第九下）半徑 7.5（其他 5）。`RingTally`（`src/ui/ring_tally.gd`）只用 `draw_circle`／`draw_arc` 畫圖形、不畫字（D-060）；「3／9」數字照舊留在提示那一行（無障礙、測試）。
- 理由：第二輪盤點第 4 項。敲鐘是整個切片最有儀式感的一段，只有畫面正中一行小字「[F] 敲鐘　3／9」；一排會亮起的鐘點讓玩家一眼看到「還差幾下」，第九個特別大，預告最後一下的份量。
- 影響：`test_main_flow` 檢查刻度顯示、九個、敲八下亮八個、光暈。之後其他「按 N 次」的鏡頭（若有）自動有刻度。這一輪沒有本機截圖（D-082），位置與大小看 CI 的 `bell.png`（敲第 3 下）再調。

## D-083　2026-11-08　第二輪「第一眼」盤點用 CI 截圖做，7 項寫進 PLAN

- 決策：第一輪 10 項做完後的第二輪盤點，先用 CI 發布的截圖（latest 的 `title`／`dialogue`／`bell`／`combat`）加上第一輪留下的候選排出 7 項（敲鐘鐘室、README 的戰鬥圖換成霜橋鎮、看穿面板、敲鐘刻度、暫停選單、梨販攤補光、標題的窗）；收尾時「盤點截圖」job（D-082）的 screens 發布了，看過後補上第 8 項（石拱預覽鏡頭貼到諾恩後腦）與第 9 項（北街救援的平屋頂）。
- 理由：敲鐘是遊戲副標題的那一刻、README 第三張圖，現在是最平的一張（素面圓桶＋灰霧）；README 的戰鬥圖是沙盒，玩家與 Jacky 打開 repo 第一眼就看到。順序照「被看到的程度」。
- 影響：每輪照表從上往下拿；新發現照樣加進表。

## D-082　2026-11-08　本 session 下載不到 Godot：改靠 CI 驗證，CI 新增「盤點截圖」job 發布到 prerelease「screens」

- 決策：第 20 輪的雲端 session 對 `github.com/godotengine/godot/releases/download/...` 一律回 504（GitHub API 回「這個 session 沒開這個 repo 的存取」；`add_repo` 不在這次的工具裡），`scripts/get-godot.sh` 拿不到 Godot，本機不能 import、測試、截圖。照排程指示**不繞過**（不從其他來源下載未驗證的 Godot、不把 Godot 轉存到自己的 repo），這一輪完全靠 GitHub Actions 驗證：push 前用 `gdtoolkit` 的 `gdparse`（PyPI）檢查 GDScript 語法、用 Python 驗證幾何（三角形方向與法線），推上去看 CI 的測試與截圖。artifact 的儲存空間（`*.blob.core.windows.net`）也被擋，只有本 repo 的 release 下載得到（偶爾 504，重試幾次會過）。所以 CI 新增平行的 `screens` job（`continue-on-error`）：import 後拍 10 個主要畫面，上傳 artifact 並發布到 prerelease「screens」（每張 PNG＋`screens.zip`），main 已有更新的程式 commit 時跳過發布。
- 理由：之後的 session 也可能遇到同樣的存取範圍；有了 screens，loop 與 Jacky 都能在不跑 Godot 的情況下看到每個主要畫面，盤點與前後對照不必等本機截圖。平行 job 不拉長「測試與匯出」的時間。
- 影響：下一輪開工先試 `scripts/get-godot.sh`；拿不到就照這個做法（NEXT 寫了步驟）。下載 screens：`curl -sSL -o screens.zip https://github.com/twjackysu/yuming-city/releases/download/screens/screens.zip`（失敗重試）。FOR_JACKY 註記：排程任務如果能把 `godotengine/godot`、`notofonts/noto-cjk` 加進可存取的 repo，雲端本機就能跑測試與截圖。

## D-081　2026-11-08　鐘改成車床旋轉的鐘形（Lathe）、鐘室加格柵與百葉

- 決策：新增 `Lathe`（`src/world/lathe.gd`）：剖面線（x＝半徑、y＝高度）繞 Y 軸轉成 ArrayMesh，法線取剖面切線右轉 90°（`n = (-dy, dr)`，外側從上往下描、內側從下往上描），一條剖面線內平滑、硬邊分成好幾條剖面線；三角形照 Godot 的順時針正面排。`Lathe.bell_mesh(1.5, 0.95)` 是鐘：肩、細腰、外翻鐘口、厚唇、中空。鐘身加三道 TorusMesh 紋帶（磨亮一點的青銅：粗糙度 0.3、金屬度 0.45），頂上一塊深色木頭鐘架包住橫梁、兩條鐵箍，全部掛在 `Bell` 底下（敲鐘時一起擺）。鐘室屋頂下四根木格柵，背面與東西兩側各 8 片往外斜 38° 的百葉板（正面留空，從街上看得到鐘）。木構沿用既有木頭材質（進合併、小鎮 mesh 數不變），燈數不變；鐘身青銅的參數不變（金屬度高了在夜裡會變黑影，D-050）。
- 理由：第二輪盤點第 1 項。latest 的 `bell.png`：鐘是圓柱＋球＋薄唇拼成的橘色桶，背後一片灰霧，頭上一塊平的棕色屋頂板。百葉讓鐘的背後是被鐘室燈照暖的斜木條，格柵讓屋頂看得出結構；紋帶在燈下有一圈一圈的高光。
- 影響：`test_lathe`（外形與範圍、頂點數、外側法線朝外、鐘唇朝下、所有三角形朝法線那一側）、`test_frostbridge` 檢查 `BellBody` 是 ArrayMesh、紋帶、鐘架、`belfry_louvres == 24`。之後要做其他旋轉體（井的水桶、燈罩、花瓶）也用 `Lathe`。

## D-080　2026-11-08　路燈改成方形燈籠、門邊掛燈加鐵框

- 決策：路燈柱頂的發光球換成方形燈籠（鐵底座 0.3 m、發光玻璃 0.24×0.34、四角 2.5 cm 細鐵條、鐵頂板、八角形尖頂＋一小片雪）；門邊掛燈的發光方塊外面也加四角鐵條（`_cage_bars`）。鐵件用門邊掛燈原本的鐵材質、尖頂用屋頂材質，小鎮 mesh 數不變；OmniLight 的位置與參數都不變（地面照明不變）。
- 理由：NEXT 的小項目、第二輪盤點的已知候選。近看時發光球像除錯用的標記；概念圖的燈是有框的燈籠。截圖（裁切放大）看得出底座、鐵條、尖頂。
- 影響：`test_frostbridge` 檢查 `street_lanterns == 10`。

## D-079　2026-11-08　本 session 連不到 notofonts/noto-cjk 時，本機字型改用 apt 的 Noto CJK（不進 git）

- 決策：第 19 輪的雲端 session 對 `github.com/notofonts/noto-cjk` 的 release 一律回 504（GitHub API 回「這個 session 沒開這個 repo 的存取」，`add_repo` 也不在工具裡），`scripts/gen_fonts.py` 下載失敗、`check.sh` 跑不起來。本機改用 `apt-get install fonts-noto-cjk fonts-noto-cjk-extra` 的 TTC（同一個字族的 TC 那一套，Serif SemiBold／Sans Regular／Medium），用 scratchpad 的小腳本照 `gen_fonts.py` 的字元集合子集化、寫進 gitignore 的 `game/assets/generated/fonts/` 並寫上相同的 `.stamp`，`check.sh` 就照常跑。**repo 裡的 `gen_fonts.py`、CI 都不改**（CI 照舊從 release 下載、有 cache）。
- 理由：只是本機驗證環境的網路限制；字型版本與 SHA 固定的做法不該為了一個 session 改掉。apt 的 Noto CJK 字形與 release 版同一族，截圖看得出排版與字重。
- 影響：NEXT「開工先確認」寫了做法；改了 `i18n/*.csv` 後要重跑那個小腳本（字元集合變了 stamp 會變，`gen_fonts.py` 又會去下載）。

## D-078　2026-11-08　選單換值的「叮」（ui_tick）

- 決策：新增程序音效 `ui_tick`（`scripts/gen_sfx.py`：1568 Hz 與它的 2.41 倍兩個泛音、每秒衰減 38 倍，加 4 ms 的高通噪音「喀」，共 0.14 秒）。設定頁的多選一切換（點箭頭、左右鍵、確認鍵）與拖音量滑桿時播放，-15 dB、走 SFX 匯流排，拖滑桿時每 70 ms 最多一聲。
- 理由：「打擊感、音效」也包含選單——切換值沒有聲音時，手把玩家不確定按了有沒有作用；用高音鐘的泛音，跟遊戲的鐘同一個語彙。走 SFX 匯流排，調「音效」音量時能馬上聽到新的大小。
- 影響：`Sfx.NAMES` 多一個（打包驗證與 `test_sfx` 會檢查）。之後其他選單（暫停、標題）的焦點移動要不要也有聲音，等 Jacky 試玩說太吵或太安靜再決定。

## D-077　2026-11-08　廣場中心的石框與鐘紋、井的燈與小屋頂、木箱模式

- 決策：
  - 廣場中央的圓形石框改成：外側一道深色石縫（r 3.32）、淺色斜邊石緣（上 3.15／下 3.28、高 7 cm）、裡面低一點的鋪石（r 2.8），正中央一個「鐘紋」石盤（淺色外圈 r 1.0、深色溝 r 0.78、內圈 r 0.7、中心深色點）。全部不加碰撞（車隊與角色會走過去，石緣只高 7 cm）。
  - 井：井身改用石牆材質（跟石階燈柱共用 `stone_wall(1.0)`）、淺色井沿石（跟廣場石緣同一個材質）、木架上兩片斜板的小屋頂＋雪、繩子與水桶；木架東側掛一盞小燈（發光小方塊＋上下兩片蓋，OmniLight 1.1、範圍 3.4 m、不投影）。
  - `door.gdshader` 加「木箱模式」：頂點色 r＝0 時橫排四片木板、四邊一圈角條、沒有門把與鐵條（`FrostbridgeLook.crate_tint(pos)`）。梨販的攤桌與旁邊疊著的三個木箱都用它，跟門合併在同一個 mesh；`StaticBatch.add_box_tinted` 多一個 `collide` 參數（木箱要擋人）。
- 理由：盤點第 10 項。之前的石框是兩片幾乎一樣高、顏色接近的薄圓盤，遠看只有一圈淡線；井是一個淺色圓柱；攤桌是素面方塊。截圖對照（`--at=plaza`、`--pos=3.0,3.2`）：石框與鐘紋一進廣場就看得到，井有了屋頂輪廓與暖光。新材質全部沿用既有的，小鎮合併 mesh 數不變（測試上限 24）。
- 影響：`test_frostbridge::test_layout_nodes_and_batching` 檢查木箱數、石框層數、井燈（不投影、範圍小、在井旁）；`test_static_batch` 檢查帶色方塊的碰撞與木箱頂點色。攤子正面在夜裡偏暗、木板紋要靠近才看得到；之後可以在攤桌前面加一點補光（目前燈在布篷下）。

## D-076　2026-11-08　設定頁分組、「‹ 值 ›」箭頭、小圓點、音量百分比

- 決策：設定頁分成四組——遊戲（難度、語言、字幕、目標指引）、聲音（四個音量）、畫面（畫質、全螢幕、垂直同步、減少鏡頭晃動）、操作（按鍵設定）。每組一個暖金色小標題（Noto Sans Medium 17 px、英文大寫）＋往右延伸的細線。多選一（含開／關）改成「‹ 值 ›」：值置中，兩側的箭頭是 `ValueArrow`（用 `draw_polyline` 畫的線，不靠字型；平常淡灰、按鈕有焦點或滑鼠在上面時暖金色；可以點；切換時往那邊彈 4 px）；難度、語言、畫質的值下面有 `ValuePips`（幾個選項幾顆，目前那顆實心暖金色），有圓點的按鈕文字抬高 3 px 讓出空間。音量滑桿旁邊顯示百分比。列高 44 → 38、列距 8 → 4，加了四個標題後面板仍是約 900 px 高（測試擋 ≤ 1040）。新翻譯 key：`SET_GROUP_GAME`／`AUDIO`／`DISPLAY`／`INPUT`（遊戲／聲音／畫面／操作；英文 Input 避免跟「Controls」那一列重複）。
- 理由：盤點第 9 項，開／關、畫質只是一排左對齊的文字，看不出能左右切、也看不出有幾個選項；13 列沒有分組，很難找。箭頭用畫的，是因為字型子集不一定有「‹」（D-060 的經驗）。
- 影響：`SettingsMenu` 新增測試用的 `group_keys()`、`group_of()`、`arrow_of()`、`pips_of()`；`test_ui::test_settings_menu_groups_arrows_pips` 擋回歸。`control_of()` 照舊回傳第 2 個子節點（Slider 或 Value 按鈕），舊測試與手把流程測試不用改。

## D-075　2026-11-08　送葬者兜帽裡的霜光

- 決策：送葬者的上身加兩點冷藍自發光（`HoodEyeL`／`HoodEyeR`，emission 5.0，不投影）在兜帽前緣，和一盞小 OmniLight（`HoodLight`，霜色、0.9、範圍 2.4 m、不投影）在胸口前方。被斬倒跪下的 `FALL_KNEEL_SEC` 內熄掉（光變 0、光點縮小），倒地後由 `_frost_exhale`（D-054）接手。
- 理由：盤點第 8 項，送葬者在遠處跟背景一樣暗。截圖對照（`--convoy --face=undertaker --pos=-1,3`）：加了之後隔著半個廣場看得出兜帽與肩膀的冷色輪廓，站在他面前的席菈也被照亮；燈不投影，成本只有一盞小點光。
- 影響：`test_undertaker::test_cut_down_falls_forward_then_sinks` 擋回歸。換正式模型時，霜光要掛在頭骨骼前方。

## D-074　2026-11-08　商店截圖的構圖旗標：`--pos=x,z`、`--face-off=度`、`--hide=noen`

- 決策：霜橋鎮截圖旗標新增 `--pos=x,z`（其他旗標排好場面之後，最後把諾恩移到這裡，高度照 `ground_y`）、`--face-off=度`（`--face` 轉向目標後再往左轉，目標落在畫面右側）、`--hide=noen`（藏起諾恩的模型，提燈的光留著；`--felled` 共用同一個 `dev_hide_player()`）。商店截圖 6（燃燒劍）改用 `--convoy --throw=kindling --throw-t=0.6 --face=sheila --pos=2.6,6.5 --face-off=16`。
- 理由：盤點第 5 項。換成過肩鏡頭（D-072）後，石拱預覽的諾恩已經在畫面左側、不擋石拱，不用另外處理；但燃燒劍那張其實是送葬者站在諾恩正後方（z≈14.4），鏡頭卡進他身體裡，畫面中間一大片灰色。從廣場側面拍，席菈、火光、車隊、廣場都在畫面裡。
- 影響：`docs/steam/asset-specs.md` 截圖 6 的旗標已更新。之後做「商店截圖 CI 步驟」時直接用這組旗標。遊戲中大型敵人站在諾恩正後方時鏡頭也可能進到敵人模型裡（SpringArm 只看碰撞形狀），實機回饋再決定要不要讓靠太近的敵人淡出。

## D-073　2026-11-08　日記改成一張暖色舊紙

- 決策：`JournalView` 的紙改用程式畫的紋理（`JournalView.paper_texture()`：FastNoiseLite 大塊斑駁＋橫向拉長的細纖維，256² 只畫一次、`StyleBoxTexture` 平鋪）；紙上用深褐墨水、紅褐標題、標題下兩條細線、每張卡上方一條細線（不再是深色卡片）；被付出的記憶畫成紙上挖掉的洞（深夜色＋一圈淺色剪口＋陰影）。新遊戲空日記的提示改成一句開場（`JOURNAL_EMPTY`：「第一頁還是空白的。之後付出去的記憶，會從這幾頁上被剪掉。」）。重現預覽時右側的代價卡維持深色底亮色字（疊在遊戲畫面上）。
- 理由：盤點第 7 項，日記是深灰面板＋深灰卡片，像除錯視窗；記憶代價是這個遊戲最核心的情感，日記要像一本真的被剪過的本子。空日記那句同時教會玩家「付出的記憶會被剪掉」。
- 影響：`_card(v, on_paper)` 多一個參數；`test_journal_paper_look` 擋回歸。

## D-072　2026-11-08　鏡頭改成過肩：探索 0.85 m、戰鬥／鎖定 0.55 m，肩膀射線防穿牆

- 決策：`PlayerController` 每幀設定 SpringArm 的 x（`SHOULDER_OFFSET` 0.85 m；鎖定或 20 m 內有敵人時 `SHOULDER_OFFSET_COMBAT` 0.55 m，以 1.6 m/s 漸變）。從鏡頭架（諾恩頭部高度）往右打一條射線（長度＝偏移＋0.35 m），偏移不超過量到的空間（貼牆時立即收回、離開後慢慢放回）；射線打到 CharacterBody3D／RigidBody3D（席菈、敵人、車隊）就排除再打，不算牆。`CAMERA_HEIGHT` 維持 1.6（截圖看諾恩頭部在畫面約 45% 高度，不用再壓低）。
- 理由：盤點第 4 項，原本 0.45 m 時諾恩幾乎在畫面正中，深色背影擋住街景；改成 0.85 m 後諾恩在畫面左側約四成，廣場、主街、石階、北街救援、石拱預覽都把前方留給場景。SpringArm 只檢查自己那條往後的射線，側移的起點本身不檢查碰撞，所以要自己量。戰鬥時收小，讓敵人在畫面中間、鎖定時目標不會跑到太右邊。
- 影響：`test_camera_shoulder`（4 項）。`02-gameplay.md`「鏡頭」已更新。手感（會不會晃、貼牆收回會不會跳）等 Jacky 實機回饋，必要時調 `SHOULDER_EASE`。

## D-071　2026-11-08　遊戲 Theme 也併進引擎預設 Theme（關卡裡的 UI 之前沒套到）

- 決策：`App._ready()` 除了 `root.theme = UiFonts.build_theme()`，再 `ThemeDB.get_default_theme().merge_with(theme)`。
- 理由：驗證 D-067 時發現對話選項還是白框。用腳本確認：`root.theme` 只傳給一路都是 Control 的子孫，**傳不過 Node3D／CanvasLayer**；關卡的 HUD、對話框、暫停／設定選單、重現提示都掛在那底下，所以一直用引擎預設字型＋系統字型 fallback（Windows 上會變成系統中文字型、跟標題畫面不一致）、預設白色焦點框。D-060 記的「遊戲裡 draw_string 這套子集字型畫成缺字方塊」很可能也是這個原因（遊戲裡拿到的其實不是子集字型）。
- 影響：關卡 UI 的字型與標題畫面一致（Noto 子集）；`test_ui_theme::test_controls_under_canvas_layer_get_game_theme` 擋回歸。之後如果要用不同的 Theme，要記得引擎預設 Theme 已經被改過。

## D-070　2026-11-08　門改用 door.gdshader

- 決策：新增 `src/world/door.gdshader`、`FrostbridgeLook.door()`、`door_tint()`；`_house` 的門改用 `add_box_tinted`（頂點色 g＝木色深淺與門把在哪邊、b＝舊不舊）。五片直排木板（每片深淺不同、板縫、細木紋）、門框（左右與上方）、兩道鐵條＋鉚釘、門把鐵環、門腳浸濕。鐘樓塔門維持發光（開著的門）。
- 理由：盤點第 6 項，主街與石階兩側的門是一塊平的深棕色方塊。
- 影響：合併 mesh +1（門原本跟其他木頭共用 `mat(WOOD)`）；扣掉 D-066 少的 2 個，總數仍比本輪開始少。

## D-069　2026-11-08　「第一眼」盤點結果與 12/1–12/8 打磨順序

- 決策：照 `docs/ART_QUALITY_BAR.md` 逐項截圖（標題、設定、廣場、主街、石階、北街救援、灰巡者（沙盒）、送葬者戰、石拱預覽、日記），本輪先修最便宜、每個畫面都看得到的三項（窗 D-066、選單焦點 D-067、雪 D-068），其餘排進 PLAN 階段 2「第一眼盤點」表，依序：鏡頭過肩偏移 → 截圖旗標構圖（諾恩背影擋住左半）→ 門 → 日記紙張質感 → 送葬者在遠處看不清 → 設定頁開關樣式與分組 → 廣場中心與木箱。
- 理由：NEXT 第 1 項。人偶（諾恩深色剪影、席菈白色棉花糖）是最大的缺口，但正式模型等 Jacky（D-041）；在那之前先讓「角色以外」的東西不再像白盒。
- 影響：PLAN 階段 2 有逐項表（狀態欄）；之後每輪從表的最上面拿。

## D-068　2026-11-08　積雪改用 snow.gdshader

- 決策：新增 `src/world/snow.gdshader`、`FrostbridgeLook.snow()`（全部的雪共用一個 ShaderMaterial，取代 `look.mat(SNOW)`）：世界座標 fbm 做雪堆起伏（亮暗 0.86～1.08、低處偏藍 35%、朝上的面法線跟著傾斜）、貼地雪帶有幾塊髒雪（灰、較粗糙）、4 cm 格子的雪粒閃點（約 1.2% 的格子、跟視線反射對上才亮、遠處 fwidth 淡掉）。
- 理由：盤點時北街救援鏡頭左半是一整片平的淺藍屋頂、主街兩側是兩條平的白帶，一眼就是白盒。
- 影響：合併 mesh 數不變；`test_frostbridge` 擋「沒有平的淺色雪」。閃點在實機（會動的鏡頭）上要看會不會太閃，太閃就降 `sparkle_energy`。

## D-067　2026-11-08　選單樣式 UiTheme：暖金色焦點細條取代 Godot 預設白框

- 決策：新增 `src/ui/ui_theme.gd`（`UiTheme.style(theme)`，由 `UiFonts.build_theme()` 呼叫，套在 root）：Button 的 focus 是 `StyleBoxTexture`（程式畫的 128×4 圖：左邊 3 px 實心暖金色當九宮格左邊界、不拉伸，右邊 22% → 0 淡出），normal 等狀態是左邊距 14 px 的 StyleBoxEmpty；文字冷灰白 → 焦點／滑鼠暖金色、disabled 變暗。HSlider：細軌道、暖金色填滿、程式畫的圓形把手、焦點同按鈕。
- 理由：盤點時標題畫面第一眼就是 Godot 預設的白色圓角方框；設定、按鍵設定也一樣。按鈕全部是 flat（不畫 normal／hover），所以焦點框是唯一的「被選中」提示，最該好看。
- 影響：個別按鈕的顏色覆寫（對話選項、按鍵設定格）仍優先；新選單直接用 flat Button 就會套到。

## D-066　2026-11-08　窗改用 window_glass.gdshader（木窗框＋十字窗櫺），每扇窗的資料放頂點色

- 決策：新增 `src/world/window_glass.gdshader`、`FrostbridgeLook.window()`、`FrostbridgeLook.window_tint()`、`StaticBatch.add_box_tinted()`。房子的亮窗與暗窗、鐘樓塔窗共用一個材質（原本亮窗 `glow(LAMP, 1.4)`、暗窗、塔窗 `glow(LAMP, 4.0)` 三個 → 一個）。面內座標用 BoxMesh 的 UV（每個面佔 1/3 × 1/2 格，`fract(UV × (3, 2))`，y=0 在上，已用腳本確認）。頂點色：r 亮／暗、g 色溫與窗簾方向、b 窗簾比例（約四成的亮窗）、a 亮度（× 4）；用位置雜湊，不動 `_rng`。亮窗基準強度 `WINDOW_ENERGY` 1.5（每扇 0.75～1.2 倍）。
- 理由：盤點時每個霜橋鎮鏡頭最亮的東西都是一塊塊奶油色的發光長方形（近看像貼紙）；有了窗框、窗櫺、窗簾，馬上像有人住的屋子。
- 影響：合併 mesh 少 2 個（亮窗、塔窗的發光材質）；之後的門、招牌可以照同樣模式（一個 shader＋頂點色）。

## D-065　2026-11-08　「走近就能做」的提示搬到 HUD（InteractPrompt），3D 場景只留台詞

- 決策：新增 `scenes/ui/interact_prompt.gd`（`InteractPrompt`，掛在 `Hud`）：每幀找 `interact_prompts` 群組裡第一個 `interact_hint()` 回傳非空字典的節點（`{"fmt": 保留 {key} 的翻譯字串, "action": 動作, "progress": 0..1 或 -1}`），在畫面下方中央顯示 `GlyphLine`＋按住進度條；重現提示同時出現時疊在它上方 12 px。`RescueSite` 拿掉瓦礫上的 Label3D（`prompt_shown()` 照舊）；`Sheila` 倒下時頭上不再浮「拉起席菈」，改由 `interact_hint()` 提供（她頭上的 Label3D 只放台詞）。
- 理由：D-063 之後 HUD 的鍵名都有手把圖示，只剩這兩個 3D 提示還是「[A]」文字；同一類提示也該在同一個位置（D-059 的理由：3D 文字會被別的面板蓋住、遠近大小不一）。
- 影響：新的互動點（例如下一段章節的機關、門）只要加進 `interact_prompts` 群組並實作 `interact_hint()`，提示就會出現在 HUD；玩家被鎖住（對話、過場）時不顯示。

## D-064　2026-11-08　Steam 膠囊圖替代版由 CI 產生（`scripts/steam_mock.py`），截圖旗標 `--nohud`、`--face`

- 決策：新增 `scripts/steam_mock.py`（PIL）：拿無 HUD 的主街夜景截圖（`--level=frostbridge --at=main --quality=2 --nohud`）cover 裁切、壓暗＋暗角＋底部漸層，左下疊「餘命城／YUMING CITY」（遊戲自己的標題子集字型＋暖色光暈），產生 Header 920×430、Small 462×174、Main 1232×706；Library 600×900 用標題畫面截圖的鐘樓剪影（切掉底部「原型版本」字、避開左側標題與選單）。CI 截圖步驟後跑（`pillow==11.3.0`、`continue-on-error`），全部進 artifact、Header 附在 latest release。新旗標：`--nohud`（`Hud` 整層不顯示）；`--face=sheila|undertaker|frame`（每幀把諾恩與鏡頭轉向那個角色，燃燒劍斬鐵架在諾恩背後才拍得到）；`--convoy --arch=restored|spent` 時諾恩退到送葬者北邊（原本站進送葬者身體裡）。
- 理由：NEXT 第 4 項「替代版截圖與 Header Capsule」：png 走 LFS、雲端推不上去，所以圖不進 git，改成指令＋CI 產生。膠囊圖規則只能有遊戲名稱與美術，所以只放標題字。
- 影響：Jacky 在 release 下載 `header_capsule.png` 就能看到商店頁大概的樣子；正式主視覺（ART_REQUESTS）做好後換掉。Steam 商店截圖要 1920×1080 高畫質，仍需在 Windows 實機截（雲端軟體渲染品質不夠）。

## D-063　2026-11-08　HUD 的操作提示在手把模式用按鈕圖示（GlyphLine）

- 決策：新增 `src/ui/glyph_line.gd`（`GlyphLine`，HBoxContainer）：吃「已翻譯、保留 `{key}`」的字串＋動作＋裝置。鍵鼠模式整句一個 Label（「按住 [V]　重現 9 秒」）；手把模式把 `{key}` 換成 `PadGlyph`、前後各一個 Label（`{key}` 可以出現多次，例如「{key} 繼續・按住 {key} 跳過」）；圖示高度 = 字級 × 1.3；`plain_text()` 永遠是文字版（測試、讀屏）。用在：戰鬥 HUD 三個指令＋掙扎提示、重現提示的「按住」列、對話框提示列、過場的動作提示與「按住跳過」。`InputGlyphs.spec_for_action()` 新增（`label_for_action` 改用它）。不需要新的翻譯 key。
- 理由：D-060 只做了按鍵設定頁；手把玩家在戰鬥裡看到「[↑] 打弱點」「按住 [Y]」的文字不夠直覺，也跟設定頁不一致。
- 影響：3D 場景裡的提示（救援「按住 [A]」、拉起席菈）仍是 Label3D 文字；之後要換圖示得改成 HUD 提示或 Sprite3D。新的 HUD 提示照這個模式：翻譯字串放 `{key}`，交給 `GlyphLine.set_line()`。

## D-062　2026-11-08　石階兩側的矮石燈柱

- 決策：`frostbridge.gd` 的 `_build_step_lanterns()`：石階底下（z = STEPS_S + 0.45）與台地邊（z = STEPS_N − 0.45、y = RISE）各一對矮石燈柱（石柱 0.8 m＋小燈籠），貼著街邊（|x| = MAIN_HALF − 0.38），每盞一個不投影的小 OmniLight（範圍 3.8 m、強度 1.1）。石柱有碰撞；材質跟後牆、屋頂、路燈共用（合併 mesh 數不變）。
- 理由：NEXT「石階兩側可加矮石欄或石階邊的燈」：往鐘樓爬的石階在霧裡是一片暗，踏面前緣看不清；截圖對照（`--at=steps`）燈柱把石階頭尾與兩側牆面照亮，也把視線往鐘樓引。
- 影響：燈的總數 +4（仍在 `test_frostbridge` 的上限 40 內）；`step_lanterns` 給測試用。

## D-061　2026-11-08　標題畫面：霜橋鎮冬夜剪影＋流動的霧堤

- 決策：`scenes/boot/title_fog.gdshader` 加上程序生成的剪影——遠近兩排山牆屋頂（每格一棟、高度與屋頂用雜湊決定，部分平頂）、鐘樓（塔身、尖頂、鐘室開口透出暖燈，位置跟著 `glow_pos`）、近排下方幾扇亮窗；霧改成三層：天空的淡高霧、兩排屋頂之間的霧堤（`smoothstep(0.42, 0.72, fbm)` 壓成一塊一塊）、貼地低霧；燈改成小燈心＋兩層光暈（之前是一大團糊光）。
- 理由：ART_QUALITY_BAR 盤點「標題畫面霧層幾乎看不出來」：舊版 fbm 的值集中在 0.5 附近，乘上 0.38 只是一層均勻薄霧；標題是玩家第一眼，現在一眼看得出「冬夜、鐘樓、小鎮、霧」。
- 影響：仍是單一 canvas_item shader、沒有貼圖；之後 Jacky 的商店主視覺（ART_REQUESTS）可以換掉或疊在上面。

## D-060　2026-11-08　手把按鈕圖示用程序畫（PadGlyph），文字留著

- 決策：新增 `src/ui/pad_glyph.gd`（`PadGlyph`）：A／B／X／Y 四色圓鈕（柔和的綠、紅、藍、黃）、LB／RB 圓角長條、LT／RT 扳機形、搖桿外圈＋L／R（按下搖桿多一個內圈）、十字鍵亮起該方向的那一臂、View／Menu 小方鈕；鍵盤、滑鼠不畫。按鍵設定頁的手把格掛一個 `PadGlyph`，按鈕文字保留但變透明（測試、讀屏、日後要改回文字都簡單）；固定的格子圖示變暗；等新鍵時藏起圖示、顯示「按下新按鍵」。圖示上的字用子節點 Label（`meta glyph`）。
- 理由：ART_QUALITY_BAR 盤點「手把圖示是文字 A／B／LB」。在遊戲裡直接 `draw_string` 這套子集字型會畫成缺字方塊（單獨的測試場景卻正常，原因沒查到），改用 Label 就正常——之後自己畫字的元件都用 Label。
- 影響：只用在按鍵設定頁；HUD 的操作提示（「[Q] 打弱點」）仍是文字，之後要換圖示時直接重用 `PadGlyph`。正式上架可以再換成 Steam Input 的官方圖示（需要 GodotSteam）。

## D-059　2026-11-08　重現提示改成 HUD 的 2D 提示（下方中央），石拱上不再浮 3D 文字

- 決策：新增 `scenes/ui/restore_prompt.gd`（`RestorePrompt`，掛在 `Hud`）：諾恩走近可重現的東西時，畫面下方中央顯示三行——可以重現什麼（霜藍、小）、**代價**（暖色、最大、Medium 字重）、「按住 V　重現 9 秒」＋按住進度條；重現中改成「重現中　還剩 N 秒」＋九顆心跳點（每過一秒熄一顆）。`NineBreathSite` 拿掉 `Label3D`，改提供 `prompt_lines()`、`hold_ratio()`、`is_counting()`、`breaths_left()`、`countdown_text()`；HUD 每幀從 `nine_breath_site` 群組讀（純顯示）。
- 理由：第 14 輪截圖：石拱上方的 Label3D 右半被「重現的代價」記憶卡蓋住，**代價那一行被切掉**（這是玩家最該看清楚的一行），上緣跟劇情提示擠在一起，背後還是石拱輪廓。下方中央跟右側記憶卡、上方劇情提示、左下戰鬥 HUD 都不重疊（`test_restore_prompt` 中英文都量過）。
- 影響：新的可重現物件照常放 `NineBreathSite`，提示自動出現在 HUD；對話中（玩家被鎖住）不顯示。

## D-058　2026-11-08　濕石板路：燈的高光加強、石面更光滑、水窪細波紋

- 決策：路燈、門邊掛燈、梨販燈的 `light_specular` 0.5（Godot 預設）→ 1.0（`frostbridge.gd` 的 `LAMP_SPECULAR`；窗裡的小補光維持預設）；`wet_cobble.gdshader` 石面粗糙度 0.62 → 0.46；水窪加細波紋 `ripple_strength` 0.14（沿 z／沿 x 起伏的細長雜訊，依視線方向混合權重；波紋固定在世界座標上，轉鏡頭只換權重、不會跟著滑動；遠處比像素細時淡掉），水窪 albedo 再暗 25%（`puddle_darken`）。
- 理由：概念圖的濕石板路是「燈在石頭上拉出長長的亮點」；之前石面太粗、燈的高光只有預設一半，夜裡地面是一片暗。只靠水窪＋probe（D-051）效果含蓄，因為倒影只在靠牆的水窪看得到窗。截圖對照（xvfb）：廣場遠處與梨販攤前的石板多了一串暖色亮點，水窪輪廓更清楚；高畫質（SSR）沒有過曝。第一版水窪壓暗 45% 反而把燈照在水窪上的暖光吃掉，改成 25%。
- 影響：每個地面像素多兩次雜訊取樣（很便宜）。真正的效果要 Jacky 在中／高畫質實機看（FOR_JACKY 第 1 條）。

## D-057　2026-11-08　按鍵設定頁的十字鍵焦點關在頁面裡

- 決策：`ControlsMenu` 開著時監聽 `gui_focus_changed`，焦點跑到頁面外（後面的設定選單）就拉回上一個格子；固定的格子（移動的手把搖桿、暫停）`focus_mode = FOCUS_NONE`，十字鍵直接跳過；最後一列往下明確指到「還原預設」（鍵鼠欄）／「返回」（手把欄），按鈕往上回最後一列、第一列往上不動。
- 理由：手把改鍵的流程測試抓到：在最後一列（暫停）按下，Godot 會往整個畫面找最近的按鈕，焦點跑到後面設定選單的「按鍵設定」與「返回」，手把玩家到不了「還原預設」，按 A 還會關掉按鍵設定。
- 影響：滑鼠移到固定格子上仍看得到「固定」提示。之後新的疊加選單（例如存檔欄位、確認對話框）都要照這個做法關住焦點。

## D-056　2026-11-08　粒子一律用圓形貼圖（ParticleLook）

- 決策：新增 `src/world/particle_look.gd`（`ParticleLook`）：`soft_dot()` 柔邊圓點（粉塵、灰燼）、`hot_dot()` 亮心較大的圓點（火星）、`material(color, additive, billboard)`；火星用加法混色。席菈劍上的火星、鐵架被斬開的火星、鐵架撞石拱的石粉、石拱化灰的灰燼、敵人倒地粉塵都改用它；火星面片 0.035 → 0.05 m、斬開的火星 0.05 → 0.07 m、灰燼 0.06 → 0.09 m（圓點看起來比方塊小，放大一點維持份量）。`ParticleLook.untextured(node)` 給測試找出沒有貼圖的粒子。
- 理由：沒有貼圖的 QuadMesh 粒子是硬邊方塊（第 13 輪在倒地粉塵發現，其他粒子也一樣）。
- 影響：新的粒子都走 `ParticleLook.material()`；`test_particle_look` 會檢查席菈、鐵架、石拱底下的粒子都有貼圖。

## D-055　2026-11-08　Steam 商店文案與素材規格先寫草稿；系統需求標成估計

- 決策：`docs/steam/store-page.md`（簡短描述、完整描述中英版、標籤、語言、系統需求）與 `docs/steam/asset-specs.md`（商店／收藏庫／圖示尺寸、替代版做法、截圖清單與旗標）先寫，不等 Jacky 的 Steamworks 帳號。文案只寫切片與 12/31 版本確定會有的內容（重現、看穿、席菈三個指令、送葬者戰的抉擇），不寫城市據點等還沒做的系統、不寫原作後段劇透、不用「3A／開放世界」字眼。系統需求是依 Godot 4 Forward+ 與目前場景規模的**估計**，Jacky 跑完 benchmark 後改成實測。尺寸以 Steamworks 官方頁為準（上傳前再核對一次）。
- 理由：階段 2 的 Steam 準備有很多不需要帳號的部分；文案越早寫，越能反過來檢查「切片做的東西說不說得清楚」。
- 影響：商店截圖要在 Windows 實機高畫質截（雲端只有軟體渲染）；正式主視覺（key art、標誌字標）需要 Jacky 處理，階段 2 列進 ART_REQUESTS。

## D-054　2026-11-08　一般敵人向前撲倒；送葬者倒地的冷光與邊緣光；席菈斬完鐵架守著車隊

- 決策：
  - 倒下流程移到 `EnemyActor` 共用（`_begin_death`：停掉 `_physics_process`、`collision_layer = 0` 不再擋路、藏起看穿與弱點；`_on_fall_impact`；`_ground_puff`；`FALL_FORWARD = -1.0` 常數也搬到這裡）。灰巡者：跪下 0.22 秒 → 向前撲倒 0.38 秒（82°）→ 灰粉＋小聲鈍響、胸口鐘盤與爪上的霜光 0.9 秒熄掉 → 躺 1.3 秒 → 1.1 秒沉進雪裡（共約 3 秒；不再壓扁）。
  - 送葬者：大衣加邊緣光（rim 0.7、tint 0.35）；倒地那一刻身體上方 1.4 m 亮一盞冷光（霜色、2.0、範圍 4 m）2.6 秒熄掉；結尾斬倒時燃燒劍火光 2.4 → 3.6 秒（倒地那一刻還亮著）。
  - 席菈：燃燒劍路線斬完鐵架後 `hold_guard(她斬的位置, 5 秒, "車隊我守著。")`：`CompanionBrain.hold_guard` 暫時打開守住（不經過指令冷卻與回話），時間到恢復原本的守住／跟隨；守的途中玩家按「守住」照常切換並結束暫時狀態；倒下時不接。
- 理由：一般敵人「往後倒＋壓扁」沒有重量、方向也和送葬者不一致；暗色大衣倒在夜裡看不見（截圖對照：加冷光後大衣邊緣與周圍濕石板亮起來，看得出倒地的輪廓）；斬完鐵架就跑回諾恩身邊，像是忘了車隊。
  - 倒地粉塵用程序生成的柔邊圓點貼圖（`EnemyActor.soft_dot_texture()`，32×32 放射漸層）；之前沒有貼圖是硬邊方塊。HUD「守住」那一格在 `guard_active` 時染成霜藍（含暫時守住）。
- 影響：倒下的敵人約 3 秒後才移除，期間仍在 `enemies` 群組（鎖定、目標選擇都已經略過死亡的敵人）。暫時守住時送葬者的抓取會被她擋下（`_guard_for` 讀 `guard_active`），這是想要的。

## D-053　2026-11-08　送葬者戰的小演出：石拱被撞時閃光、鐵條落地聲、席菈先衝到車隊前

- 決策：鐵架撞上重現的石拱那一刻 `NineBreathSite.flash()`（冷光 5 倍、0.8 秒退回；石拱不在時不作用）；碎成十截的鐵條第一次落地各響一聲小的 `iron_clang`（越重越大聲、整場最多 6 聲）；燃燒劍路線席菈離車隊超過 3 m 時先 0.18 秒衝到車隊與送葬者之間（離車隊 1.4 m），鐵架在她新位置身前被斬斷。
- 理由：石拱「擋下」要讓玩家看得出是它擋的；十截一起響會糊成一聲；席菈在遠處原地轉身斬鐵架，看起來像鐵架自己掉在她面前。
- 影響：斬完她回到一般跟隨（還沒有「留在車隊旁守著」，記在 NEXT）。

## D-052　2026-11-08　送葬者的倒地演出；前兆姿勢方向修正

- 決策：送葬者死亡時不用一般敵人的「往後倒＋壓扁」，改成：跪下（身體下沉 0.55 m、上身前垂）0.45 秒 → 停 0.5 秒 → 向前倒 0.55 秒（繞膝蓋轉 84°，背上的鐵架朝天）→ 落地那一刻鐵與身體撞地聲、雪粉、鏡頭小震（`fell` 訊號）→ 躺 2.5 秒 → 1.4 秒沉進雪裡移除。倒下時關掉 `_physics_process`（`_update_look` 每幀會蓋掉動作）、藏起前兆霜紋與看穿標示。
- 同一輪修正：前兆姿勢的正負號寫反了——繞 X 軸**負角度才是往前**（頭在 -Z）。之前「下砸上身後仰」實際是前傾、「衝撞低頭／抓取往前探」實際是後仰。改成 `Undertaker.telegraph_lean()`（靜態函式、有測試）。
- 理由：精英被打倒是整段戰鬥的收尾，「壓扁消失」沒有份量。前兆方向錯會讓玩家讀錯招（02-gameplay「讀前兆」是核心）。
- 影響：截圖旗標 `--convoy --felled`（停在倒地那一刻）。倒在地上的送葬者是暗色大衣，夜裡不太顯眼，之後可加邊緣光或讓燃燒劍的火光多留一下。

## D-051　2026-11-08　水窪倒影：ReflectionProbe（只拍一次、只拍靜態幾何）

- 決策：霜橋鎮廣場、主街、南街各一個 `ReflectionProbe`（`UPDATE_ONCE`、盒狀投影、盒子從地面下 0.5 m 到 8.5 m、從離地 1.5 m 拍）。`cull_mask` 只拍「倒影層」（第 11 層）：小鎮合併後的靜態 mesh 才加這一層，角色、敵人、車隊不會被凍在載入那一刻的倒影裡。水窪粗糙度 0.18 → 0.04、水窪 specular 1.0、`render_mode specular_occlusion_disabled`（Godot 會依環境光亮度遮掉反射，夜景暗處的倒影會被整個吃掉）；probe intensity 3.0。低畫質關掉 probe；反射圖集上限 64 → 8 張（只用 3 張，省記憶體）。
- 理由：中畫質沒有 SSR，之前水窪只映出燈的高光。實驗（把地面換成鏡面）確認 probe 拍得到路燈與亮窗；但介電質的反射率低、暗處又被反射遮蔽吃掉，只加 probe 幾乎看不出差別，所以水窪本身也調了。
- 影響：效果仍然偏含蓄（暖色的模糊亮塊，不是概念圖那種拉長的燈影）；重現的石拱與燃燒劍的火光不會出現在倒影裡（probe 只在載入時拍）。高畫質的 SSR 疊在上面。效能：每個像素多一次反射取樣，Jacky 的 benchmark 可以比較中／低畫質。

## D-050　2026-11-08　鐘的材質：低金屬度舊青銅＋鐘唇

- 決策：鐘改成金屬度 0.35、較亮的青銅底色、加邊緣光，鐘口加一圈外翻的唇。
- 理由：原本金屬度 0.8，夜裡沒有可反射的環境，敲鐘鏡頭裡的鐘只剩一個黑影（截圖對照）。金屬感改靠高光與邊緣光表現。
- 影響：之後有 ReflectionProbe 或正式模型時可以再提高金屬度。

## D-049　2026-11-08　匯出版 smoke test

- 決策：CI 匯出後用 **Linux 匯出執行檔**（不是編輯器）在 xvfb 跑截圖模式開到霜橋鎮主街（`scripts/smoke_export.sh`）；有 `SCRIPT ERROR`／載入失敗、沒有截圖、或截圖小於 60 KB（黑畫面）就讓 CI 失敗。截圖與紀錄上傳成 artifact。
- 理由：D-044 只檢查 PCK 裡有沒有檔案；匯出版本身能不能啟動、進關卡、畫出東西，之前要等 Jacky 實機才知道。Linux 版和 Windows 版共用同一個 PCK 內容，能擋掉大部分「編輯器可以、匯出版不行」的問題。
- 影響：每次 CI 多約 1 分鐘。Windows 專屬的問題（D3D12、路徑）仍要 Jacky 實機。

## D-048　2026-11-08　爬坡的做法：看得到的石階＋看不到的斜坡碰撞

- 決策：主街北段四級石階（每級 0.18 m×1.0 m）上到高 0.9 m 的台地，北街、鐘樓、北城牆在台地上。碰撞用一片穿過每級前緣的斜坡（約 10°），台階本身不碰撞。
- 理由：照概念圖「街道往遠處鐘樓上坡、有幾級石階」。CharacterBody3D 不會自己跨階，斜坡碰撞是最便宜、手把和鍵鼠都順的做法；腳離踏面最多 0.18 m，第三人稱看不出來。台地不做整條斜坡，是因為北街要陷落、受困者與灰巡者的位置要好算（`ground_y()`）。
- 影響：測試與開發瞬移用 `level.ground_y(pos)`；之後其他高低差照這個做法。

## D-047　2026-11-08　手把：A 確認、B 返回（UI）

- 決策：`InputSetup.ensure_actions()` 幫 Godot 內建的 `ui_accept` 加手把 A、`ui_cancel` 加手把 B（固定，不進按鍵設定）。
- 理由：內建的 `ui_accept`／`ui_cancel` 只有鍵盤。手把能用十字鍵移動焦點，卻**按不下對話選項與選單按鈕、也關不掉選單**——手把玩家卡在第一段對話的選項。這是新的手把整段流程測試（`test_gamepad_route`，只送手把事件）抓到的；README 寫了「A 確認、B 返回」但其實沒有作用。
- 影響：遊戲中 B 是閃避，但選單沒開時 `ui_cancel` 沒有人處理，不衝突；改鍵時（等待輸入）的 `_input` 先攔截，按 B 會被當成要綁的鍵。
- 同一輪補充：手把綁定的 device 從 0 改成 -1（任何一支手把都認），右搖桿鏡頭讀 `App.last_pad`（最後動過的那支）。Windows 上有其他 HID 裝置或 Steam Input 虛擬手把時，玩家的手把可能不是 0 號。

## D-046　2026-11-08　重現的預覽：從地面往上長出來的冷光輪廓

- 決策：按住 V 時石拱的預覽用 `src/world/restore_ghost.gdshader`（加法混合、不受光、不寫深度）：邊緣（fresnel）亮、石縫隱約可見，`fill`＝按住進度，從物件底部往上長、上緣一道亮線；按滿 1 秒就重現（D-043 的實體石拱接手）。
- 理由：之前是平的半透明塊，看不出形狀，也看不出「還要按多久」。讓輪廓長出來就是世界裡的進度條，不用再加 UI。
- 影響：其他可重現物件共用這個 shader（設 `height`）。

## D-045　2026-11-08　「字幕」設定的範圍：戰鬥中的喊話

- 決策：設定裡的「字幕」控制**席菈頭上的戰鬥喊話**（Label3D）；關掉時台詞照樣記著（`line_text()`），只是不顯示。對話框與過場的字永遠顯示。
- 理由：之前這個開關只存檔、沒有任何地方用到（M1.4 對照時發現）。遊戲沒有配音，對話框與過場文字就是內容本身，不能關；戰鬥喊話是「說出口的話」，最接近一般遊戲的字幕。
- 影響：之後如果有配音或環境人聲（NPC 閒聊），也走這個開關；對話框照舊。

## D-044　2026-11-08　打包驗證：匯出後讀嵌入的 PCK 目錄

- 決策：`scripts/check.sh --export` 匯出後跑 `scripts/verify_package.py`，讀 Windows／Linux 執行檔尾端嵌入的 PCK（`embed_pck=true`；格式 v3／v4 的目錄）並檢查必要檔案：專案設定、主選單與霜橋鎮場景、繁中與英文翻譯、任務／對話／日記／戰鬥數值、字型子集、`Sfx.NAMES` 裡的每個音效（原路徑或 `.import`／`.remap` 都算）。讀不懂目錄時退回字串搜尋。
- 理由：程序生成的字型與音效不進 git，最容易在匯出時漏掉而本機測試看不出來；Jacky 下載的是 zip，不是編輯器。
- 影響：CI 每次匯出都會擋。新增必要資源時把路徑加進 `REQUIRED`；音效清單自動跟 `src/core/sfx.gd`。

## D-043　2026-11-08　重現的石拱：石牆 shader＋石縫冷光

- 決策：石拱重現後用鎮上石牆同一個 `half_timber.gdshader`（石塊放大 1.25），shader 新增 `glow_color`／`glow_energy`（預設 0）：石縫透出冷藍光、邊緣（fresnel）亮；心跳時亮到三倍再退回。
- 理由：之前是 StandardMaterial 的發光＋邊緣光，在霧與去飽和下變成一整塊發白的板子，看不出是石頭（截圖對照）。重現的東西應該「是原本那座石拱、被冷光撐起來」。
- 影響：房子、城牆不設 glow，不受影響。之後其他可重現物件（第一部的橋、門）照用。

## D-042　2026-11-08　送葬者戰演出：鐵架真的飛出去、燃燒劍有火

- 決策：鐵架拋擲的結局仍在擲出那一刻由 `FrameThrowEvent` 決定；之後 `ThrownFrame` 演出：背上的鐵架藏起來，飛出去的那副沿拋物線（0.55 秒、拱高 2.2 m）邊翻邊飛。石拱路線撞在拱心碎成十截往回彈＋石粉＋`iron_clang`；燃燒劍路線席菈轉身出劍（`burn_strike`），鐵架在她身前 1.2 m 被斬成兩截、斷口燒紅＋火星＋橘光。席菈的劍平常熄著，`ignite_sword(秒)` 讓劍身燒紅、加 OmniLight 與火星；提前斬鐵架與結尾斬倒送葬者都會燒。車上的傷者改成程序人偶仰躺（`Puppet.lying = "back"`）、受困者是側倒的人偶（救出時轉正）。
- 理由：這是切片最重要的一場，之前只有橫幅文字和一下震動，看不到「石拱擋下了什麼」「席菈付出了什麼」。燃燒劍的火光在冷色的鎮上很搶眼，正好是代價的視覺。
- 影響：震動與撞擊音效移到撞上那一刻。碎片數固定、2.6 秒後消失，不影響效能。之後換正式模型時，鐵架與劍的掛點跟手骨走。

## D-041　2026-11-08　角色模型接入點：art-inbox → 收件檢查 → game/assets/characters → Puppet

- 決策：Jacky 把正式模型放在 `art-inbox/characters/<id>/<id>.glb`（LFS）。`scripts/gen-assets.sh` 呼叫 `scripts/import_characters.py`，用 Jacky 的 `scripts/check_character_glb.py` 收件檢查；通過才複製到 `game/assets/characters/<id>/<id>.glb`（不進 git，CI 只 `git lfs pull` 這個資料夾）。遊戲端 `Puppet` 加 `character_id`：找得到模型（有 Skeleton3D）就用模型＋AnimationPlayer，狀態對應動作表（idle／walk／run／dodge_roll／light_attack_01，容許 glTF 前綴），手掛點用 BoneAttachment3D（Mixamo 骨骼名在 Godot 匯入後是 `mixamorig_LeftHand`）；缺的閃避動作退回整個人前滾、其他退回 idle；找不到或沒有骨架就用程序人偶。
- 理由：Jacky 正在做正式模型（`ART_PRODUCTION.md`、`ART_QUALITY_BAR.md`），模型一到就要能換上、不用再改外部程式；收件檢查沿用他定的標準，不合格的模型不會偷偷進遊戲。`art-inbox/` 在 Godot 專案外面，匯出時打包不到，所以要複製進 `game/`。
- 影響：PlayerController／Sheila 呼叫的介面不變（set_move_speed、play_action、current_state、hand）。碰撞、AI、弱點判定不跟模型走。之後要接 AnimationTree（混合、上半身疊加）時改 `Puppet._animate_model()`。雲端 session 沒有 LFS 檔時一律用程序人偶，所以測試用程式組的假模型驗證。

## D-040　2026-11-08　目標指引：小菱形＋距離，目標寫在任務資料

- 決策：HUD 畫一個指向目前目標的小菱形＋距離（畫面外貼邊緣加方向三角）；平常半透明、目標文字亮著時全亮；戰鬥中、對話／過場／倒下、離目標 4 公尺內不顯示；設定「目標指引」可關（預設開）。目標寫在 `slice_main.json` 每個階段的 `marker`（`node:`、`nearest:`、`[x,y,z]`）與 `marker_if`（依狀態換目標），測試要求每個階段都有。
- 理由：霜橋鎮比沙盒大，NEXT 記下「玩家可能不知道要去哪」；菱形在霧裡、身後都看得到，比光柱便宜、也不用改場景。資料驅動，之後的章節照填。
- 影響：02-gameplay 新增「目標指引」一節。之後覺得太「遊戲」可以改成目標地點的淡暖光柱，用同一份資料。

## D-039　2026-11-08　房子外牆：半木構 shader（一樓石牆、樓上灰泥＋木框），後牆／城牆／鐘樓改石牆

- 決策：`src/world/half_timber.gdshader`，世界座標、依法線選投影面（朝 ±X 用 ZY、朝 ±Z 用 XY），2.6 公尺以下錯位石塊＋灰縫、以上灰泥＋每層橫梁、1.5 公尺立柱、部分格子斜撐；牆腳濕、積雪，橫梁上緣薄雪；遠處細節淡掉。`FrostbridgeLook.half_timber()`（灰泥冷／暖兩色）與 `stone_wall()`（同 shader、石牆拉到頂）。門口掛燈用位置雜湊決定、不動配置用的 `_rng`。
- 理由：概念圖的第二個辨識點是半木構房子；平塗暗色方塊是目前第一眼最大的缺點。跟濕石板路同一套做法，不需要貼圖、仍可被 StaticBatch 合併（材質數只多 3～4 個）。
- 影響：房子大小與位置是隨機的，木框用世界座標的固定間距，所以立柱不一定對齊房子邊緣（遠看不明顯）。之後要更精緻時可以在 `_house` 裡加真的角柱幾何。

## D-038　2026-11-08　主線流程測試改成真的換場景＋每個檢查點重來

- 決策：`tests/flow/test_slice_playthrough.gd` 用 `Game.go_to_level("frostbridge")`（`change_scene_to_file`）進關卡，從新遊戲走到地窖；每進一個檢查點就呼叫 `Game.retry()`（真的重新載入場景），檢查任務階段、HUD 目標、出生位置、場上的人（席菈、灰巡者、受困者、送葬者）與記憶代價。九息與薪火劍兩條路線各跑一次。
- 理由：「任務恢復」是切片必須驗證的項目；之前的流程測試只在任務層面或手動實例化關卡，沒驗證「死掉重來後場景長得對不對」。
- 影響：之後新增段落要在這個測試裡補一段；場景切換相關的改動（`Game.go_to_level`、`retry`）都會被它擋。

## D-037　2026-11-08　對話依狀態換台詞（text_if）；死者名單的人數

- 決策：對話節點可加 `text_if: [{if, text}]`，第一個成立的條件換掉 `text`，流程不變。收束時艾妲先說死了幾個人：原作的 31 人是預設；救滿四人 30；救滿四人且車隊沒被打 29；車隊被打三次以上 33（優先順序：29 → 33 → 30 → 31）。
- 理由：救援與護送的結果要被故事記得（01-adaptation「死者名單：救援成果反映在名單上」），只換一句台詞就夠，不需要分支節點。
- 影響：`DialogueRunner.current_text()`；`DialogueBox` 第一句改用它。之後「同一句話依狀態不同」都用 text_if。

## D-036　2026-11-08　濕石板路：程序 shader，參考 Jacky 的冬夜概念圖

- 決策：霜橋鎮的地面與廣場用 `src/world/wet_cobble.gdshader`（世界座標 XZ、錯位圓角石塊、濕石縫、低頻水窪、薄雪、遠處淡成平均值）。`FrostbridgeLook.wet_ground()` 同參數共用材質，仍可被 StaticBatch 合併。Jacky 的概念草案（`art-inbox/concepts/`）當作色彩與構圖參考：冷藍月光＋暖燈、濕亮的石板、濃霧、半木構房子、雪只在邊緣。
- 理由：概念圖第一眼最有質感的就是燈光落在濕石頭上；這可以完全用 shader 做到、不需要貼圖或 LFS。合併後的幾何沒有可靠 UV，所以用世界座標。
- 影響：雲端 session 可以 `git lfs pull` 拿到 Jacky 推的圖（推不上去的限制不變）。下一步：房子外牆（半木構、石牆）也用同樣做法；水窪倒影在中畫質沒有 SSR 時只靠燈的高光。

## D-035　2026-11-08　玩家看到的用詞一律白話（回應 Jacky）

- 決策：人名、地名、怪物名照原作；能力、系統、職業、技能、按鍵名用「它做什麼」的白話，不用文言單字。九息 → **重現**（重現 9 秒，Restore）、弔鐘人 → **敲鐘人**（Bell-Ringer）、薪火劍 → **燃燒劍**（Burning Blade）、王室巡界隊 → **王室巡邏隊**、下城 → **地底城**、廢鐘 → 舊鐘、爹 → 爸。代價提示寫成一句完整的話（「永遠忘掉和父親在石拱下的最後一次對話」）。對照表在 `docs/design/06-terminology.md`，`test_i18n::test_no_obscure_terms` 擋住表上左欄的詞出現在翻譯裡。
- 理由：Jacky 回覆「用詞太中國武俠玄學感，九息、弔鐘人完全看不懂」。玩家要靠這些字決定怎麼玩；原作的「弔鐘人能重現已毀之物」本來就用「重現」這個詞，所以能力名直接取它。
- 影響：程式識別碼（`nine_breath`、`kindling`）與設計文件裡的原作名稱不變，只有玩家畫面換掉；之後新名詞先進對照表再用。

## D-034　2026-11-08　救援、席菈、收束段落在霜橋鎮裡的規則

- 決策：北街陷落後出現四個受困者（`RescueSite`），任務在 `rescue` 或 `meet_sheila` 階段時可救：走近按住互動鍵 1.6 秒（放開歸零），救出 → `slice.rescued.<id>`＋`slice.rescued_count` +1。`rescue` 階段的完成條件改成「`slice.rescue_done` 或救出 ≥ 3」，救滿三人席菈就在主街北段出現（第四人在送葬者戰前還能救，影響死者名單）。走到席菈 2.6 公尺內自動開始「夾板／你敲了幾下」（說實話或說謊 → `slice.told_truth_about_bell`），說完北街裂縫爬出一隻灰巡者，倒下 → `slice.ashwalker_defeated`。護送階段走進南街口開打送葬者戰（只一次），車隊抵達 → `slice.convoy_through`。收束：走回梨販攤 3 公尺內和艾妲說話，之後踩進梨販攤東側的地窖蓋板 → `slice.cellar_entered`（切片完成）。
- 理由：先讓「新遊戲 → 結尾」在正式關卡裡每段都有可玩的觸發，演出與手感之後再打磨。救三人就推進，是為了不讓玩家卡在找最後一個人；多救的會被記得。說謊分支「我也數了」是改編新寫，原作只有說實話。
- 影響：`data/quests/slice_main.json` 的 rescue 條件；`scenes/levels/frostbridge.gd` 的段落觸發。原本的流程測試（直接設 `rescue_done`）不受影響。

## D-033　2026-11-08　日記：付出狀態只看 memories_paid；預覽時顯示代價卡

- 決策：日記條目是靜態資料（`data/journal/slice.json`：id＝記憶 id、title／context／body／residue 翻譯 key、people／places、可選 `unlocked_when`）。付了沒只看 `GameState.memories_paid`，所以存讀檔不多存任何東西。付出後：標題與前後文（context）保留，內文（body）變成一塊被整齊剪掉的空白，下面出現殘留（residue）。Tab／View 打開日記（暫停）；九息預覽時（`Game.journal.highlighted`）不暫停，在畫面右側只顯示那一張卡、加暖色框，標題「九息的代價」。
- 理由：02-gameplay「預覽時日記中那段記憶同時被標亮」——按住九息時不可能同時開日記，所以把那張卡帶到畫面上，讓玩家在按滿之前就讀到自己要失去什麼。第一條的前後文與殘留用原作第一部的句子；被剪掉的那段對話原作沒有寫出來，遊戲新寫了一段（躲貓貓、熱薯），讓「失去」有具體內容。
- 影響：之後的可付記憶都照這個格式加條目；`JournalView` 也是第四部「記憶歸零」的介面基礎。

## D-032　2026-11-08　霜橋鎮白盒：程式生成＋StaticBatch；所有檢查點改進霜橋鎮

- 決策：霜橋鎮（`scenes/levels/frostbridge.gd`）跟沙盒一樣在 `_ready` 用程式生成，但靜態幾何不用一個方塊一個 CSG，而是收進 `StaticBatch`：同材質合併成一個 MeshInstance3D（約 15 個 draw call 等級），碰撞是一個 StaticBody3D 底下多個形狀；會動的（北街房子、鐘）各自一個節點。版面：廣場（出生點、梨販攤、井）→ 主街 → 北街（陷落）→ 鐘樓；廣場 → 南街（石拱）→ 路口。每排房子背後有一道連續後牆，房子之間的窄巷看得到但出不去。劇情邏輯抽成 `StoryLevel`，沙盒和霜橋鎮共用；環境抽成 `FrostbridgeLook`。`Game.DEFAULT_LEVEL` 改成 frostbridge，沙盒只用 `++ --level=sandbox`。窗戶的燈最多 22 盞，路燈 5 盞有陰影。
- 理由：沙盒每個方塊一個 CSG，draw call 約 236；小鎮的方塊數是沙盒的好幾倍，不合併會直接吃掉 60 fps 的預算。程式生成可以在 Linux 驗證（測試看結構、截圖看畫面），之後要換成 Jacky 提供的模型時，只要替換 `_house` 之類的產生函式。
- 影響：benchmark 改跑霜橋鎮（數字會跟之前不同，FOR_JACKY 量測請用新版）；CI 截圖 `town.png` 取代 `sandbox.png`。

## D-031　2026-11-08　戰鬥 HUD、席菈倒下、被抓掙扎、鎖定換目標

- 決策：戰鬥 HUD 只在 20 公尺內有活著的敵人時淡入（左下：諾恩生命、席菈生命＋體力、三個指令的鍵名與冷卻圓弧），探索時隱藏。席菈倒下後 8 秒內，諾恩走到 1.8 公尺內按互動鍵拉起（生命 40%）；超過時間就等附近沒有敵人時自己起來（25%）。送葬者抓住諾恩：2 秒內連按閃避或攻擊 5 次掙脫，沒掙脫被捏 12 點才放開；抓著時被打中鐵架關節（席菈打弱點）會鬆手。鎖定中右搖桿水平過 0.75 或滑鼠水平甩 0.12 rad 換到那一側角度最近的目標；被牆擋住 1.5 秒解除。戰鬥中未鎖定時鏡頭拉遠到 4.2 公尺。
- 理由：02-gameplay 的規格；掙扎用閃避鍵是因為被抓的玩家本能會按閃避。換目標不另開新按鍵（少一個要記的鍵，也不必改按鍵設定頁）。
- 影響：數值在 `tuning.json`（`sheila.revive_*`、`undertaker.moves.grab.*`），可 F5 重載調整。

## D-030　2026-11-08　九息石拱與鐵架拋擲的串接

- 決策：沙盒的南街石拱改成「已毀」：兩截斷柱＋碎石＋地上鐘紋；九息重現的是完整石拱（有碰撞）。靠近 5 公尺顯示「可保存：南街石拱／代價：…／按住 [V] 九息」；按住期間顯示半透明輪廓（預覽不付代價），滿 1 秒發動。重現期間畫面飽和度降到 0.12、石拱發冷光、九聲程序心跳、頭上倒數；站在柱子裡的人往前後推出；結束化灰（粒子），只剩廢墟。鐵架拋擲：送葬者站定舉鐵架 4 秒，**落下那一刻**石拱是實體就擋下，否則席菈燒薪火劍（`sheila.kindling_used_early`）。所以太早用九息（拋擲前就化灰）等於白付代價。送葬者戰由 `ConvoyEncounter` 串接：車隊抵達路口＝結束，送葬者被薪火劍斬倒（之後換過場），寫 `slice.convoy_done`、`slice.convoy_injured`、`slice.frame_throw_outcome`。
- 理由：「代價看得見」與「時機有意義」；兩條路都能過、代價由不同的人付（02-gameplay）。邏輯放純資料類別（`FrameThrowEvent`）好測。
- 影響：霜橋鎮白盒（M1.3）直接沿用 `NineBreathSite`、`Caravan`、`ConvoyEncounter`；死者名單與艾妲的態度讀 `slice.convoy_injured`。

## D-029　2026-11-08　送葬者第二階段與傷者車隊

- 決策：`EnemyBrain` 加「連段」（招式的 `chain`：出招結束直接進下一招前兆，不經破綻）與「讀不懂的招」（`unreadable`：席菈的閃開一律算失敗）。連續下砸＝第一下前兆 0.7、第二下 0.5；諾恩在 8 公尺內沒被第二下打到＝看過一次 → 看穿改成已證實、席菈之後抓得到時機。攻略沒寫的招（連續下砸、抓取）在 `intel.json` 標 `hidden`，出現過才顯示。第二階段輪替 `pattern_phase2`（連續下砸／橫掃／抓取／衝撞），優先追車隊。車隊（`CaravanRunner`）每秒 1.1 公尺，被打中停 2 秒、傷者＋1，停下中再被打不重複計。鐵架拋擲在第二階段生命 ≤ 300 或車隊過半時觸發一次。另修正：`EnemyBrain` 的招式資料改成複製一份（原本直接改到共用的 `CombatTuning`）；換難度後送葬者會重新套用第二階段設定。
- 理由：02-gameplay 的「攻略從這裡開始失準」要有可操作的規則：沒看過就喊不準，看過一次就學會。
- 影響：之後的敵人可以直接用 `chain`／`unreadable`／`hidden` 做「攻略錯誤」的變招。

## D-028　2026-11-08　鎖定規則

- 決策：鎖定（中鍵／R3）挑鏡頭前方 70° 內「距離＋角度×0.08」最小的敵人，前方沒有就挑 15 公尺內最近的；鎖定中鏡頭水平方向與角色面向跟著目標（滑鼠／右搖桿只調上下），超過 15 公尺或目標倒下自動解除。席菈的目標優先用諾恩的鎖定目標。「被擋 1.5 秒解除」與「右搖桿撥動換目標」延後到霜橋鎮白盒（街道有遮擋時才測得出來）。
- 理由：02-gameplay 的「打弱點打目前鎖定的敵人」需要一個明確的目標；純函式挑目標好測。
- 影響：之後的「打弱點」指令提示可以畫在鎖定目標上。

## D-027　2026-11-08　難度存在設定檔；音效程序生成、不進 git

- 決策：難度（故事／標準／困難）是設定（`settings.cfg` 的 `[gameplay]`），不是存檔欄位；改了即時套用到場上的敵人（前兆長度、傷害）與席菈（指令時機窗）。音效用 `scripts/gen_sfx.py`（只用 Python 標準函式庫、固定種子）在建置時產生到 `game/assets/generated/sfx/`，跟字型一樣不進 git；檔案不存在時 `Sfx` 安靜跳過。
- 理由：難度只改數值、不改代價與流程（02-gameplay），玩家卡關時應該能隨時調；雲端推不了 LFS（FOR_JACKY 第 3 項），程序音效又小又可重現。
- 影響：正式音效（Jacky 提供或 CC0）之後放 `art-inbox/` 匯入時，同名覆蓋程序版即可；CREDITS 已記。

## D-026　2026-11-08　敵人共用 EnemyActor；多招敵人用 moves＋pattern 資料

- 決策：敵人場景節點繼承 `EnemyActor`（追最近的心跳＝諾恩或席菈、看穿顯示、弱點、難度、`hit_heartbeats`／`hurt`），子類別只寫外型、命中形狀與前兆表現。`EnemyBrain` 支援多招：`tuning.json` 的 `<敵人>.moves`（每招 telegraph／active／recover／min_range／range 與形狀數值）＋`pattern`（輪替順序，距離不合就跳下一個）。送葬者第一階段「前兆與攻略一致」：下砸前兆 1.0 秒；生命 450 以下進第二階段，下砸變 0.7 秒、看穿標成未證實。
- 理由：送葬者、之後的鐘舌送葬者（D-023 第 3 章）都需要多招；資料驅動才能在 F5 重載時調手感。
- 影響：第二階段的連續下砸、拋擲、抓取在下一步加進 moves；車隊目標另做。

## D-025　2026-11-08　席菈指令的細部規則

- 決策：被接受的指令進 1.5 秒冷卻，被拒絕的不進（玩家可以馬上改下別的）。拒絕理由：沒有目標、體力不夠、她倒下了。「打弱點」只在敵人破綻（攻擊後恢復中）或跪地時成功（60 傷害、失衡打滿），其他時候「被反擊」（她扣爪擊傷害）；「閃開」只在前兆後段（標準 60%、故事 100%、困難 35%）成功：0.5 秒無敵＋敵人出完招後反擊（27 傷害、失衡 30），太早只是白閃。自主行為：跟隨、在範圍內斬擊（18），但**不在敵人前兆中出手**——不叫她閃，她就等前兆過去。「守住」是切換：記下當下諾恩的位置，守在那裡、只打靠近的敵人。
- 理由：指令要有明確的對錯回饋（頭上回話），又不能讓自主行為搶走指令的價值。
- 影響：「拒絕會害死人的指令」（例如傷者旁引怪）等車隊與傷者實作後再加；倒下 8 秒內可被拉起也延後。

## D-024　2026-11-08　看穿與弱點的判定

- 決策：看穿按住才顯示（不放慢時間），資料在 `game/data/combat/intel.json`（名字、弱點、招式、已證實與否），執行期可覆寫成未證實；正在出的招前面加 ▶。弱點是「方向」判定：攻擊者在敵人的哪一側（`exposed_arc`，灰巡者左膝＝左側 25°～155°，送葬者鐵架關節＝背後），跪地時全露。打中弱點：諾恩鈍擊傷害與失衡 ×2、停頓 0.09 秒。敵人前兆中受擊失衡 ×0.5（硬撐、不打斷），破綻中 ×2。
- 理由：用位置而不是精準打點，鍵鼠與手把都能做到、看得懂（「繞到牠左邊」），也和席菈的「打弱點」共用同一份資料。前兆硬撐／破綻加倍讓「等破綻」比亂打划算，呼應「看懂比數值重要」。
- 影響：D-022 原本寫的「命中點高度」改成方向判定；看穿文字走翻譯 key。

## D-023　2026-11-08　12/31 版本範圍：序章（切片）＋第一部第 1～3 章

- 決策：12/31 版本＝序章「第九聲鐘」（垂直切片）＋第 1 章「攻略之外的門」（酒館簡報、地窖、白晝城石碑）＋第 2 章「城主的飯桌」（縮成一場飯桌對話與探索）＋第 3 章「不准替我答應」（鐘舌送葬者解謎 Boss）。第一部第 4、5 章（城市據點、屏障高潮）與第二～四部放到 2027。對應表與角色弧線在 `docs/design/01-adaptation.md`。
- 理由：序章到第 3 章是一條完整的小弧線（敲錯鐘 → 知道真相 → 第一次「不准替別人決定」），只需要切片已有的系統再加一個解謎 Boss；第 4 章起需要完整的城市據點系統，12 月做不精。
- 影響：12/14～12/24 的「下一段章節」以第 1、3 章為主，第 2 章做成對話章。

## D-022　2026-11-08　命中判定用幾何扇形＋群組；打擊停頓用 time_scale

- 決策：近戰命中不用物理形狀查詢，改在出招那一幀對 `damageable` 群組做水平扇形判定（`PlayerController.in_strike_arc`，純函式）；每次揮擊只判定一次（`strike_window` 進入時）。敵人邏輯在 `EnemyBrain`（純狀態機，吃距離與時間），場景節點只負責移動與表現。打擊停頓用 `Engine.time_scale`＋真實時間計時器（重疊時以最後一次為準），回標題與重試時強制恢復 1.0。測試輸出出現 `SCRIPT ERROR` 一律視為失敗（之前執行期錯誤會讓測試「通過」）。
- 理由：headless 測試裡物理查詢時機不穩；扇形判定可預測、好調、好測。敵人數量少（切片同時 ≤ 4），遍歷群組沒有效能問題。
- 影響：之後的弱點（左膝）判定在扇形內再看命中點高度與方位；大型敵人（送葬者）改成多個 hurtbox 點。

## D-021　2026-11-08　過場＝可互動演出；狀態只由 effects 改變，跳過永遠安全

- 決策：過場放 `game/data/cutscenes/*.json`，一串鏡頭（Marker3D 名稱）；鏡頭有時長或等待某個動作（`await`＋`prompt`＋可選 `counter`）。狀態只能由鏡頭的 `effects` 與 `on_end` 改變，`event` 只給畫面與聲音。跳過＝依序補上還沒套用的 effects 再套 `on_end`，被跳過的 event 不發，關卡改看旗標補上結果（例如北街沉陷）。按住互動鍵 1 秒跳過（對話 0.6 秒，共用 `HoldToSkip`）。過場中玩家不能移動（`Game.is_player_locked()`）。
- 理由：原作的「親手敲九下」需要每一下一個輸入，又要能跳過與重試；把互動與演出放在同一個資料格式，跳過與讀檔都不會漏掉狀態。
- 影響：敲鐘、之後的九息還原演出、席菈薪火劍都用這個格式。字幕目前一律顯示（沒有配音），之後有語音時才讓字幕開關生效。

## D-020　2026-11-08　按鍵重新綁定規則

- 決策：每個動作兩格（鍵鼠、手把）。暫停鍵（Esc／Start）與移動搖桿固定，不能被綁走；新鍵已被同一格的其他動作使用時兩者交換。只存跟預設不同的動作到 `settings.cfg` 的 `[input]`，讀取時從預設開始逐筆 rebind，壞值略過、衝突自動解開。鍵名：滑鼠、手把（Xbox 配置）、幾個有名字的鍵走翻譯 key（`GLYPH_*`）；其他鍵盤按鍵用系統鍵名（鍵帽上的字，不翻譯），這類 UI 節點標 `meta glyph`、關閉自動翻譯，i18n 測試略過。
- 理由：保證永遠叫得出選單；交換比拒絕更少挫折；設定檔被手改壞也不會讓遊戲不能玩。
- 影響：手把圖示目前是文字（A／B／LB…），打磨階段可換成圖示字型或貼圖，介面（`InputGlyphs.label_for_spec`）不變。

## D-019　2026-11-08　畫質三級只切開關；設定即時生效、關閉選單才存檔

- 決策：`QualityPreset`（低／中／高）只切換效果開關與 MSAA，不改場景調好的霧色與密度。低畫質關體積霧時改開便宜的深度霧（顏色取自場景的體積霧），保住冬夜氛圍。場景的 WorldEnvironment 進樹時由 Settings 自動套用（`node_added`），場景不用自己處理。音訊匯流排 Master／Music／SFX／Voice／UI（UI 接 SFX）由程式建立。設定改值即時生效，關閉設定選單時才寫 `settings.cfg`（語言切換例外，立即寫入）。
- 理由：場景只需要做一份「中」畫質的調整；畫質選項可以測試；拖滑桿不會一直寫檔。
- 影響：新場景只要用 WorldEnvironment 就自動支援畫質；之後新增的效果（SDFGI、陰影距離等）加在 `QualityPreset` 一處。

## D-018　2026-11-08　對話：JSON 節點圖＋DialogueRunner，由 Game 接到任務

- 決策：對話放 `game/data/dialogue/*.json`（格式見 `dialogue_db.gd` 開頭），文字 key 放 `i18n/slice.csv`。`DialogueRunner` 是純邏輯（台詞、條件過濾選項、效果）；`Game.start_dialogue(id)` 建立 runner、效果套用後呼叫 `session.advance()` 推進任務；`DialogueBox` 只聽訊號。驗證規則：next／choices 指向存在節點、不能同時有 next 與 choices、每組選項至少一個無條件選項（避免卡住）、所有節點都要從 start 走得到。跳過只跳到下一個選項，不替玩家做選擇。
- 理由：照 04 架構與 D-013；對話與任務共用 StoryLogic，條件與效果都可測；「付過的記憶讓選項消失」直接用 `{"not": {"memory_paid": ...}}` 表達。
- 影響：對話中玩家不能移動（`Game.is_in_dialogue()`）；對話狀態不存檔（從檢查點重建時重新觸發）。

## D-017　2026-11-08　程序人偶用 Node3D 關節，不用 Skeleton3D

- 決策：`Puppet`（`scenes/actors/puppet/`）用 Node3D 樞紐＋膠囊肢體，程式算姿勢（待機呼吸、走跑步態、前滾、鐘錘下劈）。對外介面固定：`set_move_speed`、`play_action("dodge"|"attack")`、`current_state()` ∈ `STATES`（idle／walk／run／dodge／attack）、`hand("L"|"R")`。
- 理由：程序骨架＋蒙皮的價值在換模型時才出現，但那時會整個換成 Jacky 提供的模型與 AnimationTree；Node3D 樞紐更快、好測、剪影一樣清楚。05 計畫原寫 Skeleton3D，改為介面相容即可。
- 影響：正式模型到位時，新增一個同介面的類別（內部用 AnimationTree，狀態名沿用 STATES），PlayerController 不用改。

## D-016　2026-11-08　效能量測：overlay＋benchmark JSON；開發工具文字不翻譯

- 決策：`Perf` autoload（F3／`--perf`）顯示 FPS、1% low、CPU／GPU 渲染時間、draw calls、VRAM、驅動與顯示卡；`--benchmark` 跑固定鏡頭路徑 30 秒（暖機 2 秒不計），寫 `user://benchmark/bench-*.json`。達標判定：平均 ≥ 60 fps 且 1% low ≥ 45 fps。overlay 與 benchmark 是開發／量測工具，文字用英文技術縮寫、不走翻譯 key（不出現在玩家選單）。
- 理由：session 沒有 GPU，效能只能由 Jacky 實機量測；把量測做成一個指令、一個 JSON，回報成本最低。
- 影響：benchmark 場景會隨切片內容更新（之後改成霜橋鎮白盒）；JSON 格式改動要保持舊欄位。

## D-015　2026-11-08　使用者資料夾固定為 YumingCity

- 決策：`application/config/use_custom_user_dir=true`、`custom_user_dir_name="YumingCity"`。Windows 為 `%APPDATA%\YumingCity\`（存檔在 `saves/`、benchmark 在 `benchmark/`、設定 `settings.cfg`）。
- 理由：路徑短、不含空格與 Godot 字樣，方便寫給 Jacky 的量測步驟，之後 Steam 雲端存檔也指向這裡。
- 影響：改名會讓舊存檔找不到；正式發行前不再更動。

## D-013　2026-11-08　任務與對話：JSON 結構＋翻譯 key

- 決策：任務、對話、戰鬥數值放 `game/data/**/*.json`；JSON 只放結構與翻譯 key，玩家看得到的文字一律在 `game/i18n/*.csv`（切片的任務與對話文字用 `slice.csv`，與介面 `strings.csv` 分開；每個 CSV 都要在 project.godot 註冊，測試會檢查）。條件與效果只能讀寫旗標與記憶，不執行任意程式。
- 理由：Godot 內建 JSON 解析、純文字好 diff 與測試；遵守「所有文字走翻譯 key」；字型子集化只需掃 CSV。
- 影響：測試檢查 JSON 引用的 key 都存在且有 en＋zh_TW；`gen_fonts.py` 掃描 `i18n/*.csv`。詳見 `docs/design/04-architecture.md`。

## D-014　2026-11-08　戰鬥數值與鏡頭規則定初版

- 決策：照 `docs/design/02-gameplay.md` 的數值表與鏡頭規則實作；諾恩沒有體力條，席菈有；難度只調傷害、前兆長度與指令時機窗，不改代價。開發用 `user://tuning.json` 覆寫並熱重載。
- 理由：Jacky 喜歡「簡單但吃技巧」的戰鬥——減少資源管理、把技巧放在讀前兆與下指令的時機。
- 影響：數值不寫死；試玩後調整只改資料檔。

## D-012　2026-11-07　九息的狀態語意

- 決策：可保存物件只有三態 BROKEN → RESTORED（倒數九息，每息 1 秒）→ SPENT（化灰，最終狀態，不會回到損壞）。代價在 activate 時付，同一段記憶只付一次。存檔若落在九息中間，讀檔一律視為 SPENT。狀態存在旗標 `ninebreath.<object_id>`。
- 理由：照原作（九次心跳後石拱化灰）；避免讀檔重複扣代價或卡在半途。
- 影響：場景節點只負責顯示、碰撞切換與把玩家推出碰撞體；邏輯在 `game/src/core/nine_breath.gd`。

## D-011　2026-11-07　存檔格式：JSON＋版本號＋逐版遷移

- 決策：`{"version", "saved_at", "state"}`，目前 v1；改格式就加版本與遷移步驟和測試。寫檔先寫 `.tmp` 再改名，舊檔留 `.bak`，主檔壞掉自動讀 `.bak`。拒絕讀取比遊戲新的存檔版本。
- 理由：純文字好除錯、好測試；遷移鏈保證舊存檔能讀。
- 影響：之後 Steam 雲端存檔同步 `user://saves/` 下的 JSON 即可。

## D-010　2026-11-07　字型：Noto CJK TC 建置時子集化

- 決策：從 notofonts/noto-cjk release 下載（SHA-256 固定），依翻譯與資料檔用字子集化，標題用 Noto Serif CJK TC SemiBold，介面用 Noto Sans CJK TC。產物不進 git；字型不存在時退回系統字型。
- 理由：繁中字形在各系統一致、標題有質感；子集後每個字型約 100 KB；OFL 授權可商用。
- 影響：新增文字檔類型時要確認 `gen_fonts.py` 的收字範圍涵蓋；測試會檢查缺字。

## D-009　2026-11-07　畫面驗證用 xvfb＋軟體 Vulkan 截圖

- 決策：遊戲支援 `-- --screenshot=<png> --frames=<n>`，跑 n 幀後存檔結束；`scripts/screenshot.sh` 以 xvfb-run 執行，Vulkan 失敗時改 opengl3。CI 也截一張標題畫面放到 release。
- 理由：session 實測 xvfb＋mesa（lavapipe）能跑 Forward+ 並截圖，loop 可以看到自己的畫面。
- 影響：截圖只代表畫面內容，不代表效能。效能一律由實機量測。

## D-008　2026-11-07　CI 每次 push 重建 prerelease「latest」

- 決策：push 到 main 時，CI 刪除舊的 `latest` release 與 tag，再以當次 commit 建立新的 prerelease，附 Windows／Linux zip 與截圖。
- 理由：讓 Jacky 永遠從同一個網址下載最新版；刪除後重建不需要 force push tag。
- 影響：`latest` 沒有歷史；正式版本另打版本 tag（階段 3）。

## D-007　2026-11-07　渲染：Forward+，Windows 預設 D3D12

- 決策：`rendering_method=forward_plus`，Windows 驅動 `d3d12`，Godot 失敗時自動退回 Vulkan。
- 理由：Jacky 指定 Forward+；DX12 在 Windows 上的驅動相容性較廣。
- 影響：實機量測時要記錄實際使用的驅動（效能 overlay 會顯示）。

## D-006　2026-11-07　在地化用 CSV（keys,en,zh_TW）

- 決策：`game/i18n/strings.csv` 一個檔案放兩種語言；生成的 `.translation` 不進 git。預設語言依 OS：繁中系統用 zh_TW，其他一律英文。key 用大寫底線。
- 理由：兩語並排好維護；測試可以檢查每個 key 都有兩種語言、場景沒有寫死文字。
- 影響：乾淨 clone 要先 import 一次才有翻譯檔（`scripts/check.sh` 已處理）。

## D-005　2026-11-07　測試框架自製（極簡 TestCase），不引入 GUT

- 決策：`game/tests/run_tests.gd`（SceneTree 腳本）＋ `TestCase` 基底類別；先檢查所有腳本能載入，再跑 `tests/unit`、`tests/flow`。
- 理由：零依賴、headless 直接跑、程式碼不到 200 行；需求長大再評估 GUT（MIT）。
- 影響：新邏輯一律寫 `test_*.gd`。

## D-004　2026-11-07　Git LFS：session 無法推送，loop 不 commit LFS 類型

- 決策：保留 `.gitattributes` 的 LFS 規則（並加入 glb、ogg、jpg、字型等），但 loop 不 commit 這些類型。程序生成的素材在建置時產生到 `game/assets/generated/`（不進 git），CI 和本機用同一支腳本產生。
- 理由：實測 LFS 上傳被雲端 session 的網路代理擋下（上傳到 GitHub 的 S3 儲存回 403）。
- 影響：Jacky 從自己電腦推 LFS 不受影響；loop 能否下載 LFS 內容待實際遇到再測。見 FOR_JACKY。

## D-003　2026-11-07　GDScript＋靜態型別，未加型別視為錯誤

- 決策：`untyped_declaration`、`unreachable_code`、`standalone_expression` 設為錯誤；`unsafe_*` 等設為警告。允許 `:=` 型別推斷。
- 理由：Jacky 指定；型別錯誤在 import／測試階段就會被抓到。
- 影響：不使用 C#／.NET。

## D-002　2026-11-07　Godot 版本固定 4.7.2-stable

- 決策：`scripts/get-godot.sh` 固定 4.7.2-stable（標準版），用同一 release 的 `SHA512-SUMS.txt` 驗證。
- 理由：2026-11-07 查證，4.7.2 是最新 stable；4.8 仍在 beta。
- 影響：不因新版發布就升級；要升級需記新的決策並全面重測。

## D-001　2026-11-07　引擎由 UE5 改為 Godot 4（Jacky 定案）

- 決策：使用 Godot 4，取代原本建議的 Unreal Engine 5。
- 理由：開發 loop 在沒有 GPU 的 Linux 雲端 session 執行，無法安裝或編譯 UE5，Blueprint／地圖是二進位檔，無法自我驗證。Godot 開源、無權利金，場景與腳本是純文字，可以在 Linux 與 GitHub Actions 測試並匯出 Windows 版。
- 影響：`README.md`、`docs/technical-direction.md`、`.gitignore`、`.gitattributes` 已改為 Godot 方向；專案在 `game/`。
