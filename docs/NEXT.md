# 下一輪待辦（依優先順序）

每輪從最上面拿 1～2 項。開工前跑 `scripts/check.sh` 確認全綠。劇本 `docs/story/chapter-1.md`、計畫 `docs/design/13-chapter-1-plan.md`、程式在哪 `docs/design/04-architecture.md`、規則 `docs/design/02-gameplay.md`。截圖與工具的用法在 `04` 的「開發工具」。

## ★ 垂直切片：腐敗之森入口的 3 分鐘

現在有的：諾恩（Tripo 模型、鏽劍）→ 瘴氣（中毒 → 反轉成回血，**有完整的反轉回饋**：邊緣紫紅 → 碎裂 → 金光、圖示翻金、劍透金光）→ 三隻劇毒史萊姆（會追、會撲、撞到上毒）→ 打完跳橫幅。場景有了氣氛（苔與土的地面、草叢、紫霧、發光的毒蕈、孢子），還缺兩個主角的互動。沒有人真的玩過。

1. **席菈進場**：新寫 `scenes/actors/sera/`（id 還是 `sheila`）：跟在諾恩後面 4～6 m、手上【鍊金藥瓶手弩】（`weapon_alchemy_crossbow`，先加進 `gen_props.sh`）、每隔幾秒往諾恩拋一瓶負面藥水（上狀態就會自動播反轉回饋，不用另外寫）。先做一種藥（麻痺 → 神經超頻，來源 `sera_paralysis_vial`；記得把麻痺裝進反轉欄位，不然只有紫紅）。開場接 `ch1_forest_gate` 那段對話。
2. **諾恩的劍有性格**：每一刀給自己微弱中毒（`on_hit_source = "rusty_sword_cut"`）＋新狀態「流血 → 攻速」；兩到三下的連段。
3. **教學戰照劇本走**：史萊姆出現 → 席菈慌了誤射【重度麻痺＋防禦歸零】→ 面板跳【神經超頻】【鋼鐵壁壘】→ 一刀清場 → 戰後對話（兩個選項，記好感度旗標）。`tests/flow/test_chapter1.gd` 跟著延長到這裡。
4. **森林再好看一點**（做完 1～3 再回來，或某一輪剛好只動畫面時）：地面還是平的——加緩坡或土堤（碰撞要跟著改，先只做玩家走不到的外圍）；樹只有一種模型——要第二種樹或枯木得排 Tripo；史萊姆是紫的、場景也是紫的——給敵人一圈冷色的輪廓光或把牠的顏色往螢光綠偏；天空加星星與月亮（要寫 sky shader）；土丘的邊緣從側面近看還有一圈。改前先 `scripts/shots.sh forest --save-baseline`。
5. **反轉回饋要有人玩過才知道的**：被史萊姆連續撞（中毒每 3 秒斷一次又重新上身）時整個畫面一直閃會不會太吵——太吵就讓短時間內重複的那幾次只播圖示與劍、不播整個畫面；兩個新音效（`curse_sting`、`reversal_shatter`）沒有人聽過。
6. 切片好玩了再擴：森林完整版 → 祭壇 Boss → 公會大廳 → 城鎮（`13` 的場景表）。

## 模型還沒接的

人物（`gen_art.sh` 的 `SRC` 加一行就能用）：lilith、leo、leo_party_mage、leo_party_tank、black_market_merchant、royal_inspector、guild_adventurer_a/b。
有骨架的怪（要先決定走 `gen_art.sh` 還是新寫一個轉檔）：enemy_spore_treant、boss_plague_golem（雙足）、enemy_miasma_wolf（四足，`_anim.glb` 有走路）。
物件已經擺正、可以直接 `PropModels.instance("tripo/…")`：看 `scripts/gen_props.sh` 的 `ARGS`。還沒加的：weapon_alchemy_crossbow、prop_poison_vent（只取底座，煙用粒子）、prop_paralysis_web_v2、prop_cursed_ring。

## 小事（改到的時候順手）

- `docs/design/04-architecture.md`「還沒整理的舊東西」那一節。
- 標題畫面的背景換成新遊戲的（現在是舊的鐘樓剪影）。
- 腳步聲沒有「土」的材質（森林現在借用雪的）。
