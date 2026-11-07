# 開發紀錄

新的放最上面。時間為台北時間。

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
