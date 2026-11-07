# 給 Jacky

只列需要你處理或想聽你意見的重點；處理完的會刪掉。沒回覆的意見題，loop 會照預設做。

1. **試玩＋第一次效能量測（約 5 分鐘）**：從 [Releases → latest](https://github.com/twjackysu/yuming-city/releases/tag/latest) 下載 Windows zip 並解壓。
   - 雙擊 `YumingCity.exe` →「新遊戲」會進入冬夜街道沙盒，可以用 WASD／滑鼠或手把走動，F3 開效能 overlay。
   - 量測：在解壓的資料夾開 PowerShell 或命令提示字元，執行 `.\YumingCity.exe ++ --benchmark`（`++` 是 Godot 的使用者參數分隔符，PowerShell 也不會吃掉），約 35 秒後自動結束；結果在 `%APPDATA%\YumingCity\benchmark\bench-*.json`。請把那個 JSON 的內容（或檔案）貼到下面回覆區，並註明顯示卡型號與螢幕解析度。
   - 打不開或畫面怪怪的，回覆錯誤訊息或截圖說明即可。
2. **Steam（不急，12 月初前）**：Steamworks 開發者帳號、App 費用、App ID、商店頁、內容分級問卷只有你能處理。AI 生成的素材上架時需要在 Steam 問卷申報，用了哪些會記在 `docs/CREDITS.md`。
3. **Git LFS**：雲端 session 推不了 LFS（上傳被網路代理擋），所以 loop 只 commit 文字檔，素材在建置時程序生成。你從自己電腦推 LFS 沒問題；要給我素材時照 `docs/ART_REQUESTS.md` 放進 `art-inbox/`。如果 loop 下載不到 LFS 內容，會再請你改用 GitHub Release 附件。
4. **最大的美術缺口是有骨架、有動畫的角色模型**：需求與規格在 `docs/ART_REQUESTS.md` 第 1、2 項。在你提供之前，loop 會用程序生成的人偶加程式動畫頂上，不會卡進度。
5. **意見題：英文名**。暫定 諾恩 Noen、席菈 Sheila、霜橋鎮 Frostbridge、弔鐘人 Bellmourner、九息 Nine Breaths、送葬者 Undertaker（完整表在 `docs/design/01-adaptation.md`）。有偏好請回覆，沒回覆就照這樣用。

---

## 回覆

在這一行下面寫你的回覆，每則開頭寫日期（例如 `2026-11-08：…`）。loop 每輪開頭都會先讀這裡，處理完會在你的字下面加一行「→ 已處理（時間、commit）」，不會修改你寫的內容。

- 要暫停 loop：寫一則只有「暫停」或「STOP」的回覆；要恢復時再寫一則「繼續」。
- 也可以開 GitHub Issue，或直接 commit 修改／素材。
