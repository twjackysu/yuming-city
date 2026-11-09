# 羊毛材質與 UV 密度研究（未採用為正式角色）

xatlas 0.0.11 將既有送葬者袍身 UV 利用率從約 21.99% 提高到 74.13%，不增加三角面。其內部打包尺寸為 2772×2778，UV 正規化後仍烘焙成 2048×2048；並非超規貼圖。保留 SourceAtlas 取樣原始皮膚、幾何 AO 與法線，完成新圖後移除舊 UV。

素材為 [Poly Haven Poly Wool Herringbone](https://polyhaven.com/a/poly_wool_herringbone)，colormass 攝影、Rico Cilliers 處理，[CC0](https://polyhaven.com/license)。採 2K Diffuse／Displacement／Rough／AO，原始檔未重複加入 Git；固定下載連結與 SHA-256 在 scan_manifest.json，fetch_scan_material.py 驗證後下載。未使用 Hunyuan 輸出。

流程：Blender 5.2.3 執行 export_undertaker_uv.py → 在 trellis-env（含 xatlas 0.0.11）執行 unwrap_undertaker_xatlas.py → 下載掃描材質 → Blender 執行 bake_undertaker_scanned_wool.py。需要先完成送葬者原始袍身 body_baked/undertaker_body.blend；預設工作位置 ~/Documents/undertaker-wool-pbr。

以世界座標依約 27cm 材質寬度做 box projection，染為冷黑色，混合底部濕污、皮膚與皮革區域，保留原本高模法線。實驗已產生嵌入 BaseColor／Normal／ORM 的本機 GLB，但近景織紋辨識、手部遮罩、衣料輪廓及接縫仍不合格，因此沒有替換 art-inbox 的角色候選，也不列為正式交件。cloth_closeup.png 是檢查缺陷的 Blender 渲染。
