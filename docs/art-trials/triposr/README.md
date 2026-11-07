# TripoSR 本機試跑：諾恩

日期：2026-11-08。結論：**免費本機 GPU 生成已跑通；人物品質未達需求，不作正式交付。**

## 執行證據

RTX 2080 SUPER 8GB、Python 3.10.18、PyTorch 2.7.1+cu118。`torch.cuda.is_available()` 為 true，實際推論使用 GPU。未安裝完整 CUDA Toolkit；PyTorch 套件附帶的 CUDA runtime 已足夠。僅 marching cubes 擷取使用 CPU scikit-image，沒有編譯 torchmcubes。

官方來源：VAST-AI-Research/TripoSR，commit `107cefdc244c39106fa830359024f6a2f1c78871`。權重：stabilityai/TripoSR，revision `5b521936b01fbe1890f6f9baed0254ab6351c04a`。來源程式與模型採 MIT，原始授權附於 UPSTREAM_LICENSE.txt；依賴套件仍有各自授權。

輸入：`art-inbox/concepts/character_references/noen/noen_front.png`，先前內建 imagegen 生成的角色正面參考。無雲端推論、API 登入或付費點數；公開權重下載只需網路。

| 試跑 | 網格擷取解析度 | 三角面 | PyTorch 峰值配置顯存 | 影像推論／擷取秒數 | 結果 |
|---|---:|---:|---:|---:|---|
| 未補邊初試 | 192 | 44,352 | 1,991.5 MiB | 3.12 / 4.75 | 人物比例被輸入縮放影響 |
| 未補邊高解析 | 256 | 78,424 | 2,506.5 MiB | 2.00 / 10.17 | 增加面數沒有解決比例和細節 |
| 等比例補邊 | 256 | 56,184 | 2,506.5 MiB | 2.91 / 11.20 | 比例改善，仍不合格 |

顯存數字是 PyTorch `max_memory_allocated`，不是整張卡含桌面等程序的總顯存用量。時間不含首次權重下載及 Blender 渲染。各次原始測量 JSON 隨附；前兩輪未計算 checkpoint hash，最後一輪有完整 hash，並已核對與官方 Hugging Face LFS metadata 的 SHA-256 相同。

## 視覺驗收

已用 Blender 重新匯入，渲染四個相反方向及三分之四視角。修正原始 GLB 的 Z-up／glTF Y-up 展示差異，並開啟平滑表面陰影；原始 GLB 不因此被覆寫。

- 等比例補邊避免官方前處理直接把直式圖壓成方形，修正明顯變寬的人體比例。
- 臉、眼、嘴與頭髮仍模糊／失真；側面有帽沿狀錯誤突出。
- 手指黏合、衣服結構糊成表面起伏，無法符合主角近景品質要求。
- 正確補邊後的模型不是 watertight；頭髮與鞋端仍有破損／薄片。
- 只有頂點色，沒有 UV、PBR、骨架、蒙皮和動畫；56,184 面也超過主角 40k 上限。

**不以加面數、平滑或綁骨架把這個結果包裝成成品；不替換遊戲角色，也不把它放入正式 art-inbox。** TripoSR 可作粗略重建與流程測試，這次結果不足以作 3A 主角基礎。下一個候選是 TripoSG 的幾何生成，但尚未實測；其去背依賴需避免非商用 BRIA 權重。

## 本機產物

以下在被 Git 忽略的 `art-work/triposr/noen_256_square/`：

- `noen_triposr.glb`：原始頂點色網格，未驗收。
- `noen_trial_review.blend`：可旋轉檢查的 Blender 場景。
- `renders/`：五個視角 PNG。
- `model_input.png`：模型輸入使用的等比例補邊版本。
- `trial.json`：環境、耗時、面數、顯存及 hash。

未將粗糙模型或測試渲染推送到 main；本次提交僅含流程程式、環境記錄、相容修補與結果報告。

## 重跑

獨立環境位於 `C:\Users\jacky\Tools\triposr-env`，官方 checkout 位於 `C:\Users\jacky\Tools\TripoSR`。不污染系統 Python。

建立其他環境時，先以 uv 建立 Python 3.10 venv，從 PyTorch 官方 cu118 index 安裝 `torch==2.7.1`，再安裝 omegaconf 2.3.0、numpy 1.26.4、pillow 10.4.0、einops 0.7.0、transformers 4.35.0、trimesh 4.0.5、imageio 2.37.0、scikit-image 0.24.0。完整解析後版本見 environment.lock.txt。這是相容性實驗的固定環境，不代表所有舊依賴已完成安全稽核；不啟動 web server。

在上述官方 commit 使用 `git apply --unidiff-zero <patch絕對路徑>` 套用 windows_compat.patch（零 context，與固定版本配套）：只改成 CPU marching cubes、延遲載入未使用的 rembg、明確 `weights_only=True`。無 `trust_remote_code=True` 或任意 pickle 載入。

```powershell
& 'C:\Users\jacky\Tools\triposr-env\Scripts\python.exe' scripts/run_triposr_trial.py --source 'C:\Users\jacky\Tools\TripoSR' --input art-inbox/concepts/character_references/noen/noen_front.png --output art-work/triposr/noen_retry --resolution 256 --chunk-size 2048
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' --background --factory-startup --python scripts/render_triposr_trial.py -- 'E:\Users\jacky\Documents\Repo\yuming-city\art-work\triposr\noen_retry\noen_triposr.glb'
```

Runner 預設固定已測試的權重 revision。模型來源的設定僅允許 tsr.models.* 類別；這是有限防護，不是系統沙箱或完整安全稽核。原始 source checkout 必須先審查並套用所附修補。
