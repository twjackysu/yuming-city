# 下一輪待辦（依優先順序）

> 每輪從最上面拿 1～3 項。開工前先跑 `scripts/check.sh` 確認全綠（約 20 秒；第一次會下載 Godot 與字型來源）。截圖前先 `apt-get update && apt-get install -y xvfb mesa-vulkan-drivers`（沒有 update 會找不到 mesa-vulkan-drivers，截圖退回 OpenGL、沒有體積霧）。每日排程見 `docs/design/05-vertical-slice-plan.md`。

## 0. 開工先確認

- 上一輪（第 3 輪）最後一次程式 push 的 CI 結果寫在 PROGRESS 最上面；照常看最近的 CI。
- **程式 commit 與 `[skip ci]` 文件 commit 要分開 push**（同一次 push 的 HEAD 帶 `[skip ci]` 會讓整個 push 不跑 CI）。
- 截圖用旗標：`--level=sandbox`、`--open=pause|settings`、`--quality=0..2`、`--dialogue=slice_pear_seller --dialogue-steps=2`、`--locale=zh_TW`。

## 1. 按鍵重新綁定＋裝置圖示（05 計畫 11/13，M1.1 收尾）

- 設定選單加「按鍵」子頁：列出 `InputSetup.BINDINGS` 的動作（每個動作一個翻譯 key `ACT_*`），按下後等待下一個鍵／手把鍵寫入；存到 `settings.cfg` 的 `[input]`，啟動時覆寫預設（04 架構「輸入」）。衝突時交換。「恢復預設」按鈕。
- `InputGlyphs`（`src/ui/`）：依最後輸入裝置發 `device_changed`；對話框提示（`HUD_DLG_HINT`）改成顯示目前裝置的鍵名（`[F]`／`Ⓐ`）。
- 測試：重新綁定存讀、衝突交換、恢復預設、裝置切換訊號。

## 2. 過場跳過＋M1.1 驗收（05 計畫 11/14）

- `Cutscene` 最小框架：一串鏡頭點（Marker3D）＋字幕行（翻譯 key）＋時長；按住互動鍵跳過（共用 DialogueBox 的按住邏輯，抽成 `HoldToSkip`）；跳過時套用結束效果。
- 用它做「敲鐘」的短演出替換沙盒鐘樓觸發區的即時推進（目前走到鐘樓就直接設 `slice.bell_rings = 9`）。
- 驗收：對照 `docs/vertical-slice.md`「必須驗證」清單，把 M1.1 涵蓋的項目在 PLAN 打勾。

## 3. M1.2 戰鬥起步（05 計畫 11/15）

- `CombatTuning`（`data/combat/*.json`＋`user://tuning.json` 熱重載，D-014）、`Health`、受傷／死亡 → `GameSession.retry_from_checkpoint()`、閃避無敵（PlayerController 已有 `invulnerable`）、鐘錘鈍擊命中判定（人偶 attack 的 35～60% 區間）、hit stop、鏡頭震動（`Settings.reduce_camera_shake` 為 true 時減到 25%）。
- 沙盒放一個木樁假人驗證命中與 hit stop。

## 4. 改編文件補完（01-adaptation 的「待補」）

- 全篇章節 → 遊戲章節對應表、12/31 版本範圍（初判：切片＋第一部第 3～6 章）、角色弧線。12/1 前要有。
- 切片事後對話（艾妲：「你爸以前買梨，老說我爸秤不準」）要和梨販對話呼應：付出 `arch_father_last_talk` 後，諾恩答不出「真的不準？」——寫進 01 的切片段落，再做成 `slice_ada_aftermath.json`。

## 備註

- 暫停後立刻截圖時，SpringArm 還沒伸長，鏡頭會在角色身上（只有截圖模式會遇到，實際遊玩不會）。
- 沙盒 draw calls 約 236（CSG 很多），人偶再加約 30 個 MeshInstance；霜橋鎮白盒時把靜態 CSG 烘成 MeshInstance 或合併，benchmark 會反映。
- 標題畫面的霧層幾乎看不出來（`title_fog.gdshader` 的霧強度可再調）；放到打磨階段。
- 測試輸出裡 `QuestRunner: 推進超過 256 步` 的 ERROR 是 `test_cycle_guard` 故意觸發的，不是失敗。
- CI 有 Node 20 deprecation 警告（actions/checkout@v4 等），目前被強制用 Node 24 跑，不影響結果；之後確認新版號再升級。
- `art-inbox/` 目前不存在；Jacky 放素材時會建立。
