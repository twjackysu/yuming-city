# 送葬者：可開啟檢查的工作版本

**未通過正式美術驗收，ART_REQUESTS.md 尚未全部完成。**

- undertaker_walk_candidate.glb：53,259 三角面、71 根骨骼，三個 PBR 材質、九張嵌入 PNG，最大 2048。
- walk_candidate.fbx：30 fps、無模型、原地 walk 循環；含袍骨與鏈骨。
- walk_preview.mp4／preview.png：Godot 4.7.2 Forward+ 實際播放擷取。
- weakpoint_preview.png：引擎內只讓 `M_FrameJoint` 發光，鐵架其餘部位不變。
- manifest.json、SOURCE.txt 與檢查記錄：實際規格、檔案雜湊、來源及限制。

已建立兩立柱三橫桿、52 個鏈節、獨立弱點材質、袍骨及逐幀鏈條接地。尚缺橫掃、下砸、衝撞、撞牆跪地、扯斷鐵鏈等動作；手部、袍身、接縫及材質也還需修整。本版沒有替換遊戲內程序模型。

腳本與重現方式見 [製作紀錄](../../../docs/art-trials/undertaker-rigging/README.md)。

追加 frame_material_preview.png 顯示鐵架磨邊與鏽蝕；night_preview.png 使用遊戲共用的霜橋鎮夜景、體積霧及濕石板材質，加入暖燈測試。這些檢查仍未使本模型通過正式美術驗收。

新增六個隨 frame_root 移動的定位節點 FrameJoint_L0/L1/L2、FrameJoint_R0/R1/R2（由下往上，自身左右）。joint_locators.json 記錄位置；Godot 59 幀／354 次定位檢查通過。joint_locator_preview.png 紅點是另加的檢視標記，實際 GLB 只有定位 Node3D，未加入碰撞體或擅自替換遊戲角色。骨骼、三材質、九張貼圖及原動畫二進位資料不變。
