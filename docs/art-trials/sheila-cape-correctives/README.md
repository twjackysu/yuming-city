# 席菈披肩：走路修形候選

此版解決的是 walk 已量測範圍的披肩／外套交叉，不是全部動畫或 3A 品質驗收。正式收件路徑不變，遊戲角色仍未替換。

## 結果與證據

- 39,028 三角面、53 骨、5 網格、3 材質、9 張內嵌 2048² PNG。
- 寬短披肩獨立為 Sheila_Cape，共用 Clothes 圖集；24 組形變配合 walk，沒有執行期布料模擬。
- 重新匯出的 GLB 在 69 個 60fps 時間點，披肩與 6,242 個外套三角面的雙向邊交叉為 0。檢查不是全身／所有姿勢的碰撞認證。
- 位置最大誤差約 1.54mm；Godot 形變權重差換算頂點位移的保守上限約 0.0051mm，接地通過。
- 保留原身體 159 條骨骼軌道、原 FBX；來源授權見 SOURCE.txt。此版使用 Poly Haven CC0 毛料，包含原衣料 CC BY 3.0 與 ACCAD CC BY 3.0 的衍生歸屬。

## 可重現的製作順序

Blender 5.2 LTS、系統 Python＋numpy、Godot 4.7.2。YUMING_SHEILA_CAPE_WORK 指向獨立工作目錄。需要前一輪原生、多物件的 .blend：YUMING_SHEILA_NATIVE_BLEND（例如 sheila-sword-v2/source.blend），以及 YUMING_SHEILA_FBX（既有 walk Without Skin FBX）。不是直接讀合併後 GLB 當原生來源。毛料來源下載／雜湊流程在 ../wool-uv；將 Poly Haven diffuse／displacement 放在該流程使用的 Tools/cc0-materials/poly_wool_herringbone。

1. Blender 執行 prepare_cape_pose_samples.py。預設讀 inputs/cape_draped_pattern.json；可用 YUMING_SHEILA_CAPE_PATTERN 覆寫。JSON 為本專案生成的布面與權重，非可執行腳本。先對齊 FBX／原生骨架的座標框架，再取 35 個姿勢。cloth_source.blend／cloth_simulation.npz 是沿用試作檔名；本流程不跑動態布料模擬，npz 實際保存原生布面蒙皮與骨架矩陣。
2. Blender 執行 build_cape_correctives.py：領部採外輪廓射線、下段採鄰近面／三角面中心約束，最大修整約 3.3cm。以 PCA 壓縮為 24 組位置修形。選出的形變僅供這段走路，未覆蓋其他動作。
3. 沿用 ../sheila-rigging/bake_sheila_three_materials.py，設定 YUMING_SHEILA_SOURCE_BLEND=工作目錄/morph_source.blend、YUMING_SHEILA_ATLAS_WORK=同工作目錄。重新烘焙三組 2K。
4. Blender 執行 split_cape_mesh.py，然後沿用 ../sheila-rigging/split_sheila_atlas_weapon.py。保留披肩與大劍為獨立網格；其他網格清掉零位移形變。
5. 系統 Python 執行 merge_body_and_cape_animation.py。YUMING_SHEILA_BODY_GLB 可指定已存在的身體動畫 GLB，預設 studies/sheila。核對 inverse bind、保留原骨骼軌道，將時間起點歸零，再加入披肩 weights 軌道。重跑時先排除舊 weights，避免重複軌道。
6. 系統 Python 執行 fit_cape_normals.py，輸出 sheila_walk_normal_fitted.glb；只調整形變法線，位置與動畫保留。
7. Blender 執行 check_exported_cape.py。它檢查真正匯出的模型與半幀取樣，不只檢查擬合陣列。Blender glTF 匯入器會依初始值縮小部分 ShapeKey 滑桿範圍，檢查前必須擴至 [-1.1,1.1]，否則負係數會被讀取工具限制而產生錯誤偏差。這不修改 GLB 檔案。

本機從保存的布面 JSON 重建姿勢樣本，蒙皮位置差約 0.0024mm。圖集烘焙與工具版本仍可能造成像素／浮點差異，不能以 SHA 不同推定外觀不同。

## Godot

godot_review 的 src/world 與相關 shader 由 prepare_lighting_review.py 複製專案 game/src/world（同專案霜橋鎮 look）；將最終 GLB 複製為 sheila_walk_preview.glb。先 --headless --editor --import，再依既有說明把 .glb.import 的 import_script/path 設為 res://sheila_material_import.gd，重匯入。畫面用 Forward+ 執行 review.tscn／night_review.tscn／cape_close_review.tscn；接地與形變值用 --headless --script check_ground.gd／check_cape_weights.gd。

權重檢查不只看係數差，也以每組形變最大位移計算保守的幾何偏差上限。當前 69 點最大權重差約 0.000768，換算位移上限僅約 0.0051mm；門檻分別為 0.001 與 0.1mm。

## 還沒完成

披肩自然垂墜、邊緣厚度、皺褶與暖光質感仍須精修；其他 17 個動作及動作混合未覆蓋。FBX 不帶布面形變，遊戲端若改用獨立 FBX 重定向，需保留／重建對應 weights 軌道。這個工作版不能據此當作正式 3A 角色交件。所有實檔、預覽與通過紀錄見 ../../../art-inbox/studies/sheila。
