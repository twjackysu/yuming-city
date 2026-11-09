# 席菈模型與 walk 製作試作（2026-11-09）

可檢查的候選 GLB／FBX 與 Godot 影片見 [工作版本](../../../art-inbox/studies/sheila/README.md)。此模型尚未通過美術驗收；完整待修項目與授權見候選資料夾 README 及 SOURCE.txt。

Blender 5.2.3、MPFB 與 TripoSG 版本沿用 [諾恩製作紀錄](../noen-rigging/README.md)。新增的官方 CC0 皮膚與馬尾由 `fetch_sheila_assets.py` 取得。冬衣素材來自 punkduck / CC BY 3.0，靴子沿用本專案先前製作並重新配合腿部。

執行順序：`build_sheila_base.py` → `assemble_sheila.py` → `project_sheila.py` → `bake_sheila.py` → `finish_sheila_materials.py` → `add_sheila_weapon_socket.py`。Blender 呼叫格式為 `blender -b --offline-mode --python-exit-code 1 --python SCRIPT.py`。

環境變數 `SHEILA_PRODUCTION` 指向模型工作目錄；`YUMING_MPFB_SOURCE`、`YUMING_MPFB_USER`、`YUMING_MPFB_ASSETS` 沿用諾恩；`SHEILA_BOOT_SOURCE` 指向含已完成獨立靴子的 `noen_candidate_v2.blend`。`SHEILA_FRONT_IMAGE` 與 `SHEILA_REAR_IMAGE` 分別指向 inputs 裡的固定材質參考。

動畫另使用 `SHEILA_WORK` 目錄，先將模型 `.blend` 複製為 `tailored_noen.blend`、GLB 複製為 `tailored_candidate.glb`（沿用試作工具的歷史檔名），再執行 `retarget_sheila_walk.py` → `export_sheila_walk.py` → `review_sheila_walk.py`。走路原始資料與授權詳 SOURCE.txt。Godot 檢視場景需放入輸出的 `sheila_walk_preview.glb`，可擷取 34 個時間點，`check_ground.gd` 以實際蒙皮資料檢查鞋底位置。

已處理的實際問題：斗篷與肩部的站姿穿模、肩膀動作權重差異、背劍與斗篷交叉、褲腳與靴筒相交，以及前方角色顏色被投射到劍身。劍身兩面使用無遮擋的背面材質參考；其他表面按物件遮擋選擇投射與原材質。這些處理仍需在更多姿勢下驗證。

inputs 的圖片由 OpenAI image generation 依固定鏡頭渲染製作，僅是表面材質參考，並非模型實機截圖。提示摘要：保留相機、幾何與位置，添加泥濘白羊毛短斗篷、暗色絎縫衣、皮革、舊鋼鐵、銅環、三劍徽章與右眉舊疤；背面需維持既有寬斷劍輪廓。投射包含對這一批輸入的畫布校正，不宜直接套用任意新圖。
