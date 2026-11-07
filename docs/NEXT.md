# 下一輪待辦（依優先順序）

> 每輪從最上面拿 1～3 項。開工前先跑 `scripts/check.sh` 確認全綠（約 40 秒；第一次會下載 Godot 與字型來源、產生音效）。截圖前先 `apt-get update && apt-get install -y xvfb mesa-vulkan-drivers`（沒有 update 會找不到 mesa-vulkan-drivers，截圖退回 OpenGL、沒有體積霧）。每日排程見 `docs/design/05-vertical-slice-plan.md`（M1.1、M1.2 都已提前完成；目前超前約 13 天，11/22 的 M1.3 項目可以開工）。

## 0. 開工先確認

- 上一輪（第 6 輪）最後一次程式 push 的 CI 結果寫在 PROGRESS 最上面；照常看最近的 CI（GitHub MCP `actions_list`）。
- **程式 commit 與 `[skip ci]` 文件 commit 要分開 push**（同一次 push 的 HEAD 帶 `[skip ci]` 會讓整個 push 不跑 CI）。
- 截圖旗標：`--level=sandbox`、`--enemies`（灰巡者＋席菈）、`--boss`（送葬者＋席菈）、`--convoy`（送葬者＋席菈＋車隊＋遭遇戰）、`--caravan`、`--phase2`、`--arch=preview|restored|spent`（諾恩站在南街石拱前）、`--insight`、`--lock`、`--difficulty=story|standard|hard`、`--open=pause|settings|controls`、`--quality=0..2`、`--dialogue=<id> --dialogue-steps=N`、`--cutscene=slice_bell_nine --cutscene-steps=N`、`--device=pad`、`--locale=zh_TW`。軟體渲染很慢、一幀可能跑好幾個物理步：戰鬥截圖用 14～40 幀。
- 改了 `i18n/*.csv` 之後：先 `scripts/gen-assets.sh`（字型子集，不然 test_fonts 會報缺字）再 `godot --headless --path game --import`（不然截圖裡還是舊翻譯）。

## 1. 霜橋鎮白盒（05 計畫 11/22，M1.3 開始）

- 新關卡 `scenes/levels/frostbridge.gd`（＋`.tscn`，跟沙盒一樣用程式生成）：廣場與梨販攤、主街、鐘樓、南街石拱（`NineBreathSite`）、北街（崩塌用）、路口（車隊終點）。沿用沙盒的 `_build_environment` 設定（之後抽成 `FrostbridgeLook`）。
- 靜態 CSG 在 `_ready` 後烘成 MeshInstance／合併（沙盒 draw calls 約 236），benchmark 場景改用霜橋鎮。
- `Game.level_for_checkpoint` 對應到 frostbridge；沙盒留給開發測試。主線流程測試改走霜橋鎮（任務層面不變）。
- 送葬者戰放在南街：`spawn_convoy_fight` 的邏輯搬成關卡裡的遭遇戰觸發（車隊從北街口出發、穿過南街石拱、到路口）。

## 2. 日記與記憶條目（05 計畫 11/23）

- `Journal`（純邏輯）：記憶條目 id、標題 key、內文 key、相關人物／地點；付出後內文變「被整齊剪掉的空白」、標題保留。資料 `data/journal/slice.json`；`arch_father_last_talk` 是第一條。
- 日記 UI（Tab 長按或暫停選單一頁）；九息預覽時把那段記憶標亮（02-gameplay「預覽」）。
- 測試：付出前後的顯示、存讀檔、預覽標亮。

## 3. 送葬者戰打磨（看到畫面才知道好不好玩的部分）

- 鐵架拋擲的畫面：鐵架真的飛出去（拋物線）、撞到石拱碎裂／被薪火劍斬成兩截；薪火劍的火光（席菈劍上 OmniLight＋粒子）。送葬者擲完背上的鐵架要消失。
- 席菈手傷等級 `sheila.hand_injury`（薪火劍後 +1，影響斬擊動作與之後的對話）。
- 席菈拒絕會害死人的指令（02-gameplay：例如車隊旁邊叫她「閃開」會把攻擊讓給傷者 → 拒絕並說理由）。
- 車隊上的傷者看起來像木頭：換成程序人偶躺姿（`Puppet` 加 `lying` 姿勢）。

## 4. 救援互動、救出計數（05 計畫 11/25）

- 北街崩塌後的受困者：互動點（按住 F 搬開瓦礫）、救出計數 `slice.rescued`，影響死者名單與艾妲的態度。

## 備註

- 戰鬥沙盒：`++ --level=sandbox --enemies`（灰巡者＋席菈）或 `--convoy`（完整送葬者戰）。Q／E／R（手把十字鍵上／右／下）下指令，右鍵／LT 看穿，中鍵／R3 鎖定（滑鼠左右甩／右搖桿左右撥換目標），V／Y 按住九息。敵人都不在預設沙盒（會干擾主線流程測試）。
- 測試輸出裡兩個 ERROR 是故意的：`QuestRunner: 推進超過 256 步`（test_cycle_guard）、`CutsceneRunner: 過場 no_such_cutscene 不存在`（test_cutscene）。`SCRIPT ERROR` 則一律算失敗（check.sh 會擋）。測試結尾若剛播過音效，多等一個 `process_frame` 再結束，否則會有 ObjectDB leak 警告。
- **測試裡別讓諾恩真的倒下**：`Game` 的倒下狀態會漏到後面的測試（流程測試會整個走不動）。只測某個招式時把敵人 `set_physics_process(false)`。測試裡生成敵人：**先設 `position` 再 `add_child`**。
- 外觀待打磨（階段 2）：席菈目前是長外套（應為白短斗篷），斷劍在暗處幾乎看不到；送葬者整體太暗、鐵架需要霜光或邊緣光；看穿文字可加半透明底；九息石拱重現時偏亮（emission 0.35＋rim），預覽輪廓是平的半透明塊。
- 標題畫面的霧層幾乎看不出來（`title_fog.gdshader`）；鐘的造型、按鍵設定頁的手把圖示（目前是文字 A／B／LB）都是打磨階段的項目。
- CI 有 Node 20 deprecation 警告（actions/checkout@v4 等），目前被強制用 Node 24 跑，不影響結果。
- `art-inbox/` 目前不存在；Jacky 放素材時會建立。
