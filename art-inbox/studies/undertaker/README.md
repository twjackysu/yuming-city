# 送葬者：可開啟檢查的工作版本

**未通過正式美術驗收，ART_REQUESTS.md 尚未全部完成。**

- undertaker_walk_candidate.glb：53,259 三角面、71 根骨骼，三個 PBR 材質、九張嵌入 PNG，最大 2048。
- walk_candidate.fbx：30 fps、無模型、原地 walk 循環；含袍骨與鏈骨。
- walk_preview.mp4／preview.png：Godot 4.7.2 Forward+ 實際播放擷取。
- weakpoint_preview.png：引擎內只讓 `M_FrameJoint` 發光，鐵架其餘部位不變。
- manifest.json、SOURCE.txt 與檢查記錄：實際規格、檔案雜湊、來源及限制。

已建立兩立柱三橫桿、52 個鏈節、獨立弱點材質、袍骨及逐幀鏈條接地。尚缺橫掃、下砸、衝撞、撞牆跪地、扯斷鐵鏈等動作；手部、袍身、接縫及材質也還需修整。本版沒有替換遊戲內程序模型。

腳本與重現方式見 [製作紀錄](../../../docs/art-trials/undertaker-rigging/README.md)。
