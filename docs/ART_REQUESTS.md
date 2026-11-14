# 美術進度

這份是 loop 自己的美術待辦，不是給 Jacky 的需求單（D-249）。來源優先順序：Jacky 放進 `art-inbox/` 的 → Tripo 佇列的產物（`art-inbox/tripo/`，D-270）→ 授權明確的現成 CC0 素材 → `tools/blender/` 自製。做的順序在 `docs/NEXT.md`。

## Jacky 定下的方向（2026-11-13～14）

- 畫風：**漫畫風，帥氣、漂亮、可愛**。人物吃場景的光（D-255）。
- 兩個主角都是**正常動漫比例（約 6 頭身）**：Jacky 11/14 決定諾恩重產成 `noen_rank_f_v2`，Q 版的 `noen_rank_f` 不用。
- 兩人是冒險者：一開始是剛進冒險者公會的 **F 級、破舊服裝**，裝備越好服裝越好，**最高 S 級**。之後的等級可以用 Tripo 再產，或用 bpy 在 F 級模型上加護甲、換配色。
- **武器可換、男主角不拿燈籠**：角色是空手模型，武器是獨立模型，掛在手骨上依裝備切換（長劍、短劍、斧、槌、法杖、弓）。
- 場景要有冒險感：建築、街道用 CC0 模組化套件拼，Tripo 只做有劇情意義的重點物件，光影、霧、材質在 Godot 裡做。

## 進度表

| 項目 | 來源 | 狀態 | 下一步 |
|---|---|---|---|
| 諾恩 F 級 | Tripo `noen_rank_f_v2`（正常比例，Mixamo 骨架；Q 版 `noen_rank_f` 不用） | 重產中 | bpy 修朝向／原點／縮放 → 重定向到 Godot humanoid → 取代 VRoid 版 |
| 席菈 F 級 | Tripo `sheila_rank_f` | 已接進遊戲（D-271，`tools/blender/tripo_character.py`） | 補動作、武器掛點 |
| 送葬者 | Tripo `undertaker`（walk／slash） | 已產生，未接 | 接進開場與戰鬥場；弱點要獨立材質槽 `M_FrameJoint` |
| 六把武器 | Tripo `weapon_*` | 已產生，未接 | 做成手骨上的可換裝備；先給諾恩一把 |
| 開場物件 | Tripo `prop_poison_barrel`、`prop_broken_lamppost`、`prop_supply_cart`；公會 `prop_guild_quest_board` | 已產生，未接 | 放進開場南街與公會 |
| 地下市場小物 | Quaternius CC0（`art-inbox/props/`，D-258） | 已進 repo | 換掉攤位、木桶、木箱、瓶子 |
| 現在遊戲裡的主角 | VRoid CC0＋自製服裝（D-253、D-264） | 使用中 | Tripo 版接好後退役 |
| 一般敵人、灰巡者 | 程序人偶 | 未開始 | 點數不夠就用 bpy 改既有模型或找 CC0 |
| 動作 | Tripo idle／walk／run；`common.py` 自製 | 部分 | 補 `dodge_roll`、攻擊、受擊、倒下（自製或 CC0 動捕） |

## 模型規格（收件檢查 `scripts/check_character_glb.py`）

- `.glb`、Y 朝上、公尺、面向 −Z、原點在腳底；人物有骨架與蒙皮。
- 主角 15k～40k 三角面（Q 版身高另訂）；送葬者 30k～60k；灰巡者 10k～20k。
- 材質要有 BaseColor、Normal、ORM，貼圖內嵌、2048 以內。
- 動作名稱照 `game/src/world/character_models.gd` 的 `ANIM_MAP`。
- 全年齡、不裸露；不用其他作品的角色、名字、美術；AI 生成的記進 CREDITS 並列入 Steam 申報。

## 舊紀錄

11/8～11/10 的本機寫實試作（MakeHuman、TripoSR、TRELLIS）與概念圖已刪除（2026-11-14），要查看 git 歷史。
