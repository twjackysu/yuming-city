# 席菈：可開啟檢查的工作版本

尚未通過正式美術或 3A 驗收。此版本保存角色、walk 試作及引擎影片，供檢查進度。

- `sheila_walk_candidate.glb`：含 PBR 貼圖、53 根骨骼與 walk 循環。
- `walk_candidate.fbx`：同骨架、30 fps、無模型的 walk 試作。
- `walk_preview.mp4`、`preview.png`：Godot 4.7.2 Forward+ 實際擷取，標示 WORK IN PROGRESS。
- `SOURCE.txt`、`manifest.json`：來源、授權、修改說明、實際規格與逐檔 SHA-256。

本版 37,636 三角面，12 材質、33 張嵌入 PNG，最大 2048。已做結構檢查、FBX 重新匯入、Godot 播放與鞋底位置檢查。材質與衣物細節仍須改善；技術檢查不能代替美術驗收。

已製作白色短斗篷、三劍銀徽、左耳銅環、寬斷劍與獨立 `weapon_socket` 骨骼；眉疤包含於正面材質參考。仍需檢查舊疤顯示、斗篷變形、接縫、右手握姿、戰鬥動畫及遊戲內武器切換。**整份 ART_REQUESTS.md 尚未完成。**

製作腳本與重現方式：[席菈製作紀錄](../../../docs/art-trials/sheila-rigging/README.md)。
