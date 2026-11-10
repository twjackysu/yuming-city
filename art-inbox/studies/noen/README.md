# 諾恩：可開啟檢查的工作版本

**尚未達到正式美術或 3A 驗收，不替換遊戲內角色。** 這裡保存實際 GLB、FBX 與引擎影片，方便檢查製作進度；不是整份美術需求的完成交件。

- `noen_walk_candidate.glb`：含角色、PBR 貼圖、60 根骨骼與 idle／walk／run 三段試作，可用 Blender 或 Godot 開啟。
- `walk_candidate.fbx`：相同骨架的 30 fps 動畫，無模型，移除水平根位移。
- `walk_preview.mp4`：Godot 4.7.2 Forward+ 實際播放擷取，畫面標示 WORK IN PROGRESS。
- `preview.png`：同一次引擎擷取的畫面。
- `SOURCE.txt`：作者、素材與 AI 工具來源、授權及修改說明，請與衍生版本一起保留。

本版為 39,866 三角面、3 材質、9 張嵌入 PNG，貼圖最大 2048。GLB 結構檢查、FBX 30 fps／無模型／循環接合檢查及 Godot 匯入播放已執行；SHA-256 與檔案大小見 `manifest.json`。這些技術檢查不能代替美術驗收。

相較初版，重建了獨立靴子並烘焙高解析法線，調整靴筒與褲腳的配合，加入冬衣內層及領口；修正無模型 FBX 的骨架基準姿勢，並處理走路循環的接地。

仍待改善：髮絲與臉部質感、衣物接縫、領口／衣襬在各種姿勢下的變形與碰撞、步態自然度及腳步滑動，還有全部其他動畫與角色。**`ART_REQUESTS.md` 的正式需求仍未全部完成。**

製作方法與歷史試驗：[本機製作紀錄](../../../docs/art-trials/noen-rigging/README.md)。本資料夾的來源歸屬包含 punkduck 的 CC BY 3.0 冬衣與 ACCAD / The Ohio State University 的 CC BY 3.0 動作資料。


新增骨折保護步態：右前臂護在腹前，手指自然微彎；修正袖口共 144 頂點錯配至手／手指骨的權重，避免轉腕時拉出尖面。35 幀檢查中，夾板邊長最大相對變化約 0.00053%，且 GLB 夾板只受 RightForeArm 單一骨骼影響；FBX 仍為 30 fps／無模型／原地循環。Godot 35 個時間點均通過 3mm 接地門檻。這些檢查不代表腳步滑動、所有碰撞或 3A 品質已驗收。

新增 night_preview.png 重用遊戲的霜橋鎮夜空、月光、體積霧、濕石板，再加暖燈檢查；不是已完成的正式關卡整合。製作腳本與後續限制見本機製作紀錄的骨折步態段落。


2026-11-09 開發回饋修整：綁帶按袖子與木夾板的實際三角面輪廓貼合，接觸袖面鎖至同一前臂骨；35 幀綁帶頂點距兩者最近表面最大約 1.5mm。左手姿勢改為留在前襟外側，對前襟面片的最短距離約 8.5cm、側向保守間距約 4.6cm；這項量測不包含本來就重疊的手腕／袖口，不代表所有部位都無碰撞。保留骨折護臂、夾板剛性、無模型 FBX 循環及逐幀引擎接地檢查。

補回 MakeHuman short02 原附的 CC0 髮絲法線（先前使用中性法線），降低髮材高光，重烘焙連續頸部膚色；portrait_front.png／portrait_threequarter.png 是相同中性棚光的局部檢視。這次表面修整最初有 11 個材質；後續整併為下述三材質版本，仍未通過 3A 美術驗收。


三材質整併：M_Noen_Skin（皮膚／眼睛）、M_Noen_Clothes（衣物／靴子／木夾板／綁帶）、M_Noen_Hair（頭髮／眉毛），各一組 BaseColor＋Normal＋ORM，均為 2048×2048。重建 UV 後重新烘焙切線法線，三角面與 60 根骨骼不變。35 幀前後雙向頂點比對最大距離為 0m（容許值 0.01mm）；這證明保留既有接觸修整的幾何／蒙皮結果，不代表貼圖毫無損失。

**Godot 匯入注意**：這次 4.7.2 實測未沿用 GLB 的 KHR_materials_specular 設定，頭髮高光回到預設 0.5。預覽已套用隨附的 noen_material_import.gd 將 M_Noen_Hair 設回 0.06，其餘材質不動；單獨把 GLB 匯入而不設定此腳本，頭髮會較亮。重現見製作紀錄的 godot_review_atlas。後續已加入 idle／run，仍未投入正式角色路徑。


新增 idle_loop／idle_candidate.fbx：3.2 秒、30fps、60 骨、Without Skin，雙腳站穩，軀幹微幅呼吸，保留右前臂護傷與左手放鬆。idle_preview.mp4／idle_preview.png／idle_night_preview.png 為本次引擎擷取；既有 night_preview.png 保留作前版 walk 棚外光照記錄。97 個時間點實際蒙皮接地、護傷肩腕距離及腳骨穩定檢查通過，兩腳骨最大位移 0m；這不是完整衣物碰撞驗收。

GLB 同時含 idle_loop 和 walk_loop；Godot 4.7.2 自動辨識 loop 後匯入名稱為 idle、walk。已測試 idle→walk→idle→walk 可以恢復各自姿勢，未測成品遊戲交叉淡化的腳部鎖定。修正 Blender 匯出時間從第 2 幀開始的 0.0667s 前置偏移，idle 為 3.2s、walk 為約 1.1333s。合併時原始網格／貼圖二進位前綴不變、inverse bind 相同。完整 18 個主角動作與正式交件仍未完成。


2026-11-10 新增 run_loop／run_candidate.fbx：ACCAD Male1_C03_Run 真實跑步動捕第 12～31 幀，20 個關鍵取樣／19 幀週期，30fps、Without Skin、In Place，約 0.6333s。保留右前臂護傷；依腿長縮放原動捕的騰空高度，校準後低於 15mm 的足尖高度視為接觸，未將騰空強壓到地面。20 個引擎實際蒙皮最低點與預定高度差最大 0.00037mm，兩次落地、最高騰空約 14.5cm；這是垂直接觸檢查，不代表移動時腳步滑動已驗收。移速參考約 4.49m/s，仍須遊戲實際驗證。

run_preview.mp4／run_preview.png 是 Godot Compatibility 棚光擷取，run_night_preview.png 是 Forward+ 遊戲夜空／霧與暖燈檢查。FBX 60 骨、0 網格、30fps、循環矩陣差小於 0.000001；idle→walk→run→idle→run→walk 姿勢恢復檢查通過。原模型／貼圖區段不變，衣襬外翹、髮膚品質與其他完整動作仍未解決。run_source_cycle.json／run_retarget_cycle.json 記錄來源週期、接觸校準與重定向參數；run_engine_*.log 是引擎證據。


2026-11-10 衣襬修整：只調整 walk 的四根 Coat_*_Lower 旋轉，下半段以重力方向為基準，跟隨上段角度 35%，限制在 ±0.24rad（約 13.75°）；不再上下兩段一起跟著大腿整片抬起。coat_side_preview.png 是側面檢查，preview.png／walk_preview.mp4／night_preview.png 已更新。idle／run 保留原動作，尚未套用此修整。

walk_candidate.fbx 已重匯出，60 骨／0 網格／30fps／原地與循環檢查通過。逐軌比較僅四根衣襬下段 rotation 改變；35 幀引擎接地與三動作切換通過。另分網格確認最低點來自不透明 Clothes（靴子），不是透明皮膚面片。技術棚光改 Forward+，25cm 地面格線；平地只接收陰影，避免自身陰影條紋。褲面有向距離檢查的負側頂點峰值由 21 降至 15，最深既有負距離約 5.9cm 仍存在；開放表面的有向距離只是診斷，不等於完整碰撞解決。請勿把這次修整理解為所有衣物與極端姿勢均已驗收。


2026-11-10 待機左手修整：回應第四點回饋，左臂較接近垂直自然下垂，減少手肘外撐；手指朝中指方向收攏並微彎，保留掌部原來的朝向。右前臂護傷與雙腳站姿不變。97 個時間點中，左肘相對肩部的側向偏移最大約 8.21cm；手掌／手指到排除左袖後衣物面的最短距離約 8.65cm。此量測刻意排除手腕與袖口的正常重疊，不代表全身所有碰撞驗收。

新 idle FBX 仍為 60 骨、30fps、Without Skin、In Place；首尾骨架矩陣差為 0。97 點引擎接地、右手護傷與腳骨穩定通過，idle／walk／run 切換通過。更新 idle 專用預覽、影片與夜景；walk／run 動作不變，原網格與貼圖二進位前綴保留。更多角色、動作與正式品質驗收仍未完成。
