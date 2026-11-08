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

## 用戶端圖示（Client icons）

| 素材 | 規格 | 備註 |
|---|---|---|
| Community Icon | 184 × 184 JPG | 社群、好友動態 |
| Client Icon | .ico（含 16／32 px）＋ 32 × 32 | 收藏庫列表；同一張也用在 Windows 執行檔圖示（`game/icon.svg` 之後換） |

## 截圖清單（替代版，loop 會用遊戲內截圖模式產生）

| # | 內容 | 截圖旗標 |
|---|---|---|
| 1 | 霜橋鎮廣場夜景與通往鐘樓的主街 | `--level=frostbridge --at=plaza --quality=2` |
| 2 | 親手敲九下（敲鐘鏡頭） | `--cutscene=slice_bell_nine --cutscene-steps=3` |
| 3 | 陷落的北街救援 | `--rescue` |
| 4 | 看穿灰巡者、席菈在旁 | （沙盒）`--level=sandbox --enemies --insight` |
| 5 | 送葬者舉起鐵架、石拱重現 | `--convoy --throw=arch --throw-t=0.5` |
| 6 | 燃燒劍斬斷鐵架 | `--convoy --throw=kindling --throw-t=0.6 --face=sheila`（鏡頭轉向席菈，不然斬開的位置在鏡頭後方） |
| 7 | 日記：被剪掉的記憶 | `--open=journal` |

> 商店截圖要 1920 × 1080：在 Windows 實機用高畫質截（雲端只有軟體渲染，品質不夠上架）。這件事會寫進 FOR_JACKY（階段 2）。
