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

## 開發端第四點回饋：表面與接觸修整（2026-11-09）

沿用骨折保護步態工作版本，新增 `refine_noen_surfaces.py` → `fit_noen_linen_bands.py` → `retarget_contact_safe_walk.py` → `export_walk_rest_bind.py` → `check_noen_guarded_fbx.py` → `review_walk_export.py` → `check_noen_guarded_pose.py` → `check_noen_contact_walk.py`。各動畫／接觸腳本使用 YUMING_NOEN_WORK，請指向新的工作目錄，避免覆蓋輸入版本。

表面修整額外需要 YUMING_NOEN_SOURCE_BLEND（先前骨折步態的靜態 .blend）、YUMING_NOEN_SKIN_DRIVER（先前 tailored_projected.blend，保有原始皮膚 UV）；兩者身體拓撲與座標逐點比對後才複製 UV。輸出仍是 tailored_noen.blend 與 tailored_candidate.glb。皮膚與頭髮法線取既有 MPFB 使用者素材，不下載任何新資產。這一步只做一次；之後再執行會重設後續的綁帶修整。

綁帶以 Blender 的實際 loop triangle 射線求袖面／夾板最外層輪廓，再留 1.5mm；接觸三角形袖面頂點與綁帶同綁 RightForeArm，避免動起來再分離。先前使用任意圓柱形綁帶，頂點與袖面最大相差約 28.4mm。原四邊面 BVH 與 GLB 三角化的對角線可能不同，必須按 loop triangle 計算。

左手與大衣的檢查限定於原始身體座標 abs(x)<0.24m、z<1.1m 的前襟／裙襬面片；不把本來就應重疊的手腕／袖口算成穿衣。35 幀測得綁帶最大表面距離 1.5003mm 以下，左手與前襟最短距離 84.9mm 以上、保守側向間距 45.8mm 以上。這不是全角色任意動作的碰撞保證。

頭髮保留原型與 UV，補回 short02_normal.png（CC0），不採用未達品質的 AI 髮片實驗。皮膚只以原始膚色平滑修正頸部；32 張嵌入 PNG 逐一驗證最大 2048。仍有 11 個材質，尚未達正式版 2～3 個材質的要求。

## 三材質 2K 整併（2026-11-09）

完成上述表面／綁帶／雙手接觸修整後，先保存含 walk 的 GLB 作為基準。再以 YUMING_NOEN_SOURCE_BLEND 指向修整後靜態 .blend、YUMING_NOEN_ATLAS_WORK 指向另一個新目錄，執行 bake_noen_three_materials.py。它合併為 Skin、Clothes、Hair 三個網格與材質，重排 UV，重新烘焙切線 Normal、BaseColor／Alpha、ORM，輸出九張 2048×2048 圖；不是簡單把舊切線法線貼到新 UV。頭髮保留 blended alpha；皮膚／眼睛用 cutout。

把已檢查的 walk_trial.fbx 複製到新目錄，改設 YUMING_NOEN_WORK 為此目錄，再執行 review_walk_export.py。YUMING_NOEN_BASELINE_GLB 指向前述基準動畫 GLB；執行 check_noen_atlas_geometry.py，以 30fps 匯入兩版，在 35 幀對實際蒙皮頂點做雙向最近點比對。本次最大位置差為 0m、容許 0.01mm，三角面仍為 39,866。合併後不再有獨立 Noen_Coat／Wood_Splint 節點，因此舊接觸／剛性檢查要在合併前跑；合併後的等價檢查確認同一動作保留接觸修正，不是忽略這些檢查。

Godot 檢視改用 godot_review_atlas：

1. 複製最終 noen_walk_preview.glb，先 `godot --headless --editor --path DIR --import`。
2. 執行該目錄的 configure_material_import.py，再跑一次 import。這會將 Import Script 指向 noen_material_import.gd。
3. 執行 check_ground.gd（35 幀，所有蒙皮網格，逐個實際索引頂點），再播放 review.tscn；夜景沿用 prepare_lighting_review.py 及既有 YUMING_REPO 設定。

Godot 4.7.2 本機實測：GLB 的 KHR_materials_specular.specularFactor=0.12 未反映為髮材預期的低高光，匯入 material.metallic_specular 仍為 0.5。匯入腳本只將 M_Noen_Hair 設為 0.06；實測值 0.0599999986589，其他欄位與兩材質不動。這是資產專屬 profile，不是引擎所有 glTF 的通用修補。預覽影片及夜景截圖使用此腳本，獨立開 GLB 的其他軟體依自身支援處理 KHR 擴充。參考 [Godot 官方 EditorScenePostImport](https://docs.godotengine.org/en/stable/classes/class_editorscenepostimport.html)。

正式遊戲目前仍未接入候選角色；開發端將來接入時也需設定這個 Import Script。三材質僅解決材質數／貼圖組數，尚未達 3A 美術驗收或全部動畫需求。

## 諾恩 idle／walk 雙動作工作版

build_noen_idle.py 需要先前 noen-surface-refinement/mocap_walk_trial.blend（frame 18 的護傷上身）及三材質製作輸出的原生 tailored_noen.blend／tailored_candidate.glb；不是重新匯入 GLB 後另存的原生骨架。YUMING_NOEN_IDLE_WORK 指定新輸出目錄；其餘驗證工具的 YUMING_NOEN_WORK 也指向同一目錄。執行 build_noen_idle.py → review_noen_idle.py → check_noen_idle_fbx.py → merge_noen_idle_walk.py。可以設定 YUMING_SKIP_RENDERS=1 跳過中間棚拍。

合併器預設讀取專案 art-inbox/studies/noen/noen_walk_candidate.glb，也可設定 YUMING_NOEN_BASE_GLB。它按骨名核對 inverse bind、映射動畫節點，只新增必要的動畫 buffer views／accessors，原網格／貼圖 bytes 不變；兩個 clip 各覆蓋 60 骨 TRS。所有時間減去各 clip 最早時間，消除 2/30 秒前置空檔。再次執行會替換既有 idle_loop 的索引，不重複建立同名動作。

Godot 檢視在 godot_review_idle。將合併後 GLB 複製為 noen_walk_preview.glb，先 import，執行 configure_material_import.py，再 import；夜景依既有 prepare_lighting_review.py 準備 shader。review.tscn 拍 idle 97 取樣、walk_review.tscn 拍 walk 35 取樣。check_ground.gd／check_walk_ground.gd 分別驗證接地，check_idle_guard.gd 驗證護傷肩腕距離及腳骨穩定，check_clip_switch.gd 驗證切換後姿勢恢復。

注意：glTF 名稱 idle_loop／walk_loop 經 Godot 4.7.2 識別 loop 後會成 idle／walk。驗證與檢視腳本使用匯入後名稱，並檢查其存在，避免播放失敗卻誤當成驗證成功。預覽影片排除重複的循環末幀。

這是諾恩護傷待機，不是席菈待機，也不能代替 sword_idle、扛人或其他要求動作。完整未完成項目見 ../../ART_DELIVERY_STATUS.md。
