# 美術交付狀態

本目錄保存概念設計；圖片不是已綁骨架的遊戲角色，也不是固定尺寸的 Steam 商店膠囊圖。

## 驗收狀態

| ART_REQUESTS 項目 | 狀態 | 尚缺 |
|---|---|---|
| 1 主角模型 | 未交付 | 諾恩、席菈正式 GLB、PBR 貼圖、蒙皮及 Godot 驗收 |
| 2 動畫組 | 未交付 | Mixamo 或手工製作的 FBX；不將程序動畫計為交付 |
| 3 敵人模型 | 未交付 | 送葬者、灰巡者 GLB 與指定動作、獨立發光材質槽 |
| 4 概念圖與 key art | 見 concepts 目錄及 manifest.json | 商店裁切、標題排版需另依實際上架尺寸製作 |
| 5 配音 | 不需交付 | 依原需求維持字幕 |

## 後續模型驗收

- 主角：Y-up、公尺、面向 -Z、1.7–1.8m、15k–40k 三角面；有骨架蒙皮；BaseColor/Normal/ORM 內嵌且不超過 2048。
- 諾恩：右臂木板夾傷；建議夾板與手臂分離，避免骨骼動畫把木板彎曲。
- 席菈：短白披風、左耳銅環、右眉疤、三劍銀徽；戰鬥使用右手。武器需可從背部掛點移至右手掛點。
- 送葬者：2.6m、30k–60k 三角面；鐵架兩立柱三橫桿；M_FrameJoint 獨立材質槽；鐵鏈不可改動碰撞判定。
- 灰巡者：1.7m、10k–20k 三角面；鐘盤使用 M_Dial；左膝弱點與現有判定對齊。
- 靜止姿勢、走路、攻擊、倒地皆需檢查穿模、腳滑、武器掛點及弱點位置，模型不得取代既有碰撞／AI 邏輯。

## 動畫交件清單

每支 FBX：Without Skin、30 fps、In Place；統一同一骨架與骨骼命名。躲避翻滾及扛人動作可能需手工修正，不能假設服務中有完全符合的片段。

idle, walk, run, sprint, dodge_roll, sword_idle, light_attack_01, light_attack_02, light_attack_03, heavy_attack, block, hit_front, hit_back, death, get_up, interact_reach, bell_pull, carry_walk。

敵人動作：undertaker_walk, undertaker_sweep, undertaker_slam, undertaker_charge, undertaker_wall_kneel, undertaker_chain_break；ashwalker_walk, ashwalker_claw（0.8 秒前兆）, ashwalker_kneel, ashwalker_death。

每次外部匯入須附 SOURCE.txt：工具、來源連結、授權條件、是否 AI 生成；不能把服務條款標為 CC0。

## 可檢查的工作版本（尚未正式驗收）

- [諾恩](studies/noen/README.md)：角色及 walk。
- [席菈](studies/sheila/README.md)：角色及 walk，尚待戰鬥握姿與斗篷修整。
- [送葬者](studies/undertaker/README.md)：角色、walk、鎖鏈接地與獨立弱點發光檢查。

上述候選不能將正式需求標為完成；遊戲內程序角色仍保留。
