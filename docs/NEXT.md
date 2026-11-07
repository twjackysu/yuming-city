# 下一輪待辦（依優先順序）

> 每輪從最上面拿 1～3 項。開工前先跑 `scripts/check.sh` 確認全綠（約 30 秒；第一次會下載 Godot 與字型來源）。截圖前先 `apt-get update && apt-get install -y xvfb mesa-vulkan-drivers`（沒有 update 會找不到 mesa-vulkan-drivers，截圖退回 OpenGL、沒有體積霧）。每日排程見 `docs/design/05-vertical-slice-plan.md`（目前超前約 1 週）。

## 0. 開工先確認

- 上一輪（第 4 輪）最後一次程式 push 的 CI 結果寫在 PROGRESS 最上面；照常看最近的 CI。
- **程式 commit 與 `[skip ci]` 文件 commit 要分開 push**（同一次 push 的 HEAD 帶 `[skip ci]` 會讓整個 push 不跑 CI）。工作區有未提交的文件時，先 `git stash` 再 pull／push 程式 commit。
- 截圖旗標：`--level=sandbox`、`--open=pause|settings|controls`、`--quality=0..2`、`--dialogue=<id> --dialogue-steps=N`、`--cutscene=slice_bell_nine --cutscene-steps=N`（跳過開場後敲 N 下）、`--enemies`（沙盒放灰巡者）、`--device=pad`、`--locale=zh_TW`。軟體渲染很慢：幀數超過約 100 會超過 2 分鐘，背景執行或用小幀數。

## 1. 看穿＋弱點（05 計畫 11/16 收尾）

- 按住 `insight`（右鍵／LT）：灰巡者頭上顯示已知資訊（弱點「左膝（已證實）」、招式名），文字走翻譯 key；不放慢時間（02-gameplay）。
- 弱點命中：`in_strike_arc` 內再判斷打點在敵人左膝附近（敵人 local 空間 x<0、y<0.6）→ 傷害 ×、失衡加倍；之後席菈「打弱點」指令共用。
- `EnemyBrain` 加「前兆中受擊不打斷」與「破綻中受擊加倍失衡」，數值放 tuning.json。
- 測試：看穿顯示切換、弱點命中倍率。

## 2. 席菈（05 計畫 11/17）

- `CompanionBrain`（純邏輯）：跟隨、自主攻擊最近敵人、三個指令（打弱點／閃開／守住）、指令冷卻 1.5 秒、拒絕指令（附理由 key）。時機窗依 `difficulty.*.command_window`。
- `Sheila` 節點：程序人偶換配色（白短斗篷、寬斷劍），體力 100。
- 測試：指令時機窗成功／失敗、冷卻、拒絕。

## 3. 難度選單＋打擊回饋音效

- 設定加「難度」（故事／標準／困難），存 `settings.cfg`；`EnemyBrain.configure` 與爪擊傷害讀目前難度（現在寫死 standard）。
- `scripts/gen-assets.sh` 加 Python 程序生成音效：鐘聲（敲鐘九下用，第九聲更低更長）、鈍擊、爪擊、閃避風聲；接到 SFX 匯流排；CREDITS 記「程序生成」。

## 4. 送葬者第一階段（05 計畫 11/18）

- 照 02-gameplay 招式表：鐵架橫掃／下砸／衝撞＋霜紋前兆；鎖定鏡頭（`lock_on`）。

## 備註

- 敲鐘演出目前在沙盒：走到鐘樓（任務 ring_bell 時）→ 開場鏡頭 → 每按一次互動鍵敲一下（提示「[F] 敲鐘 n／9」）→ 第九下北街房屋沉陷 → 收尾鏡頭。按住互動鍵 1 秒跳過。
- 灰巡者沒有放進沙盒預設（會干擾流程測試），用 `--enemies` 開啟；正式遭遇戰在 M1.3 的霜橋鎮。
- 測試輸出裡兩個 ERROR 是故意的：`QuestRunner: 推進超過 256 步`（test_cycle_guard）、`CutsceneRunner: 過場 no_such_cutscene 不存在`（test_cutscene）。`SCRIPT ERROR` 則一律算失敗（check.sh 會擋）。
- 沙盒 draw calls 約 236（CSG 很多）＋人偶、木樁、鐘；霜橋鎮白盒時把靜態 CSG 烘成 MeshInstance 或合併，benchmark 會反映。
- 標題畫面的霧層幾乎看不出來（`title_fog.gdshader` 霧強度可再調）；放到打磨階段。
- 鐘的造型、按鍵設定頁的手把圖示（目前是文字 A／B／LB）都是打磨階段的項目。
- CI 有 Node 20 deprecation 警告（actions/checkout@v4 等），目前被強制用 Node 24 跑，不影響結果。
- `art-inbox/` 目前不存在；Jacky 放素材時會建立。
