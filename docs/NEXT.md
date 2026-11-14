# 下一輪待辦（依優先順序）

每輪從最上面拿 1～2 項。開工前跑 `scripts/check.sh` 確認全綠。劇本 `docs/story/chapter-1.md`、計畫 `docs/design/13-chapter-1-plan.md`、程式在哪 `docs/design/04-architecture.md`、規則 `docs/design/02-gameplay.md`。截圖與工具的用法在 `04` 的「開發工具」。

## ★ 垂直切片：腐敗之森入口的 3 分鐘

現在有的：諾恩（Tripo 模型、鏽劍）與席菈（Tripo 模型、手弩；開場站在旁邊，之後跟在後面 4.5～6 m）→ 瘴氣（中毒 → 反轉成回血，**有完整的反轉回饋**）→ 兩人講四句 → 三隻劇毒史萊姆（開打後席菈每 9 秒往諾恩背上射一瓶麻痺 → 出手加速）→ 打完跳橫幅。沒有人真的玩過。

1. **反轉欄位拿掉，改成全部都反轉**（做 2、3 之前先做，不然第三種狀態沒有格子）：劇本是「落在諾恩身上的異常狀態全部反轉」，`ReversalSlots`（兩格、要解鎖）是重新開始前的設計。現在席菈的藥瓶落地時自己把麻痺裝進欄位（`SeraVial._land()`）——拿掉欄位時一起刪。要動：`StatusEffects.is_reversed`、存檔的 `reversal`（版本 +1＋遷移）、`ReversalCue` 「不會反轉的只有紫紅」那條路留給以後敵人身上的狀態或直接刪、相關測試。
2. **教學戰照劇本走**：史萊姆出現 → 席菈慌了（喊一句）誤射【重度麻痺＋防禦歸零】→ 面板跳【神經超頻】【鋼鐵壁壘】→ 一刀清場 → 戰後對話（兩個選項，記好感度旗標）。要加狀態「防禦歸零 → 減傷」；麻痺的倍率現在 ×1.35，劇本是攻速 +150%，「一刀清場」要調到真的清得掉。`tests/flow/test_chapter1.gd` 跟著延長到這裡。
3. **諾恩的劍有性格**：每一刀給自己微弱中毒（`on_hit_source = "rusty_sword_cut"`）＋新狀態「流血 → 攻速」；兩到三下的連段。
4. **席菈再好一點**：①平常她在鏡頭後面看不到——試試讓她跟在斜後方、偏鏡頭看得到的那一側，或開打時往側面站 ②手弩的方向是對的（順著前臂指向諾恩），握把有沒有在手心要更近才看得出來（`Sera.CROSSBOW_ROT`／`CROSSBOW_OFFSET`；現在最近的看法是 `BURST_RES=1920x1080 --burst-on=vial --cam-yaw=90`）③走過瘴氣要有反應（劇本：慌張地找防毒面具）——戴面具的樣子要排 Tripo 或先用對話帶過 ④按鍵向她要藥（`SeraBrain.request()` 已經有，接上按鍵與第二種藥）⑤射藥與藥瓶碎掉的聲音現在借用 `whoosh`、`glass_clink`。
5. **森林再好看一點**（做完 1～3 再回來，或某一輪剛好只動畫面時）：地面還是平的——加緩坡或土堤（碰撞要跟著改，先只做玩家走不到的外圍）；樹只有一種模型——要第二種樹或枯木得排 Tripo；史萊姆是紫的、場景也是紫的——給敵人一圈冷色的輪廓光或把牠的顏色往螢光綠偏；天空加星星與月亮（要寫 sky shader）；土丘的邊緣從側面近看還有一圈。改前先 `scripts/shots.sh forest --save-baseline`。
6. **反轉回饋要有人玩過才知道的**：被史萊姆連續撞（中毒每 3 秒斷一次又重新上身）時整個畫面一直閃會不會太吵——太吵就讓短時間內重複的那幾次只播圖示與劍、不播整個畫面；兩個新音效（`curse_sting`、`reversal_shatter`）沒有人聽過。
7. 切片好玩了再擴：森林完整版 → 祭壇 Boss → 公會大廳 → 城鎮（`13` 的場景表）。

## 模型還沒接的

人物（`gen_art.sh` 的 `SRC` 加一行就能用）：lilith、leo、leo_party_mage、leo_party_tank、black_market_merchant、royal_inspector、guild_adventurer_a/b。
有骨架的怪（要先決定走 `gen_art.sh` 還是新寫一個轉檔）：enemy_spore_treant、boss_plague_golem（雙足）、enemy_miasma_wolf（四足，`_anim.glb` 有走路）。
物件已經擺正、可以直接 `PropModels.instance("tripo/…")`：看 `scripts/gen_props.sh` 的 `ARGS`。還沒加的：prop_poison_vent（只取底座，煙用粒子）、prop_paralysis_web_v2、prop_cursed_ring。

## 小事（改到的時候順手）

- `docs/design/04-architecture.md`「還沒整理的舊東西」那一節。
- 標題畫面的背景換成新遊戲的（現在是舊的鐘樓剪影）。
- 腳步聲沒有「土」的材質（森林現在借用雪的）。
- 席菈走路沒有腳步聲：接 `Puppet.footfall`（做法看 `PlayerController`，小聲一點）。
- 程式人偶（沒有模型時的替身）的步頻還是舊的算法，跟模型不完全一樣；模型都在的時候看不到。
- `scripts/shots.sh forest --fetch-baseline` 抓不到基準（`screens` release 沒有 `forest-*.png`）：看 CI 有沒有在上傳，沒有就把那個選項拿掉或補上傳。
