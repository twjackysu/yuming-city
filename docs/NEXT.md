# 下一輪待辦（依優先順序）

> 每輪從最上面拿 1～3 項。開工前先跑 `scripts/check.sh` 確認全綠（約 40 秒；第一次會下載 Godot 與字型來源、產生音效）。截圖前先 `apt-get update && apt-get install -y xvfb mesa-vulkan-drivers`（沒有 update 會找不到 mesa-vulkan-drivers，截圖退回 OpenGL、沒有體積霧）。每日排程見 `docs/design/05-vertical-slice-plan.md`（目前超前約 10 天：11/19 的項目已可開工）。

## 0. 開工先確認

- 上一輪（第 5 輪）最後一次程式 push 的 CI 結果寫在 PROGRESS 最上面；照常看最近的 CI（GitHub MCP `actions_list`）。
- **程式 commit 與 `[skip ci]` 文件 commit 要分開 push**（同一次 push 的 HEAD 帶 `[skip ci]` 會讓整個 push 不跑 CI）。
- 截圖旗標：`--level=sandbox`、`--enemies`（灰巡者＋席菈）、`--boss`（送葬者＋席菈）、`--insight`（按住看穿，敵人會放近一點）、`--lock`（鎖定最近敵人）、`--difficulty=story|standard|hard`、`--open=pause|settings|controls`、`--quality=0..2`、`--dialogue=<id> --dialogue-steps=N`、`--cutscene=slice_bell_nine --cutscene-steps=N`、`--device=pad`、`--locale=zh_TW`。軟體渲染很慢、一幀可能跑好幾個物理步：戰鬥截圖用 14～40 幀。
- 測試裡生成敵人：**先設 `position` 再 `add_child`**（不然會在原點跟諾恩重疊，把諾恩頂上去當平台載走）。

## 1. 送葬者第二階段＋車隊（05 計畫 11/19）

- `tuning.json` 的 `undertaker.moves` 加 `double_slam`（兩次下砸，第二次前兆 0.5）、`grab`（抓最近的心跳）；`pattern_phase2`，`Undertaker.enter_phase_two()` 換 pattern。
- 「閃過一次後看穿變成已證實」：諾恩或席菈在 double_slam 第二下時無敵或不在範圍內 → `intel_overrides["double_slam"] = true`；之前的「閃開」指令對第二下算失敗。
- 車隊：`CaravanRunner`（純邏輯：沿路線點推進、被鐵架打中停 2 秒並 `injured += 1`、到終點 `arrived`）；`Caravan` 節點（程序推車＋兩個傷者人偶）。送葬者第二階段優先追車隊的心跳。
- 鐵架拋擲（劇情觸發一次，生命 ≤ 300 或車隊過半）：先只做觸發與 `slice.frame_thrown` 旗標，接九息（第 2 項）或薪火劍。
- 測試：第二階段 pattern、已證實切換、車隊推進／受傷／抵達、拋擲只觸發一次。

## 2. 九息石拱場景物件（05 計畫 11/20）

- 南街石拱（沙盒 `_build_arch` 那座）標成 `NineBreath` 可保存物：附近出現鐘紋提示「可保存：南街石拱」與代價文字；按住 `nine_breath`（V／Y）1 秒確認、放開取消。
- 發動：畫面去飽和（WorldEnvironment adjustment）、只有石拱發光、九聲心跳倒數（程序音效 `heartbeat` 加到 gen_sfx）；石拱有完整碰撞、會擋鐵架拋擲；站在裡面的人被推出。結束化灰（粒子）＋記憶條目被剪掉。
- 拒絕路線：席菈燒薪火劍（`sheila.kindling_used_early`）。狀態機 `nine_breath.gd` 已有，只做場景與演出。
- 測試：預覽不付代價、放開取消、九息期間擋下拋擲、結束後記憶已付、存讀檔後石拱狀態正確。

## 3. 戰鬥 HUD＋席菈倒下

- HUD：諾恩生命條、席菈生命／體力條、三個指令的鍵名（`InputGlyphs`）與冷卻；被拒絕時 HUD 也閃一下理由（她頭上已有回話）。
- 席菈倒下 8 秒內諾恩走近按互動鍵拉起（02-gameplay），超過就等戰鬥結束；倒下時拒絕所有指令（已做）。
- 測試：HUD 跟著數值變、拉起時機。

## 4. 鎖定補完與戰鬥鏡頭

- 鎖定時被牆擋 1.5 秒解除；右搖桿左右撥（或滑鼠側鍵）切換目標；戰鬥中（附近有敵人、未鎖定）鏡頭拉到 4.2 m。

## 備註

- 戰鬥沙盒：`++ --level=sandbox --enemies`（灰巡者＋席菈）或 `--boss`（送葬者＋席菈）。Q／E／R（手把十字鍵上／右／下）下指令，右鍵／LT 看穿，中鍵／R3 鎖定。灰巡者與送葬者都不在預設沙盒（會干擾主線流程測試）；正式遭遇戰在 M1.3 的霜橋鎮。
- 測試輸出裡兩個 ERROR 是故意的：`QuestRunner: 推進超過 256 步`（test_cycle_guard）、`CutsceneRunner: 過場 no_such_cutscene 不存在`（test_cutscene）。`SCRIPT ERROR` 則一律算失敗（check.sh 會擋）。測試結尾若剛播過音效，多等一個 `process_frame` 再結束，否則會有 ObjectDB leak 警告。
- 外觀待打磨（階段 2）：席菈目前是長外套（應為白短斗篷），斷劍在暗處幾乎看不到；送葬者整體太暗、鐵架需要霜光或邊緣光；看穿文字可加半透明底。
- 沙盒 draw calls 約 236（CSG 很多）；霜橋鎮白盒時把靜態 CSG 烘成 MeshInstance 或合併，benchmark 會反映。
- 標題畫面的霧層幾乎看不出來（`title_fog.gdshader`）；鐘的造型、按鍵設定頁的手把圖示（目前是文字 A／B／LB）都是打磨階段的項目。
- CI 有 Node 20 deprecation 警告（actions/checkout@v4 等），目前被強制用 Node 24 跑，不影響結果。
- `art-inbox/` 目前不存在；Jacky 放素材時會建立。
