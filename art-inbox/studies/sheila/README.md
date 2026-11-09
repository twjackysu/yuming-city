# 席菈：可開啟檢查的工作版本

尚未通過正式美術或 3A 驗收。此版本保存角色、walk 試作及引擎影片，供檢查進度。

- `sheila_walk_candidate.glb`：含 PBR 貼圖、53 根骨骼與 walk 循環。
- `walk_candidate.fbx`：同骨架、30 fps、無模型的 walk 試作。
- `walk_preview.mp4`、`preview.png`：Godot 4.7.2 Forward+ 實際擷取，標示 WORK IN PROGRESS。
- `SOURCE.txt`、`manifest.json`：來源、授權、修改說明、實際規格與逐檔 SHA-256。

本版 38,396 三角面，3 材質、9 張嵌入 PNG，最大 2048。已做結構檢查、FBX 重新匯入、Godot 播放與鞋底位置檢查。材質與衣物細節仍須改善；技術檢查不能代替美術驗收。

已製作白色短斗篷、三劍銀徽、左耳銅環、寬斷劍與獨立 `weapon_socket` 骨骼；眉疤包含於正面材質參考。仍需檢查舊疤顯示、斗篷變形、接縫、右手握姿、戰鬥動畫及遊戲內武器切換。**整份 ART_REQUESTS.md 尚未完成。**

製作腳本與重現方式：[席菈製作紀錄](../../../docs/art-trials/sheila-rigging/README.md)。


2026-11-09 大劍／材質更新：刀身補出中央槽、斜刃、厚斷口、彎曲護手、圓柄與纏繞皮帶、金屬柄頭；保持寬於肩膀的設定。大劍保留獨立 Sheila_Broken_Sword 網格，100% 綁 weapon_socket，與衣物共用同一材質圖集。另修正舊版把胸前三劍徽章誤綁 weapon_socket 的問題，徽章回綁 Spine2，避免之後裝備大劍時跟著移動。整體三材質，各 BaseColor／Normal／ORM 2048×2048。

本次保留原披肩：新披肩試作未通過外觀及變形檢查，不能視為第四點的披肩問題已解決。35 幀雙向蒙皮頂點比對確認除大劍外的原角色幾何結果保持不變；這也表示舊披肩穿插仍未解決。新增 blade_preview.png、night_preview.png 與近照供檢查。

Godot 4.7.2 的預覽使用 sheila_material_import.gd，只把 M_Sheila_Hair 的 metallic_specular 設為 0.06。直接匯入 GLB 若未設定此腳本，髮材較亮。影片與靜態棚光採 shadow_bias=0.1、shadow_normal_bias=0.5，以避免先前棚光的自陰影網紋；引擎實際頂點接地另外檢查。仍只有 walk，不是正式美術交件。


2026-11-10 回應第四點大劍回饋：劍身護手下寬由 55cm 改為 44cm，往斷口漸窄至 28.6cm；中央脊最大總厚由 7cm 減至 3.2cm，護手深度由 4.5cm 減至 2.6cm，垂直輪廓也削薄。保留中央槽、斜刃與不規則斷口。重烘焙鋼材：劍面與磨亮刃口分別設定反射／粗糙度，加入短刮磨與少量局部氧化，避免以長條噪聲模擬刮痕而像木紋。仍共用三組 2K，未增加材質或三角面。

blade_preview.png 為棚光近景；blade_night_preview.png 為背面暖燈檢查，night_preview.png 為原本正面夜景。金屬在光源方向不同時會明暗變化，這些圖不等於已完成所有關卡光照驗收。35 幀角色非武器部分幾何保持檢查通過，原 walk FBX 不變，接地通過。披肩形體／米色穿插、臉髮品質和握劍戰鬥仍未完成。
