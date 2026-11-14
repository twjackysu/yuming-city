# 下一輪待辦（依優先順序）

每輪從最上面拿 1～2 項。開工前跑 `scripts/check.sh` 確認全綠。劇本 `docs/story/chapter-1.md`、計畫 `docs/design/13-chapter-1-plan.md`、程式在哪 `docs/design/04-architecture.md`、規則 `docs/design/02-gameplay.md`。截圖與工具的用法在 `04` 的「開發工具」。

## ★ 垂直切片：腐敗之森入口的 3 分鐘

現在有的：諾恩（Tripo 模型、鏽劍）→ 瘴氣（中毒 → 反轉回血，任務往下走）→ 三隻劇毒史萊姆（會追、會撲、撞到上毒）→ 打完跳橫幅。沒有人真的玩過，也還不好看。

1. **反轉的回饋**（這個遊戲的招牌）：吃到異常狀態 → 畫面邊緣閃紫／暗紅 → 0.3 秒 → 玻璃碎裂聲 → 金光；狀態列的紅圖示翻成金色。先做中毒，做成共用的（之後每種狀態都走這個）。用 `scripts/burst.sh` 連拍驗收。
2. **森林看起來像森林**：地面現在是一片平的色塊——加地形起伏或至少地面材質與落葉雜物；光與霧（體積霧現在幾乎看不出來、瘴氣的貼地霧盤還是綠色的，改成紫黑：`src/world/poison_mist.gdshader`）；樹的密度與遠景；路邊的毒蕈會發光。改前先 `scripts/shots.sh forest --save-baseline`。
3. **席菈進場**：新寫 `scenes/actors/sera/`（id 還是 `sheila`）：跟在諾恩後面 4～6 m、手上【鍊金藥瓶手弩】（`weapon_alchemy_crossbow`，先加進 `gen_props.sh`）、每隔幾秒往諾恩拋一瓶負面藥水（落點有反轉回饋）。先做一種藥（麻痺 → 神經超頻，來源 `sera_paralysis_vial`）。開場接 `ch1_forest_gate` 那段對話。
4. **諾恩的劍有性格**：每一刀給自己微弱中毒（`on_hit_source = "rusty_sword_cut"`）＋新狀態「流血 → 攻速」；兩到三下的連段；有反轉中的狀態時劍的裂縫透金光。
5. **教學戰照劇本走**：史萊姆出現 → 席菈慌了誤射【重度麻痺＋防禦歸零】→ 面板跳【神經超頻】【鋼鐵壁壘】→ 一刀清場 → 戰後對話（兩個選項，記好感度旗標）。`tests/flow/test_chapter1.gd` 跟著延長到這裡。
6. 切片好玩了再擴：森林完整版 → 祭壇 Boss → 公會大廳 → 城鎮（`13` 的場景表）。

## 模型還沒接的

人物（`gen_art.sh` 的 `SRC` 加一行就能用）：lilith、leo、leo_party_mage、leo_party_tank、black_market_merchant、royal_inspector、guild_adventurer_a/b。
有骨架的怪（要先決定走 `gen_art.sh` 還是新寫一個轉檔）：enemy_spore_treant、boss_plague_golem（雙足）、enemy_miasma_wolf（四足，`_anim.glb` 有走路）。
物件已經擺正、可以直接 `PropModels.instance("tripo/…")`：看 `scripts/gen_props.sh` 的 `ARGS`。還沒加的：weapon_alchemy_crossbow、prop_poison_vent（只取底座，煙用粒子）、prop_paralysis_web_v2、prop_cursed_ring。

## 小事（改到的時候順手）

- `docs/design/04-architecture.md`「還沒整理的舊東西」那一節。
- 標題畫面的背景換成新遊戲的（現在是舊的鐘樓剪影）。
- 腳步聲沒有「土」的材質（森林現在借用雪的）。
