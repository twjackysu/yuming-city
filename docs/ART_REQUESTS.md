# 美術自製進度

> 2026-11-13 起（Jacky 的指示、D-249）：這份**不再是給 Jacky 的需求單**。角色模型、動畫、敵人都由 loop 自己用 Blender（`bpy`）做——腳本在 `tools/blender/`，建置時由 `scripts/gen_art.sh` 產生，不進 git。Jacky 不用再用 ChatGPT／Tripo 產模型；他自己放進 `art-inbox/characters/<id>/<id>.glb` 的照舊優先接入。待辦的順序在 `docs/NEXT.md` 最上面「0000」。

## 進度表

| 項目 | 狀態 | 現在有什麼 | 還缺什麼 |
|---|---|---|---|
| 席菈 模型 | **第一版（樣本），已接進遊戲**（第 101 輪） | MakeHuman CC0 身體＋深色短髮、米灰短披肩、深藍厚布上衣與下襬、皮護臂手套、長褲、皮靴、腰帶；28,136 面、22 根骨頭、一個材質（BaseColor／Normal／ORM 1024²）；通過 `check_character_glb.py` | 披肩胸口缺一塊、眼睛、手指沒握、靴子像襪子、頭髮耳邊、整體偏暗；左耳銅環、右眉疤、三劍銀徽、大劍 |
| 席菈 動作 | 第一版 | `idle`、`walk`、`run`、`light_attack_01`（程式關鍵影格） | 除了跑步都沒有在遊戲畫面上看過；`hit_front`、`death`、`dodge_roll`、連段 |
| 諾恩 模型與動作 | **下一個做**（遊戲裡還是程序人偶；他是玩家整場看著的人，D-250） | — | 同一套：男性 target、縫補過的長大衣、右前臂夾板；動作多 `dodge_roll` 與釋放的姿勢 |
| 一般敵人（拿棍子的、戴護腕的、丟毒瓶的） | 諾恩之後做（程序人偶） | — | 同一套身體換服裝與配色 |
| 送葬者、灰巡者 | 還沒開始（CSG／程序 mesh） | — | 鐵架、鐵鏈這種硬表面最適合程式做；弱點要獨立材質槽（`M_FrameJoint`、`M_Dial`） |
| 概念圖 | Jacky 的 AI 概念草案在 `art-inbox/concepts/`（設計參考） | — | 不擋進度 |
| Steam 素材、配音 | 暫緩／不需要 | — | — |

## 模型要符合的規格（收件檢查 `scripts/check_character_glb.py`）

- `.glb`、含骨架與蒙皮、Y 朝上、公尺、面向 −Z、身高 1.7～1.8 m。
- 主角 15k～40k 三角面；送葬者 30k～60k；灰巡者 10k～20k。
- 每個材質都要有 BaseColor、Normal、ORM（遮蔽與粗糙金屬同一張），貼圖內嵌、2048 以內。
- 動作名稱照 `game/src/world/character_models.gd` 的 `ANIM_MAP`（`idle`、`walk`、`run`、`dodge_roll`、`light_attack_01`）。
- 全年齡、不裸露；不用其他作品的角色、名字、美術。

## 外觀方向（原作第一部第一、二章）

- **席菈**：約 25 歲，沾泥的白色短斗篷，背一把比肩膀還寬的斷劍，左耳一枚銅環，右眉一道舊疤，胸前銀徽（三把交錯的劍）；右手持劍。
- **諾恩**：23 歲，北方小鎮出身的普通青年，縫補過的冬衣；右手骨折後夾著木板。
- **送葬者**：約 2.6 m 高、駝背、黑色長袍，背上綁著生鏽的鐵架（兩根立柱＋三根橫桿），鐵鏈垂到地上，臉藏在兜帽裡；鐵架背面的關節是弱點。
- **灰巡者**：約 1.7 m、佝僂灰色人形、胸口嵌一個鐘盤，雙手是長爪。

## 以前的紀錄

Jacky 11/8～11/10 在本機試作的模型與交件狀態（都沒有正式接進遊戲）：[ART_DELIVERY_STATUS.md](ART_DELIVERY_STATUS.md)、[ART_PRODUCTION.md](ART_PRODUCTION.md)、`art-inbox/studies/`、`docs/art-trials/`。品質標準：[ART_QUALITY_BAR.md](ART_QUALITY_BAR.md)。
