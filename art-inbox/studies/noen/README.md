# 諾恩：可開啟檢查的工作版本

**尚未達到正式美術或 3A 驗收，不替換遊戲內角色。** 這裡保存實際 GLB、FBX 與引擎影片，方便檢查製作進度；不是整份美術需求的完成交件。

- `noen_walk_candidate.glb`：含角色、PBR 貼圖、60 根骨骼與一段 walk 試作，可用 Blender 或 Godot 開啟。
- `walk_candidate.fbx`：相同骨架的 30 fps 動畫，無模型，移除水平根位移。
- `walk_preview.mp4`：Godot 4.7.2 Forward+ 實際播放擷取，畫面標示 WORK IN PROGRESS。
- `preview.png`：同一次引擎擷取的畫面。
- `SOURCE.txt`：作者、素材與 AI 工具來源、授權及修改說明，請與衍生版本一起保留。

本版為 39,866 三角面、11 材質、30 張嵌入 PNG，貼圖最大 2048。GLB 結構檢查、FBX 30 fps／無模型／循環接合檢查及 Godot 匯入播放已執行；SHA-256 與檔案大小見 `manifest.json`。這些技術檢查不能代替美術驗收。

相較初版，重建了獨立靴子並烘焙高解析法線，調整靴筒與褲腳的配合，加入冬衣內層及領口；修正無模型 FBX 的骨架基準姿勢，並處理走路循環的接地。

仍待改善：髮絲與臉部質感、衣物接縫、領口／衣襬在各種姿勢下的變形與碰撞、步態自然度及腳步滑動，還有全部其他動畫與角色。**`ART_REQUESTS.md` 的正式需求仍未全部完成。**

製作方法與歷史試驗：[本機製作紀錄](../../../docs/art-trials/noen-rigging/README.md)。本資料夾的來源歸屬包含 punkduck 的 CC BY 3.0 冬衣與 ACCAD / The Ohio State University 的 CC BY 3.0 動作資料。
