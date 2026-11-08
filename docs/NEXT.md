# 下一輪待辦（依優先順序）

> 每輪從最上面拿 1～3 項。開工前先跑 `scripts/check.sh` 確認全綠（約 50 秒；第一次會下載 Godot 與字型來源、產生音效、檢查角色模型）。截圖前先 `apt-get update && apt-get install -y xvfb mesa-vulkan-drivers`（**一定要先 update**，不然裝不到 mesa-vulkan-drivers，截圖退回 OpenGL、沒有體積霧）。每日排程見 `docs/design/05-vertical-slice-plan.md`（M1.1、M1.2 完成；M1.3 段落全部可走、外牆／掛燈／目標指引、送葬者戰演出完成，剩爬坡與倒影；M1.4 流程測試、打包驗證、清單對照完成，剩手把整段測試與 Jacky 實機項目）。

## 0. 開工先確認

- 上一輪（第 10 輪）最後一次程式 push 的 CI 結果寫在 PROGRESS 最上面；照常看最近的 CI（GitHub MCP `actions_list`）。
- **程式 commit 與 `[skip ci]` 文件 commit 要分開 push**（同一次 push 的 HEAD 帶 `[skip ci]` 會讓整個 push 不跑 CI）。工作區有未提交的文件時，push 程式前先 `git stash`、push 完再 `git stash pop`。
- **玩家看得到的字一律白話**：新名詞先寫進 `docs/design/06-terminology.md` 再用；`test_i18n::test_no_obscure_terms` 會擋舊詞（九息、弔鐘、薪火、巡界、下城、爹…）。程式識別碼照舊（`nine_breath`、`kindling`）。
- Jacky 的概念圖在 `art-inbox/concepts/`（LFS）：`git lfs pull --include="art-inbox/concepts/frostbridge_winter/**"` 這樣指定資料夾下載（推 LFS 還是不行）。看圖前先用 PIL 縮到 900 寬。
- 霜橋鎮截圖旗標（`--level=frostbridge`）：`--at=plaza|main|north|south|cross`、`--rescue`、`--convoy`（＋`--phase2`、`--throw=arch|kindling --throw-t=秒`）、`--arch=preview|restored|spent`、`--open=journal`、`--dialogue=slice_sheila_meet --dialogue-steps=5`、`--cutscene=slice_bell_nine --cutscene-steps=3`、`--quality=0..2`、`--locale=zh_TW`。沙盒（`--level=sandbox`）還有 `--enemies`、`--boss`、`--insight`、`--lock`。軟體渲染很慢：一般 25～40 幀。
- 改了 `i18n/*.csv` 之後：`scripts/check.sh` 會重跑字型子集與 import。改 CSV 時**只改那幾行**（Python 讀一行插一行／改一行，保留原本的引號；整檔用 csv.writer 重寫會把 `" (confirmed)"` 前面的空白弄丟）。英文裡有逗號要整格加雙引號。

## 1. 霜橋鎮第一眼（照概念圖）

- **街道往鐘樓爬坡**：概念圖主街往遠處鐘樓上坡、有幾級石階。最便宜：北街＋鐘樓那段地面整體抬高 0.6～1.2 m、主街盡頭加 3～4 級台階（碰撞要跟著；北街陷落、救援位置 `RESCUE_SPOTS`、席菈等待點的 y 要對；`test_frostbridge`、`test_slice_playthrough` 會擋）。先畫在 05 再做。
- **水窪倒影**：中畫質沒有 SSR，水窪只有燈的高光。試 1～2 個 ReflectionProbe（廣場、南街，UPDATE_ONCE），截圖比較；benchmark 量不到就寫進 FOR_JACKY 請他比。
- 鐘室的鐘偏暗（看 `--cutscene=slice_bell_nine --cutscene-steps=3`）；半木構的立柱不一定對齊房子邊緣，近看不順就在 `_house` 加真的角柱幾何（深色木條 box，進 StaticBatch）。
- 車隊提燈在 `--convoy` 開場離鏡頭很近，像一個白色圓盤：鏡頭 SpringArm 太近時把近處小物件淡掉，或車隊出生點往前挪 2 m。
- 程序人偶小幅輪廓：席菈白**短**斗篷＋寬斷劍（刃上一點冷光）；送葬者鐵架加邊緣光。不要大改（正式模型由 Jacky 做）。

## 2. M1.4 收尾（清單見 05「M1.4 必須驗證對照」）

- 補測試：手把整段（`Input.parse_input_event` 模擬搖桿＋A／X，至少走完梨販 → 敲鐘）。（暫停中重現倒數與車隊不推進：第 10 輪 `test_nine_breath_site::test_pause_freezes_restoration_and_caravan` 完成）
- 打包版 smoke test：CI 匯出後用 Linux 執行檔跑一次 `--screenshot`（xvfb），確認匯出版能開到霜橋鎮（不只是編輯器）。
- 寫試玩指南給 Jacky（20～30 分鐘路線、兩條路線各怎麼走、哪些感想最有用），放 `docs/playtest.md`，FOR_JACKY 第 1 項改成連過去。

## 3. 送葬者戰再打磨（第 10 輪完成鐵架飛出、燃燒劍火光、躺姿）

- 席菈斬鐵架時目前只轉身出劍：離車隊遠時先一步衝到車隊前（`_dash_to` 類似的短位移），斬完留在那裡守著。
- 鐵架撞上石拱那一刻石拱的 `glow_energy` 閃一下（`NineBreathSite` 加 `flash()`），碎片落地有小碰撞聲。
- 送葬者被結尾斬倒：現在是 `apply_damage` 直接死，補倒地演出（跪下 → 倒向前、鐵鏈落地聲），再接橫幅。
- 截圖：`--convoy --throw=arch|kindling --throw-t=0.3／0.7`；石拱路線的鏡頭離石拱遠，碎片看起來小，之後可在 `--throw` 時把諾恩放到石拱旁。

## 4. 角色模型（等 Jacky 交件）

- 接入點已完成（D-041、04-architecture「角色模型接入點」）。Jacky 放 `art-inbox/characters/<id>/<id>.glb` 後：跑 `scripts/check.sh`（會先 `git lfs pull --include="art-inbox/characters/**"` 才拿得到檔案），看 `[characters]` 那幾行有沒有通過；通過就截圖對照 `--at=plaza`、`--rescue`、`--convoy`，檢查提燈／鐘錘掛點、走跑步頻、面向（-Z）。席菈的燃燒劍掛在 `hand("R")`，換模型後要確認火光位置。
- 之後：敵人（Undertaker、Ashwalker）走同一個入口；弱點位置（灰巡者左膝、送葬者鐵架關節）用骨骼名或 Marker 對齊；動作多了換 AnimationTree。傷者／受困者的躺姿只在程序人偶上（`Puppet.lying`），模型版要另外的躺姿動畫。

## 備註

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
