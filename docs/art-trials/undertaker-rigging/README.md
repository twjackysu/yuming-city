# 送葬者模型與 walk 工作版本

這是未通過正式美術驗收的候選；可開啟的 GLB、FBX、Godot 影片及弱點發光截圖見 [工作版本](../../../art-inbox/studies/undertaker/README.md)。並未替換遊戲內程序模型。

本機 TripoSG 高解析袍身重建後，減至 31,839 面並以高模烘焙法線。整體含鐵架、52 個鏈節共 53,259 三角面、71 根骨骼。鐵架精確兩立柱三橫桿，關節共用獨立 `M_FrameJoint` 材質。來源及授權見 SOURCE.txt。

Blender 5.2.3 命令：`blender -b --offline-mode --python-exit-code 1 --python SCRIPT.py`。先沿用 ../noen-rigging 的 `run_triposg_production.py`，輸入 inputs/undertaker_body_input.png、seed 81、50 steps、depth 9。輸出保留歷史檔名 noen_triposg.glb。

製作順序：`bake_undertaker_body.py` → `assemble_undertaker.py` → `bake_undertaker_frame.py`。環境變數 `UNDERTAKER_GEOMETRY` 指向 TripoSG 輸出資料夾，`UNDERTAKER_PRODUCTION` 指向組裝工作目錄，`UNDERTAKER_ANATOMY` 指向先前 MPFB anatomy.blend，`UNDERTAKER_REAR_IMAGE` 指向 inputs/undertaker_rear_material.png。骨架來源需先完成諾恩製作流程。

動畫目錄由 `UNDERTAKER_WORK` 指定；先將 undertaker_baked.blend 複製為 tailored_noen.blend、undertaker_candidate.glb 複製為 tailored_candidate.glb。`YUMING_WALK_BVH` 指向官方 ACCAD Male1_B3_Walk.bvh。執行 retarget → export → check FBX → review。FBX 匯出使用 frame 0 身分姿勢作 bind rest，正式範圍 1–59，30 fps Without Skin。GLB roundtrip 2–60。輸出 GLB 加 0.5mm 展示接地餘量，以容納引擎匯入後的插值／蒙皮差異。

修正過的問題：UV 島邊距過大使材質只使用 0.7% 畫布，縮小邊距後約 22%；烘焙前清除不一致自訂法線；鄰面轉權重將袖口錯分給手指與髖部造成極長尖面，改以分區、焊接位置鄰接平滑及最多四骨權重；袍角及整條鏈的實際頂點參與接地校正。鎖鏈使用五節 FABRIK 保長解算，每幀重新量測最低鏈節再校正目標；這是動畫烘焙，不是遊戲內物理模擬。

把 undertaker_walk_preview.glb 放進 godot_review，使用 Godot 4.7.2 `--editor --headless --import` 後執行。check_ground.gd 量測所有 59 幀的實際蒙皮頂點，不只骨頭位置；weakpoint_review.tscn 驗證只有一個材質槽被設為發光。截圖採 Forward+；一般啟動需指定 `--rendering-method forward_plus`。

仍待處理：袍身與手部拓撲、投射光影與接縫、金屬磨損分布、更多極端姿勢、五個其他送葬者動作，以及 Godot 正式關卡夜景整合。不能用本次技術檢查宣稱符合 3A 品質。
