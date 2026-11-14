# 下一輪待辦（依優先順序）

每輪從最上面拿 1～2 項。開工前跑 `scripts/check.sh` 確認全綠。劇本 `docs/story/chapter-1.md`、計畫 `docs/design/13-chapter-1-plan.md`、程式在哪 `docs/design/04-architecture.md`、規則 `docs/design/02-gameplay.md`。截圖與工具的用法在 `04` 的「開發工具」。

## ★ 垂直切片：腐敗之森入口的 3 分鐘

現在有的：諾恩一個人走進森林 → 席菈等在瘴氣前面，問能不能一起去（兩個回答）→ 結伴 → 瘴氣（她戴防毒面具；諾恩中毒 → 回血，完整的反轉回饋）→ 兩人講四句 → 三隻劇毒史萊姆，席菈慌了射錯一瓶（重度麻痺＋防禦歸零 → 出手快 150%＋受傷少 80%）→ 連砍清場 → 戰後對話（兩個回答）→ 「未完待續」。Jacky 11/14 玩過兩次：「還行」；相遇、面具、誤射、戰後對話這幾段他還沒玩過。

1. **諾恩的劍有性格**：每一刀給自己微弱中毒（`on_hit_source = "rusty_sword_cut"`，現在不用先解鎖了）＋新狀態「流血 → 攻速」（越砍越快）；兩到三下的連段。做完重量一次清場時間（`test_overdrive_…` 會印）。
2. **「一刀秒殺」還不是一刀**（D-279）：吃了拿錯的那一瓶是 3 秒連砍。要更接近劇本可以試：超頻時每一刀的打擊停頓縮短、砍中會波及旁邊的（範圍變大）、或那一瓶再帶一種加傷害的狀態。先等 1 做完再量，流血的攻速疊上去可能就夠了。另外平常的藥瓶（×1.35）會幫重度麻痺（×2.5）續時間——同一種狀態只留最強的強度；教學戰幾秒就打完看不出來，之後戰鬥變長要處理（弱的來源不續強的時間，或強度跟著時間退）。
3. **席菈再好一點**：①平常她在鏡頭後面看不到——頭上的話這時候不顯示，教學戰那兩句玩家可能根本沒看到（試：開打時往側面站、或她在鏡頭外時把話放在畫面邊上並標名字）②手弩的握把有沒有在手心（`Sera.CROSSBOW_ROT`／`CROSSBOW_OFFSET`；`BURST_RES=1920x1080 --burst-on=vial --cam-yaw=90`）③走過瘴氣要有反應（劇本：慌張地找防毒面具）④按鍵向她要藥（`SeraBrain.request()` 已經有，接上按鍵與第二種藥）⑤射藥與藥瓶碎掉的聲音現在借用 `whoosh`、`glass_clink` ⑥戰後對話的選項畫面拍一張看排版 ⑦相遇那一段加一點演出（她看著瘴氣猶豫的樣子、開口時鏡頭帶到她的臉）⑧防毒面具現在是程式拼的，玩的距離看得出來；要近看再排 Tripo（物件約 20 點）。
4. **森林再好看一點**（某一輪只動畫面時）：地面還是平的——加緩坡或土堤（先只做玩家走不到的外圍）；樹只有一種模型；史萊姆是紫的、場景也是紫的——給敵人一圈冷色的輪廓光或把牠的顏色往螢光綠偏；天空加星星與月亮；土丘的邊緣從側面近看還有一圈。改前先 `scripts/shots.sh forest --save-baseline`。
5. **要有人玩過才知道的**：被史萊姆連續撞（中毒每 3 秒斷一次又重新上身）時整個畫面一直閃會不會太吵；教學戰那一下（兩種狀態同時上身）回饋夠不夠爽；出手快 150% 手感會不會太飄；三個音效（`curse_sting`、`reversal_shatter`、腳步）沒有人聽過。
6. 切片好玩了再擴：森林完整版 → 祭壇 Boss → 公會大廳 → 城鎮（`13` 的場景表）。**做公會大廳（節點 1）的時候**：兩人在那裡先見到面（席菈縮在角落、被雷歐一起罵），森林口那段對話的自我介紹要跟著改短（D-280）。好感度現在只記數字（`sera.affinity`），還沒有地方看。

## 模型還沒接的

人物（`gen_art.sh` 的 `SRC` 加一行就能用）：lilith、leo、leo_party_mage、leo_party_tank、black_market_merchant、royal_inspector、guild_adventurer_a/b。
有骨架的怪（要先決定走 `gen_art.sh` 還是新寫一個轉檔）：enemy_spore_treant、boss_plague_golem（雙足）、enemy_miasma_wolf（四足，`_anim.glb` 有走路）。
物件已經擺正、可以直接 `PropModels.instance("tripo/…")`：看 `scripts/gen_props.sh` 的 `ARGS`。還沒加的：prop_poison_vent（只取底座，煙用粒子）、prop_paralysis_web_v2、prop_cursed_ring。

## 小事（改到的時候順手）

- `docs/design/04-architecture.md`「還沒整理的舊東西」那一節。
- 一瓶藥帶兩種狀態時，`curse_sting`（紫紅那一聲）會在同一幀播兩次，比平常大聲：`PlayerController._on_status_changed` 在回饋剛開始的那一幀（`reversal_cue.t == 0`）不要再播一次。
- `statuses.json` 的 `paralysis_on_hit`、`boss_miasma`、道具 `sera_poison_vial`（`PotionBelt`）現在沒有場景在用：接劍的自傷、Boss、背包時用上，用不上就刪。
- 標題畫面的背景換成新遊戲的（現在是舊的鐘樓剪影）。
- 腳步聲沒有「土」的材質（森林現在借用雪的）。
- 席菈走路沒有腳步聲：接 `Puppet.footfall`（做法看 `PlayerController`，小聲一點）。
- 程式人偶（沒有模型時的替身）的步頻還是舊的算法，跟模型不完全一樣；模型都在的時候看不到。
- `scripts/shots.sh forest --fetch-baseline` 抓不到基準（`screens` release 沒有 `forest-*.png`）：看 CI 有沒有在上傳，沒有就把那個選項拿掉或補上傳。
