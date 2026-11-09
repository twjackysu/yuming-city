# Steam 商店與收藏庫素材規格（清單）

> 狀態：**整理版**（2026-11-08）。尺寸以 Steamworks 官方文件為準：<https://partner.steamgames.com/doc/store/assets>（上傳前請再看一次，Valve 偶爾會改規則）。
> 誰做：構圖與程序截圖 loop 可以先做「替代版」（遊戲內截圖＋標題字），正式的主視覺（key art）需要 Jacky 用 AI 生成或委託繪製，需求另列在 `docs/ART_REQUESTS.md`。
> 規則重點：膠囊圖（capsule）上**只能有遊戲名稱／標誌與美術**，不能放評價、獎項、「特價」「新作」等字樣；文字要在小尺寸也讀得出來。

## 替代版膠囊圖（已自動產生）

CI 每次 push 到 main 都會用遊戲內截圖＋標題字產生 Header／Small／Main／Library 四張替代版（D-064），Header 附在 [latest release](https://github.com/twjackysu/yuming-city/releases/tag/latest)（`header_capsule.png`），四張都在該次 CI 的 artifact 裡。本機產生：`python3 -P scripts/steam_mock.py <主街夜景.png> <輸出資料夾> --title-shot <標題畫面.png>`（背景截圖用 `scripts/screenshot.sh out.png 40 --level=frostbridge --at=main --quality=2 --nohud`）。上架前換成正式主視覺。

## 商店頁（Store assets）

| 素材 | 尺寸（px） | 用途 | 替代版做法 |
|---|---|---|---|
| Header Capsule | 920 × 430 | 商店頁頂端、推薦、清單 | 霜橋鎮主街夜景截圖＋「Yuming City／餘命城」標題 |
| Small Capsule | 462 × 174 | 搜尋結果、小清單（要極度精簡，標題要大） | 只放標題＋鐘的剪影 |
| Main Capsule | 1232 × 706 | 首頁大輪播 | 送葬者與重現石拱的構圖 |
| Vertical Capsule | 748 × 896 | 季節特賣等直式版位 | 鐘樓直式構圖 |
| Page Background | 1438 × 810 | 商店頁背景（低對比、可省略） | 霧中街景模糊版 |
| Screenshots | 1920 × 1080（16:9），至少 5 張 | 商店頁截圖 | 遊戲內截圖模式（`--screenshot`），挑 5～8 張：廣場、敲鐘、救援、看穿、送葬者、重現石拱、日記 |
| Trailer | 1080p 以上、建議 30～90 秒 | 商店頁第一個媒體 | 階段 2 後半再剪（遊戲內錄影） |

## 收藏庫（Library assets）

| 素材 | 尺寸（px） | 用途 | 備註 |
|---|---|---|---|
| Library Capsule | 600 × 900 | 收藏庫格狀顯示 | 直式，要有標題 |
| Library Hero | 3840 × 1240 | 收藏庫遊戲頁頂部背景 | **不能有文字**（標誌另外疊） |
| Library Logo | 寬 1280 或高 720 以內、透明 PNG | 疊在 Hero 上的標誌 | 需要「餘命城／Yuming City」字標設計 |
| Library Header | 920 × 430 | 收藏庫其他版位 | 可與 Header Capsule 共用 |

## 成就圖示（D-147）

- 每個成就一張**解鎖**圖示；Steamworks 建議 **256 × 256 PNG**（JPG 也可、最小 64 × 64、必須正方形）。**未解鎖**圖示可以在後台自動產生灰階版，也可以自己上傳。
- 批次上傳時檔名＝成就 API 名稱＋`_ACHIEVED`／`_UNACHIEVED`（例：`ACH_NINTH_BELL_ACHIEVED.png`），會自動對到成就。API 名稱照 `game/data/achievements.json` 的 id。
- **替代版已自動產生**：每次建置在 [latest](https://github.com/twjackysu/yuming-city/releases/tag/latest) 附 `achievement-icons.zip`（8 個成就 × 解鎖／未解鎖）與總覽 `achievements_sheet.png`（`scripts/achievement_icons.py`：暗藍底、暖金色雙圈＋小圖案，圖示上不放字）。正式版想換時見 `docs/ART_REQUESTS.md`。

## 用戶端圖示（Client icons）

| 素材 | 規格 | 備註 |
|---|---|---|
| Community Icon | 184 × 184 JPG | 社群、好友動態 |
| Client Icon | .ico（含 16／32 px）＋ 32 × 32 | 收藏庫列表；同一張也用在 Windows 執行檔圖示（`game/icon.svg` 之後換） |

## 截圖清單（D-145：清單在 `scripts/store_shots.txt`，以那份為準）

| # | 內容 | 截圖旗標（摘要） |
|---|---|---|
| 1 | 霜橋鎮廣場夜景與通往鐘樓的主街（無 HUD） | `--at=plaza --nohud` |
| 2 | 親手敲九下（敲鐘鏡頭） | `--cutscene=slice_bell_nine --cutscene-steps=3` |
| 3 | 陷落的北街救援 | `--rescue` |
| 4 | 看穿送葬者（看穿小卡） | `--convoy --insight --pos=2.2,9.5 --face=undertaker --face-off=18`（原本是沙盒的灰巡者；沙盒是測試場景，改成霜橋鎮） |
| 5 | 送葬者擲出鐵架、石拱重現（無 HUD） | `--convoy --throw=arch --throw-t=0.8 --pos=2.6,10.5 --face=arch --face-off=14` |
| 6 | 燃燒劍斬斷鐵架 | `--convoy --throw=kindling --throw-t=0.6 --face=sheila --pos=2.6,6.5 --face-off=16` |
| 7 | 日記：被剪掉的記憶 | `--open=journal` |

**上架用的要在 Windows 實機拍**（雲端只有軟體渲染，霧與反射品質不夠）：下載 latest 的 Windows 版、解壓，在資料夾裡執行

```powershell
powershell -ExecutionPolicy Bypass -File .\store-shots.ps1
```

會用高畫質（`--quality=2`）、1920 × 1080 拍英文與繁中各一套，輸出在 `store-shots\en\`、`store-shots\zh_TW\`（一張約幾秒）。雲端確認構圖用 `scripts/store-shots.sh <輸出資料夾> [en|zh_TW] [只拍檔名含這段字的]`。清單改了之後 `scripts/check.sh` 會檢查旗標都對得上遊戲程式。
