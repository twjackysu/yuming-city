# TRELLIS：免費 MIT 本機 3D 生成試跑

這是未驗收研究，不是正式角色交件。已在 RTX 2080 SUPER 8GB／Windows 跑通官方 TRELLIS-image-large，包含實際 CUDA attention、稀疏卷積及網格解碼。送葬者輸入沿用專案原創圖；25＋25 步、seed 81，共 424,492 三角面，輸出逐頂點 RGB 與法線屬性。端到端 57.06 秒（包含載入／首次權重準備），PyTorch peak allocation 6,600MiB；不代表所有輸入皆能以相同速度或顯存生成。

- undertaker_trellis_color.glb：未減面的靜態研究網格，無骨架，不能直接作正式送葬者。
- front_preview.png／back_preview.png：Blender 中性光，並非概念圖或遊戲內截圖。
- trial.json、runtime_check.json：本次數據；來源授權見 SOURCE.txt。

此版比單張貼圖投射提供較一致的三維顏色，但表面仍偏平、手部及衣褶需要修形，沒有完整 PBR、UV 或綁定，尚未取代目前的角色候選。

## 固定版本與環境

TRELLIS https://github.com/microsoft/TRELLIS @193e0502b5cb3eb5997ec457d5340e95d09b158e（MIT）。FlexiCubes 子模組 @815e075a2a400d06c48d94c347674344ed6ae5c5（Apache-2.0）。DINOv2 https://github.com/facebookresearch/dinov2 @7764ea0f912e53c92e82eb78a2a1631e92725fc8（Apache-2.0）。utils3d https://github.com/EasternJournalist/utils3d @9a4eb15e4021b67b12c460c7057d642626897ec8（MIT）。權重 microsoft/TRELLIS-image-large@25e0d31ffbebe4b5a97464dd851910efc3002d96，Safetensors；DINOv2 使用官方公開 checkpoint，PyTorch weights_only 載入。

Python 3.10.18；獨立 trellis-env：torch 2.7.1+cu126、torchvision 0.22.1+cu126、xformers 0.0.31（PyTorch 官方 cu126 索引）、spconv-cu120 2.3.6、numpy 1.26.4、transformers 4.48.3。完整套件版本見 environment.txt。已有 NVIDIA driver 617.42；本試跑不需另裝完整 CUDA Toolkit。

預設將原始碼放 ~/Tools/TRELLIS、~/Tools/dinov2、~/Tools/utils3d，權重 ~/Tools/trellis-weights。先 clone 上述官方來源並 checkout 固定提交、初始化 FlexiCubes 子模組；環境建立後執行 apply_local_compat.py → check_runtime.py → fetch_weights.py → run_trellis_production.py → prepare_vertex_color.py。生成器可用 TRELLIS_INPUT 指定 RGBA 輸入；預設指向鄰近的送葬者原創輸入。輸出位於 ~/Documents/undertaker-trellis。Blender 中性檢視可用 ../../../scripts/render_triposr_trial.py。

相容性修正：此版官方 xFormers Windows 輪檔將原生庫放在 pyd 而非 _C.pyd；比對固定 SHA-256 後複製成可辨識檔名，CUDA 實測通過。FlexiCubes 只使用 Kaolin 的 shape assertion，改為等價的本機張量形狀檢查；未移除驗證。圖片流程不預載未使用的 Open3D 文字流程。DINOv2 程式從固定本機原始碼載入，避免執行 Torch Hub 未固定主分支。模型分階段搬到 GPU，結束即卸回 CPU。

glTF 頂點顏色規範為線性值；模型 RGB 屬性先由 sRGB 轉線性，以 float32 COLOR_0 保存並加入明確 PBR 材質。這也避免 Trimesh 無 material 的預設白模匯入及暗色 8-bit 量化問題。未將此轉換誤記為新貼圖或完整 PBR 生成。
