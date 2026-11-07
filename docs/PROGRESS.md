# 開發紀錄

新的放最上面。時間為台北時間。

## 2026-11-08 04:26–05:00　第 6 輪：送葬者第二階段＋車隊、九息石拱、鐵架拋擲兩條路線、戰鬥 HUD、席菈拉起、掙扎、鎖定補完（M1.2 完成）

**做了什麼**

- 送葬者第二階段：連續下砸（第二下前兆 0.5、攻略沒寫，諾恩近處看過一次才變已證實、席菈之前閃不開）、抓取（席菈守著就擋下；抓到諾恩要連按閃避掙脫）、第二階段輪替、優先追車隊；`EnemyBrain` 加連段 `chain`、讀不懂 `unreadable`，看穿 `hidden` 招式（D-029）。
- 傷者車隊：`CaravanRunner`（推進、被打停 2 秒＋傷者、抵達、存讀）＋程序推車與提燈。
- 九息石拱 `NineBreathSite`：廢墟＋鐘紋 → 走近顯示可保存與代價 → 按住預覽（不付代價）→ 1 秒發動：石拱重現（碰撞、推出）、畫面去飽和、九聲程序心跳、倒數 → 化灰（D-030）。
- 鐵架拋擲：生命 ≤ 300 或車隊過半觸發一次，送葬者站定舉鐵架 4 秒；落下時石拱是實體就擋下，否則席菈燒薪火劍。`ConvoyEncounter` 串起來：車隊通過路口＝結束、送葬者被斬倒、寫旗標。沙盒 `--convoy`。
- 戰鬥 HUD（戰鬥中才出現：生命、體力、指令冷卻、席菈倒下倒數、掙扎提示）；席菈倒下 8 秒內走近按 F 拉起，超過等戰鬥結束；鎖定被牆擋 1.5 秒解除、滑鼠／右搖桿左右甩換目標；戰鬥中鏡頭拉遠 4.2 m（D-031）。
- 修正兩個潛伏 bug：`EnemyBrain` 直接改到共用的戰鬥數值（第二階段下砸前兆會汙染之後的所有送葬者）；換難度會把送葬者的第二階段設定洗掉。
- CI release latest 多一張 `ninebreath.png`；README、FOR_JACKY 試玩說明（`--convoy`、九息、掙扎、拉起）。

**怎麼驗證**

- 測試 119 → 144 全綠：車隊推進／受傷／存讀、第二階段追車隊並打中；連段與第二下前兆、看穿隱藏招式、閃開對讀不懂的招失敗、看過一次變已證實；拋擲只觸發一次（生命／車隊過半）；抓取被席菈守住擋下、諾恩掙扎／被捏／弱點鬆手；石拱提示＋代價、預覽不付代價、放開取消、發動後射線被擋、去飽和與恢復、九聲心跳、推出、讀檔後化灰；拋擲兩種結局；遭遇戰舉鐵架時不動、車隊抵達結束；HUD 數值與顯示時機、拉起時機；鎖定換目標、被擋解除、戰鬥鏡頭；**M1.2 驗收流程測試：沙盒送葬者戰兩條路線（九息／薪火劍）都打得完**。
- 畫面：xvfb＋lavapipe 看過石拱預覽（提示＋代價＋輪廓）、重現（全畫面去飽和、只有石拱亮）、第二階段＋車隊＋看穿（連續下砸未證實）、戰鬥 HUD。依截圖調了：截圖位置會觸發梨販對話（換位置）、重現的石拱過曝（emission 1.4 → 0.35＋rim）、傷者布料太亮。
- CI：第二階段＋車隊 run 42411579068、九息石拱 run 42412146209 綠燈；之後幾個 push 的 run 被後一個取消，最後一次程式 commit（ac48102）的結果見下一則或 NEXT。

**遇到的問題**

- 新測試裡送葬者一直出招把諾恩打倒，`Game` 的倒下狀態漏到後面的流程測試（整條走不動）→ 只測招式時把敵人 `set_physics_process(false)`，寫進 NEXT 備註。
- 改了翻譯 CSV 要重跑字型子集（test_fonts 會報缺字）和 `--import`（截圖才會用到新翻譯）。

## 2026-11-08 03:27–04:08　第 5 輪：看穿＋弱點、席菈與三指令、難度選單、程序音效、送葬者第一階段、鎖定

**做了什麼**

- 看穿：按住右鍵／LT，敵人頭上顯示已知資訊（`intel.json`：名字、弱點、招式，已證實／未證實？，正在出的招加 ▶），弱點位置亮起；不放慢時間（D-024）。
- 弱點：方向判定（灰巡者左膝＝從牠左側、送葬者鐵架關節＝背後、跪地全露），諾恩打中傷害與失衡 ×2；敵人前兆中失衡 ×0.5、破綻中 ×2。
- 席菈：`CompanionBrain`＋`Sheila`（程序人偶白衣、斷劍）：跟隨、自主斬擊（不在敵人前兆中出手）、打弱點／閃開／守住、時機窗依難度、冷卻 1.5 秒、拒絕附理由、頭上回話（D-025）。敵人改追最近的心跳（諾恩或席菈）。
- 難度選單（故事／標準／困難，存 `[gameplay]`，即時套用）；程序音效 `scripts/gen_sfx.py`（鐘聲、第九聲、鈍擊、弱點鈍擊、爪擊、斬擊、閃避），接到打擊、閃避、敲鐘（D-027）。
- `EnemyActor` 共用基底、`EnemyBrain` 多招（`moves`＋`pattern`）；送葬者第一階段：橫掃／下砸／衝撞＋扇形、圓形、直線霜紋與前兆姿勢，衝撞撞牆跪地；生命 450 以下進第二階段入口（下砸變未證實、前兆 0.7）（D-026）。
- 鎖定（中鍵／R3）：挑前方最近的敵人、鏡頭與身體轉向、超距或倒下解除；席菈優先打鎖定目標（D-028）。
- 沙盒旗標 `--boss`、`--insight`、`--lock`、`--difficulty=`；CI release 多一張 `combat.png`；README、FOR_JACKY 試玩說明更新。

**怎麼驗證**

- `scripts/check.sh`：119 個測試全綠（新增看穿文字／覆寫、弱點方向、失衡倍率、場景內看穿顯示、左側打左膝；席菈時機窗／冷卻／拒絕／反擊／自主斬擊／跟隨／打弱點擊倒；難度存讀與即時套用；音效產生與播放；送葬者招式輪替、前兆長度、橫掃／下砸命中、撞牆跪地、第二階段資訊、背後弱點；鎖定挑目標、鏡頭轉向、解除、席菈跟著鎖定）。
- 畫面：xvfb＋lavapipe 看過看穿（灰巡者、送葬者）、席菈、設定選單難度列、鎖定標記。
- CI：看穿＋席菈 run 42407048423、難度＋音效 run 42407220230、送葬者 run 42407785988、鎖定＋戰鬥截圖 run 42408238805（705629b，鎖定那次 run 42408215895 被後一個 push 取消、由這次涵蓋）全部綠燈；release latest 已更新並有 `combat.png`。

**遇到的問題**

- 測試裡先 `add_child` 再設敵人位置，敵人會先在原點跟諾恩重疊，把諾恩頂到頭上、再當移動平台載走 → 改成先設位置再進樹（寫進 NEXT）。
- 測試剛播完音效就結束會留下 ObjectDB leak 警告 → 結尾多等一個 frame。
- 原本的「前兆中三下鈍擊跪地」測試因為前兆失衡減半改成六下（規則變更，不是 bug）。

## 2026-11-08 02:26–03:00　第 4 輪：按鍵重新綁定、過場與敲鐘九下、戰鬥起步、灰巡者、死亡重試

**做了什麼**

- 輸入：按鍵設定頁（每個動作鍵鼠＋手把兩格、衝突交換、恢復預設、Esc／Start 取消，存 `[input]`）；`InputGlyphs` 依最後使用的裝置顯示鍵名，對話提示變成「[F] 繼續・按住 [F] 跳過」／「[A] …」（D-020）。
- 過場：`CutsceneRunner`（資料驅動，鏡頭可等待輸入）＋`CutsceneView`（黑邊、字幕、提示、按住 1 秒跳過）＋`HoldToSkip`（對話共用）。沙盒鐘樓改成可互動演出：廢鐘、親手敲九下（[F] 敲鐘 n／9）、第八下狗吠字幕、第九下北街房屋沉陷；跳過或讀檔直接套結果（D-021）。
- 戰鬥起步：`tuning.json`＋`user://tuning.json` 覆寫（F5 重載）、`Health`、鐘錘下劈命中判定（扇形、每次揮擊一次）、打擊停頓、鏡頭震動（減少晃動 25%）、練習木樁（D-022）。
- 灰巡者：`EnemyBrain`（追 → 前兆 → 爪擊 → 破綻；失衡 60 跪地 2 秒；故事難度前兆 ×1.3）、霜紋前兆發光；沙盒 `--enemies` 放一隻。
- 死亡重試：倒下 → HUD「你倒下了」→ 2.2 秒後回最近自動存檔。
- 改編：01 補完全篇 → 遊戲章節對應、12/31 範圍（序章＋第一部第 1～3 章，D-023）、角色弧線、主題保留方式；切片收束對話「梨與秤」（`slice_ada_aftermath.json`）。
- check.sh：測試輸出有 `SCRIPT ERROR` 一律失敗（發現自製框架會把執行期錯誤當通過）。CI release 多一張 `bell.png`。

**怎麼驗證**

- `scripts/check.sh`：92 個測試全綠（新增重新綁定／衝突／壞設定檔／鍵名與裝置切換／按鍵設定頁操作、過場驗證與推進與跳過、流程測試改成親手敲九下、戰鬥數值與覆寫、Health、扇形、木樁命中＋停頓＋震動、灰巡者狀態機與場景內爪擊、閃避無敵、死亡重試回檢查點、收束對話依記憶過濾選項）。
- 畫面：xvfb＋lavapipe 看過按鍵設定頁（繁中）、手把提示 [A]、敲鐘提示 3／9 與黑邊、木樁。修了：鐘的錐體上下顛倒、提示字壓在鐘上。
- CI：重新綁定 run 42401979630、過場 run 42402604445、收束對話 run 42403248771（含戰鬥、灰巡者、死亡重試的所有程式）綠燈，latest 有 `bell.png`。死亡重試 run 42402903825 測試與匯出綠燈，但發布 latest 時 403（見下）。CI 修正 run 42404425846 綠燈、latest 已更新（f44b331）。

**遇到的問題**

- `CombatTuning.reload()` 跟 GDScript 內建的 `Script.reload()` 撞名，測試呼叫到後者 → 改名 `load_tuning()`。這個錯誤當時被測試框架當成「通過」，所以加了 SCRIPT ERROR 檢查。
- 軟體渲染截圖 200 幀會超過 2 分鐘；改用背景執行＋較少幀數。
- 發布 latest 偶爾 403「Resource not accessible by integration」：兩次都是 main 上已經有改過 workflow 檔的新 commit，舊 run 用 GITHUB_TOKEN 在舊 commit 建 tag 被擋，而且「先刪再建」讓 latest 暫時消失。修正：main 已有更新的程式 commit 時舊 run 直接跳過發布（f44b331）。

## 2026-11-08 01:27–02:05　第 3 輪：暫停／設定選單、HUD、程序人偶、對話系統

**做了什麼**

- 設定：`QualityPreset`（低：深度霧代替體積霧、關 SSAO／Glow／MSAA；高：SSR、SSIL、MSAA 4x），新場景自動套用；音訊匯流排 Music／SFX／Voice／UI；全螢幕、垂直同步、減少鏡頭晃動（D-019）。
- UI：暫停選單（Esc／Start，視窗失焦自動暫停）、設定選單（標題與暫停共用，手把可操作）、HUD（目標淡入、8 秒後淡出、Tab 再看；「已存檔」提示）。標題「語言」改為「設定」。
- 程序人偶 `Puppet`：長外套、圍巾、左手提燈、右手鐘錘；待機呼吸、走跑步態、前滾閃避、鐘錘下劈；介面固定方便換正式模型（D-017）。
- 對話：`DialogueDB`（驗證）、`DialogueRunner`、`Game.start_dialogue()`、`DialogueBox`（逐字浮現、選項、按住跳過）；梨販＋艾妲的對話（取材原作第一章與第四部「秤不準」），付出「父親最後的對話」後提到父親的選項會消失（D-018）。
- 沙盒：梨販攤子、劇情觸發區（梨販 → 對話 → 敲鐘目標；鐘樓 → 北街陷落）。CI 多截一張繁中對話圖。

**怎麼驗證**

- `scripts/check.sh`：67 個測試全綠（新增畫質、設定存讀與匯流排、UI 文字皆為翻譯 key、暫停／繼續、HUD、人偶狀態與步態、對話驗證／記憶隱藏選項／跳過、場景層面：走進觸發區 → 對話 → 任務推進＋自動存檔）。
- 畫面：xvfb＋lavapipe 截圖看過 HUD、暫停、設定（中英）、低畫質、人偶、對話選項；修了兩個問題（全螢幕 UI 用 `set_anchors_preset` 沒有撐開 → 改 `set_anchors_and_offsets_preset`；低畫質背景全黑 → 深度霧影響天空）。
- CI：UI run 42397436866、人偶 run 42397764670 綠燈；對話 run 42398212944 測試與匯出綠燈、但建立 release 時遇到暫時性 403（latest 被刪掉後沒建回來）；下一個 run 42398233141（04efd8a，含對話截圖）全綠，latest 恢復並多了 `dialogue.png`。之後加上建立 release 失敗重試（7a49588，run 42398890348 綠燈）。

**遇到的問題**

- `apt-get install mesa-vulkan-drivers` 要先 `apt-get update`（已寫進 NEXT）。
- 測試留下未結束的對話會讓後面的測試玩家不能動 → 測試 after_each 清掉 `Game.dialogue`。
- CI 的 release 步驟是「先刪再建」，建立失敗時 latest 會暫時消失 → 加重試；若再發生，下一次 push 也會補回。

## 2026-11-08 00:26–01:00　第 2 輪：設計 02～05 定稿、任務系統、沙盒與效能量測

**做了什麼**

- 設計文件：02 補完（數值初版、送葬者兩階段招式表、鏡頭規則）；新增 03 美術音效、04 架構、05 切片計畫（每日排程）；PLAN 同步；D-013～D-016。
- 任務系統：`StoryLogic`（條件／效果）、`QuestDB`（JSON 驗證）、`QuestRunner`（推進、檢查點、循環保護）、`GameSession`（新遊戲、自動存檔、讀檔恢復、死亡重試）；`data/quests/slice_main.json`＋`i18n/slice.csv`。
- `Game` autoload；標題「新遊戲／繼續」接上；`--level=<id>` 直接進關卡。
- `PlayerController`（相機相對移動、衝刺、閃避、越肩 SpringArm 鏡頭）＋冬夜街道沙盒（AgX、體積霧、SSAO、暖色路燈與窗光）。
- `Perf` overlay（F3／`--perf`）、`FrameStats`、benchmark 場景（`++ --benchmark` → `user://benchmark/*.json`）；使用者資料夾改為 `YumingCity`。
- CI 多截一張沙盒圖放到 release `latest`；README 改用這張圖。

**怎麼驗證**

- `scripts/check.sh`：49 個測試全綠（新增條件／效果、任務驗證與推進、兩條路線的主線流程測試含中途存讀檔與死亡重試、沙盒中按前進會走、幀統計、benchmark）。
- 畫面：xvfb＋lavapipe（Forward+）截圖，調整一次光色（第一版整體偏暖褐 → 提高月光與霧的冷色自發光，暖色只留在燈）。
- benchmark 在 xvfb 與 headless 都跑完並寫出 JSON；確認 `++` 分隔符可用。
- CI：任務系統 run 42391936076、沙盒 run 42392600104、overlay run 42392790363、benchmark run 42392980863 綠燈；release `latest`（0544afd）有 Windows／Linux zip、`title.png`、`sandbox.png`。

**遇到的問題**

- 新 session 沒裝 `mesa-vulkan-drivers`，截圖退回 OpenGL（沒有體積霧）→ 安裝後恢復 Vulkan／Forward+。
- GameSession 用 lambda 轉接 QuestRunner 訊號造成 RefCounted 循環洩漏 → 改用方法 Callable。
- 一次推了程式 commit（6121a2f，只改註解）＋`[skip ci]` 文件 commit，整個 push 被跳過 CI → 手動 workflow_dispatch（run 42393121387）補驗，綠燈。之後程式與文件 commit 一定分開 push。

## 2026-11-07 23:26–23:59　第 1 輪：Godot 骨架、CI、存檔與九息核心、讀完原作

**做了什麼**

- 引擎方向改為 Godot 4.7.2-stable（D-001、D-002）：改寫 README、technical-direction、.gitignore、.gitattributes。
- `scripts/get-godot.sh`（下載＋SHA512 驗證）、`scripts/check.sh`（import＋腳本型別檢查＋測試＋匯出）、`scripts/screenshot.sh`（xvfb 截圖）、`scripts/gen-assets.sh`／`gen_fonts.py`（Noto CJK TC 子集化）。
- `game/` 專案：標題畫面（程序霧氣 shader、明體標題）、App／Settings autoload、繁中＋英文翻譯、GDScript 未加型別視為錯誤。
- 核心邏輯：`GameState`、`SaveCodec`（版本＋遷移＋.bak 回復）、`NineBreath`（九息狀態機）、`InputSetup`（鍵鼠＋手把預設按鍵，在程式碼註冊，方便之後做重新綁定）。
- 自製測試框架；23 個測試（i18n 規則、設定、存檔、九息、字型缺字、按鍵綁定、開機到標題的流程）。
- CI：push 到 main 時測試、匯出 Windows／Linux、截圖，更新 prerelease `latest`。
- 讀完原作四部＋終章，整理成 `docs/design/00-story-digest.md`；`01-adaptation.md` 初稿（切片段落對應、英文名暫定）；`02-gameplay.md` 初稿（喊前兆的協作戰鬥、九息流程、日記、死亡重試）。
- 建立 PLAN、NEXT、DECISIONS（D-001～D-012）、FOR_JACKY、ART_REQUESTS、CREDITS。

**怎麼驗證**

- 本機：`scripts/check.sh --export` 全綠，Windows exe（約 114 MB，含 pck）與 Linux 匯出成功。
- 畫面：xvfb＋軟體 Vulkan 截圖，英文與繁中標題畫面都看過（繁中改用 Noto Serif CJK TC 後字形正確）。
- CI：run 42386961785 失敗（乾淨 clone 的 .translation 尚未產生）→ 修正後 run 42387162270 綠燈，release `latest` 有 Windows／Linux zip 與截圖。存檔、九息 commit 的 run 42388049346、42388111643 綠燈；字型 commit 的 run 42388277840 失敗（`python3 -I` 看不到 pip --user 裝的 fonttools）→ 改 `-P` 後 run 42388383397 綠燈；本輪最後一次程式 push（按鍵綁定）run 42388726011 綠燈。

**遇到的問題**

- Git LFS 推送被雲端 session 的網路代理擋下（S3 上傳 403）→ 不 commit LFS 類型，素材建置時生成（D-004）。
- `curl` 讀不到 GitHub 的 `releases/latest` 轉址（403），改用 WebSearch 確認版本、直接測下載網址。
