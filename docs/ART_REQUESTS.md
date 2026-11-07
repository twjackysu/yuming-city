# 美術與音效需求（給 Jacky）

依優先順序排列。每一項都已經（或將會）有程式生成的替代品，你沒提供也不會卡住進度；有了就換上去。

## 交件方式（共通）

- 放進 `art-inbox/<類別>/<名稱>/`，例如 `art-inbox/characters/noen/noen.glb`。
- 檔名用小寫英文與底線；附一個 `SOURCE.txt` 寫來源工具或網站、授權、是否 AI 生成。
- 二進位檔請用 Git LFS（`.gitattributes` 已設定）。單檔盡量不超過 50MB。
- 不要使用其他作品的角色、名字、美術或音樂；AI 生成素材請確認該服務允許商業使用。

## 1. 主角諾恩、席菈的角色模型（最高優先）

- 用途：玩家角色與主要同伴。
- 格式：`.glb`（glTF 2.0 binary），含骨架與蒙皮，Y 軸朝上，單位公尺，身高約 1.7–1.8m，面朝 -Z（Godot 前方）。
- 面數：15k–40k 三角面；材質 PBR（BaseColor、Normal、ORM），貼圖 2048×2048 以內，嵌入 glb。
- 骨架：Mixamo 自動綁定的標準人形骨架即可（loop 會在 Godot 用 `SkeletonProfileHumanoid` 重新對應）。
- 外觀方向：寒冷北方小鎮、實用的冬衣與皮革；席菈慣用左手持劍。細節等 `docs/design/03-art-audio-direction.md` 完成後補上參考描述。
- 建議來源：AI 3D 生成（Meshy、Tripo 等）→ Mixamo 自動綁定 → 匯出 FBX 後轉 glb（或直接給 FBX，loop 轉）。
- 命名：`art-inbox/characters/noen/noen.glb`、`art-inbox/characters/sheila/sheila.glb`（英文名暫定，以 `docs/design/01-adaptation.md` 定案為準；資料夾名不影響匯入）。
- 程式替代品：程序生成的低面數人偶（膠囊與方塊組合）＋程式驅動的走路擺動與攻擊動作。

## 2. 角色動畫組（Mixamo）

- 用途：移動、戰鬥、受擊。需要第 1 項的骨架（或 Mixamo 預設角色 Y Bot 的骨架）。
- 清單：idle、walk、run、sprint、dodge roll、劍的 idle、輕攻擊三段、重攻擊、格擋、受擊（前／後）、倒地死亡、起身、互動（伸手）、敲鐘（拉繩）、扛人走路。
- 格式：每個動畫一個 FBX，「Without Skin」，30 fps，In Place（不位移）勾選。
- 命名：`art-inbox/animations/<動作>.fbx`，例如 `dodge_roll.fbx`。
- 程式替代品：程式補間動畫（身體傾斜、肢體擺動、武器軌跡特效）。

## 3. 精英敵人「送葬者」與普通敵人

- 用途：切片的精英戰與一般戰。外觀等設計文件完成後補描述。
- 格式同第 1 項；精英 30k–60k 三角面。
- 程式替代品：CSG／程序 mesh 組成的鐵架怪物，用 shader 做發光弱點。

## 4. 概念圖與 key art

- 用途：統一美術方向，以及之後的 Steam 商店素材。
- 格式：PNG，長邊 2048 以上。主題：霜橋鎮冬夜、廢鐘樓、南街石拱、席菈與諾恩。
- 程式替代品：不需要（只影響方向判斷）。

## 5. 配音

- 目前不需要。切片以字幕演出為主。
