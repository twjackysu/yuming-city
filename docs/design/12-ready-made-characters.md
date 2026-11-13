# 12　用網路上現成的角色模型（查證紀錄）

> 2026-11-13 15:10～15:35（台北）在 Claude 對話裡查的。起因是 Jacky 看了自製的席菈之後問：
> 「不能線上下載現成3D模型使用嗎?」
> 結論：**可以，而且臉與頭髮比自己做的好看很多。** 下面是實際查過、試過的東西；沒查的都標了「還沒確認」。

## 1. 已經確認可以用的：VRoid 的 CC0 範例角色（動漫風）

- **在哪**：GitHub `madjin/vrm-samples`（commit `e16eb187100149a315ad92c3c9968f1d5baa6c7d`）。雲端 session 的 shell 連得到（GitHub），CI 也連得到。
- **授權怎麼確認的**：`.vrm` 檔本身是 glb，JSON 裡的 `extensions.VRM.meta` 寫著授權。直接讀出來：

  | 檔案（`vroid/beta/`） | `licenseName` | 商用 | 大小 | 三角面 |
  |---|---|---|---|---|
  | `Sendagaya_Shino.vrm`（長黑髮的女生） | **CC0** | Allow | 15.1 MB | 31,211 |
  | `Sendagaya_Shibu.vrm`（短髮） | **CC0** | Allow | 17.0 MB | 34,395 |
  | `Sakurada_Fumiriya.vrm` | **CC0** | Allow | 19.3 MB | 39,548 |
  | `Darkness_Shibu.vrm` | **CC0** | Allow | 20.4 MB | 33,758 |
  | `Victoria_Rubin.vrm`、`Vita.vrm`、`Vivi.vrm`、`HairSample_Male.vrm` | **CC0** | Allow | 14～19 MB | 沒量 |

  該 repo 的 README 引用 pixiv 的說明頁（`vroid.pixiv.help/hc/en-us/articles/4402614652569`）：這幾個是 CC0、放棄著作權、可以修改與商用。**我沒有直接打開 pixiv 那一頁**（第 103 輪 17:35 再試一次：雲端抓網頁的工具要人按同意、沒人在，還是沒打開），授權的根據是檔案裡的 meta 與 README 的引用；正式用之前再開那一頁確認一次，並記進 `docs/CREDITS.md`。
- **不要用的**：同一個 repo 的 `vroid/stable/AvatarSample_A／B／C.vrm`、`vroid/fem_vroid.vrm`、`vroid/masc_vroid.vrm`——meta 寫的是 `Other`（有另外的使用條件，不是 CC0）。`Seed-san`、`Avatar_Orion`、`meebits`、`cryptovoxels` 沒查。
- **規格**：VRM 0.x（VRoid Studio 0.8.1 匯出）、T 字站姿、身高 1.62～1.65 m、匯入 Blender 之後面向 +Y（＝glTF 的 −Z，跟遊戲要的一樣）、15～17 個材質、27～30 張貼圖、112～154 個節點（含頭髮與裙子的擺動骨頭）。
- **試過的**：把 `.vrm` 複製成 `.glb`，`bpy.ops.import_scene.gltf()` 直接讀得進來，貼圖都在；Cycles 算兩張圖 24 秒。對照圖（左＝自製席菈，右＝Shino 與 Shibu）已經在對話裡給 Jacky 看過。匯入時會多一個沒有綁骨架的網格（骨頭的顯示用形狀），算圖與匯出要排除（只留有 Armature modifier 的）。
- **抓檔的坑**：`git clone --depth 1 --filter=blob:none --no-checkout` 之後用 `git show HEAD:<路徑> > 檔` 一個一個拿。**不要對這個 repo 跑 `git ls-tree -r -l`**——它會把每個檔都下載下來（460 MB）。

## 2. 接進遊戲要做的事（第 1、2、5 點第 103 輪做完了，D-253；第 3 點的受光與第 4 點的服裝還沒）

1. **骨名**：VRoid 的骨頭叫 `J_Bip_C_Hips`、`J_Bip_L_UpperArm`…；`extensions.VRM.humanoid.humanBones` 有「人形骨頭 → 節點」的對照表，用它在 bpy 裡改成 Godot 人形骨架的名字（Hips、LeftUpperArm…），`tools/blender/sheila.py` 的 `Animator`（照世界座標的軸轉、手臂垂下的角度從休息姿勢算）就能直接套四段動作。T 字站姿不用另外處理。
2. **收件檢查**：`check_character_glb.py` 要求每個材質都有 Normal 與 ORM、15k～40k 面。面數過得了；材質要補（每個材質給一張平的 Normal 與固定值的 ORM，或烘成一張圖）。這是 Jacky 寫的收件檢查，不要為了過關把它改鬆——在 bpy 那一步補齊。
3. **畫風**：這些角色是卡通著色（MToon，貼圖本身就畫好明暗）。直接用 Godot 的標準材質會變成「被場景的光再打一次」。先試最便宜的：標準材質、粗糙度拉高、不要金屬；不行再看 `V-Sekai/godot-vrm`（GitHub 上有，Godot 4 的 VRM 匯入外掛，含 MToon 著色器與頭髮裙子的擺動；授權還沒確認）。
4. **服裝**：都是現代的制服，跟地底城不搭。VRoid 匯出時衣服底下的身體通常被挖掉，**不要刪衣服的網格**；做法是改貼圖的顏色（制服 → 深色短上衣）＋把自製管線的披肩、腰帶、護臂、靴子、劍加上去（硬的東西程式做得好）。頭髮顏色、眼睛顏色也改，免得一眼看出是 VRoid 的範例角色（很多人用）。
5. **驗收**：照 D-250——玩家的鏡頭改前｜改後一張、近照一張，放進 FOR_JACKY 讓他判斷。

## 2.5 本機試接的結果（2026-11-13 16:13；沒有進 `latest`）

- `Sendagaya_Shino.vrm` → `tools/blender/vrm_character.py`（用 VRM 的人形對照表把 54 根骨頭改成 Godot 人形骨架的名字、套 `common.py` 的五段動作、匯出）→ 7.8 MB 的 glb、31,211 面、148 根骨頭、身高 1.65 m，5 秒。
- 沒有經過收件檢查（材質沒有 Normal／ORM，過不了），直接複製到 `game/assets/characters/sheila/sheila.glb` → Godot 匯入沒有錯誤 → 戰鬥場裡她會動（拍到在跑），臉與頭髮好看。
- **玩家的鏡頭看得到她了**：材質是 `KHR_materials_unlit`（不受光），暗的場景裡她是亮的。代價是不吃場景的光（毒霧的綠、燈的暖色染不到她）。
- 毛病：劍橫在腰邊（握法）、現代制服、頭髮與裙子的擺動骨頭沒有動。
- 對照圖（玩家的鏡頭 自製｜現成、近照 自製｜現成）在對話裡給 Jacky 看過，他看完決定走漫畫風（D-252）。圖沒有進 repo——下一輪接進建置之後用 `scripts/shots.sh characters` 重拍。

## 3. 還沒確認、值得查的

- **動作**：Quaternius 的 Universal Animation Library（120 個以上的動作，有 Godot 用的版本；在 itch.io、quaternius.com、OpenGameArt、Godot Asset Store）。授權原文還沒看（他的素材一向標 CC0）。**不在 GitHub 上，雲端的 shell 連不到**；CI 連得到——可以加一個 CI 步驟下載後放進一個 GitHub release（例如 `art-src`），本機再從 release 抓。拿得到的話，出手、翻滾、受擊、倒下都不用自己寫關鍵影格。
- **KayKit 的冒險者角色**：GitHub `KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0` 連得到；Q 版低面數、帶動作。授權還沒看、樣子還沒看。
- 寫實風、授權開放、放在 GitHub 上的帶骨架人物：搜過一次，沒找到。

## 4. 不能用的

- Mixamo、Sketchfab、CGTrader、RenderHub 上的「免費」模型：要帳號才能下載，多數不能把原始檔放進公開的 repo 或由 CI 重新散布，授權也一個一個不同。
- MakeHuman 社群的頭髮、衣服、皮膚貼圖：不在 GitHub 上（`makehumancommunity/makehuman-assets` 連不到），而且做出來還是 MakeHuman 的臉。
- 其他遊戲、動畫的角色：不行。

## 5. Jacky 的決定（2026-11-13 16:10～16:40，D-252）

人物改走漫畫風；模型能抓現成的就抓，抓不到的才自己做。原話在 `docs/FOR_JACKY.md` 回覆區最後。做的順序在 `docs/NEXT.md`「0000」最上面。還要他選的只剩一件：人物「不受光」還是「吃場景的光」（兩種各拍一張給他）。
