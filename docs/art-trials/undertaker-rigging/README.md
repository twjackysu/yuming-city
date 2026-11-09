# 送葬者模型與 walk 工作版本

這是未通過正式美術驗收的候選；可開啟的 GLB、FBX、Godot 影片及弱點發光截圖見 [工作版本](../../../art-inbox/studies/undertaker/README.md)。並未替換遊戲內程序模型。

本機 TripoSG 高解析袍身重建後，減至 31,839 面並以高模烘焙法線。整體含鐵架、52 個鏈節共 53,259 三角面、71 根骨骼。鐵架精確兩立柱三橫桿，關節共用獨立 `M_FrameJoint` 材質。來源及授權見 SOURCE.txt。

Blender 5.2.3 命令：`blender -b --offline-mode --python-exit-code 1 --python SCRIPT.py`。先沿用 ../noen-rigging 的 `run_triposg_production.py`，輸入 inputs/undertaker_body_input.png、seed 81、50 steps、depth 9。輸出保留歷史檔名 noen_triposg.glb。

製作順序：`bake_undertaker_body.py` → `assemble_undertaker.py` → `polish_undertaker_metal.py` → `bake_undertaker_frame.py`。環境變數 `UNDERTAKER_GEOMETRY` 指向 TripoSG 輸出資料夾，`UNDERTAKER_PRODUCTION` 指向組裝工作目錄，`UNDERTAKER_ANATOMY` 指向先前 MPFB anatomy.blend，`UNDERTAKER_REAR_IMAGE` 指向 inputs/undertaker_rear_material.png。骨架來源需先完成諾恩製作流程。

動畫目錄由 `UNDERTAKER_WORK` 指定；先將 undertaker_baked.blend 複製為 tailored_noen.blend、undertaker_candidate.glb 複製為 tailored_candidate.glb。`YUMING_WALK_BVH` 指向官方 ACCAD Male1_B3_Walk.bvh。執行 retarget → export → check FBX → review。FBX 匯出使用 frame 0 身分姿勢作 bind rest，正式範圍 1–59，30 fps Without Skin。GLB roundtrip 2–60。輸出 GLB 加 0.5mm 展示接地餘量，以容納引擎匯入後的插值／蒙皮差異。

修正過的問題：UV 島邊距過大使材質只使用 0.7% 畫布，縮小邊距後約 22%；烘焙前清除不一致自訂法線；鄰面轉權重將袖口錯分給手指與髖部造成極長尖面，改以分區、焊接位置鄰接平滑及最多四骨權重；袍角及整條鏈的實際頂點參與接地校正。鎖鏈使用五節 FABRIK 保長解算，每幀重新量測最低鏈節再校正目標；這是動畫烘焙，不是遊戲內物理模擬。

把 undertaker_walk_preview.glb 放進 godot_review，使用 Godot 4.7.2 `--editor --headless --import` 後執行。check_ground.gd 量測所有 59 幀的實際蒙皮頂點，不只骨頭位置；weakpoint_review.tscn 驗證只有一個材質槽被設為發光。截圖採 Forward+；一般啟動需指定 `--rendering-method forward_plus`。

仍待處理：袍身與手部拓撲、投射光影與接縫、金屬磨損分布、更多極端姿勢、五個其他送葬者動作，以及 Godot 正式關卡夜景整合。不能用本次技術檢查宣稱符合 3A 品質。

鐵架材質另以每個零件的局部包圍盒座標計算磨邊，讓磨損落在邊緣。座標先存成 ForgeBoxCoords 屬性，合併烘焙後移除，避免誤輸出為頂點顏色而改變金屬底色；氧化沿重力方向延伸，對應金屬度與粗糙度不同。

新增 night_review.tscn：執行 godot_review/prepare_lighting_review.py，會複製目前遊戲的 FrostbridgeLook、夜空及濕石板 shader 到被忽略的本機目錄，再 `--editor --headless --import`。夜景測試重用遊戲的 AgX、月光、體積霧、濕石板，另加暖色燈觀察材質；這是光照檢視場景，仍不是正式關卡的角色整合。拍攝所用來源雜湊見 night_source_snapshot.json。

## 六個鐵架關節定位節點（開發回饋）

烘焙 walk GLB 後執行 `add_undertaker_joint_locators.py`。UNDERTAKER_INPUT_GLB 指向輸入 GLB，UNDERTAKER_LOCATOR_WORK 指向輸出目錄；產生 undertaker_walk_preview.glb、joint_locators.json。輸出六個非蒙皮定位節點：FrameJoint_L0/L1/L2、FrameJoint_R0/R1/R2，0 為最下橫桿，2 為最上橫桿，L/R 為角色自身左右。

節點直接隸屬 frame_root，位置是對應 M_FrameJoint 板件／螺栓整體包圍盒中心，從實際網格與 inverse bind matrix 推導，不依第一幀的彎腰姿勢猜座標。關節骨列表仍為 71 根；原 GLB 的二進位區塊（網格、貼圖、蒙皮與動畫）逐位元保持不變。suggested_radius_m=0.07 只是定位節點的建議資訊，並未建立命中碰撞或改動遊戲端判定。

將新 GLB 與 joint_locators.json 放進 godot_review，匯入後執行 `godot --headless --path godot_review --script check_joint_locators.gd`。Godot 4.7.2 檢查 59 幀、6 個節點共 354 次，均與 frame_root 姿勢一致。遊戲端可用 actor.find_child("FrameJoint_L0", true, false) 取得 Node3D，再讀 global_position；不要把 bone_local_position 當成世界座標。

locator_review.tscn 的紅點只是檢視用，另外向板面外偏移 4.5cm，方便從發光關節上辨認；GLB 中實際定位節點沒有這項顯示偏移。金屬亮白條的修整已在上一版磨邊／鏽蝕烘焙處理；本次未再更換材質，仍需正式美術複核。
