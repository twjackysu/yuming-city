# 免費本機角色製作：未驗收的工作版本

**不是正式角色交件，也沒有達到 3A 品質驗收。** `ART_REQUESTS.md` 的正式模型與動畫仍未完成。本資料夾保存製作方法、來源與技術驗證；不替換遊戲內既有角色。

## 已實際執行

- TripoSG 在 RTX 2080 SUPER 8 GB 上使用 FP16、CPU offload 與 CPU 網格提取運作；不使用付費 Tripo API，也不載入 BRIA 權重。
- 單張圖生成的人臉、手與大衣／褲子拓撲不足以交付。現改用 MPFB 人體與獨立衣物，生成網格僅保留並改製靴子。
- 諾恩拆成身體、眼睛、眉毛、頭髮、大衣、褲子、靴子、補丁、右前臂木夾板與繃帶；52 根人體骨骼加 8 根衣襬骨骼。
- 固定鏡頭生成的材質參考投射回模型後，烘焙為 BaseColor／Normal／ORM。毛髮、眉毛與眼球保留原始透明貼圖並明確附上中性 Normal／ORM；中性圖不代表有額外幾何細節。
- 靜態候選 GLB：37,864 三角面、29,213,060 bytes、1 skin、10 材質、27 張嵌入 PNG，最大 2048。`candidate_manifest.json` 固定此版本的 SHA-256。
- ACCAD 的走路擷取轉到同一骨架，取原始 37–71 frame 的週期，修正循環接縫與垂直接地，輸出 30 fps、無模型的 FBX。這只是 **walk 試作**，不是整套動畫。
- 無模型 FBX 匯出需在 frame 0 放置靜止骨架基準，再只輸出 frame 1–35；否則重新匯入會把匯出當下的動作當成基準姿勢。`export_walk_rest_bind.py` 保存此修正。
- GLB / FBX 重新匯入 Blender 及 Godot 4.7.2；Godot 成功匯入並擷取四個動畫時間點。這不是完整遊戲整合測試。

## 還沒通過的項目

髮絲、靴子形體、衣料細節與貼圖接縫；所有姿勢下的衣物碰撞；腳步滑動及完整動作自然度；遊戲中的速度、武器與互動對齊。席菈、送葬者、灰巡者與其動畫、其餘主角動畫及正式高解析概念圖也仍待完成。不能因檔案檢查通過就勾選正式交件。

## 來源與授權

詳細逐項作者、授權、AI 使用與修改見 `SOURCE.txt`。冬衣源自 **punkduck / CC BY 3.0**；人體等核心素材 **MakeHuman / CC0**；走路資料 **ACCAD / The Ohio State University / CC BY 3.0**。必須隨衍生交件保留這些歸屬。

- MPFB：`6ff1eb358f6c1959ced77e79e6dd2406d9a71f49`，Blender 5.2.3 LTS。程式碼 GPL 與核心素材 CC0 是不同授權。
- TripoSG：`fc5c40990181e2a756c4e0b1c2f4d6b5202faf8c`；權重 `VAST-AI/TripoSG@2c1c516d22d58db486a058d98d31bb6177344e06`，只讀本機 Safetensors。來源修改見 `triposg-local.patch`，環境見 `triposg-environment.txt`。
- [MPFB 素材授權](https://static.makehumancommunity.org/about/license.html)
- [冬衣素材包](https://static.makehumancommunity.org/assets/assetpacks/dress03.html)
- [ACCAD 官方資料及 CC BY 3.0](https://accad.ohio-state.edu/research/motion-lab/mocap-system-and-data)

## 重現入口

這些是工作室製作腳本，不是下載後自動完成高品質角色的工具。先自行準備上述固定版本、官方素材包及 TripoSG 原始生成網格。腳本不會替你安裝或下載依賴。

環境變數：

- `YUMING_NOEN_WORK`：所有 Blender 中間檔、貼圖、GLB 與 FBX 的輸出資料夾。
- `YUMING_MPFB_SOURCE`：MPFB 的 `src`；`YUMING_MPFB_USER`：MPFB 使用者資料根目錄；`YUMING_MPFB_ASSETS`：其中 `data`。
- `YUMING_SG_MODEL`：TripoSG 高解析試作 GLB。只擷取靴子，不將生成的人體當正式成品。
- `YUMING_NOEN_FACE_IMAGE`：`inputs/face.png`。
- `YUMING_NOEN_FRONT_MATERIAL`：`inputs/garment_front.png`。
- `YUMING_NOEN_REAR_MATERIAL`：`inputs/garment_rear.png`。
- `YUMING_WALK_BVH`：官方 `Male1_B3_Walk.bvh`。
- `YUMING_TRIPOSG_SOURCE`：TripoSG checkout，僅供生成腳本。

Blender 呼叫格式：`blender -b --offline-mode --python-exit-code 1 --python SCRIPT.py`。

依序執行 `build_noen_tailored.py` → `tailor_noen.py` → `project_tailored_materials.py` → `bake_noen_tailored.py` → `finish_cutout_materials.py`。再執行 `retarget_accad_trial.py` → **`export_walk_rest_bind.py`** → `check_walk_fbx.py` → `review_walk_export.py`。最後一步輸出含走路動作的獨立檢視 GLB；它不代表正式動畫庫。

`godot_review/` 是獨立檢視場景；將 `noen_walk_preview.glb` 與 `walk_trial.fbx` 複製到該資料夾，再用 Godot 4.7.2 匯入及執行。生成的快照只用於人工檢查。

`inputs/` 全是 AI 輔助的材質／生成參考，**不是 3D 實機截圖**。正面與背面參考圖的畫布對齊不同；投射腳本包含對這一批固定輸入的 UV 校正，不宜直接套用任意新圖。提示內容摘要見 `inputs/README.md`。

## V2 可開啟檢查的候選檔

見 [諾恩工作版本](../../../art-inbox/studies/noen/README.md)：含 GLB、獨立 FBX、Godot Forward+ 播放影片與逐檔 SHA-256，仍未通過正式美術驗收。V1 的數據與 manifest 保留作為歷史記錄。

V2 單獨以 `inputs/boot_front.png` 執行 TripoSG，網格由 2,059,936 三角面減到每隻 1,913 面，烘焙高解析法線並搭配前後材質投射。`bake_boot_trial.py` 使用 `YUMING_BOOT_WORK`（TripoSG 輸出資料夾）、`YUMING_BOOT_FRONT_IMAGE` 與 `YUMING_BOOT_REAR_IMAGE`。再依序使用 `fit_noen_boots_v2.py`（`YUMING_BOOT_MODEL` 指向烘焙的 GLB）、`add_noen_inner_wool.py`、`bake_noen_inner_wool.py`。輸出 `noen_candidate_v2.glb` 與 `.blend`。

動畫重測使用獨立工作資料夾，將新版 `.blend` 複製為 `tailored_noen.blend`、GLB 複製為 `tailored_candidate.glb`，設定 `YUMING_NOEN_WORK` 指向此資料夾，再執行前述動畫流程。重定向腳本支援左右獨立靴子，逐格用實際蒙皮後的鞋底校正垂直位置。

V2 修正：烘焙前清除低面數靴子的舊自訂法線，減少配合小腿形狀後的三角形明暗；使用 Blender 官方 `create_settings_group` 建立完整 glTF 材質設定群組，避免將另一個 GLB 匯入現有場景時缺少擴充插槽。

`godot_review_v2/` 保存本次 Forward+ 檢視腳本，需放入 `noen_walk_preview.glb`；擷取 34 張標有 WORK IN PROGRESS 的畫面。這不是遊戲角色整合或正式動畫品質驗收。

## 骨折保護步態（2026-11-09）

設定 YUMING_NOEN_WORK 指向新的工作目錄，將 V2 的 tailored_noen.blend、tailored_candidate.glb 複製進去，再執行 fix_noen_cuff_weights.py → retarget_guarded_walk.py → export_walk_rest_bind.py → check_noen_guarded_fbx.py → review_walk_export.py → check_noen_guarded_pose.py（Blender 命令格式同前）。

右手不再使用一般步行擺臂：兩骨姿勢解算讓前臂護在腹前，手指微彎。冬衣袖口 144 頂點從手／指骨重配給前臂，避免轉腕拉扯；夾板及綁帶仍固定於 RightForeArm。檢查記錄涵蓋 FBX 無模型／30 fps／原地／循環、35 幀夾板邊長與肩腕距離，以及 glTF 夾板的單一骨權重。不是所有動作的碰撞或美術驗收。

新的 Godot 檢視在 godot_review_guarded；放入輸出的 noen_walk_preview.glb，先 import，再執行 check_ground.gd。這版接地檢查覆蓋全部 35 幀，另有實際引擎影片。night_review.tscn 可重用遊戲共用夜空／月光／霧／濕石板；先執行 prepare_lighting_review.py（需要時設定 YUMING_REPO 為專案根目錄），再 import。這是材質光照檢視，尚未把候選角色換進正式關卡。
