# 技術方向建議

研究日期：2026-11-07。這是技術選型建議，尚未代表引擎已安裝或遊戲已編譯。

## 決策

建議 Unreal Engine 5，以 C++ 建立系統底層，Blueprint 實作設計層；首發 Windows 64-bit / Steam，採 DirectX 12。先以第三人稱、章節式動作 RPG 加城市據點驗證。這些遊戲形式是建議，可在原型階段調整。

UE 的 C++ / Blueprint 混合架構符合本專案需要：敘事、關卡與互動可快速迭代，核心狀態與效能敏感邏輯保留文字程式碼及可測試邊界。不要把每個物件都做逐幀輪詢，也不需要把全部 Blueprint 轉成 C++；先用 Unreal Insights 找瓶頸。

## 分工

| 領域 | 建議 |
|---|---|
| 戰鬥、能力代價、存檔版本、任務狀態 | C++，向 Blueprint 暴露明確介面 |
| 互動、遭遇配置、UI 流程、角色調參 | Blueprint + Data Assets / Data Tables |
| 對話演出 | Sequencer，與任務狀態分開，支援跳過與續接 |
| 同伴 AI | 先做小規模狀態與行為原型，再決定 StateTree / Behavior Tree 配置 |
| 畫面 | 評估 Nanite、Lumen、Virtual Shadow Maps，依目標硬體與實測取捨 |
| 音效 | 先使用引擎內建音訊工具，需求明確後才加入第三方音訊中介層 |
| 開發工具 | Visual Studio 或 Rider；MSVC / Windows SDK 版本依選定 UE 文件安裝 |
| 輔助自動化 | Python / PowerShell，用於資產檢查、建置與打包，不作主要遊戲執行語言 |
| 版本控制 | GitHub + Git LFS；二進位資產採責任分配或鎖定，團隊擴大再評估 Perforce |

不建議本案自製引擎。Unity + C# 或 Godot 可製作 PC 遊戲，但本案以高畫質 3D 戰鬥和敘事演出為目標，優先評估 UE 的整合流程；這是對本案的選型判斷，不表示其他引擎無法達成。

## 九息能力的工程邊界

不做整個世界任意倒轉或任意毀壞物復原。第一版讓設計者標記可保存物件，提供完整態 / 損壞態資料與碰撞切換。九秒倒數結束後還原指定狀態，處理玩家站位、相依物件與存檔。

記憶代價由可追蹤的故事旗標與已知關聯決定，確認時清楚揭示可能後果；不要隨機刪除玩家存檔或任意扣除已購內容。小說的失憶是角色事件，不等於玩家必須失去操作知識。

## GPU 與效能目標

「有 GPU」仍不足以定義最低規格：顯示記憶體、GPU 世代、CPU、RAM、SSD 都會影響體驗。先選 NVIDIA 與 AMD 的中階實機作基準，待代表性關卡打包實測後再公布最低 / 建議配備。

原型驗收目標：在指定測試機上，1080p 中等畫質、60 fps（每幀約 16.7 ms）；另外記錄 1440p 高畫質表現。這是待驗證目標，不是已達成的承諾。

記錄 CPU / GPU frame time、1% low、VRAM、記憶體、串流與 shader / PSO 引起的卡頓。將升頻與光追做成可調畫質選項，避免把硬體光追作為第一版必要條件。Nanite / Lumen 不保證任何素材自動跑得快。

## 發行與成本

遊戲先能離線遊玩；Steam 成就、雲端存檔與手把整合在基本存檔及輸入流程穩定後加入。上架仍需另行處理 Steamworks 帳戶、商店內容、建置測試與發行程序，本 repo 建立不等於已完成上架。

Epic 目前公開的標準遊戲授權說明：產品終身總收入超過 US$1,000,000 的部分通常收取 5% 權利金，具體豁免、優惠及計算依適用 EULA。Steam 的平台費用另計。正式商業發行前確認適用版本條款。

3A 品質涉及角色美術、場景、動作捕捉 / 動畫、音效、演出、QA、最佳化和製作管理。引擎能提供工具，不能取代這些工作。先用一段 20–30 分鐘的代表性關卡驗證團隊產能與每分鐘內容成本，再估完整遊戲。

## 官方來源

- [Epic：C++ 與 Blueprint 分工](https://dev.epicgames.com/documentation/en-us/unreal-engine/coding-in-unreal-engine-blueprint-vs-cplusplus)
- [Epic：硬體與軟體需求](https://dev.epicgames.com/documentation/en-us/unreal-engine/hardware-and-software-specifications-for-unreal-engine)
- [Epic：Lumen 技術細節](https://dev.epicgames.com/documentation/en-us/unreal-engine/lumen-technical-details-in-unreal-engine)
- [Epic：授權](https://www.unrealengine.com/license)
