# 美術進度

這份是 loop 自己的美術待辦，不是給 Jacky 的需求單（D-249）。來源優先順序：Jacky 放進 `art-inbox/` 的 → Tripo 佇列的產物（`art-inbox/tripo/`，D-270）→ 授權明確的現成 CC0 素材 → `tools/blender/` 自製。做的順序在 `docs/NEXT.md`。

## Jacky 定下的方向（2026-11-13～14）

- 畫風：**漫畫風，帥氣、漂亮、可愛**。人物吃場景的光（D-255）。
- 兩個主角都是**正常動漫比例（約 6 頭身）**：Jacky 11/14 決定諾恩重產成 `noen_rank_f_v2`，Q 版的 `noen_rank_f` 不用。
- 兩人是冒險者：一開始是剛進冒險者公會的 **F 級、破舊服裝**，裝備越好服裝越好，**最高 S 級**。之後的等級可以用 Tripo 再產，或用 bpy 在 F 級模型上加護甲、換配色。
- **武器可換、男主角不拿燈籠**：角色是空手模型，武器是獨立模型，掛在手骨上依裝備切換。諾恩初始【瘴氣生鏽鐵劍】（近戰），席菈【鍊金藥瓶手弩】（後排）。
- 場景要有冒險感：建築、街道用 CC0 模組化套件拼，Tripo 只做有劇情意義的重點物件，光影、霧、材質在 Godot 裡做。

## 進度表（第一章；劇本 `docs/story/chapter-1.md`）

| 項目 | 來源 | 狀態 |
|---|---|---|
| 諾恩 F 級 | Tripo `noen_rank_f_v2` | 已接進遊戲（戰鬥場與劇情） |
| 席菈 F 級 | Tripo `sheila_rank_f` | 已接進遊戲；之後用 bpy 在腰間加藥瓶 |
| 第一批武器（長劍、短劍、斧、槌、法杖、弓） | Tripo `weapon_*` | 已擺正（`scripts/gen_props.sh`）；長劍、法杖在用 |
| **第二批 28 個**（2026-11-14 全部產完，在 `art-inbox/tripo/`）：三把新武器（`weapon_rusty_miasma_sword`、`weapon_alchemy_crossbow`、`weapon_ominous_split_blade`）、8 個人物（`lilith`、`leo`、`leo_party_mage`、`leo_party_tank`、`black_market_merchant`、`royal_inspector`、`guild_adventurer_a/b`，都有 mixamo 骨架）、5 種敵人（`enemy_poison_slime`、`enemy_mold_slime`、`enemy_miasma_wolf`〔四足骨架＋走路〕、`enemy_spore_treant`、`boss_plague_golem`〔雙足骨架〕）、12 個物件（`prop_*`；營火、蜘蛛網、櫃檯用 `_v2`，第一版混進小人在 `_unused/`） | Tripo | **已產、還沒接進遊戲**：照 NEXT ★ 的垂直切片順序接（`scripts/gen_art.sh`／`gen_props.sh` 加條目）。莉莉絲、雷歐約 7.5 頭身，比主角（5.5～6）高瘦，接的時候用 `--height` 拉齊，Jacky 看過再決定要不要重產。`prop_poison_vent` 的毒煙是實心模型且帶兩顆眼睛，可能只取底座、煙用粒子 |
| 森林的地形、樹叢、岩石；公會與城鎮的牆、地板、家具 | CC0 模組化套件＋現有霜橋鎮 | 還沒選；先看 KayKit（GitHub 抓得到）、Quaternius Medieval Village（要 Jacky 下載） |
| 之後：服裝等級（D／B／S）、更多敵人與 NPC | Tripo 或 bpy 改色加甲 | 第一章做完再排 |
| 舊劇情的模型（送葬者、毒藥桶、斷街燈、推車） | Tripo 第一批 | 不再接（舊劇情）；毒藥桶已在舊試玩裡 |

預算：Jacky 願意投入到 100 美元（11/14）。第一章估 15～25 美元含重產。

## 模型規格（收件檢查 `scripts/check_character_glb.py`）

- `.glb`、Y 朝上、公尺、面向 −Z、原點在腳底；人物有骨架與蒙皮。
- 主角 15k～40k 三角面（Q 版身高另訂）；送葬者 30k～60k；灰巡者 10k～20k。
- 材質要有 BaseColor、Normal、ORM，貼圖內嵌、2048 以內。
- 動作名稱照 `game/src/world/character_models.gd` 的 `ANIM_MAP`。
- 全年齡、不裸露；不用其他作品的角色、名字、美術；AI 生成的記進 CREDITS 並列入 Steam 申報。

## 舊紀錄

11/8～11/10 的本機寫實試作（MakeHuman、TripoSR、TRELLIS）與概念圖已刪除（2026-11-14），要查看 git 歷史。
