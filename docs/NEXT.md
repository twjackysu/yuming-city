# 下一輪待辦（依優先順序）

> 每輪從最上面拿 1～3 項。開工前先跑 `scripts/check.sh` 確認全綠（約 40 秒；第一次會下載 Godot 與字型來源、產生音效）。截圖前先 `apt-get update && apt-get install -y xvfb mesa-vulkan-drivers`（**一定要先 update**，不然裝不到 mesa-vulkan-drivers，截圖退回 OpenGL、沒有體積霧）。每日排程見 `docs/design/05-vertical-slice-plan.md`（M1.1、M1.2 完成；M1.3 主線、段落 1、死者名單完成，剩演出與畫面打磨；M1.4 場景層面流程測試已完成）。

## 0. 開工先確認

- 上一輪（第 8 輪）最後一次程式 push 的 CI 結果寫在 PROGRESS 最上面；照常看最近的 CI（GitHub MCP `actions_list`）。
- **程式 commit 與 `[skip ci]` 文件 commit 要分開 push**（同一次 push 的 HEAD 帶 `[skip ci]` 會讓整個 push 不跑 CI）。
- **玩家看得到的字一律白話**：新名詞先寫進 `docs/design/06-terminology.md` 再用；`test_i18n::test_no_obscure_terms` 會擋舊詞（九息、弔鐘、薪火、巡界、下城、爹…）。程式識別碼照舊（`nine_breath`、`kindling`）。
- Jacky 的概念圖在 `art-inbox/concepts/`（LFS）：`git lfs pull --include="art-inbox/concepts/**"` 可以下載（推 LFS 還是不行）。看圖前先用 PIL 縮到 900 寬。
- 霜橋鎮截圖旗標（`--level=frostbridge`）：`--at=plaza|main|north|south|cross`、`--rescue`、`--convoy`（＋`--phase2`）、`--arch=preview|restored|spent`、`--open=journal`、`--dialogue=slice_sheila_meet --dialogue-steps=5`、`--cutscene=slice_bell_nine --cutscene-steps=3`、`--quality=0..2`。沙盒（`--level=sandbox`）還有 `--enemies`、`--boss`、`--insight`、`--lock`。軟體渲染很慢：一般 25～40 幀。
- 改了 `i18n/*.csv` 之後：`scripts/check.sh` 會重跑字型子集與 import。改 CSV 時**只改那幾行**（Python 讀一行改一行，保留原本的引號；整檔用 csv.writer 重寫會把 `" (confirmed)"` 前面的空白弄丟）。

## 1. 霜橋鎮照概念圖打磨（第一眼質感）

- **房子外牆**：照概念圖做半木構＋石牆。做法同 `wet_cobble.gdshader`：新 shader 用世界座標＋法線選投影面（牆面用 XY 或 ZY），下半石塊、上半灰泥＋深色木框（橫梁、斜撐），邊緣與屋簷下加一點雪；接到 `FrostbridgeLook.WALL`／`WALL_WARM` 的材質（`_house` 裡）。截圖前後對照 `--at=plaza`、`--at=main`。
- **水窪倒影**：中畫質沒有 SSR，水窪只有燈的高光。試 1～2 個 ReflectionProbe（廣場、南街，UPDATE_ONCE）或在 shader 裡用 `SCREEN_TEXTURE` 以外的便宜假倒影；量 benchmark 的差。
- **屋簷下的油燈**：概念圖每幾戶門口一盞掛燈（暖光＋發光燈罩），取代部分窗燈的 OmniLight（燈數上限 40，見 test_frostbridge）。
- **提示文字可讀性**：重現提示（Label3D）疊在石拱預覽上很難讀 → 加 outline 或半透明底（看穿文字同樣）。
- 北街陷落後的受困者在暗處不明顯（提燈亮一點）；`RescueSite` 搬瓦礫加音效；鐘室的鐘偏暗（確認 `bell.png`）。

## 2. 目標指引

- 小鎮比沙盒大，玩家可能不知道要去哪。先在 `02-gameplay.md` 寫一條規則（例如 HUD 目標旁加方向小箭頭與距離，或目標地點一道淡暖光柱，可在設定關掉），再做。各階段的目標位置放進任務資料（`slice_main.json` 的 stage 加 `marker`）。

## 3. 角色模型接入點（Jacky 正在做正式模型）

- Jacky 那邊在用 Tripo／Blender 做諾恩的正式模型（`docs/ART_PRODUCTION.md`、品質標準 `docs/ART_QUALITY_BAR.md`：程序人偶不算正式交付）。loop **不要再花大量時間雕程序人偶**，改做「模型一到就能換上」的接入點：
  - `Puppet` 旁加一個載入器：`art-inbox/characters/<id>/<id>.glb` 存在且通過檢查就用模型，否則用程序人偶；動畫名稱照 `art-inbox/README.md` 的動作表對應到現有狀態（idle、walk、run、dodge_roll、light_attack_01、hit_front、death、bell_pull、carry_walk…），缺的動作退回程式動畫。
  - 掛點（武器、提燈、夾板）、弱點位置（灰巡者左膝、送葬者鐵架關節）用骨骼名稱或 Marker 對齊，碰撞與 AI 不跟模型走。
  - 寫成 `04-architecture.md` 的一節；用 `scripts/check_character_glb.py` 當收件檢查（Jacky 寫的，純標準函式庫）。
- 程序人偶只做小幅輪廓調整：席菈白**短**斗篷＋寬斷劍（刃上一點冷光）、諾恩圍巾＋右臂夾板（`slice.sheila_talked` 之後）；送葬者鐵架加邊緣光。

## 4. 送葬者戰打磨（之前留下的）

- 鐵架真的飛出去（拋物線）、撞到石拱碎裂／被燃燒劍斬成兩截；席菈劍上的火光（OmniLight＋粒子）。擲完背上的鐵架要消失。
- 席菈手傷 `sheila.hand_injury`（燃燒劍後 +1，影響之後的對話）。
- 席菈拒絕會害死人的指令（車隊旁叫她「閃開」→ 拒絕並說理由）。
- 車隊傷者、受困者換成程序人偶躺姿（`Puppet` 加 `lying`）。

## 備註

- 主線流程測試 `tests/flow/test_slice_playthrough.gd`：真的換場景（`Game.go_to_level`）＋每個檢查點 `Game.retry()`。新增段落時在這裡補一段；場景層面的斷言寫在 `[檢查點]` 前綴的訊息裡。
- 對話依狀態換台詞用 `text_if`（D-037）；`DialogueRunner.current_text()`。
- 測試輸出裡兩個 ERROR 是故意的：`QuestRunner: 推進超過 256 步`（test_cycle_guard）、`CutsceneRunner: 過場 no_such_cutscene 不存在`（test_cutscene）。`SCRIPT ERROR` 則一律算失敗（check.sh 會擋）。測試結尾若剛播過音效，多等一個 `process_frame` 再結束。
- **測試裡別讓諾恩真的倒下**：`Game` 的倒下狀態會漏到後面的測試。只測某個招式時把敵人 `set_physics_process(false)`。測試裡生成敵人：**先設 `position` 再 `add_child`**。
- 霜橋鎮的劇情觸發（席菈、艾妲）是在 `frostbridge.gd` 的 `_physics_process` 依任務階段輪詢距離；其他用 `StoryLevel._trigger` 的 Area3D（梨販、鐘樓、南街口、石拱回憶、地窖）。
- `StaticBatch.build()` 之後不能再加東西（會被丟掉）：所有要合併的幾何都要在 `_batch.build(self, "Town")` 之前加。
- 外觀待打磨（階段 2）：九息石拱重現時偏亮、預覽輪廓是平的半透明塊；標題畫面的霧層幾乎看不出來；鐘的造型、按鍵設定頁的手把圖示（目前是文字 A／B／LB）。
- CI 有 Node 20 deprecation 警告（actions/checkout@v4 等），目前被強制用 Node 24 跑，不影響結果。
