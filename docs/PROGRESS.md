# 開發紀錄

新的放最上面。時間為台北時間。

## 2026-11-07 23:26–00:00　第 1 輪：Godot 骨架、CI、存檔與九息核心、讀完原作

**做了什麼**

- 引擎方向改為 Godot 4.7.2-stable（D-001、D-002）：改寫 README、technical-direction、.gitignore、.gitattributes。
- `scripts/get-godot.sh`（下載＋SHA512 驗證）、`scripts/check.sh`（import＋腳本型別檢查＋測試＋匯出）、`scripts/screenshot.sh`（xvfb 截圖）、`scripts/gen-assets.sh`／`gen_fonts.py`（Noto CJK TC 子集化）。
- `game/` 專案：標題畫面（程序霧氣 shader、明體標題）、App／Settings autoload、繁中＋英文翻譯、GDScript 未加型別視為錯誤。
- 核心邏輯：`GameState`、`SaveCodec`（版本＋遷移＋.bak 回復）、`NineBreath`（九息狀態機）。
- 自製測試框架；20 個測試（i18n 規則、設定、存檔、九息、字型缺字、開機到標題的流程）。
- CI：push 到 main 時測試、匯出 Windows／Linux、截圖，更新 prerelease `latest`。
- 讀完原作四部＋終章，整理成 `docs/design/00-story-digest.md`；`01-adaptation.md` 初稿（切片段落對應、英文名暫定）；`02-gameplay.md` 初稿（喊前兆的協作戰鬥、九息流程、日記、死亡重試）。
- 建立 PLAN、NEXT、DECISIONS（D-001～D-012）、FOR_JACKY、ART_REQUESTS、CREDITS。

**怎麼驗證**

- 本機：`scripts/check.sh --export` 全綠，Windows exe（約 114 MB，含 pck）與 Linux 匯出成功。
- 畫面：xvfb＋軟體 Vulkan 截圖，英文與繁中標題畫面都看過（繁中改用 Noto Serif CJK TC 後字形正確）。
- CI：run 42386961785 失敗（乾淨 clone 的 .translation 尚未產生）→ 修正後 run 42387162270 綠燈，release `latest` 有 Windows／Linux zip 與截圖。存檔、九息 commit 的 run 42388049346、42388111643 綠燈；字型 commit 的 run 42388277840 失敗（`python3 -I` 看不到 pip --user 裝的 fonttools）→ 改 `-P` 後 run 42388383397 綠燈。

**遇到的問題**

- Git LFS 推送被雲端 session 的網路代理擋下（S3 上傳 403）→ 不 commit LFS 類型，素材建置時生成（D-004）。
- `curl` 讀不到 GitHub 的 `releases/latest` 轉址（403），改用 WebSearch 確認版本、直接測下載網址。
