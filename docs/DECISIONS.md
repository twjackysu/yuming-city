# 決策紀錄

新的放最上面。格式：編號、日期（台北時間）、決策、理由、影響。

## D-028　2026-11-08　鎖定規則

- 決策：鎖定（中鍵／R3）挑鏡頭前方 70° 內「距離＋角度×0.08」最小的敵人，前方沒有就挑 15 公尺內最近的；鎖定中鏡頭水平方向與角色面向跟著目標（滑鼠／右搖桿只調上下），超過 15 公尺或目標倒下自動解除。席菈的目標優先用諾恩的鎖定目標。「被擋 1.5 秒解除」與「右搖桿撥動換目標」延後到霜橋鎮白盒（街道有遮擋時才測得出來）。
- 理由：02-gameplay 的「打弱點打目前鎖定的敵人」需要一個明確的目標；純函式挑目標好測。
- 影響：之後的「打弱點」指令提示可以畫在鎖定目標上。

## D-027　2026-11-08　難度存在設定檔；音效程序生成、不進 git

- 決策：難度（故事／標準／困難）是設定（`settings.cfg` 的 `[gameplay]`），不是存檔欄位；改了即時套用到場上的敵人（前兆長度、傷害）與席菈（指令時機窗）。音效用 `scripts/gen_sfx.py`（只用 Python 標準函式庫、固定種子）在建置時產生到 `game/assets/generated/sfx/`，跟字型一樣不進 git；檔案不存在時 `Sfx` 安靜跳過。
- 理由：難度只改數值、不改代價與流程（02-gameplay），玩家卡關時應該能隨時調；雲端推不了 LFS（FOR_JACKY 第 3 項），程序音效又小又可重現。
- 影響：正式音效（Jacky 提供或 CC0）之後放 `art-inbox/` 匯入時，同名覆蓋程序版即可；CREDITS 已記。

## D-026　2026-11-08　敵人共用 EnemyActor；多招敵人用 moves＋pattern 資料

- 決策：敵人場景節點繼承 `EnemyActor`（追最近的心跳＝諾恩或席菈、看穿顯示、弱點、難度、`hit_heartbeats`／`hurt`），子類別只寫外型、命中形狀與前兆表現。`EnemyBrain` 支援多招：`tuning.json` 的 `<敵人>.moves`（每招 telegraph／active／recover／min_range／range 與形狀數值）＋`pattern`（輪替順序，距離不合就跳下一個）。送葬者第一階段「前兆與攻略一致」：下砸前兆 1.0 秒；生命 450 以下進第二階段，下砸變 0.7 秒、看穿標成未證實。
- 理由：送葬者、之後的鐘舌送葬者（D-023 第 3 章）都需要多招；資料驅動才能在 F5 重載時調手感。
- 影響：第二階段的連續下砸、拋擲、抓取在下一步加進 moves；車隊目標另做。

## D-025　2026-11-08　席菈指令的細部規則

- 決策：被接受的指令進 1.5 秒冷卻，被拒絕的不進（玩家可以馬上改下別的）。拒絕理由：沒有目標、體力不夠、她倒下了。「打弱點」只在敵人破綻（攻擊後恢復中）或跪地時成功（60 傷害、失衡打滿），其他時候「被反擊」（她扣爪擊傷害）；「閃開」只在前兆後段（標準 60%、故事 100%、困難 35%）成功：0.5 秒無敵＋敵人出完招後反擊（27 傷害、失衡 30），太早只是白閃。自主行為：跟隨、在範圍內斬擊（18），但**不在敵人前兆中出手**——不叫她閃，她就等前兆過去。「守住」是切換：記下當下諾恩的位置，守在那裡、只打靠近的敵人。
- 理由：指令要有明確的對錯回饋（頭上回話），又不能讓自主行為搶走指令的價值。
- 影響：「拒絕會害死人的指令」（例如傷者旁引怪）等車隊與傷者實作後再加；倒下 8 秒內可被拉起也延後。

## D-024　2026-11-08　看穿與弱點的判定

- 決策：看穿按住才顯示（不放慢時間），資料在 `game/data/combat/intel.json`（名字、弱點、招式、已證實與否），執行期可覆寫成未證實；正在出的招前面加 ▶。弱點是「方向」判定：攻擊者在敵人的哪一側（`exposed_arc`，灰巡者左膝＝左側 25°～155°，送葬者鐵架關節＝背後），跪地時全露。打中弱點：諾恩鈍擊傷害與失衡 ×2、停頓 0.09 秒。敵人前兆中受擊失衡 ×0.5（硬撐、不打斷），破綻中 ×2。
- 理由：用位置而不是精準打點，鍵鼠與手把都能做到、看得懂（「繞到牠左邊」），也和席菈的「打弱點」共用同一份資料。前兆硬撐／破綻加倍讓「等破綻」比亂打划算，呼應「看懂比數值重要」。
- 影響：D-022 原本寫的「命中點高度」改成方向判定；看穿文字走翻譯 key。

## D-023　2026-11-08　12/31 版本範圍：序章（切片）＋第一部第 1～3 章

- 決策：12/31 版本＝序章「第九聲鐘」（垂直切片）＋第 1 章「攻略之外的門」（酒館簡報、地窖、白晝城石碑）＋第 2 章「城主的飯桌」（縮成一場飯桌對話與探索）＋第 3 章「不准替我答應」（鐘舌送葬者解謎 Boss）。第一部第 4、5 章（城市據點、屏障高潮）與第二～四部放到 2027。對應表與角色弧線在 `docs/design/01-adaptation.md`。
- 理由：序章到第 3 章是一條完整的小弧線（敲錯鐘 → 知道真相 → 第一次「不准替別人決定」），只需要切片已有的系統再加一個解謎 Boss；第 4 章起需要完整的城市據點系統，12 月做不精。
- 影響：12/14～12/24 的「下一段章節」以第 1、3 章為主，第 2 章做成對話章。

## D-022　2026-11-08　命中判定用幾何扇形＋群組；打擊停頓用 time_scale

- 決策：近戰命中不用物理形狀查詢，改在出招那一幀對 `damageable` 群組做水平扇形判定（`PlayerController.in_strike_arc`，純函式）；每次揮擊只判定一次（`strike_window` 進入時）。敵人邏輯在 `EnemyBrain`（純狀態機，吃距離與時間），場景節點只負責移動與表現。打擊停頓用 `Engine.time_scale`＋真實時間計時器（重疊時以最後一次為準），回標題與重試時強制恢復 1.0。測試輸出出現 `SCRIPT ERROR` 一律視為失敗（之前執行期錯誤會讓測試「通過」）。
- 理由：headless 測試裡物理查詢時機不穩；扇形判定可預測、好調、好測。敵人數量少（切片同時 ≤ 4），遍歷群組沒有效能問題。
- 影響：之後的弱點（左膝）判定在扇形內再看命中點高度與方位；大型敵人（送葬者）改成多個 hurtbox 點。

## D-021　2026-11-08　過場＝可互動演出；狀態只由 effects 改變，跳過永遠安全

- 決策：過場放 `game/data/cutscenes/*.json`，一串鏡頭（Marker3D 名稱）；鏡頭有時長或等待某個動作（`await`＋`prompt`＋可選 `counter`）。狀態只能由鏡頭的 `effects` 與 `on_end` 改變，`event` 只給畫面與聲音。跳過＝依序補上還沒套用的 effects 再套 `on_end`，被跳過的 event 不發，關卡改看旗標補上結果（例如北街沉陷）。按住互動鍵 1 秒跳過（對話 0.6 秒，共用 `HoldToSkip`）。過場中玩家不能移動（`Game.is_player_locked()`）。
- 理由：原作的「親手敲九下」需要每一下一個輸入，又要能跳過與重試；把互動與演出放在同一個資料格式，跳過與讀檔都不會漏掉狀態。
- 影響：敲鐘、之後的九息還原演出、席菈薪火劍都用這個格式。字幕目前一律顯示（沒有配音），之後有語音時才讓字幕開關生效。

## D-020　2026-11-08　按鍵重新綁定規則

- 決策：每個動作兩格（鍵鼠、手把）。暫停鍵（Esc／Start）與移動搖桿固定，不能被綁走；新鍵已被同一格的其他動作使用時兩者交換。只存跟預設不同的動作到 `settings.cfg` 的 `[input]`，讀取時從預設開始逐筆 rebind，壞值略過、衝突自動解開。鍵名：滑鼠、手把（Xbox 配置）、幾個有名字的鍵走翻譯 key（`GLYPH_*`）；其他鍵盤按鍵用系統鍵名（鍵帽上的字，不翻譯），這類 UI 節點標 `meta glyph`、關閉自動翻譯，i18n 測試略過。
- 理由：保證永遠叫得出選單；交換比拒絕更少挫折；設定檔被手改壞也不會讓遊戲不能玩。
- 影響：手把圖示目前是文字（A／B／LB…），打磨階段可換成圖示字型或貼圖，介面（`InputGlyphs.label_for_spec`）不變。

## D-019　2026-11-08　畫質三級只切開關；設定即時生效、關閉選單才存檔

- 決策：`QualityPreset`（低／中／高）只切換效果開關與 MSAA，不改場景調好的霧色與密度。低畫質關體積霧時改開便宜的深度霧（顏色取自場景的體積霧），保住冬夜氛圍。場景的 WorldEnvironment 進樹時由 Settings 自動套用（`node_added`），場景不用自己處理。音訊匯流排 Master／Music／SFX／Voice／UI（UI 接 SFX）由程式建立。設定改值即時生效，關閉設定選單時才寫 `settings.cfg`（語言切換例外，立即寫入）。
- 理由：場景只需要做一份「中」畫質的調整；畫質選項可以測試；拖滑桿不會一直寫檔。
- 影響：新場景只要用 WorldEnvironment 就自動支援畫質；之後新增的效果（SDFGI、陰影距離等）加在 `QualityPreset` 一處。

## D-018　2026-11-08　對話：JSON 節點圖＋DialogueRunner，由 Game 接到任務

- 決策：對話放 `game/data/dialogue/*.json`（格式見 `dialogue_db.gd` 開頭），文字 key 放 `i18n/slice.csv`。`DialogueRunner` 是純邏輯（台詞、條件過濾選項、效果）；`Game.start_dialogue(id)` 建立 runner、效果套用後呼叫 `session.advance()` 推進任務；`DialogueBox` 只聽訊號。驗證規則：next／choices 指向存在節點、不能同時有 next 與 choices、每組選項至少一個無條件選項（避免卡住）、所有節點都要從 start 走得到。跳過只跳到下一個選項，不替玩家做選擇。
- 理由：照 04 架構與 D-013；對話與任務共用 StoryLogic，條件與效果都可測；「付過的記憶讓選項消失」直接用 `{"not": {"memory_paid": ...}}` 表達。
- 影響：對話中玩家不能移動（`Game.is_in_dialogue()`）；對話狀態不存檔（從檢查點重建時重新觸發）。

## D-017　2026-11-08　程序人偶用 Node3D 關節，不用 Skeleton3D

- 決策：`Puppet`（`scenes/actors/puppet/`）用 Node3D 樞紐＋膠囊肢體，程式算姿勢（待機呼吸、走跑步態、前滾、鐘錘下劈）。對外介面固定：`set_move_speed`、`play_action("dodge"|"attack")`、`current_state()` ∈ `STATES`（idle／walk／run／dodge／attack）、`hand("L"|"R")`。
- 理由：程序骨架＋蒙皮的價值在換模型時才出現，但那時會整個換成 Jacky 提供的模型與 AnimationTree；Node3D 樞紐更快、好測、剪影一樣清楚。05 計畫原寫 Skeleton3D，改為介面相容即可。
- 影響：正式模型到位時，新增一個同介面的類別（內部用 AnimationTree，狀態名沿用 STATES），PlayerController 不用改。

## D-016　2026-11-08　效能量測：overlay＋benchmark JSON；開發工具文字不翻譯

- 決策：`Perf` autoload（F3／`--perf`）顯示 FPS、1% low、CPU／GPU 渲染時間、draw calls、VRAM、驅動與顯示卡；`--benchmark` 跑固定鏡頭路徑 30 秒（暖機 2 秒不計），寫 `user://benchmark/bench-*.json`。達標判定：平均 ≥ 60 fps 且 1% low ≥ 45 fps。overlay 與 benchmark 是開發／量測工具，文字用英文技術縮寫、不走翻譯 key（不出現在玩家選單）。
- 理由：session 沒有 GPU，效能只能由 Jacky 實機量測；把量測做成一個指令、一個 JSON，回報成本最低。
- 影響：benchmark 場景會隨切片內容更新（之後改成霜橋鎮白盒）；JSON 格式改動要保持舊欄位。

## D-015　2026-11-08　使用者資料夾固定為 YumingCity

- 決策：`application/config/use_custom_user_dir=true`、`custom_user_dir_name="YumingCity"`。Windows 為 `%APPDATA%\YumingCity\`（存檔在 `saves/`、benchmark 在 `benchmark/`、設定 `settings.cfg`）。
- 理由：路徑短、不含空格與 Godot 字樣，方便寫給 Jacky 的量測步驟，之後 Steam 雲端存檔也指向這裡。
- 影響：改名會讓舊存檔找不到；正式發行前不再更動。

## D-013　2026-11-08　任務與對話：JSON 結構＋翻譯 key

- 決策：任務、對話、戰鬥數值放 `game/data/**/*.json`；JSON 只放結構與翻譯 key，玩家看得到的文字一律在 `game/i18n/*.csv`（切片的任務與對話文字用 `slice.csv`，與介面 `strings.csv` 分開；每個 CSV 都要在 project.godot 註冊，測試會檢查）。條件與效果只能讀寫旗標與記憶，不執行任意程式。
- 理由：Godot 內建 JSON 解析、純文字好 diff 與測試；遵守「所有文字走翻譯 key」；字型子集化只需掃 CSV。
- 影響：測試檢查 JSON 引用的 key 都存在且有 en＋zh_TW；`gen_fonts.py` 掃描 `i18n/*.csv`。詳見 `docs/design/04-architecture.md`。

## D-014　2026-11-08　戰鬥數值與鏡頭規則定初版

- 決策：照 `docs/design/02-gameplay.md` 的數值表與鏡頭規則實作；諾恩沒有體力條，席菈有；難度只調傷害、前兆長度與指令時機窗，不改代價。開發用 `user://tuning.json` 覆寫並熱重載。
- 理由：Jacky 喜歡「簡單但吃技巧」的戰鬥——減少資源管理、把技巧放在讀前兆與下指令的時機。
- 影響：數值不寫死；試玩後調整只改資料檔。

## D-012　2026-11-07　九息的狀態語意

- 決策：可保存物件只有三態 BROKEN → RESTORED（倒數九息，每息 1 秒）→ SPENT（化灰，最終狀態，不會回到損壞）。代價在 activate 時付，同一段記憶只付一次。存檔若落在九息中間，讀檔一律視為 SPENT。狀態存在旗標 `ninebreath.<object_id>`。
- 理由：照原作（九次心跳後石拱化灰）；避免讀檔重複扣代價或卡在半途。
- 影響：場景節點只負責顯示、碰撞切換與把玩家推出碰撞體；邏輯在 `game/src/core/nine_breath.gd`。

## D-011　2026-11-07　存檔格式：JSON＋版本號＋逐版遷移

- 決策：`{"version", "saved_at", "state"}`，目前 v1；改格式就加版本與遷移步驟和測試。寫檔先寫 `.tmp` 再改名，舊檔留 `.bak`，主檔壞掉自動讀 `.bak`。拒絕讀取比遊戲新的存檔版本。
- 理由：純文字好除錯、好測試；遷移鏈保證舊存檔能讀。
- 影響：之後 Steam 雲端存檔同步 `user://saves/` 下的 JSON 即可。

## D-010　2026-11-07　字型：Noto CJK TC 建置時子集化

- 決策：從 notofonts/noto-cjk release 下載（SHA-256 固定），依翻譯與資料檔用字子集化，標題用 Noto Serif CJK TC SemiBold，介面用 Noto Sans CJK TC。產物不進 git；字型不存在時退回系統字型。
- 理由：繁中字形在各系統一致、標題有質感；子集後每個字型約 100 KB；OFL 授權可商用。
- 影響：新增文字檔類型時要確認 `gen_fonts.py` 的收字範圍涵蓋；測試會檢查缺字。

## D-009　2026-11-07　畫面驗證用 xvfb＋軟體 Vulkan 截圖

- 決策：遊戲支援 `-- --screenshot=<png> --frames=<n>`，跑 n 幀後存檔結束；`scripts/screenshot.sh` 以 xvfb-run 執行，Vulkan 失敗時改 opengl3。CI 也截一張標題畫面放到 release。
- 理由：session 實測 xvfb＋mesa（lavapipe）能跑 Forward+ 並截圖，loop 可以看到自己的畫面。
- 影響：截圖只代表畫面內容，不代表效能。效能一律由實機量測。

## D-008　2026-11-07　CI 每次 push 重建 prerelease「latest」

- 決策：push 到 main 時，CI 刪除舊的 `latest` release 與 tag，再以當次 commit 建立新的 prerelease，附 Windows／Linux zip 與截圖。
- 理由：讓 Jacky 永遠從同一個網址下載最新版；刪除後重建不需要 force push tag。
- 影響：`latest` 沒有歷史；正式版本另打版本 tag（階段 3）。

## D-007　2026-11-07　渲染：Forward+，Windows 預設 D3D12

- 決策：`rendering_method=forward_plus`，Windows 驅動 `d3d12`，Godot 失敗時自動退回 Vulkan。
- 理由：Jacky 指定 Forward+；DX12 在 Windows 上的驅動相容性較廣。
- 影響：實機量測時要記錄實際使用的驅動（效能 overlay 會顯示）。

## D-006　2026-11-07　在地化用 CSV（keys,en,zh_TW）

- 決策：`game/i18n/strings.csv` 一個檔案放兩種語言；生成的 `.translation` 不進 git。預設語言依 OS：繁中系統用 zh_TW，其他一律英文。key 用大寫底線。
- 理由：兩語並排好維護；測試可以檢查每個 key 都有兩種語言、場景沒有寫死文字。
- 影響：乾淨 clone 要先 import 一次才有翻譯檔（`scripts/check.sh` 已處理）。

## D-005　2026-11-07　測試框架自製（極簡 TestCase），不引入 GUT

- 決策：`game/tests/run_tests.gd`（SceneTree 腳本）＋ `TestCase` 基底類別；先檢查所有腳本能載入，再跑 `tests/unit`、`tests/flow`。
- 理由：零依賴、headless 直接跑、程式碼不到 200 行；需求長大再評估 GUT（MIT）。
- 影響：新邏輯一律寫 `test_*.gd`。

## D-004　2026-11-07　Git LFS：session 無法推送，loop 不 commit LFS 類型

- 決策：保留 `.gitattributes` 的 LFS 規則（並加入 glb、ogg、jpg、字型等），但 loop 不 commit 這些類型。程序生成的素材在建置時產生到 `game/assets/generated/`（不進 git），CI 和本機用同一支腳本產生。
- 理由：實測 LFS 上傳被雲端 session 的網路代理擋下（上傳到 GitHub 的 S3 儲存回 403）。
- 影響：Jacky 從自己電腦推 LFS 不受影響；loop 能否下載 LFS 內容待實際遇到再測。見 FOR_JACKY。

## D-003　2026-11-07　GDScript＋靜態型別，未加型別視為錯誤

- 決策：`untyped_declaration`、`unreachable_code`、`standalone_expression` 設為錯誤；`unsafe_*` 等設為警告。允許 `:=` 型別推斷。
- 理由：Jacky 指定；型別錯誤在 import／測試階段就會被抓到。
- 影響：不使用 C#／.NET。

## D-002　2026-11-07　Godot 版本固定 4.7.2-stable

- 決策：`scripts/get-godot.sh` 固定 4.7.2-stable（標準版），用同一 release 的 `SHA512-SUMS.txt` 驗證。
- 理由：2026-11-07 查證，4.7.2 是最新 stable；4.8 仍在 beta。
- 影響：不因新版發布就升級；要升級需記新的決策並全面重測。

## D-001　2026-11-07　引擎由 UE5 改為 Godot 4（Jacky 定案）

- 決策：使用 Godot 4，取代原本建議的 Unreal Engine 5。
- 理由：開發 loop 在沒有 GPU 的 Linux 雲端 session 執行，無法安裝或編譯 UE5，Blueprint／地圖是二進位檔，無法自我驗證。Godot 開源、無權利金，場景與腳本是純文字，可以在 Linux 與 GitHub Actions 測試並匯出 Windows 版。
- 影響：`README.md`、`docs/technical-direction.md`、`.gitignore`、`.gitattributes` 已改為 Godot 方向；專案在 `game/`。
