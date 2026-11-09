# 下一輪待辦（依優先順序）

> 每輪從最上面拿 1～3 項。開工前先跑 `scripts/check.sh` 確認全綠（約 50 秒；第一次會下載 Godot 與字型來源、產生音效、檢查角色模型）。截圖前先 `apt-get update && apt-get install -y xvfb mesa-vulkan-drivers`（**一定要先 update**，不然裝不到 mesa-vulkan-drivers，截圖退回 OpenGL、沒有體積霧）。目前狀態：垂直切片 M1.1～M1.3 完成、M1.4 只剩 Jacky 實機項目；「第一眼」盤點做了八輪（第 17～35 輪，逐項見 PLAN 階段 2 的八張表與 PROGRESS），第 35 輪停止。**第 37 輪完成章節切換（切片結尾 → 章節卡 → 酒館，D-149）、酒館白盒段落 1～3（中午、晚餐灑湯、畫地圖）、段落 3 的標記畫面（D-150）。下一輪接第 5 節：段落 4（白天的霜橋鎮＋艾妲的油燈）→ 段落 5（長階梯、丟石頭試探陷阱）**。

## 0. 開工先確認

- 上一輪（第 37 輪）的程式 commit：2816522 章節切換＋酒館白盒＋第 1 章對話、05d4b45 酒館開發旗標與入夜窗光、58ae5f4 標記畫面（最後一個，CI 結果見 PROGRESS 第 37 輪）。**開工先看最新 run 整個綠燈**；開工照常先跑 `scripts/check.sh`（最後 318 個測試）。紅了就看 log 修，修不好 `git revert`。
- 第 36 輪的 run 42553368535（2140c8f）已全綠（第 37 輪開工確認）；latest 的 `achievement-icons.zip` 第 37 輪沒有回頭確認，有空看一眼。
- `docs/PROGRESS.md` 約 190 行（第 34 輪已把第 24～28 輪合併成每日摘要）；超過約 300 行時把第 29～33 輪合併。
- **第 21～23 輪本機都拿得到 Godot 與字型**（第 23 輪一次就下載成功；`check.sh` 第一次約 1 分 40 秒）；`scripts/check.sh` 一次過（含字型下載）。第 20 輪那種一律 504 的情況如果再發生，照下面「本機拿不到 Godot 時」的做法。
- **盤點截圖（D-082）**：prerelease「screens」有 11 張（`01-settings`～`11-convoy-insight`）。`curl -sSL -o screens.zip https://github.com/twjackysu/yuming-city/releases/download/screens/screens.zip`（GitHub 偶爾回 504，迴圈重試；**一次只下載一個檔**），解壓到 scratchpad、PIL 縮到 900 寬再看。screens job 是 `continue-on-error`：在 run 的 jobs 裡看「盤點截圖」有沒有綠燈，紅了看 log（多半是某個旗標組合拍不出來）。
- **本機拿不到 Godot 時（第 20 輪發生過，第 21 輪恢復）**：`scripts/get-godot.sh` 對 `godotengine/godot` 的 release 回 504（session 的 GitHub 存取範圍只有本 repo）。不要繞過：改成 push 前 `pip install gdtoolkit==4.* --break-system-packages` 後 `gdparse <檔案>` 檢查語法（抓不到型別錯誤，型別一律照 project 的警告規則寫）、幾何先用 Python 驗證，推上去看 CI；畫面看 latest／screens。先試一次 `scripts/get-godot.sh`，拿得到就照舊本機驗證。
- **字型下載 504（D-079）**：第 19 輪的 session 連不到 `notofonts/noto-cjk` 的 release（504／API 說沒有這個 repo 的存取），`scripts/check.sh` 會在 `gen_fonts.py` 掛掉。先試一次 `scripts/check.sh`；如果又是 504：`apt-get install -y fonts-noto-cjk fonts-noto-cjk-extra`，再用 D-079 的做法（從 `/usr/share/fonts/opentype/noto/Noto{Serif,Sans}CJK-*.ttc` 取 TC 那一套、照 `gen_fonts.collect_chars()` 子集化、寫 `game/assets/generated/fonts/` 與相同的 `.stamp`；`import gen_fonts` 會留下 `scripts/__pycache__/`，記得刪掉）。**不要改 repo 的 `gen_fonts.py`**，CI 照常下載。改了 i18n CSV 後要重跑。
- CI 有「匯出版 smoke test」（D-049）：紅了先看 artifact 裡的 `smoke-export.log`。「Steam 膠囊圖替代版」步驟是 `continue-on-error`，失敗不會讓 CI 變紅——偶爾看一下 artifact 裡有沒有 `steam/*.png`。
- **本機截圖會在真的 `user://saves`（`/root/.local/share/YumingCity/saves`）留下自動存檔**，之後標題畫面的「繼續」會變成可按；要拍新玩家的標題畫面先把 saves 移開。只有 2 核，150 幀的對話截圖要單獨跑（同時跑會超過 120 秒逾時）。
- 本機跑匯出版 smoke test：`scripts/get-godot.sh --templates`（第一次約 1 分鐘）→ `$(scripts/get-godot.sh) --headless --path game --export-release "Linux" ../build/linux/YumingCity.x86_64` → `scripts/smoke_export.sh`。
- 只跑部分測試：`TEST_FILTER=gamepad $(scripts/get-godot.sh) --headless --path game -s res://tests/run_tests.gd`（檔名含那段字）。改了 class_name 或新檔案要先跑一次 `--import`。
- **程式 commit 與 `[skip ci]` 文件 commit 要分開 push**（同一次 push 的 HEAD 帶 `[skip ci]` 會讓整個 push 不跑 CI）。工作區有未提交的文件時：**先 commit 程式**，再 `git stash push -- docs`（只收文件）→ pull/push → `git stash pop`。第 20 輪先 `git stash` 再 `git add` 結果程式改動被收走、commit 只帶到新檔（多補了一個 commit）。
- **玩家看得到的字一律白話**：新名詞先寫進 `docs/design/06-terminology.md` 再用；`test_i18n::test_no_obscure_terms` 會擋舊詞（九息、弔鐘、薪火、巡界、下城、爹…）。程式識別碼照舊（`nine_breath`、`kindling`）。
- Jacky 的概念圖在 `art-inbox/concepts/`（LFS）：`git lfs pull --include="art-inbox/concepts/frostbridge_winter/**"` 這樣指定資料夾下載（推 LFS 還是不行）。看圖前先用 PIL 縮到 900 寬。
- 全域 Theme（D-067、D-071）：`UiTheme.style()` 定義按鈕／滑桿樣式，`App` 同時套在 root 與引擎預設 Theme；新選單直接用 flat Button 就有暖金色焦點。設定頁新增一列：在對的分組底下呼叫 `_add_cycler`（多選一，自動有「‹ 值 ›」與小圓點）／`_add_toggle`（開關，不畫圓點）／`_add_slider`（音量，帶百分比）；新分組用 `_add_group`（D-076），新 key 先查 `06-terminology.md`。
- 霜橋鎮截圖旗標（`--level=frostbridge`）：`--pos=x,z`（最後把諾恩移到這裡、高度照地面）、`--face-off=度`（`--face` 之後再往左轉，目標落到畫面右側）、`--hide=noen`（D-074）、`--at=plaza|main|steps|north|south|cross`、`--rescue`、`--convoy`（＋`--phase2`、`--throw=arch|kindling --throw-t=秒`、`--felled` 送葬者倒地、截圖時藏起諾恩）、`--arch=preview|restored|spent`、`--open=journal`、`--dialogue=slice_sheila_meet --dialogue-steps=5`、`--cutscene=slice_bell_nine --cutscene-steps=3`、`--quality=0..2`、`--locale=zh_TW`、`--device=pad`（手把圖示）、`--nohud`（整個 HUD 不顯示，D-064）、`--face=sheila|undertaker|frame`（諾恩與鏡頭每幀轉向那個角色；燃燒劍斬鐵架：`--convoy --throw=kindling --throw-t=0.6 --face=sheila`）、`--insight`（一開始就按住看穿，第 20 輪）、`--face=arch`（第 21 輪；`--convoy --arch=preview` 會把送葬者停在諾恩背後）。沙盒（`--level=sandbox`）還有 `--enemies`（＋`--felled` 灰巡者撲倒）、`--boss`、`--insight`、`--lock`。軟體渲染很慢：一般 25～40 幀。
- 改了 `i18n/*.csv` 之後：`scripts/check.sh` 會重跑字型子集與 import。改 CSV 時**只改那幾行**（Python 讀一行插一行／改一行，保留原本的引號；整檔用 csv.writer 重寫會把 `" (confirmed)"` 前面的空白弄丟）。英文裡有逗號要整格加雙引號。

## 1. 「第一眼」打磨（照 PLAN 階段 2 的盤點表，從上往下）

- 第 17 輪：窗（D-066）、選單焦點（D-067）、雪（D-068）、門（D-070）、關卡 UI 套上 Theme（D-071）。第 18 輪：過肩鏡頭（D-072）、日記舊紙（D-073）、截圖構圖旗標（D-074）、送葬者兜帽霜光（D-075）。第 19 輪：設定頁分組與「‹ 值 ›」（D-076）、廣場石框與鐘紋＋井＋木箱模式（D-077）、選單換值的「叮」（D-078）、路燈燈籠（D-080）。第 20 輪：鐘形與鐘室木構（D-081，旋轉體用 `Lathe`：剖面線繞 Y 軸，外側從上往下描）、敲鐘刻度（D-084，`RingTally`）、角色不擋鏡頭（D-085）。第 21 輪：石拱預覽截圖停住送葬者＋`--face=arch`（D-086）、看穿小卡（D-087）、前兆範圍 shader（D-088）、攤桌補光（D-089）。新的「一個 shader＋頂點色」物件照窗與門的模式：`StaticBatch.add_box_tinted`（要擋人就 `collide=true`）＋`FrostbridgeLook.xxx_tint(pos)`（位置雜湊，不動 `_rng`），面內座標 `fract(UV × (3, 2))`。木頭東西用 `look.door()`＋`crate_tint`（r＝0 木箱模式）。小鎮合併 mesh 上限 24：新材質盡量沿用既有的（`look.mat(color, rough)` 會依參數快取）。
- 第二輪盤點 10 項全部完成（第 22 輪：北街破屋頂 D-091、標題的窗與鐘 D-092、暫停選單目標與提示＋暫停藏 HUD D-093、README 重現圖構圖 D-094）。
- **第三輪盤點（PLAN 階段 2 第三張表，D-099）全部完成**：第 23 輪第 1～4 項（D-095～D-098）＋木桶（D-100）；第 24 輪第 5 項送葬者輪廓（D-101）、第 6 項破屋頂雪堆（D-102：`SnowMound.build(長, 寬, 高, seed, bias)`，模型 X＝長、Z＝寬、底在 y=0；`bias` 讓最高點偏一邊）、柴堆與手推車（D-103）；第 25 輪木圍欄（D-104：`FENCE_PATH`、`_build_fence`）、街邊雪帶（D-105：`_snow_bank(牆腳線起點, 終點, 牆的方向, 伸出寬度)`、`snow_banks`）、推車淡出（D-106：`CameraFade.apply(節點, near, far)`）、屋瓦（D-107：`RoofMesh.build`、`look.roof_tiles()`、`ROOF_SNOW`）、接地陰影（D-108：`ContactShadow.attach(角色, 半徑, 強度)`）。
- **第四輪盤點（PLAN 階段 2 第四張表，D-109）**：第 26 輪完成第 1 項（D-110：`RoofMesh.slab(長, 厚, 寬)` 只有頂面 UV 是公尺、-X 端是屋簷；`SnowMound` 20 段、輪廓大起伏）、第 2 項（D-111：`Caravan` 的 `_box`／`_part`、常數 `BED_*`／`WHEEL_*`／`LANTERN_POS`）、第 3 項（D-112：`_roof_snow_lip`）、第 5 項（D-113：`Caravan._wrap_head`）、第 7 項（併入第 1 項）。
- 第四輪第 4、6 項第 27 輪完成：地上殘雪（D-114：`FrostbridgeLook.set_ground_marks(lanes, trodden, rut)`、`frostbridge.gd` 的 `ground_lanes()`／`TRODDEN`／`RUT_PATH`；fbm 的值大多在 0.3～0.65，門檻照這個抓）、角色淡出（D-115：`CameraFade.CHARACTER_NEAR/FAR`、`EnemyActor.camera_fade_range()`；自訂 shader 要淡就宣告 `fade_near`／`fade_far` uniform，照 `frame_iron.gdshader` 的寫法）。
- **第五輪盤點（PLAN 階段 2 第五張表，D-116）**：第 28 輪完成第 1 項冬夜天空（D-117：`night_sky.gdshader`，`FrostbridgeLook.night_sky()`、`SKY_FOG_AFFECT` 0.4；雲的亮度 `cloud_dark`／`cloud_lit`／`cloud_cover`、星 `star_energy` 與門檻 0.998、遠山 `ridge_height()`；**不能用 TIME**，`test_night_sky` 會擋）、第 3 項雪堆外圈變薄（D-119：SnowMound 的 UV2.x＝圈數，其他雪沒有 UV2、合併時補 0；同一個 `look.snow()`）、第 4 項提燈影子（D-118：`PlayerController.SELF_LAYER` 第 12 層、`LANTERN_SHADOW_CASTERS`）。
- 第五輪（第 29 輪）：石板鋪法（D-120：`wet_cobble.gdshader` 的 `arc_paving`／`arc_center`／`row_wave`／`clear_disc`；`FrostbridgeLook.wet_ground_arc`、`frostbridge.gd` 的 `plaza_ground()`；**shader 內建 `TAU`，不要自己宣告**）、鐘鈕（D-121：`BELL_DROP`、`_build_bell_crown`）、店招（D-122：door shader 的店招模式 r＝0.4＋0.1×圖案編號、a 標記大面朝 X／Z；`FrostbridgeLook.sign_icon`／`sign_tint`）。
- 第六輪（第 30 輪）：雪帶（D-126：`snow.gdshader` 的 `wind_dir`／`ripple_*`／`wall_shade`／`footprint_density`；`SnowMound.build(..., bias, street_bank, on_tiles)`，UV2.y：街邊雪帶 -1～1＝往牆那側多遠、屋瓦上的雪＝`TILES_MARK`＋模型 X 公尺數、其他 0）、破屋頂的雪（D-127：`RUIN_SNOW_H`、`tile_row`、`under_color`）、廣場的圈（D-128）。
- 第七輪（第 31 輪）：石拱（D-129：`NineBreathSite` 的 `ARCH_*`、`VOUSSOIRS`、`_build_arch_trim()`；**CSGPolygon3D 從 z=0 往 -Z 擠出**）、廣場鐘剪影（D-130：`frostbridge.gd` 的 `bell_inlay_mesh(h, r)`、`PLAZA_BELL_*`；**自己用 SurfaceTool 做的 mesh 要 `st.index()` 才能進 StaticBatch**（不然跟有索引的 CylinderMesh 同材質時畫不出來）；Godot 正面順時針）、破屋頂露出屋瓦（D-131：`snow.gdshader` 的 `row_i`／`bare_n`）。
- 第七輪（第 32 輪）：拱石的放射縫（D-132：`half_timber.gdshader`／`restore_ghost.gdshader` 的 `arch_voussoirs`／`arch_center`／`arch_inner`／`arch_outer`／`arch_key_extra`，物件座標 varying `obj_pos`／`obj_normal`；`NineBreathSite.KEYSTONE_RISE`）、破屋頂屋簷那團雪拿掉（D-133：先把可疑物件註解掉截一張圖確認是誰，很快）、雪帶一串腳印（D-134：`SnowMound.build_bank`，UV＝(`BANK_MARK`＋沿著牆的公尺數, 離牆多遠)；`snow.gdshader` 的 `trail_from_wall`／`step_len`／`footprint_density`；雪帶座標換回世界方向用螢幕空間導數）。
- 第八輪（第 33 輪）：雪帶連成一整條（D-136：`SnowMound.build_strip`／`strip_height`／`strip_out`，`frostbridge.gd` 的 `SNOW_BANK_HEIGHT`；`build_bank` 已經沒有關卡在用，只剩測試）、石階的雪（D-137：`_step_snow`、`STEP_PATH_HALF`、`step_snow`）、石階前緣下的暗線（D-138）。
- 第八輪（第 34 輪）：破屋頂的雪（D-139：`SnowMound` 的 `TILES_RINGS`／`TILES_SEGMENTS`／`TILES_RAGGED`／`TILES_FALLOFF`；`snow.gdshader` 的 `tile_drape`／`tile_mottle`／`moon_to`／`backlit_shade`，沿斜面公尺數的世界梯度 `gm` 跟腳印一樣用螢幕空間導數解）、廣場的鐘（D-141：`PLAZA_BELL_H／R／FLARE／CLAPPER_R`；**地上的圖案從南邊看南北方向被壓成約四分之一**，改比例不要改方向——橫躺看起來像一支箭）。
- **「第一眼」盤點停止（第 35 輪，D-146）**：八張表做完（第七張第 7、8 項、第八張第 7 項是截圖構圖或等 Jacky，不改）。之後的打磨只做 Jacky 試玩回饋提到的，或做章節時順手修；不要再開第九輪盤點。
- 第七張表第 8 項 TAA 等 Jacky 看網點。廣場石板（D-144）：`wet_cobble.gdshader` 的 `sunken_share`／`dark_share`／`grit_amount`／`ring_gap_tighten`／`far_fade`（街道預設 1.2、廣場 `ARC_FAR_FADE`）。
- 本機截圖：**Vulkan 一張 120 秒內要拍完**（`screenshot.sh` 的逾時），40 幀的 `--convoy --phase2` 第一次會超時退回 OpenGL（沒有霧、畫面很不一樣）；改用 25～30 幀。
- 破屋頂的山牆（PrismMesh）還是 `look.mat(ROOF)` 素面；看起來沒問題就不用改。
- 看穿小卡（D-087）：`InsightCard` 在敵人自己的 CanvasLayer（layer 9），資料是 `EnemyIntel.rows()`；新敵人只要有 `intel_id()` 就自動有卡。卡片放在頭頂投影點右邊（`OFFSET`），字級在 `insight_card.gd`。
- 前兆範圍（D-088）：新的範圍招用 `Undertaker._decal(mesh, pos, SHAPE_*, extent, arc_deg)`；長條的敵人端在模型 +Z、扇形朝 -Z。
- 過肩鏡頭的後續：D-085 之後 SpringArm 不撞角色；D-115 讓席菈與敵人靠近鏡頭時淡掉（諾恩本身不淡）。鏡頭參數在 `player.gd` 的 `SHOULDER_*`。
- 雪粒閃點在實機會動的鏡頭下會不會太閃，等 Jacky 回饋（`sparkle_energy`）。選單的「叮」（`ui_tick`，-15 dB）太吵或太小聲也等回饋；要不要讓暫停／標題選單的焦點移動也有聲音，一起決定（D-078）。
- 新的互動點照做：加進 `interact_prompts` 群組、實作 `interact_hint()`（D-065）。

## 2. 霜橋鎮第一眼（照概念圖）

- 第 14 輪：燈的高光 1.0、石面 0.46、水窪細波紋（D-058）。還可以：亮窗的發光再亮一點（只在 probe 裡看得出差別）、廣場 probe 拍攝點再低（`PROBE_EYE` 0.6）。截圖 `--at=plaza`、`--at=main`、`--at=south`，高畫質 `--quality=2` 也看一下。
- **鐘的金屬度**（D-050）：鐘在台地北端，不在任何 probe 盒子裡；要提高金屬度得在鐘樓加一個小 probe（只拍倒影層），注意反射圖集上限 8 張（`project.godot`）。
- 半木構的立柱不一定對齊房子邊緣，近看不順就在 `_house` 加真的角柱幾何（深色木條 box，進 StaticBatch）。
- 程序人偶小幅輪廓：席菈白**短**斗篷＋寬斷劍（刃上一點冷光）。送葬者第 24 輪做完（D-101）。不要大改（正式模型由 Jacky 做）。
- 標題畫面（D-061）鐘樓第 16 輪加了簷口、石塊層、窄窗；霧堤速度在實機看（截圖是靜態）。

## 3. 手把（M1.4 自動測試已齊）

- `test_gamepad_route` 涵蓋：梨販 → 敲九下、救援、灰巡者、送葬者戰、暫停選單、按鍵設定頁改鍵（第 14 輪）。手感只能等 Jacky 試玩。
- 共用 helper：`_walk_to`、`_tap`、`_tap_physics`（戰鬥輸入在物理幀讀 just_pressed）、`_trigger_left`、`_focus_with_dpad`。鎖定是**右搖桿按下**（R3），不是 RB。

## 4. 階段 2 準備（12/1 起，可以提前）

- 商店截圖完成（D-145）：清單 `scripts/store_shots.txt`（改了 `check.sh` 會檢查旗標）、Windows 實機 `store-shots.ps1`（CI 放進 zip）、雲端 `scripts/store-shots.sh <資料夾> [en|zh_TW] [檔名片段]`（1920×1080，一張約 1 分鐘）。Jacky 拍了放 `art-inbox/store-shots/` 再看。
- **成就完成（D-147）**：資料 `game/data/achievements.json`、`AchievementTracker`（邊緣觸發：`baseline()` 在 `GameSession._bind`、`evaluate()` 在 `advance()`＋Game 每 0.5 秒）、`AchievementToast`（Game 的子節點，layer 30）、`SteamBridge`。新成就：加一列 JSON＋`strings.csv` 的 `ACH_<…>_NAME`／`_DESC`＋`achievement_icons.py` 的 `MOTIFS` 一個圖案；`test_achievements::test_data_is_valid_and_translated` 的數量與 `HIDDEN` 要跟著改。計數類條件用 `GameSession.add_stat("stats.xxx")`（不推進任務）。截圖 `--achievement=<id>`。測試用的 session 要算成就就 `s.attach_achievements(AchievementTracker.new(AchievementTracker.load_defs(), ""))`。
- 之後：GodotSteam（GDExtension）要等 Jacky 有 App ID（FOR_JACKY 第 2 項已寫）；放進來後 `SteamBridge` 不用改。雲端存檔走 Steam Auto-Cloud，後台路徑寫在 `docs/steam/achievements.md` 最下面。成就候補（不倒下走完切片、第 1 章「攻略筆記被推翻 N 條」）等第 1 章做完再決定。

## 5. 第一部第 1 章（12/14 起，已提前開工）——**下一輪從這裡開始**

- 照 `docs/design/07-chapter1-door.md` 的段落順序，**先白盒＋對話＋任務＋流程測試，美術後補**（D-143：白天霜橋鎮重用切片關卡、攻略筆記是日記分頁、做不完時的保留順序）。新名詞照 `06-terminology.md`（D-142）。新章節的任務每個階段要有 `marker`（D-040）、主線流程測試補一段（`tests/flow/test_slice_playthrough.gd` 的寫法）。第 1 章的文字一律放 `i18n/ch1.csv`（已登記在 project.godot、verify_package）。
- **已完成（第 36 輪，D-148）**：攻略筆記邏輯層 `GuideNotes`（`data/guide/notes.json`、`GameState.guide`、條件 `{"guide": id, "is": "sure|unsure|wrong|confirmed|unwritten", "was_unsure": bool}`、效果 `{"guide_write": [...]}`、`GameSession.guide_changed`）、存檔 v2、日記裡的「攻略筆記」一段（`JournalView._add_guide_section`、截圖 `--guide-demo`）。推翻旗標：`ch1.stair_trap_sprung`、`ch1.met_kord`、`ch1.door_opened`、`ch1.saw_empty_furnace`、`ch2.usurper_crossed_out`、`ch2.read_wall_carvings`——關卡做到時照這些名字設。
- **已完成（第 37 輪，D-149／D-150）**：
  - 章節銜接：`slice_main` 的 `on_complete` 開 `ch1_main`＋效果 `{"chapter": "ch1"}`；`GameSession.MAIN_QUESTS`／`main_quest()`（HUD、目標指引跟著最後開始的主線）、`CHAPTER_CHAIN`＋`upgrade_chapters()`（舊存檔補開）；`Game.CHECKPOINT_LEVELS` 第 1 章三個檢查點 → `tavern`。**新章節照做**：主線加進 `MAIN_QUESTS`、前一章的 `on_complete` 加 `start_quest`＋`chapter`、`CHAPTER_CHAIN` 加一列、檢查點對到關卡。
  - `ChapterCard.play(關卡, number_key, title_key, 結束時呼叫)`（`src/ui/chapter_card.gd`）：掛在關卡底下；之後每章開頭照用（第 2 章 `CH2_CARD_*`）。
  - 酒館白盒 `scenes/levels/tavern.gd`：`STAGE_TALKS`（階段 → 說話點節點名＋對話 id）、`talk_spot()`、`is_night()`、`open_guide_marking()`；開發旗標 `--level=tavern`（照正式流程走完切片）＋`--ch1-stage=dinner|draw_map|to_cellar`＋`--guide-mark`。房間 x -7～7、z -5～5，門在南牆正中（`DOOR_POS`），出門在 `to_cellar` 階段顯示「待續」（`CH1_TO_BE_CONTINUED`）。
  - 對話 `ch1_noon`／`ch1_dinner`（灑湯 → `ch1.sheila_soup_helped`）／`ch1_map`（開頭 `guide_write` 6 條、最後設 `ch1.guide_marking`）／`ch1_map_end`（依標了幾條換最後一句、設 `ch1.map_drawn`）。
  - 標記畫面 `GuideMarkView`（`scenes/ui/guide_mark_view.gd`）：`open_on(父節點, state, notes)`、`rows[id]`、`toggle`／`set_unsure`、`done_button`、`confirm()`、訊號 `confirmed(unsure_ids)`；打開時暫停。
  - 主線流程測試 `_chapter1()`（`test_slice_playthrough.gd`）：章節卡 → 酒館 → 中午 → 重來 → 晚餐 → 畫地圖＋標記 → 重來。新段落在這裡往後接。
- **下一步（依序）**：
  1. **段落 4：白天的霜橋鎮＋艾妲的油燈**（D-143：重用切片關卡）。`to_cellar` 階段走出酒館門 → 換到 `frostbridge`（`Game.CHECKPOINT_LEVELS` 加一個第 1 章的檢查點，例如 `ch1_day_town` → `frostbridge`；酒館的門口觸發改成設 `ch1.left_tavern` 再換關卡）；`FrostbridgeLook` 加 `day` 變體（白天陰天的冷光、沒有月光與路燈、雪地反光），`frostbridge.gd` 依 `GameState.chapter == "ch1"` 切換（北街照舊是陷落後的樣子、死者名單牆、沒有送葬者／車隊／灰巡者）；艾妲在地窖門口交油燈的對話（`ch1_ada_lamp`，`text_if arch_father_last_talk` 那句「你連你爸都忘了，別把我忘了」），油燈取代提燈（`PlayerController` 的提燈換一個圓肚油燈的外形、光更暖更小）。**霜橋鎮很多程式用 `stage_of(MAIN_QUEST)` 判斷切片階段，切片完成後那些判斷都不成立——先 grep `MAIN_QUEST` 確認白天版本不會生出切片的敵人或觸發**。
  2. **段落 5：一百七十二階**（新關卡 `stairs`，線性）：螺旋往下的石階（霧＋油燈範圍只看得到前後十幾級）、中間平台的髒水桶陷阱、新互動「丟石頭試探」（設 `ch1.stair_trap_sprung` → 攻略筆記第 1 條被推翻；標了我不確定的諾恩說「果然」，沒標的席菈看他一眼——用 `{"guide": "stair_arrows", "is": "wrong", "was_unsure": true}` 的 `text_if`）、往下聽到小孩笑聲。
  3. 段落 6～9（白晝城入口、柯德、上層街區、壽命石碑、柯德家晚餐、兔子）照 07 的表。
  4. 酒館美術（階段 2 後段）：現在是 CSG 白盒＋程序人偶；彌夏抱的鐘是小木箱。
- 第 1 章的白盒截圖：`scripts/screenshot.sh out.png 30 --level=tavern [--ch1-stage=dinner] [--guide-mark] [--locale=en]`（一張約 30 秒）。酒館還沒有 `--pos`／`--face` 旗標，要拍別的角度先加。

## 6. 角色模型（等 Jacky 交件）

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
- 主線流程測試 `tests/flow/test_slice_playthrough.gd`：真的換場景（`Game.go_to_level`）＋每個檢查點 `Game.retry()`。新增段落時在這裡補一段；場景層面的斷言寫在 `[檢查點]` 前綴的訊息裡。
- 對話依狀態換台詞用 `text_if`（D-037）；`DialogueRunner.current_text()`。
- 測試輸出裡兩個 ERROR 是故意的：`QuestRunner: 推進超過 256 步`（test_cycle_guard）、`CutsceneRunner: 過場 no_such_cutscene 不存在`（test_cutscene）。`SCRIPT ERROR` 則一律算失敗（check.sh 會擋）。測試結尾若剛播過音效，多等一個 `process_frame` 再結束。
- **測試裡別讓諾恩真的倒下**：`Game` 的倒下狀態會漏到後面的測試。只測某個招式時把敵人 `set_physics_process(false)`。測試裡生成敵人：**先設 `position` 再 `add_child`**。
- 連到 autoload 訊號（`Game.dialogue_ended` 等）用**方法**不要用 lambda（物件釋放時方法連線會自動斷開）。
- Godot 的骨骼名不能有冒號：Mixamo 的 `mixamorig:LeftHand` 匯入後是 `mixamorig_LeftHand`。
- 霜橋鎮的劇情觸發（席菈、艾妲）是在 `frostbridge.gd` 的 `_physics_process` 依任務階段輪詢距離；其他用 `StoryLevel._trigger` 的 Area3D（梨販、鐘樓、南街口、石拱回憶、地窖）。
- `StaticBatch.build()` 之後不能再加東西（會被丟掉）：所有要合併的幾何都要在 `_batch.build(self, "Town")` 之前加。房子裝飾用位置雜湊決定，**不要多呼叫 `_rng`**（會改掉整個鎮的配置）。
- **自己畫字的 UI 元件一律用子節點 Label**，不要在 `_draw()` 裡 `draw_string`（遊戲裡這套子集字型會畫成缺字方塊，D-060；可能其實是 D-071 的 Theme 沒套到造成的，沒驗證前照舊用 Label）；Label 印的是鍵名而不是翻譯 key 時標 `set_meta("glyph", true)`。
- **HUD 上含按鍵的提示一律用 `GlyphLine`**（D-063）：翻譯字串保留 `{key}`，其他佔位符先 `format` 掉，再 `line.set_line(fmt, action, App.last_device)`；測試讀 `plain_text()`（文字版「[Y]」）、`uses_glyph()`、`parts()`。放在錨點或容器裡時設 `fit_content = false`。
- 重現提示在 HUD（`RestorePrompt`，D-059）：新的可重現物件只要是 `NineBreathSite`，提示會自動出現；不要再在 3D 場景裡浮文字。
- 新音效：加進 `scripts/gen_sfx.py` 的 `main()` 與 `src/core/sfx.gd` 的 `NAMES`（`test_sfx` 與打包驗證都讀 NAMES）。
- 打包驗證（D-044）：新增遊戲一定要有的資源時，把路徑加進 `scripts/verify_package.py` 的 `REQUIRED`。
- CI 有 Node 20 deprecation 警告（actions/checkout@v4 等），目前被強制用 Node 24 跑，不影響結果。
