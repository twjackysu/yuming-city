# 下一輪待辦（依優先順序）

> 每輪從最上面拿 1～3 項。開工前先跑 `scripts/check.sh` 確認全綠（約 40 秒；第一次會下載 Godot 與字型來源、產生音效）。截圖前先 `apt-get update && apt-get install -y xvfb mesa-vulkan-drivers`（沒有 update 會找不到 mesa-vulkan-drivers，截圖退回 OpenGL、沒有體積霧）。每日排程見 `docs/design/05-vertical-slice-plan.md`（M1.1、M1.2 完成；M1.3 主線各段落 11/8 已能在霜橋鎮走完，剩段落 1 細節、死者名單、演出打磨）。

## 0. 開工先確認

- 上一輪（第 7 輪）最後一次程式 push 的 CI 結果寫在 PROGRESS 最上面；照常看最近的 CI（GitHub MCP `actions_list`）。
- **程式 commit 與 `[skip ci]` 文件 commit 要分開 push**（同一次 push 的 HEAD 帶 `[skip ci]` 會讓整個 push 不跑 CI）。
- 霜橋鎮截圖旗標（`--level=frostbridge`）：`--at=plaza|main|north|south|cross`、`--rescue`（跳到北街陷落後的救援）、`--convoy`（＋`--phase2`）、`--arch=preview|restored|spent`、`--open=journal`（可配 `--arch=spent`）、`--dialogue=slice_sheila_meet --dialogue-steps=5`、`--cutscene=slice_bell_nine --cutscene-steps=3`。沙盒（`--level=sandbox`）還有 `--enemies`、`--boss`、`--insight`、`--lock`。共通：`--difficulty=`、`--open=pause|settings|controls`、`--quality=0..2`、`--device=pad`、`--locale=zh_TW`、`--perf`。軟體渲染很慢：戰鬥截圖 14～40 幀、一般 20～40 幀。
- 改了 `i18n/*.csv` 之後：先 `scripts/gen-assets.sh`（字型子集，不然 test_fonts 會報缺字）再 `godot --headless --path game --import`（不然截圖裡還是舊翻譯）。CSV 有逗號或引號的欄位用 Python `csv` 模組寫（會自動加引號）。

## 1. M1.4 提前：場景層面的主線流程測試（霜橋鎮從新遊戲走到結尾）

- 新測試 `tests/flow/test_slice_playthrough.gd`：用 `Game.go_to_level("frostbridge")`（真的換場景）走完：梨販對話 → 鐘樓觸發＋敲九下 → 救三人（`RescueSite.rescue()`）→ 走近席菈對話 → 打倒灰巡者（`set_physics_process(false)` 後直接扣血）→ 南街口開打 → 九息石拱（或不用）→ 車隊推到底 → 艾妲 → 地窖 → `is_slice_complete()`。兩條路線（九息／薪火劍）。
- 中途在每個檢查點：`Game.retry()`（會重新載入關卡）後確認任務階段、出生位置、場上該有的東西（席菈、灰巡者、受困者已救的不重複）。這就是「任務恢復」的驗收。
- 注意：`Game.go_to_level` 是換整個 current_scene，測試結束要回到原本的場景或 `queue_free` 新場景；先看 `game.gd` 的 `go_to_level` 怎麼做。

## 2. 段落 1 補完＋死者名單（05 計畫 11/23、11/27）

- 段落 1「看見南街石拱」：新遊戲走進南街（`ConvoyTrigger` 附近另做一個 `ArchMemoryTrigger`）→ 一句諾恩的獨白（對話 `slice_arch_memory`：父親躲在柱子後）→ 日記解鎖第一條（把 `arch_father_last_talk` 改成 `unlocked_when: {"flag": "slice.saw_south_arch"}`，同時預覽代價卡仍要能顯示——`JournalView` 的 peek 不看解鎖條件，保持這樣）。HUD 目標可以提示「到南街看看」（選擇性，不擋主線）。
- 死者名單：收束對話 `slice_ada_aftermath` 的 `ada_list` 依 `slice.rescued_count`（0～4）與 `slice.convoy_injured` 顯示不同人數（翻譯 key 用 `{n}` 或分幾種句子）；先看那個對話現在怎麼寫的。
- 灰巡者教學提示：灰巡者出現時席菈喊「左膝」或 HUD 提示「按住 [右鍵] 看穿」「[Q] 打弱點」（只出現一次，存旗標 `tutorial.insight_shown`）。

## 3. 霜橋鎮畫面與手感（看截圖判斷）

- 北街陷落後的受困者在暗處不明顯（只有提燈小光點）→ 提燈亮一點，或被困者附近加一道霜光；`RescueSite` 搬瓦礫時加音效（目前用 `blunt_weak`）。
- 鐘室裡的鐘偏暗（鐘樓燈已移到鐘室前緣，下一輪截圖確認 `bell.png`）。
- 廣場地面大片月影很平：考慮在廣場加幾個積雪堆、木箱、長椅（進 StaticBatch，有碰撞的放牆邊）。
- VoxelGI 或 LightmapGI 的可行性（Forward+，Linux headless 能不能 bake）→ 不行就維持現在的燈＋霧，記 DECISIONS。
- 目標指引：小鎮比沙盒大，玩家可能不知道要去哪。考慮 HUD 目標旁加距離或方向（羅盤式小箭頭），或在目標地點放一道淡淡的暖光柱。先寫成 02-gameplay 的一條規則再做。

## 4. 送葬者戰打磨（上一輪留下的）

- 鐵架拋擲的畫面：鐵架真的飛出去（拋物線）、撞到石拱碎裂／被薪火劍斬成兩截；薪火劍的火光（席菈劍上 OmniLight＋粒子）。送葬者擲完背上的鐵架要消失。
- 席菈手傷等級 `sheila.hand_injury`（薪火劍後 +1，影響斬擊動作與之後的對話）。
- 席菈拒絕會害死人的指令（例如車隊旁邊叫她「閃開」→ 拒絕並說理由）。
- 車隊上的傷者換成程序人偶躺姿（`Puppet` 加 `lying`）；救援的受困者也可以用同一個姿勢。

## 備註

- 戰鬥沙盒仍可用：`++ --level=sandbox --enemies`（灰巡者＋席菈）或 `--convoy`。霜橋鎮的送葬者戰：`++ --level=frostbridge --convoy`。
- 測試輸出裡兩個 ERROR 是故意的：`QuestRunner: 推進超過 256 步`（test_cycle_guard）、`CutsceneRunner: 過場 no_such_cutscene 不存在`（test_cutscene）。`SCRIPT ERROR` 則一律算失敗（check.sh 會擋）。測試結尾若剛播過音效，多等一個 `process_frame` 再結束，否則會有 ObjectDB leak 警告。
- **測試裡別讓諾恩真的倒下**：`Game` 的倒下狀態會漏到後面的測試。只測某個招式時把敵人 `set_physics_process(false)`。測試裡生成敵人：**先設 `position` 再 `add_child`**。
- 霜橋鎮的劇情觸發（席菈、艾妲）是在 `frostbridge.gd` 的 `_physics_process` 依任務階段輪詢距離；其他用 `StoryLevel._trigger` 的 Area3D。新段落照這兩種寫法之一。
- `StaticBatch.build()` 之後不能再加東西（會被丟掉）：所有要合併的幾何都要在 `_batch.build(self, "Town")` 之前加（第 7 輪梨販攤就踩過）。
- 外觀待打磨（階段 2）：席菈目前是長外套（應為白短斗篷），斷劍在暗處幾乎看不到；送葬者整體太暗、鐵架需要霜光或邊緣光；看穿文字可加半透明底；九息石拱重現時偏亮，預覽輪廓是平的半透明塊。標題畫面的霧層幾乎看不出來；鐘的造型、按鍵設定頁的手把圖示（目前是文字 A／B／LB）。
- CI 有 Node 20 deprecation 警告（actions/checkout@v4 等），目前被強制用 Node 24 跑，不影響結果。
- `art-inbox/` 目前不存在；Jacky 放素材時會建立。
