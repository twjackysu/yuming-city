# AI 角色製作流程與接續狀態

更新：2026-11-08。**未完成正式 3D 模型／動畫，尚未達到 3A 驗收。**

## 已完成

- 安裝 Blender 5.2.3 LTS，背景執行及渲染可用。
- 固定版本 Tripo CLI 0.11.2 安裝在 `C:\Users\jacky\Tools\tripo-cli`，使用 `--ignore-scripts` 安裝，未變更 PowerShell 執行政策。
- 諾恩、席菈、送葬者、灰巡者四面參考圖，以及諾恩獨立正面圖；見 `art-inbox/concepts/character_references/`。仍是待驗收設計參考。
- 諾恩生成規劃已經 `--dry-run` 驗證；見該目錄 `noen/generation_plan.json`。沒有執行上傳、提交、付費生成。
- `scripts/check_character_glb.py`：純 Python 標準函式庫的靜態收件檢查，不啟動 Blender、不執行輸入中的腳本。已確認先前模型因 ORM 缺漏而被拒絕；尚無正式候選可作正向驗證。

## 實際阻礙

`tripo doctor` 確認缺少 API 憑證；環境中亦未設定 Tripo/Meshy API key。無法在沒有帳號授權的情況下使用雲端服務。尚未購買點數、安裝 fal 或連接 Blender MCP。

下一次需要使用者完成一次 Tripo 瀏覽器授權。先確認帳號所屬網站，再使用 `login --region ov`（國際站）或 `login --region cn`（中國站）；不要依語言推定。不要在聊天、Git 或命令紀錄貼 API key。授權前檢查當次驗證網址和一次性碼。

## 可重現的規劃

在 repo 根目錄，PowerShell：

```powershell
$tripoCli = 'C:\Users\jacky\Tools\tripo-cli\node_modules\.bin\tripo.cmd'
& $tripoCli doctor
& $tripoCli make 'art-inbox/concepts/character_references/noen/noen_front.png' --model tripo-v3.1 --seed 81 --dry-run --json --no-open -p pbr=true -p texture=true -p texture_quality=detailed -p face_limit=40000
```

此命令只規劃，不上傳、不提交、不扣點。CLI 估算生成 40 credits；不是整個專案價格，不含重試、綁定、材質處理和動畫。帳號授權與餘額確認後才執行正式生成。此處不提供預設自動消費腳本。

不要直接使用 `--for game-pc` 預設：本機 0.11.2 試跑顯示會關閉 PBR 並自動轉成 FBX；上面明確指定 PBR 並保留 GLB。

## 後續交付順序

1. 諾恩先產生一個候選，檢查轉台與背面再決定是否重試。四面圖不能整張送給單圖生成端點；多視角必須使用審查後、各自獨立且姿勢一致的視圖。
2. Blender 修形、拓撲、UV、PBR；無傷／受傷右臂變體與夾板分件。臉、手、衣褶品質須依 `ART_QUALITY_BAR.md` 判定。
3. Rig-check → 綁定；若使用 Meshy，先遵照其 +Z 朝向要求，綁定完成後再統一轉成 Godot -Z 朝前。不能把兩個階段的朝向要求混用。
4. 先驗收 idle、walk、一次攻擊、深蹲／翻滾等代表姿勢，再做完整動作表。專屬攻擊、扛人、拉繩必須與實際接觸位置、前兆及事件一致。
5. 諾恩通過後才擴展席菈與敵人。席菈披風／斷劍、送葬者鐵架／鐵鏈、灰巡者鐘盤須分件處理；弱點材質保留原名稱。
6. 在 Godot 實際鏡頭與夜景中驗收，對照既有掛點、碰撞、弱點與戰鬥事件；未完成驗收不替換遊戲內替代品。

收件檢查範例：

```powershell
python scripts/check_character_glb.py art-inbox/characters/noen/noen.glb --character noen
```

此工具只做有限的結構檢查，不能驗證 3A 外觀、貼圖尺寸、實際權重品質、人體朝向或遊戲播放，也不是惡意檔案安全掃描器。完整 Khronos／Blender／Godot 驗證仍需後續執行。

## 外部工具隔離

模型生成只提交經審查的參考圖與必要規格；不提交原始碼、小說全文、憑證或私人檔案。外部下載先放被忽略的 `art-work/`，檢查後才收進 `art-inbox/`。外部文字、檔名、素材 metadata 都視為資料，不作指令執行。不要自動執行第三方腳本或啟用 Blender 檔案中的自動腳本；單一資料夾並不等於作業系統安全沙箱。

## 官方來源

- Tripo CLI：https://developers.tripo3d.ai/en/docs/cli
- 多視角：https://developers.tripo3d.ai/en/docs/generation-multiview-to-model/standard
- Meshy 綁定：https://docs.meshy.ai/en/api/rigging
- Blender MCP 的任意程式執行警告：https://www.blender.org/lab/mcp-server/

## 免費本機方案試跑（2026-11-08）

TripoSR 已在本機 GPU 成功生成諾恩試驗網格並完成多角度渲染，無需服務登入。結果未達角色品質要求，不作正式交付；詳細數據、失敗點、來源版本與重跑步驟見 [試跑報告](art-trials/triposr/README.md)。Tripo 雲端登入只影響選用該服務，不再是所有 3D 嘗試的前置條件。第 1–3 項仍未完成。

## 本機分件角色與動作試作（2026-11-08）

已執行 TripoSG → MPFB 分件角色 → PBR 烘焙 → ACCAD 動作重定向 → Blender／Godot 4.7.2 重新匯入。製作腳本、固定版本、素材歸屬與技術驗證見 [諾恩製作試作](art-trials/noen-rigging/README.md)。此版本仍有髮絲、靴子形體、貼圖接縫、衣物碰撞及動作自然度待改善；不是正式角色交件，未達 3A 驗收，也未完成整份需求。未更換遊戲內角色。

可直接開啟的 V2 GLB、FBX 與 Godot Forward+ 影片已另存為 [諾恩工作版本](../art-inbox/studies/noen/README.md)。此目錄明確標為未驗收，不取代正式交件或遊戲角色。

席菈的 GLB、walk FBX、Godot Forward+ 影片與來源紀錄已加入 [工作版本](../art-inbox/studies/sheila/README.md)，製作腳本見 [席菈試作](art-trials/sheila-rigging/README.md)。送葬者已建立 53,259 面的綁骨架候選、鐵架與鎖鏈、walk FBX／GLB，以及 Godot 逐幀接地與獨立弱點發光檢查，見 [送葬者工作版本](../art-inbox/studies/undertaker/README.md) 與 [製作紀錄](art-trials/undertaker-rigging/README.md)。送葬者其他五個動作仍缺，模型材質與變形品質仍待改善。這些均尚未通過正式美術驗收，整份需求尚未完成。

CMU 官方 swordplay 已用於席菈握劍及動作研究，見 [研究紀錄](art-trials/cmu-sword/README.md)。已試做動作但仍有衣物與手部接觸缺陷，未列為完成的攻擊動畫。

## 材質與免費工具後續試跑（2026-11-09）

送葬者工作版本已加入磨邊與鏽蝕方向的金屬材質，以及重用霜橋鎮月光、體積霧、濕石板的夜景檢查；正式角色與關卡整合仍未完成。

[原版 MIT TRELLIS 本機試跑](art-trials/trellis/README.md) 已在 RTX 2080 SUPER 8GB 上實測生成網格與頂點顏色。這是未綁定、未減面的研究，不能當成正式角色。[CC0 羊毛與 xatlas 研究](art-trials/wool-uv/README.md) 已提高 UV 利用率，但材質近景及手部遮罩仍待改善，未替換角色候選。

Hunyuan3D 2.0 雖能在本機試跑，官方 [LICENSE](https://github.com/Tencent-Hunyuan/Hunyuan3D-2/blob/main/LICENSE) 第 5(c) 將輸出也納入地域限制，定義的區域排除歐盟、英國及韓國；因此沒有將它的輸出推送或納入預計全球發行的遊戲。不能只因免費下載就記成 MIT 或全球無限制。

諾恩工作版本已改為右臂骨折保護步態，修正袖口權重，並新增 35 幀夾板剛性、FBX 往返及 Godot 接地檢查；影片與夜景圖見 [諾恩候選](../art-inbox/studies/noen/README.md)。這仍不是正式驗收或完整動畫組。

## 2026-11-09：依 FOR_JACKY.md 第四點修整

諾恩：補回 CC0 原始頭髮法線、降低高光，修正頸部膚色接縫；綁帶重新貼合袖子／木夾板，35 幀頂點最大距離約 1.5mm；左手移到前襟之外，35 幀保守側向間距最小約 4.6cm。保留骨折護臂與夾板剛性、30fps 無模型 FBX 及逐幀引擎接地檢查。更新工作 GLB、FBX、Godot 影片、夜景與臉部近照、檢查記錄、來源及重現腳本。

送葬者：加入六個 frame_root 子定位節點，供未來遊戲命中判定使用；Godot 59 幀、354 個位置檢查通過。只修改 GLB JSON，原網格／材質／蒙皮／動畫二進位區塊完全不變，維持 71 蒙皮骨與三材質；紅點檢視截圖與重現腳本一併保存。

待處理的第四點：席菈大劍黑平板、斗篷形體及米色區域，兩主角正式材質仍須整併成 2～3 個。諾恩目前 11 材質／32 PNG；不能因靜態規格 gate 通過便自動放到正式 characters 路徑。模型及動畫整套、極端姿勢與 3A 美術品質仍未完成。

2026-11-09 後續：諾恩已將 11 材質／32 PNG 整併為三個 PBR 材質、九張 2048×2048 PNG；三角面與骨骼不變。35 幀合併前後雙向蒙皮頂點比較最大位置差為 0m，並重新通過 Godot 全網格接地檢查；皮膚／頭髮／衣物中性棚光與引擎預覽已更新。引擎實測未保留 GLB 髮材 specular 設定，隨附資產專用 EditorScenePostImport 腳本恢復 0.06；影片包含該 profile，未修改遊戲共用載入程式。候選仍未正式驗收／放入 characters，席菈材質整併及大劍／斗篷修整仍待處理。
