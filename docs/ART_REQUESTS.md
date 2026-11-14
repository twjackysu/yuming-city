# 美術進度

loop 自己的美術待辦（不是給 Jacky 的需求單）。來源優先順序：Jacky 放進 `art-inbox/` 的 → Tripo 佇列的產物（`art-inbox/tripo/`）→ 授權明確的 CC0 套件（`art-inbox/props/`）→ 程式生成。做的順序在 `docs/NEXT.md`。

## Jacky 定下的方向

- 畫風：**漫畫風，帥氣、漂亮、可愛**；人物吃場景的光。標準在 `ART_QUALITY_BAR.md`。
- 人物正常動漫比例：主角約 5.5～6 頭身；莉莉絲、雷歐約 7.5 頭身（Jacky 11/14：不用重產）。接的時候用 `--height` 把身高拉齊。
- 冒險者服裝從 **F 級破舊** 到 **S 級華麗**；之後的等級再用 Tripo 產，或用 bpy 在 F 級模型上加護甲、換配色。
- **武器可換、男主角不拿燈籠**：角色是空手模型，武器是獨立模型，掛在手骨上。
- 場景：Tripo 只做有劇情意義的重點物件；地形、牆、地板用 CC0 套件或程式做；光、霧、色彩在 Godot 裡做。

## 模型（都在 `art-inbox/tripo/<id>/`；2026-11-14 產完）

| 類別 | id | 接進遊戲了嗎 |
|---|---|---|
| 主角 | `noen_rank_f_v2`（諾恩）、`sheila_rank_f`（席菈） | 轉檔有（`gen_art.sh`）；諾恩在遊戲裡，席菈的角色還沒寫 |
| 人物（mixamo 骨架） | `lilith`、`leo`、`leo_party_mage`、`leo_party_tank`、`black_market_merchant`、`royal_inspector`、`guild_adventurer_a`、`guild_adventurer_b` | 還沒 |
| 怪物 | `enemy_poison_slime` | **在遊戲裡**（`Slime`） |
| 怪物 | `enemy_mold_slime`（已擺正）、`enemy_spore_treant`（雙足骨架）、`enemy_miasma_wolf`（四足骨架＋走路）、`boss_plague_golem`（雙足骨架） | 還沒 |
| 武器 | `weapon_rusty_miasma_sword` | **在遊戲裡**（諾恩右手） |
| 武器 | `weapon_ominous_split_blade`、`weapon_longsword`、`weapon_shortsword`、`weapon_axe`、`weapon_hammer`、`weapon_bow`、`weapon_staff`（都已擺正）、`weapon_alchemy_crossbow`（還沒擺正） | 還沒 |
| 森林 | `prop_corrupt_tree`、`prop_glow_toxic_mushroom`、`prop_rotten_fruit_bush` | **在遊戲裡**（腐敗之森入口） |
| 森林 | `prop_campfire_v2`、`prop_cursed_chest`、`prop_ruined_altar`（已擺正）、`prop_poison_vent`、`prop_paralysis_web_v2`、`prop_cursed_ring`（還沒擺正） | 還沒 |
| 公會 | `prop_guild_counter_v2`、`prop_aptitude_crystal`、`prop_guild_quest_board`、`prop_guild_signboard`（已擺正） | 還沒 |

- 「已擺正」＝寫在 `scripts/gen_props.sh` 的 `ARGS` 裡，建置時會出現在 `game/assets/props/tripo/`，可以直接 `PropModels.instance("tripo/<id>")`。
- `prop_poison_vent` 的毒煙是實心模型、還帶兩顆眼睛：只取底座，煙用粒子或 `PoisonMist`。
- 沒用到的在 `art-inbox/tripo/_unused/`（那裡有 README）；不刪。
- 點數：第一批約 500、第二批 1015；餘額約 1985（≈19.85 美元）。預算上限 100 美元。

## 之後可能要排的

席菈腰間的藥瓶與燒焦痕跡（先試 bpy 改）、D／B／S 級服裝、更多森林怪、城鎮的招牌與攤位。排之前先確認 CC0 套件裡沒有。

## 模型規格（收件檢查 `scripts/check_character_glb.py`）

- `.glb`、Y 朝上、公尺、面向 −Z、原點在腳底；人物有骨架與蒙皮，15k～40k 三角面。
- 材質要有 BaseColor、Normal、ORM，貼圖內嵌；動作名稱照 `game/src/world/character_models.gd` 的 `ANIM_MAP`。
- 全年齡、不裸露；不用其他作品的角色、名字、美術；AI 生成的記進 CREDITS 並列入 Steam 申報。
