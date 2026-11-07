# 下一輪待辦（依優先順序）

> 每輪從最上面拿 1～3 項。開工前先跑 `scripts/check.sh` 確認全綠（約 15 秒；第一次會下載 Godot 與字型來源）。截圖前確認 `apt-get install -y xvfb mesa-vulkan-drivers`，否則會退回 OpenGL（沒有體積霧）。每日排程見 `docs/design/05-vertical-slice-plan.md`。

## 0. 開工先確認

- benchmark commit（`0544afd`）與本輪最後 push 的 CI 是否綠燈；release `latest` 是否有 `sandbox.png`（README 首圖用它）。紅了先修。

## 1. 暫停選單＋設定選單（05 計畫 11/11，可提前）

- `scenes/ui/pause_menu`：Esc／Start 暫停（`get_tree().paused`），繼續、設定、回標題；暫停時釋放滑鼠。
- `scenes/ui/settings_menu`：語言、主音量／音樂／音效（建立匯流排 Master／Music／SFX／Voice／UI）、字幕開關、畫質三級（低：關體積霧／SSAO／Glow，中：預設，高：加 SSR）、「減少鏡頭晃動」。Settings autoload 擴充並存到 `settings.cfg`；畫質要套到目前場景的 WorldEnvironment（建議做一個 `QualityPreset` 純類別回傳 Environment 參數，測試它）。
- 所有文字走翻譯 key（`strings.csv`）；i18n 測試會檢查場景寫死文字。
- 標題畫面也能開設定。

## 2. HUD：目前目標＋存檔提示

- `scenes/ui/hud`：左上顯示 `Game.session.objective_key()` 的翻譯；`checkpoint_reached` 時右下閃一下「已存檔」圖示。用 Game 的訊號，不輪詢。
- 沙盒加幾個觸發區（Area3D）設旗標，讓「新遊戲 → 走到梨販 → 目標變成敲鐘」在沙盒裡能手動驗證；流程測試加一條場景層面的驗證（玩家進觸發區 → 任務推進）。

## 3. 程序人偶（05 計畫 11/13）

- Skeleton3D 由程式建立（骨盆、脊椎、頭、上臂、前臂、大腿、小腿），膠囊肢體綁骨；程式動畫：待機呼吸、走、跑、閃避翻滾、揮擊。介面設計成之後可直接換 Jacky 提供的模型（AnimationTree 狀態名固定：idle／walk／run／dodge／attack）。
- 截圖對照：剪影在霧中要認得出來（03 的「第一眼質感檢查」）。

## 4. 對話系統（05 計畫 11/14）

- `DialogueDB`／`DialogueRunner`（04 架構、D-013）：節點、選項、`if`／`do` 只用 StoryLogic；付過的記憶讓選項消失。資料放 `data/dialogue/`、文字放 `i18n/slice.csv`。
- 字幕 UI＋按住跳過。

## 5. 改編文件補完（01-adaptation 的「待補」）

- 全篇章節 → 遊戲章節對應表、12/31 版本範圍（初判：切片＋第一部第 3～6 章）、角色弧線。不急，但 12/1 前要有，階段 2 挑內容用。

## 備註

- 沙盒 draw calls 約 236（CSG 很多）；霜橋鎮白盒時把靜態 CSG 烘成 MeshInstance 或合併，benchmark 會反映。
- 標題畫面的霧層幾乎看不出來（`title_fog.gdshader` 的霧強度可再調）；放到打磨階段。
- 測試輸出裡 `QuestRunner: 推進超過 256 步` 的 ERROR 是 `test_cycle_guard` 故意觸發的，不是失敗。
- CI 有 Node 20 deprecation 警告（actions/checkout@v4 等），目前被強制用 Node 24 跑，不影響結果；之後確認新版號再升級。
- `art-inbox/` 目前不存在；Jacky 放素材時會建立。
