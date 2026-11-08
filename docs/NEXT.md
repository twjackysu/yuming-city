# 下一輪待辦（依優先順序）

> 每輪從最上面拿 1～3 項。開工前先跑 `scripts/check.sh` 確認全綠（約 50 秒；第一次會下載 Godot 與字型來源、產生音效、檢查角色模型）。截圖前先 `apt-get update && apt-get install -y xvfb mesa-vulkan-drivers`（**一定要先 update**，不然裝不到 mesa-vulkan-drivers，截圖退回 OpenGL、沒有體積霧）。每日排程見 `docs/design/05-vertical-slice-plan.md`（M1.1、M1.2 完成；M1.3 完成（含倒影、送葬者倒地）；M1.4 只剩 Jacky 實機項目；接下來是送葬者戰收尾與階段 2 的打磨準備）。

## 0. 開工先確認

- 上一輪（第 12 輪）最後一次程式 push 的 CI 結果寫在 PROGRESS 最上面；照常看最近的 CI（GitHub MCP `actions_list`）。CI 多了「匯出版 smoke test」（D-049）：紅了先看 artifact 裡的 `smoke-export.log`。
- 本機跑匯出版 smoke test：`scripts/get-godot.sh --templates`（第一次約 1 分鐘）→ `$(scripts/get-godot.sh) --headless --path game --export-release "Linux" ../build/linux/YumingCity.x86_64` → `scripts/smoke_export.sh`。
- 只跑部分測試：`TEST_FILTER=gamepad $(scripts/get-godot.sh) --headless --path game -s res://tests/run_tests.gd`（檔名含那段字）。改了 class_name 或新檔案要先跑一次 `--import`。
- **程式 commit 與 `[skip ci]` 文件 commit 要分開 push**（同一次 push 的 HEAD 帶 `[skip ci]` 會讓整個 push 不跑 CI）。工作區有未提交的文件時，push 程式前先 `git stash`、push 完再 `git stash pop`。
- **玩家看得到的字一律白話**：新名詞先寫進 `docs/design/06-terminology.md` 再用；`test_i18n::test_no_obscure_terms` 會擋舊詞（九息、弔鐘、薪火、巡界、下城、爹…）。程式識別碼照舊（`nine_breath`、`kindling`）。
- Jacky 的概念圖在 `art-inbox/concepts/`（LFS）：`git lfs pull --include="art-inbox/concepts/frostbridge_winter/**"` 這樣指定資料夾下載（推 LFS 還是不行）。看圖前先用 PIL 縮到 900 寬。
- 霜橋鎮截圖旗標（`--level=frostbridge`）：`--at=plaza|main|steps|north|south|cross`、`--rescue`、`--convoy`（＋`--phase2`、`--throw=arch|kindling --throw-t=秒`、`--felled` 送葬者倒地、截圖時藏起諾恩）、`--arch=preview|restored|spent`、`--open=journal`、`--dialogue=slice_sheila_meet --dialogue-steps=5`、`--cutscene=slice_bell_nine --cutscene-steps=3`、`--quality=0..2`、`--locale=zh_TW`。沙盒（`--level=sandbox`）還有 `--enemies`、`--boss`、`--insight`、`--lock`。軟體渲染很慢：一般 25～40 幀。
- 改了 `i18n/*.csv` 之後：`scripts/check.sh` 會重跑字型子集與 import。改 CSV 時**只改那幾行**（Python 讀一行插一行／改一行，保留原本的引號；整檔用 csv.writer 重寫會把 `" (confirmed)"` 前面的空白弄丟）。英文裡有逗號要整格加雙引號。

## 1. 送葬者戰收尾的份量（第 12 輪做了倒地、閃光、衝刺）

- 倒地的送葬者是暗色大衣，夜裡不顯眼（`--convoy --felled`）：倒地那一刻燃燒劍的火光多留 1～2 秒、或給大衣加一點邊緣光（`rim`）讓輪廓出來。
- 斬完鐵架後席菈「留在車隊旁守著」：現在衝到車隊前斬完就回到一般跟隨。可以在 `ConvoyEncounter` 斬完後設 `ally.guard_point = guard_spot` 並把 `brain.mode` 切成守護幾秒（看 `CompanionBrain` 的 guard 怎麼進出，別經過 `command()` 的冷卻與台詞）。
- 灰巡者（一般敵人）死亡仍是「往後倒＋壓扁」（`EnemyActor._on_died`，繞 X 軸 +80° 其實是往後倒）：可照送葬者的做法改成往前撲倒，或保留往後倒但不要壓扁。

## 2. 霜橋鎮第一眼（照概念圖）

- **倒影再強一點**（D-051）：目前是含蓄的暖色模糊亮塊。可試：亮窗的發光再亮一點（只在 probe 裡看得出差別）、廣場 probe 拍攝點再低一點（`PROBE_EYE` 0.6）、或在水窪 shader 裡沿視線方向把反射 UV 拉長（概念圖的長條燈影）。截圖 `--at=plaza`、`--at=south` 對照；高畫質（`--quality=2`）有 SSR 疊加也看一下。
- **鐘的金屬度**（D-050）：鐘在台地北端，不在任何 probe 盒子裡；要提高金屬度得在鐘樓加一個小 probe（只拍倒影層），注意反射圖集上限 8 張（`project.godot`）。
- 半木構的立柱不一定對齊房子邊緣，近看不順就在 `_house` 加真的角柱幾何（深色木條 box，進 StaticBatch）。
- 程序人偶小幅輪廓：席菈白**短**斗篷＋寬斷劍（刃上一點冷光）；送葬者鐵架加邊緣光。不要大改（正式模型由 Jacky 做）。
- 石階兩側可加矮石欄或石階邊的燈（`--at=steps`）。

## 3. 手把與 M1.4 延伸

- `test_gamepad_route` 已有：梨販 → 敲九下、救援三人、灰巡者（LT／X／十字鍵上）、暫停選單。還沒涵蓋：送葬者戰（RB 鎖定、B 閃避、被抓時連按 B 掙脫、按住 Y 重現石拱）、按鍵設定頁用手把改鍵。每段一個測試函式（共用 `_walk_to`、`_tap`、`_trigger_left`）；敵人不出手時用 `set_physics_process(false)`，席菈會把不動的敵人先打倒，需要時也先停住她。

## 4. 階段 2 準備（12/1 起，可以提前）

- 「第一眼就有質感」盤點：照 `docs/ART_QUALITY_BAR.md` 逐項截圖（標題畫面霧層幾乎看不出來、按鍵設定頁的手把圖示是文字、重現提示文字壓到石拱輪廓），排出 12/1–12/8 的打磨順序寫進 PLAN。
- Steam 準備：`docs/steam/` 商店文案中英版草稿與素材規格（膠囊圖尺寸、截圖數量）先寫，不用等 Jacky 的帳號。

## 5. 角色模型（等 Jacky 交件）

- 接入點已完成（D-041、04-architecture「角色模型接入點」）。Jacky 放 `art-inbox/characters/<id>/<id>.glb` 後：跑 `scripts/check.sh`（會先 `git lfs pull --include="art-inbox/characters/**"` 才拿得到檔案），看 `[characters]` 那幾行有沒有通過；通過就截圖對照 `--at=plaza`、`--rescue`、`--convoy`，檢查提燈／鐘錘掛點、走跑步頻、面向（-Z）。席菈的燃燒劍掛在 `hand("R")`，換模型後要確認火光位置。
- 之後：敵人（Undertaker、Ashwalker）走同一個入口；弱點位置（灰巡者左膝、送葬者鐵架關節）用骨骼名或 Marker 對齊；動作多了換 AnimationTree。傷者／受困者的躺姿只在程序人偶上（`Puppet.lying`），模型版要另外的躺姿動畫；送葬者倒地目前是轉整個 `_body`，模型版要倒地動畫。

## 備註

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
- 外觀待打磨（階段 2）：標題畫面的霧層幾乎看不出來；按鍵設定頁的手把圖示（目前是文字 A／B／LB）；重現提示文字（Label3D）在畫面中央壓到石拱輪廓。
- 新音效：加進 `scripts/gen_sfx.py` 的 `main()` 與 `src/core/sfx.gd` 的 `NAMES`（`test_sfx` 與打包驗證都讀 NAMES）。
- 打包驗證（D-044）：新增遊戲一定要有的資源時，把路徑加進 `scripts/verify_package.py` 的 `REQUIRED`。
- CI 有 Node 20 deprecation 警告（actions/checkout@v4 等），目前被強制用 Node 24 跑，不影響結果。
