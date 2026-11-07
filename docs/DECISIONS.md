# 決策紀錄

新的放最上面。格式：編號、日期（台北時間）、決策、理由、影響。

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
