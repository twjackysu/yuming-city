# 技術方向

更新：2026-11-07（引擎由 UE5 改為 Godot 4，見 DECISIONS D-001）。

## 決策

- **引擎**：Godot 4.7.2 stable（標準版），固定在 `scripts/get-godot.sh`，不因新版發布就升級。
- **語言**：GDScript＋靜態型別；未加型別的宣告視為錯誤。不使用 C#／.NET。
- **渲染**：Forward+。Windows 預設 D3D12，失敗時由 Godot 退回 Vulkan。
- **平台**：首發 Windows 64-bit／Steam；CI 順便匯出 Linux 供測試。
- **形式**：第三人稱、單人、章節式敘事動作 RPG，搭配城市據點（原型階段可調整，改了記 DECISIONS）。

選 Godot 的原因：開發 loop 在沒有 GPU 的 Linux 雲端 session 執行，Godot 能在 Linux 與 GitHub Actions 上 import、測試、匯出 Windows 版；場景與腳本是純文字，每次修改都能被自動驗證。開源、無權利金。

## 分工

| 領域 | 做法 |
|---|---|
| 戰鬥、九息、記憶代價、存檔、任務狀態 | 純 GDScript 類別（`RefCounted`／`Resource`），不依賴場景，可以 headless 單元測試 |
| 互動、遭遇配置、UI 流程、角色調參 | 場景（`.tscn`）＋資料資源（`.tres`／JSON） |
| 任務與對話 | 資料驅動（文字檔），演出與任務狀態分開，支援跳過與續接 |
| 同伴 AI | 小型狀態機，先做席菈一人，指令與自主行為分開 |
| 畫面 | Forward+、體積霧、SDFGI／VoxelGI 依實測取捨，後製（tonemap、bloom、色調）做成畫質選項 |
| 音效 | Godot 內建音訊匯流排；程序生成音效先頂上 |
| 自動化 | Bash／Python：下載引擎、生成素材、檢查與匯出（`scripts/`） |
| 版本控制 | GitHub；大型二進位資產走 Git LFS |

## 九息能力的工程邊界

不做整個世界任意倒轉或任意毀壞物復原。設計者在場景中標記「可保存物件」，提供完整態／損壞態與碰撞切換。九秒倒數結束後還原指定狀態，處理玩家站位（避免卡進碰撞體）、相依物件與存檔。

實作上，可保存物件的狀態是純資料（列舉＋計時），存檔只記錄「已付代價」與「物件最終狀態」，讀檔不會重複扣代價，也不會停在九秒中間。

記憶代價由可追蹤的故事旗標與已知關聯決定，確認前清楚揭示可能後果；不隨機刪除玩家存檔或已取得內容。小說的失憶是角色事件，不等於玩家必須失去操作知識。

## GPU 與效能目標

「有 GPU」不足以定義最低規格：顯示記憶體、GPU 世代、CPU、RAM、SSD 都會影響體驗。待代表性關卡打包實測後再公布最低／建議配備。

原型驗收目標：中階獨顯、1080p 中等畫質、60 fps（每幀約 16.7 ms）；另外記錄 1440p 高畫質表現。這是待驗證目標，不是已達成的承諾。

量測方式（開發 session 沒有 GPU，所以讓遊戲自己量）：

- 內建效能 overlay：CPU／GPU frame time、FPS、1% low、draw calls、VRAM、記憶體。
- benchmark 場景：固定鏡頭路徑跑固定秒數，結束後把統計寫成 JSON 到 `user://benchmark/`。
- shader 編譯卡頓：記錄首次出現各材質時的尖峰；必要時做 shader 預熱。
- 實機量測步驟寫在 `docs/FOR_JACKY.md`，由 Jacky 在 Windows 實機執行打包版本。
- 升頻（FSR）、SSR、SSAO、SDFGI、體積霧都做成畫質選項；不把光追當作必要條件。

## 發行與成本

遊戲先能離線遊玩。存檔與輸入穩定後，用 GodotSteam（GDExtension）加入成就與雲端存檔。Steamworks 帳號、App ID、商店頁、分級問卷只有 Jacky 能處理；`steam_appid.txt` 與任何憑證不進 git。

Godot 採 MIT 授權，沒有權利金；遊戲內需附上 Godot 與第三方元件的授權聲明（見 `docs/CREDITS.md`）。Steam 平台費用另計。

3A 品質涉及角色美術、場景、動畫、音效、演出、QA、最佳化。引擎提供工具，不能取代這些工作。先用 20–30 分鐘的垂直切片驗證每分鐘內容的成本，再估完整遊戲。

## 官方來源

- [Godot 4.7.2 下載與發行說明](https://godotengine.org/download/archive/4.7.2-stable/)
- [Godot 文件：GDScript 靜態型別](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/static_typing.html)
- [Godot 文件：匯出](https://docs.godotengine.org/en/stable/tutorials/export/exporting_projects.html)
- [Godot 授權](https://godotengine.org/license/)
