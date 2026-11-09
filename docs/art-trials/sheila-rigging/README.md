# 席菈模型與 walk 製作試作（2026-11-09）

可檢查的候選 GLB／FBX 與 Godot 影片見 [工作版本](../../../art-inbox/studies/sheila/README.md)。此模型尚未通過美術驗收；完整待修項目與授權見候選資料夾 README 及 SOURCE.txt。

Blender 5.2.3、MPFB 與 TripoSG 版本沿用 [諾恩製作紀錄](../noen-rigging/README.md)。新增的官方 CC0 皮膚與馬尾由 `fetch_sheila_assets.py` 取得。冬衣素材來自 punkduck / CC BY 3.0，靴子沿用本專案先前製作並重新配合腿部。

執行順序：`build_sheila_base.py` → `assemble_sheila.py` → `project_sheila.py` → `bake_sheila.py` → `finish_sheila_materials.py` → `add_sheila_weapon_socket.py`。Blender 呼叫格式為 `blender -b --offline-mode --python-exit-code 1 --python SCRIPT.py`。

環境變數 `SHEILA_PRODUCTION` 指向模型工作目錄；`YUMING_MPFB_SOURCE`、`YUMING_MPFB_USER`、`YUMING_MPFB_ASSETS` 沿用諾恩；`SHEILA_BOOT_SOURCE` 指向含已完成獨立靴子的 `noen_candidate_v2.blend`。`SHEILA_FRONT_IMAGE` 與 `SHEILA_REAR_IMAGE` 分別指向 inputs 裡的固定材質參考。

動畫另使用 `SHEILA_WORK` 目錄，先將模型 `.blend` 複製為 `tailored_noen.blend`、GLB 複製為 `tailored_candidate.glb`（沿用試作工具的歷史檔名），再執行 `retarget_sheila_walk.py` → `export_sheila_walk.py` → `review_sheila_walk.py`。走路原始資料與授權詳 SOURCE.txt。Godot 檢視場景需放入輸出的 `sheila_walk_preview.glb`，可擷取 34 個時間點，`check_ground.gd` 以實際蒙皮資料檢查鞋底位置。

已處理的實際問題：斗篷與肩部的站姿穿模、肩膀動作權重差異、背劍與斗篷交叉、褲腳與靴筒相交，以及前方角色顏色被投射到劍身。劍身兩面使用無遮擋的背面材質參考；其他表面按物件遮擋選擇投射與原材質。這些處理仍需在更多姿勢下驗證。

inputs 的圖片由 OpenAI image generation 依固定鏡頭渲染製作，僅是表面材質參考，並非模型實機截圖。提示摘要：保留相機、幾何與位置，添加泥濘白羊毛短斗篷、暗色絎縫衣、皮革、舊鋼鐵、銅環、三劍徽章與右眉舊疤；背面需維持既有寬斷劍輪廓。投射包含對這一批輸入的畫布校正，不宜直接套用任意新圖。

## 大劍重製與三材質（2026-11-09）

本輪只採用大劍與材質整併。新披肩幾版有肩部穿插、上臂拉扯或不符外觀的缺口，未採用；工作 GLB 仍保留舊披肩，不能將 FOR_JACKY 第四點的披肩意見標成已解決。

重現順序：

1. `rebuild_sheila_sword.py`：YUMING_SHEILA_BASE_BLEND 指向先前 53 骨的 tailored_baked.blend，YUMING_SHEILA_WEAPON_WORK 指向新工作目錄；輸出 source.blend。新劍身有漸縮、中央槽、斜刃、斷口厚度、彎護手、圓柄／皮革纏繞／柄頭。徽章不包含在刪除舊大劍的範圍。
2. `bake_sheila_three_materials.py`：YUMING_SHEILA_SOURCE_BLEND 指向 source.blend；YUMING_SHEILA_ATLAS_WORK 指向工作目錄。三材質各 BaseColor／Normal／ORM，2048 square。保留 SourceUV 重烘焙目的切線法線；UV pack 使用精確比例 0.005（約 10.24px），烘焙擴邊 4px。
3. `split_sheila_atlas_weapon.py`：同一 YUMING_SHEILA_ATLAS_WORK；輸出獨立 Sheila_Broken_Sword 網格，仍與衣物共用同一材質。它也修正舊版「名稱包含 Sword 就綁 weapon_socket」誤中胸前 Badge_Sword 的問題：前胸 48 個徽章頂點回綁 Spine2。大劍才由 weapon_socket 單骨影響。後續不應再用過寬的 Sword 字串篩選徽章。
4. 沿用先前 walk_trial.fbx，設定 SHEILA_WORK 為新目錄，執行 review_sheila_walk.py。FBX 沒有改動，仍為 53 骨／30fps／無模型。
5. `check_sheila_body_preservation.py` 比對前版與新版 35 幀的實際蒙皮點雲，排除更換的大劍，也排除 glTF 匯入器建立、未綁骨的 Icosphere 顯示輔助物。非武器頂點最大雙向距離約 0.000742mm，低於 0.01mm。此結果證明沒有改壞既有身體／披肩幾何，也代表沒有解決舊披肩穿插。

Godot 使用 godot_review_atlas：複製 sheila_walk_preview.glb → import → configure_material_import.py → 再 import。材質匯入腳本僅恢復 M_Sheila_Hair specular=0.06；標準棚光改用 shadow_bias=0.1、shadow_normal_bias=0.5，減少先前自陰影網紋。check_ground.gd 覆蓋所有蒙皮網格 35 幀。blade_review.tscn、night_review.tscn 提供劍身背面與實際共用夜景材質檢視。

目前 38,396 三角面／53 骨／4 網格／3 材質／9 張 2K PNG。Godot 接地、獨立大劍單骨、貼圖尺寸與結構 gate 通過，未通過正式美術及全動作碰撞驗收；仍只含 walk。
