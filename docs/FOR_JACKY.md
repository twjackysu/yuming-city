# 給 Jacky

只列需要你處理或想聽你意見的重點；處理完的會刪掉。沒回覆的意見題，loop 會照預設做。

1. **試玩＋第一次效能量測（約 30 分鐘）**：照 [**docs/playtest.md**](playtest.md) 走——下載、整段路線（兩條路線各怎麼走）、最想聽的 9 個感想、benchmark 指令都在裡面。最近加了：**敲鐘的鐘換成真正的鐘形**（肩、細腰、外翻的鐘口、紋帶、木頭鐘架；鐘室加了屋頂格柵與背面百葉——敲第九下時鐘的樣子對不對味請說；敲鐘時提示上方多了九個會亮起的圓點）、**設定頁分成四組、值變成「‹ 值 ›」**（滑鼠點箭頭或手把十字鍵左右切換，換值時有一聲很小的「叮」——太吵或太小聲請說）、**廣場中央的石框與鐘紋石盤、井有了小屋頂與一盞小燈**、梨販攤的木箱、**鏡頭改成過肩**（諾恩在畫面左邊；貼牆、窄巷會自動收回，席菈或敵人走到你背後時不會再把鏡頭拉近——跑起來有沒有突然跳動或穿牆請告訴我）、日記變成一張舊紙（被付出的記憶是紙上挖掉的洞）、窗框與窗簾、木板門、雪的起伏。地上偶爾有一顆雪粒閃光，鏡頭移動時如果太閃請說。地面的濕亮感請在中、低畫質各看一眼廣場與主街。結果與感想貼在下面回覆區，benchmark 請附顯示卡型號與解析度；打不開或畫面怪怪的，回覆錯誤訊息或截圖即可。
2. **Steam（不急，12 月初前）**：Steamworks 開發者帳號、App 費用、App ID、商店頁、內容分級問卷只有你能處理。**商店文案中英草稿**寫好了：[docs/steam/store-page.md](steam/store-page.md)（有空看一眼語氣對不對、有沒有劇透到你不想公開的）；素材尺寸與需要你做的主視覺在 [docs/steam/asset-specs.md](steam/asset-specs.md)；**商店頁頂端那張圖（Header）的替代版**現在每次建置都會自動產生，在 [latest release](https://github.com/twjackysu/yuming-city/releases/tag/latest) 下載 `header_capsule.png` 就能看到大概的樣子（遊戲截圖＋「餘命城」標題字，正式主視覺做好再換）。系統需求目前是估計，等你的 benchmark。AI 生成的素材上架時需要在 Steam 問卷申報，用了哪些會記在 `docs/CREDITS.md`。
3. **雲端 session 下載不到 Godot（不急，有空看一下）**：這一輪的排程 session 只開了 `twjackysu/yuming-city` 的 GitHub 存取，下載 Godot 官方 release（`godotengine/godot`）與字型來源（`notofonts/noto-cjk`）都被擋，所以 loop 這輪不能在雲端跑測試與截圖，改成推上去看 CI（照你的指示沒有繞過）。如果排程任務的設定能把這兩個 repo 加進可存取的範圍，loop 就能恢復本機驗證；不加也能繼續做。為了讓你和 loop 都看得到畫面，CI 現在每次建置會多拍 11 個主要畫面，放在 prerelease **[screens](https://github.com/twjackysu/yuming-city/releases/tag/screens)**（開發用，試玩還是下載 latest）。素材：概念圖已用上五樣（濕石板路、半木構＋石牆、門口掛燈、石階、水窪倒影）；雲端推 LFS 還是不行，loop 只 commit 文字檔。
4. **角色模型：接入點做好了**（D-041）。看到你推的 `docs/art-trials/noen-rigging/` 試作（MPFB 分件＋walk），照 README 沒有接進遊戲；要試接時把模型放成 `art-inbox/characters/noen/noen.glb`（席菈 `sheila/sheila.glb`，走 LFS）推上來，CI 和本機 `scripts/gen-assets.sh` 會用你的 `check_character_glb.py` 檢查，**通過就自動換掉程序人偶**、沒過就印出原因並繼續用人偶。動作名稱照 `art-inbox/README.md`（目前會用到 idle、walk、run、dodge_roll、light_attack_01，缺的會退回）；提燈掛左手骨骼、鐘錘掛右手骨骼（Mixamo／LeftHand／hand_l 都認得）。TripoSR 試跑報告看過了，同意不拿那個結果充數。
5. **意見題：白話用詞**（回應你的回覆）。人名、地名、怪物名照原作；能力、職業、技能改成白話：九息 → **重現**（Restore，「按住 V　重現 9 秒」）、弔鐘人 → **敲鐘人**、薪火劍 → **燃燒劍**、巡界隊 → 巡邏隊、下城 → 地底城、爹 → 爸。完整對照表在 `docs/design/06-terminology.md`，測試會擋住舊詞出現在遊戲畫面。哪個名字還是不順，直接回覆想要的字；沒回覆就照這張表。

---

## 回覆

在這一行下面寫你的回覆，每則開頭寫日期（例如 `2026-11-08：…`）。loop 每輪開頭都會先讀這裡，處理完會在你的字下面加一行「→ 已處理（時間、commit）」，不會修改你寫的內容。

- 要暫停 loop：寫一則只有「暫停」或「STOP」的回覆；要恢復時再寫一則「繼續」。
- 也可以開 GitHub Issue，或直接 commit 修改／素材。

我覺得用詞還是太"中國武俠玄學"感了，可以現代人一點用詞淺顯易懂嗎?
像是九息，弔鐘人，完全看不懂是啥，還是就當作是人物名稱就好? 但如果有一些東西用詞太不淺顯易懂建議不要照小說的
→ 已處理（2026-11-08 06:48 台北，d66cfad）：玩家畫面的用詞全部改白話——九息 → 重現（9 秒）、弔鐘人 → 敲鐘人、薪火劍 → 燃燒劍、巡界隊 → 巡邏隊、下城 → 地底城、爹 → 爸；人名、地名、怪物名照原作。對照表 `docs/design/06-terminology.md`、決策 D-035。
