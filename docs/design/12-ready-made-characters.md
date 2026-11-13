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

## 5. Jacky 的決定（2026-11-13 16:10～16:40，D-252；20:34 補：受光選 B，D-255）

人物改走漫畫風；模型能抓現成的就抓，抓不到的才自己做。原話在 `docs/FOR_JACKY.md` 回覆區最後。做的順序在 `docs/NEXT.md`「0000」最上面。受光方式他 20:34 看了 A｜B 的圖之後選 B（吃場景的光）。

## 6. 場景小物與武器的現成模型（2026-11-13 20:35～20:45 查；起因是 Jacky 問「場景和武器也都有現成模型能用嗎?」）

結論：**有，而且比人物好拿**——檔案小（一個 20～150 KB）、不用骨架、授權檔就在 repo 裡。但風格是「圓胖可愛的低面數」，不是地底城那種陰暗的感覺，要先試一張再決定用多少。

### 6.1 已經確認可以用的：KayKit（Kay Lousberg）的 CC0 素材包，在 GitHub 上

每個 repo 根目錄的 `LICENSE.txt` 直接讀過，都寫 `License: (Creative Commons Zero, CC0)`、「free to use in personal, educational and commercial projects」。雲端的 shell 與 CI 都連得到（`git ls-remote` 試過）。

| repo（`github.com/KayKit-Game-Assets/…`） | commit | 裡面有什麼 |
|---|---|---|
| `KayKit-Dungeon-Remastered-1.0` | `b0ca9bd` | 203 個 glb：牆（含門洞、窗、拱門、鷹架、破牆）、地板（石磚、木板、泥地、鐵柵）、柱子、樓梯、桌椅、架子、床、木桶、木箱、寶箱、行李箱、酒桶、瓶子、蠟燭、火把（含掛牆的）、旗幟、盤子、金幣、鑰匙、瓦礫。共用一張貼圖 `dungeon_texture.png`（色塊）。`Samples/` 有官方的示意圖 |
| `KayKit-Character-Pack-Adventures-1.0` | `672074b` | **武器**：單手劍、雙手劍、單手斧、雙手斧、匕首、法杖、魔杖、單手弩、雙手弩、箭、箭袋、盾（圓、方、尖刺、徽章）、煙霧彈、魔法書、酒杯；另有 5 個 Q 版角色（野蠻人、騎士、法師、盜賊、戴兜帽的盜賊；帶骨架）。武器是 `.gltf`＋`.bin`＋角色的貼圖（例如雙手劍用 `knight_texture.png`） |
| `KayKit-Character-Pack-Skeletons-1.0` | `15b62b9` | 4 個骷髏角色（法師、小兵、盜賊、戰士；帶骨架）與它們的武器（斧、刀、弩、法杖、盾） |

同一個組織底下還連得到、**還沒看內容與授權檔**的：`KayKit-Medieval-Hexagon-Pack-1.0`、`KayKit-Halloween-Bits-1.0`、`KayKit-Furniture-Bits-1.0`、`KayKit-Restaurant-Bits-1.0`、`KayKit-City-Builder-Bits-1.0`。猜過但連不到（名字可能不對或不在 GitHub）：`Fantasy-Weapons-Bits`、`Medieval-Builder-Pack`、`Forest-Nature-Pack`、`Resource-Bits`、`Block-Bits`、`Character-Animations`。

- **尺寸**：KayKit 的單位比我們大——大木桶寬 1.8、高 2.0，雙手劍長 2.37。配 1.65～1.81 m 的人物要縮到 0.4～0.55 倍左右（一樣一樣看）。
- **抓檔**：跟 VRoid 一樣——`git clone --depth 1 --filter=blob:none --no-checkout` 之後 `git ls-tree -r --name-only HEAD`（**不要加 `-l`**）看清單，`git show HEAD:<路徑> > 檔` 一個一個拿。glb 在 `addons/<包名>/Assets/gltf/`。
- **進不進 git**：單檔都遠小於 1 MB，挑幾十個直接放進 repo 也可以（建置不用連網路）；或照人物的做法由 `gen_art.sh` 抓到快取。用了哪些要記 `docs/CREDITS.md`。
- **風格**：色塊平塗、沒有細節貼圖——跟「場景往漫畫感靠（描邊、平塗）」的方向一致；但造型圓胖、偏可愛（官方示意圖是玩具感的地下城），人物是瘦長的動漫比例，放在一起會不會像「動漫人物走進玩具屋」要看圖。顏色可以整包壓暗（改那一張色塊貼圖）、打我們自己的燈與霧。

### 6.2 授權沒問題、但雲端的 shell 抓不到的

- **（2026-11-13 22:06 Jacky 下載放進 `art-inbox/props/` 了，縮成 8 MB，D-258；授權的根據與用法看 `art-inbox/props/README.md`。下面是當時查的。）Quaternius 的 Fantasy Props MegaKit**（官網那一頁打開看過）：「Free to use in personal, educational and commercial projects. (CC0 License)」；211 個中世紀小物——武器、工具、蔬菜、藥水、**市場攤位**、箱子、家具；有 glTF。造型比 KayKit 細、比例比較正常，跟地下市場最搭。**下載在 itch.io**（shell 連不到；itch 的下載要按按鈕，CI 也不好自動抓）——要用的話請 Jacky 下載 zip 放進 `art-inbox/`（或一個 GitHub release），是他五分鐘能做完的事。同一位作者還有 Medieval Village MegaKit（建築）、Lowpoly Medieval Weapons——搜得到頁面，授權頁這一輪沒有打開（OpenGameArt 擋自動抓取）。
- **Kenney 的 Fantasy Town Kit、Castle Kit、Retro Medieval Kit**：搜得到（itch.io、OpenGameArt、kenney.nl），他的素材一向標 CC0，**這一輪沒有打開授權頁確認**。不在 GitHub 上。
- **Poly Haven**（寫實的 CC0 模型、貼圖、HDRI）：風格是寫實的，跟漫畫風不搭，不用。

### 6.3 沒有現成的（還是要自己做）

- 劇情專屬的東西：諾恩的鐘錘、席菈的斷劍（現成的雙手劍可以當底，斷口自己切）、護腕、毒瓶、藥店的檢測板、貨梯。
- 怪物（送葬者、灰巡者）：KayKit 只有骷髏；要嘛改設定用骷髏當一般的雜兵，要嘛照舊自己做。
- 整條地下市場的街景（招牌鏡頭）：現成的是「零件」，街還是要自己排；現在的街是程式一塊一塊蓋的，可以把攤位、木桶、木箱、瓶子、旗子、火把這些小物換成現成的，牆與地板先不動。

## 7. 男女主角要像一對、要像冒險者（2026-11-13 22:2x；Jacky 問的，D-259）

Jacky 的原話：「另外男女主角有相似一點的模型嗎?衣服好像有點不搭，女生那套太像學生服，有更像冒險者一點的裝扮的現成模型嗎?」

### 7.1 現成、授權乾淨、漫畫風的角色一共就這 8 個（全部算了一張圖給他看）

`madjin/vrm-samples` 的 `vroid/beta/`，8 個檔的 meta 都直接讀過：`licenseName: CC0`、商用 `Allow`。用 `tools/blender/vrm_roster.py` 排成一排算的：

| 檔案 | 樣子 | 身高 |
|---|---|---|
| `HairSample_Male`（現在的諾恩） | 男，深色亂髮，白色連帽上衣、深色長褲 | 1.81 m |
| `Sakurada_Fumiriya` | **男**，橘色短髮，海軍藍針織背心＋白襯衫＋橘領帶＋深色長褲——**跟 Shino 是同一套制服** | 1.92 m（含翹起來的頭髮） |
| `Sendagaya_Shino`（現在的席菈） | 女，黑長髮，海軍藍背心＋白襯衫＋藍領結＋百褶裙＋及膝襪 | 1.65 m |
| `Sendagaya_Shibu` | **女**（不是男的），黑短髮，同一套制服、紅領結 | 1.62 m |
| `Darkness_Shibu` | 女，紅色短髮，深藍花紋的哥德風洋裝 | 1.65 m |
| `Victoria_Rubin` | 女，金色馬尾，粉白色的偶像裝 | 1.74 m |
| `Vita` | 女，白色短髮，藍綠色的科幻緊身衣 | 1.71 m |
| `Vivi` | 女，棕色短髮，綠色圍裙洋裝＋綁帶靴（村姑的感覺；最接近奇幻，但她是 1.41 m 的小個子） | 1.41 m |

**沒有一個穿冒險者的衣服。** 「最像一對」的是 `Sakurada_Fumiriya`＋`Sendagaya_Shino`（同一套制服的男女版），但兩個都是學生服。只改顏色的試作也算了一張（背心乘深褐、襯衫乘麻色、頭髮壓深）：剪裁沒變，還是制服。

### 7.2 別的來源（2026-11-13 查的；授權的句子都是從原頁面讀的）

- **Quaternius：Universal Base Characters＋Modular Character Outfits – Fantasy＋Universal Animation Library**——真的有冒險者服裝的男女一對，跟 `art-inbox/props/` 那包小物是同一位作者、同一種畫風。素材包的頁面寫「Free to use in personal, educational and commercial projects. (CC0 License)」。**但**他的網站現在有一頁「Quaternius Asset License (QAL) v1.0」（Last updated: 8/28/2026）：「You just can't resell or redistribute the assets themselves as assets」，也寫「the version in effect at the time you obtained the Assets governs your use of them」——所以要看下載到的 zip 裡附的授權檔。免費版的內容**沒有在他自己的頁面上確認到**（別人的清單寫：身體是 Superhero 男女各一；服裝是遊俠與平民男女各一，騎士／貴族／法師要付費）。格式有 glTF。下載在 itch.io，要人按按鈕，腳本抓不到；沒有官方的 GitHub 鏡像。動作庫第 1 版的免費版 45 段，OpenGameArt 上也有。**畫風：成年人的英雄比例、臉是簡單的西式卡通臉，不是漫畫風。** 預覽圖：<https://quaternius.com/assets/images/fullres/modularcharacteroutfitsfantasy.jpg>。
- **KayKit Adventurers 1.0**（GitHub 上、CC0、腳本抓得到）：騎士、野蠻人、法師、盜賊、戴兜帽的盜賊，75 段動作。Q 版大頭、低面數，跟現在的人物差很遠。2.0 與他的動作包只在 itch.io。
- **VRoid 這條路的其他做法都不乾淨**：官方沒有奇幻服裝的 CC0 範例；VRoid Studio 內建的東西「is not CC0」，可以商用、可以賣匯出的模型，但沒有明說可以放進公開的 repo；BOOTH 上免費的衣服看到的都寫不能轉散布。
- `M3-org/loot-assets`（GitHub 上，漫畫風的男女身體＋奇幻裝備，VRM）：**沒有授權檔**，不能用。
- 100Avatars（CC0）、VIPE Heroes（CC-BY）：檔案在 Arweave／IPFS，不是 GitHub；風格沒確認。

### 7.3 決定（D-259）

留著漫畫風的臉與頭髮（Jacky 下午選漫畫風就是因為這個），兩個人加**同一套**自製的冒險者裝備：短斗篷（蓋掉背心與領結）、腰帶與小包、到膝蓋的靴子（蓋掉及膝襪）、護臂；底下的衣服改成皮革與麻布的顏色。先做席菈。做兩輪還不像，再改用 Quaternius 的現成冒險者（要 Jacky 下載，臉不是漫畫風）。

VRoid 的衣服怎麼動（給做的人）：`Tops`／`Bottoms`／`Shoes`／`AccessoryNeck` 各是一個材質（`--tint <名字>=r,g,b` 可以整塊乘顏色）；衣服底下的身體是挖掉的，**不要刪衣服的網格**，新的衣服要蓋在外面；量半徑用 `vrm_character.py` 的 `reach()`，不要用 `radius_from()`（NEXT「0000」第 2 項）。

