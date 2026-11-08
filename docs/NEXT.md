# 下一輪待辦（依優先順序）

> 每輪從最上面拿 1～3 項。開工前先跑 `scripts/check.sh` 確認全綠（約 50 秒；第一次會下載 Godot 與字型來源、產生音效、檢查角色模型）。截圖前先 `apt-get update && apt-get install -y xvfb mesa-vulkan-drivers`（**一定要先 update**，不然裝不到 mesa-vulkan-drivers，截圖退回 OpenGL、沒有體積霧）。每日排程見 `docs/design/05-vertical-slice-plan.md`（M1.1、M1.2 完成；M1.3 段落全部可走、外牆／掛燈／目標指引／爬坡、送葬者戰演出完成，剩倒影；M1.4 流程測試、手把整段、打包驗證、匯出版 smoke test、清單對照、試玩指南完成，只剩 Jacky 實機項目）。

## 0. 開工先確認

- 上一輪（第 11 輪）最後一次程式 push 的 CI 結果寫在 PROGRESS 最上面；照常看最近的 CI（GitHub MCP `actions_list`）。CI 多了「匯出版 smoke test」（D-049）：紅了先看 artifact 裡的 `smoke-export.log`。
- 本機跑匯出版 smoke test：`scripts/get-godot.sh --templates`（第一次約 1 分鐘）→ `$(scripts/get-godot.sh) --headless --path game --export-release "Linux" ../build/linux/YumingCity.x86_64` → `scripts/smoke_export.sh`。
- 只跑部分測試：`TEST_FILTER=gamepad $(scripts/get-godot.sh) --headless --path game -s res://tests/run_tests.gd`（檔名含那段字）。改了 class_name 或新檔案要先跑一次 `--import`。
- **程式 commit 與 `[skip ci]` 文件 commit 要分開 push**（同一次 push 的 HEAD 帶 `[skip ci]` 會讓整個 push 不跑 CI）。工作區有未提交的文件時，push 程式前先 `git stash`、push 完再 `git stash pop`。
- **玩家看得到的字一律白話**：新名詞先寫進 `docs/design/06-terminology.md` 再用；`test_i18n::test_no_obscure_terms` 會擋舊詞（九息、弔鐘、薪火、巡界、下城、爹…）。程式識別碼照舊（`nine_breath`、`kindling`）。
- Jacky 的概念圖在 `art-inbox/concepts/`（LFS）：`git lfs pull --include="art-inbox/concepts/frostbridge_winter/**"` 這樣指定資料夾下載（推 LFS 還是不行）。看圖前先用 PIL 縮到 900 寬。
- 霜橋鎮截圖旗標（`--level=frostbridge`）：`--at=plaza|main|steps|north|south|cross`、`--rescue`、`--convoy`（＋`--phase2`、`--throw=arch|kindling --throw-t=秒`）、`--arch=preview|restored|spent`、`--open=journal`、`--dialogue=slice_sheila_meet --dialogue-steps=5`、`--cutscene=slice_bell_nine --cutscene-steps=3`、`--quality=0..2`、`--locale=zh_TW`。沙盒（`--level=sandbox`）還有 `--enemies`、`--boss`、`--insight`、`--lock`。軟體渲染很慢：一般 25～40 幀。
- 改了 `i18n/*.csv` 之後：`scripts/check.sh` 會重跑字型子集與 import。改 CSV 時**只改那幾行**（Python 讀一行插一行／改一行，保留原本的引號；整檔用 csv.writer 重寫會把 `" (confirmed)"` 前面的空白弄丟）。英文裡有逗號要整格加雙引號。

## 1. 霜橋鎮第一眼（照概念圖）

- **水窪倒影**：中畫質沒有 SSR，水窪只有燈的高光。試 1～2 個 ReflectionProbe（廣場、南街，UPDATE_ONCE），截圖比較（`--at=plaza`、`--at=south`）；benchmark 量不到就寫進 FOR_JACKY 請他比。有了 probe 之後鐘可以再提高金屬度（D-050）。
- **石階打磨**（第 11 輪做了，D-048）：台階用石牆 shader，在霧裡偏灰白、偏平（看 `--at=steps`）。可以把台階顏色壓暗一點（另一個 `stone_wall` 參數會多一個 draw call，`test_layout_nodes_and_batching` 上限 24）、兩側加矮石欄或石階邊的燈。
- 半木構的立柱不一定對齊房子邊緣，近看不順就在 `_house` 加真的角柱幾何（深色木條 box，進 StaticBatch）。
- 程序人偶小幅輪廓：席菈白**短**斗篷＋寬斷劍（刃上一點冷光）；送葬者鐵架加邊緣光。不要大改（正式模型由 Jacky 做）。

## 2. 手把與 M1.4 延伸

- `test_gamepad_route` 目前走到敲完九下＋暫停選單（Start → 設定 → B 返回）：延伸到救援（按住 A 搬瓦礫）、灰巡者（X 揮擊、LT 看穿、十字鍵上 叫席菈打弱點）、按鍵設定頁用手把改鍵。每段一個測試函式比較好維護（共用 `_walk_to`、`_tap`）。

## 3. 送葬者戰再打磨（第 10 輪完成鐵架飛出、燃燒劍火光、躺姿）

- 席菈斬鐵架時目前只轉身出劍：離車隊遠時先一步衝到車隊前（`_dash_to` 類似的短位移），斬完留在那裡守著。
- 鐵架撞上石拱那一刻石拱的 `glow_energy` 閃一下（`NineBreathSite` 加 `flash()`），碎片落地有小碰撞聲。
- 送葬者被結尾斬倒：現在是 `apply_damage` 直接死，補倒地演出（跪下 → 倒向前、鐵鏈落地聲），再接橫幅。
- 截圖：`--convoy --throw=arch|kindling --throw-t=0.3／0.7`；石拱路線的鏡頭離石拱遠，碎片看起來小，之後可在 `--throw` 時把諾恩放到石拱旁。

## 4. 角色模型（等 Jacky 交件）

- 接入點已完成（D-041、04-architecture「角色模型接入點」）。Jacky 放 `art-inbox/characters/<id>/<id>.glb` 後：跑 `scripts/check.sh`（會先 `git lfs pull --include="art-inbox/characters/**"` 才拿得到檔案），看 `[characters]` 那幾行有沒有通過；通過就截圖對照 `--at=plaza`、`--rescue`、`--convoy`，檢查提燈／鐘錘掛點、走跑步頻、面向（-Z）。席菈的燃燒劍掛在 `hand("R")`，換模型後要確認火光位置。
- 之後：敵人（Undertaker、Ashwalker）走同一個入口；弱點位置（灰巡者左膝、送葬者鐵架關節）用骨骼名或 Marker 對齊；動作多了換 AnimationTree。傷者／受困者的躺姿只在程序人偶上（`Puppet.lying`），模型版要另外的躺姿動畫。

## 備註

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
