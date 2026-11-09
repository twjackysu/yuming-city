# CMU 劍術動捕與握劍研究

這是未驗收的動畫研究，不是已完成的攻擊交件。CMU Subject 02 / Trial 07 swordplay 共 2,251 幀、120 fps；已讀取 ASF/AMC、量測右手速度，建立掌面及拇指方向對應，並試做 1400–1512 幀放慢至 30 fps / 43 幀的揮劍候選。

來源：[CMU 官方](http://mocap.cs.cmu.edu/)、[動作搜尋](https://mocap.cs.cmu.edu/search.php)。官方允許資料用於商業產品，禁止把資料本身直接轉售（轉檔後也一樣），並要求致謝；這不是 CC0 或 MIT 資料。原始動捕沒有收進 Git。本專案將資料用於遊戲角色動作，不作原始資料販售。

致謝原文：The data used in this project was obtained from mocap.cs.cmu.edu. The database was created with funding from NSF EIA-0196217.

`fetch_cmu_sword.py` 從官方取得兩個固定檔案並驗證 SHA-256，HTTPS 失敗才試 HTTP；兩者都必須符合已記錄雜湊。只讀取數字，不執行下載內容。`acclaim_motion.py` 限定本次資料所用的 XYZ 旋轉、root channel order 及零 root rest orientation，拒絕不支援的格式、不完整 channel、非有限數字與超大輸入。這不是通用 ASF 轉換器。

Blender 5.2.3 可執行 `inspect_cmu_sword.py`、`sample_cmu_sword.py` 及 `build_cmu_strike.py`。環境變數 `CMU_MOCAP` 指向原始資料，`CMU_SWORD_WORK` 指向輸出，`SHEILA_SWORD_MODEL` 指向含 weapon_socket 的席菈 tailored_baked.blend。

掌面由中指方向與食指／小指掌骨位置構成；使用 source fingers/thumb 向量保留手腕翻轉。劍柄軸沿掌骨橫向，四指以局部彎曲軸搜尋握姿，劍的位移和轉向由獨立 weapon_socket 驅動。

`strike_22.png`、`grip_review.png` 僅作缺陷檢查；仍可見斗篷／袖口變形與手部接觸問題，左手與劍的空間也未驗收。因此本次不把本機揮劍 GLB／FBX 放入正式動畫目錄，也不將輕攻擊標為完成。下一步需要校正衣物變形、握姿、武器碰撞與戰鬥時序，再跑匯出及引擎檢查。
