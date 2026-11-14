# 13　第一章實作計畫

劇本：[`../story/chapter-1.md`](../story/chapter-1.md)（Jacky 2026-11-14）。這份寫「怎麼做、先做什麼、用現有的什麼」。做完一項就在這裡打勾；細的待辦寫 NEXT。

## 核心循環（每個設計決定都回頭對這一句）

**故意去吃異常狀態 → 看它反轉成金色增益 → 用增益打爆敵人。** 陷阱、毒霧、詛咒裝備、席菈射來的藥水，都是「補給」。

## 反轉的回饋（劇本第三節，最優先做好）

吃到異常狀態：畫面邊緣閃紫／暗紅 → 0.3 秒後玻璃碎裂聲 → 轉成金色光效；HUD 上紅色 Debuff 圖示翻成金色 Buff 圖示。諾恩的劍在有反轉中的狀態時裂縫透金光。現有的 `ReversalSlots`、狀態 HUD、`status_effects` 直接擴充。

## 現況（2026-11-14 重新開始，D-273）

舊劇情的關卡與角色都砍了，只留通用底層（清單在 [`04-architecture.md`](04-architecture.md)）。現在標題按「新遊戲」會進**腐敗之森入口**的最小版：諾恩拿【瘴氣生鏽鐵劍】→ 走進瘴氣中毒、反轉成回血 → 空地上三隻劇毒史萊姆。席菈還沒進場。Tripo 第二批 28 個模型都在 `art-inbox/tripo/`，大部分還沒接。

## 場景（照做的順序）

| # | 場景 | 對應劇本 | 現況 |
|---|---|---|---|
| 1 | 腐敗之森入口＋一小段森林 | 節點 2 | **有最小版**（`scenes/levels/corrupt_forest.gd`）：平地、Tripo 的樹與毒蕈、一團瘴氣、三隻史萊姆。要補：地形起伏與地面材質、光與霧、席菈、開場對話、反轉的回饋 |
| 2 | 森林完整版（營火、毒沼、陷阱、詛咒寶箱、5 朵夜光毒蕈） | 時段 B | 沒有。模型有：`prop_campfire_v2`、`prop_poison_vent`、`prop_paralysis_web_v2`、`prop_rotten_fruit_bush`、`prop_cursed_chest`、`enemy_mold_slime`、`enemy_miasma_wolf`、`enemy_spore_treant` |
| 3 | 廢棄祭壇（Boss） | 節點 3 | 沒有。模型有：`prop_ruined_altar`、`boss_plague_golem`、`leo`、`leo_party_mage`、`leo_party_tank` |
| 4 | 公會大廳 | 節點 1、結尾 | 沒有。模型有：`lilith`、`prop_guild_counter_v2`、`prop_aptitude_crystal`、`prop_guild_quest_board`、`prop_guild_signboard`、`guild_adventurer_a/b`、`royal_inspector` |
| 5 | 城鎮（公會外、黑市商人、酒館地下室） | 時段 A | 沒有。模型有：`black_market_merchant`、`prop_cursed_ring`；建築用 `art-inbox/props/` 的 CC0 套件 |

**先把 1 做成好玩的 3 分鐘（垂直切片）**：進森林 → 吸到瘴氣反轉（有完整回饋）→ 三隻史萊姆 → 席菈誤射藥水 → 超頻一刀清場 → 戰後對話。核心循環、兩個主角、兩把新武器、反轉回饋全部驗證一次，好玩了再往外擴。

## 系統

| 系統 | 內容 | 現況 |
|---|---|---|
| 異常狀態 → 增益 | 中毒→回血、流血→攻速、麻痺→神經超頻（攻速 +150%）、防禦歸零→鋼鐵壁壘（減傷 80%）、致盲→鷹眼暴擊、衰弱→？、石化→霸體無敵、全能力下降→全能力提升 | 有中毒、麻痺；照 `data/status/statuses.json` 加（規則見 [`02-gameplay.md`](02-gameplay.md)） |
| 反轉的回饋 | 閃紫 → 0.3 秒 → 碎裂聲 → 金光；HUD 紅圖示翻金；劍的裂縫透金光 | 只有狀態列的字與回血光點；**最優先** |
| 諾恩的武器 | 【瘴氣生鏽鐵劍】：近戰連段；每一刀給自己「微弱流血＋中毒」（越砍越快）。之後【不祥的裂刃】 | 劍在手上、一刀一刀砍；連段與自傷還沒有（來源 `rusty_sword_cut` 已經在表裡，接 `PlayerController.on_hit_source` 的做法） |
| 席菈 | AI 隊友：跟在後面 4～6 m、定時用【鍊金藥瓶手弩】往諾恩射負面藥水或往敵人丟負面領域；按 Q 指定下一瓶 | 沒有（模型有；`weapon_alchemy_crossbow` 還沒加進 `gen_props.sh`）。新寫一個小的，不要照以前近戰版的做法 |
| 陷阱與毒物 | 毒氣噴發口、麻痺蜘蛛網、腐敗野果：碰到就上狀態 | `PoisonMist`／`MistZone` 可以直接當狀態區用 |
| 裝備面板 | 飾品欄（詛咒飾品）、武器欄；面板上看得到紅圖示翻金 | 沒有（先做最小的：兩格） |
| 委託 | 主線＋2 個支線、右上角目標清單（`[0/5] 採集夜光毒蕈`） | 任務引擎有；清單 UI 要做 |
| 好感度 | 席菈的對話選項加減分；營火事件 | 沒有；對話的 `do` 可以加減旗標 |
| 金錢與商人 | 初始資金、黑市商人賣詛咒飾品 | 沒有 |
| Boss | 【深淵疫病魔像】：光環、狂暴、石化凝視、要擋在席菈前面、最後一擊由席菈的藥劑收尾 | 沒有；`EnemyBrain` 支援多招與招式順序（`<id>.moves`／`pattern`） |

## 模型

清單與接入狀態在 [`../ART_REQUESTS.md`](../ART_REQUESTS.md)。還缺的再排進 `art-inbox/tripo/queue.json`（Jacky 本機產；餘額約 1985 點，預算上限 100 美元）。

## 不做的事

- 不把舊劇情的東西搬回來（要參考去分支 `archive/pre-restart-2026-11-14` 看）。
- 第一章做完之前不開第二章。
- 過場用遊戲內鏡頭＋對話框，不做預錄影片。
