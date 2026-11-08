# Steam 商店頁文案（草稿 v1）

> 狀態：**草稿**（2026-11-08，第 13 輪）。Steam 預設語言英文、另附繁中。用詞照 [06-terminology](../design/06-terminology.md)：玩家看得到的字一律白話（重現／Restore、燃燒劍／Burning Blade）。
> 只寫切片已經做到、12/31 版本會有的內容；不寫還沒做的系統。上架前 Jacky 改到滿意為止，改完把狀態改成「定稿」。
> 字數上限（Steamworks 商店頁編輯器）：簡短描述約 300 字元；完整描述沒有硬上限，建議 3～5 段、每段配一張截圖或 GIF。

## 基本資料

| 欄位 | 英文 | 繁中 |
|---|---|---|
| 名稱 | Yuming City | 餘命城 |
| 類型（Steam 標籤建議） | Action RPG、Story Rich、Third Person、Singleplayer、Dark Fantasy、Choices Matter、Atmospheric、Medieval | 同左 |
| 平台 | Windows 64-bit（DirectX 12／Vulkan） | 同左 |
| 語言 | 英文（介面＋字幕）、繁體中文（介面＋字幕）；無配音（之後補） | 同左 |
| 手把 | 完整支援（Xbox 配置） | 同左 |
| 內容 | 奇幻暴力（無血腥特寫）；全年齡為目標，分級問卷由 Jacky 填 | 同左 |

## 簡短描述（Short description）

**EN（≤ 300 字元）**

> A bell-ringer who can make broken things whole again — for nine seconds, at the price of a memory he will never get back. A story-driven third-person action RPG set in a dying winter city, adapted from an original novel.

**繁中**

> 一個能讓毀掉的東西回到原本樣子的敲鐘人——只有 9 秒，代價是永遠忘掉一段記憶。改編自原創小說的第三人稱敘事動作 RPG，舞台是一座正在死去的冬夜之城。

## 完整描述（About this game）

### EN

**Nine seconds. One memory.**
Noen rings the bells of Frostbridge. He can also *Restore*: hold his hand to a ruined arch, a collapsed street, a shattered wall — and for nine heartbeats it stands as it was. Every time he does, a memory is cut out of him for good. Your journal shows exactly which one before you choose.

**Fights you read, not grind.**
Combat is simple to learn and hard to master. Hold *Insight* to see what you know about an enemy — its weak point, its tells — and watch that knowledge go stale as enemies change their patterns mid-fight. Strike from the side, dodge through the tell, and call on your companion at the right moment.

**Sheila fights beside you — and has her own reasons.**
A royal warden whose broken sword can be set alight — if she is willing to burn her own hand with it. Tell her to hit the weak point, get clear, or hold the line; she answers, refuses when it would hurt the wounded, and remembers what you told her. Some choices cost her, not you.

**A town worth saving.**
Escort a cart of wounded through a street the Undertaker has claimed. Decide whether to Restore the old stone arch — and lose the last thing your father said to you — or let Sheila burn her own hand to buy the time.

**Features**
- A hand-crafted chapter adapted from the original novel *Yuming City*, about 20–30 minutes in the first playable slice
- Restore: bring a marked object back for 9 seconds, at a permanent, visible memory cost
- Readable combat: tells, weak points, staggers, and an Insight view that can be wrong
- A companion you command with three clear orders
- Full controller support, rebindable controls, subtitles, volume and graphics presets
- English and Traditional Chinese

### 繁中

**9 秒，一段記憶。**
諾恩是霜橋鎮的敲鐘人。他也能「重現」：把手按在倒塌的石拱、陷落的街道、碎掉的牆上——九聲心跳的時間，它會回到原本的樣子。每用一次，就有一段記憶被永遠剪掉。按住之前，日記會讓你看清楚是哪一段。

**讀得懂的戰鬥，不靠刷數值。**
上手簡單、越打越吃技巧。按住「看穿」，看你對敵人知道多少——弱點、出招前的徵兆——而敵人會在戰鬥中改招，你的攻略也會跟著失準。繞到側面打、看準徵兆閃開，在對的時機叫同伴出手。

**席菈在你身邊，也有她自己的理由。**
王室巡邏隊的劍士，手上一把斷劍——必要時她會連手一起燒，讓劍燒起來。叫她打弱點、閃開、守住；她會回應，在會傷到傷者時拒絕，也記得你跟她說過什麼。有些選擇，付出代價的是她，不是你。

**值得守住的小鎮。**
護送一車傷者穿過被送葬者佔據的街道。決定要不要重現那座老石拱——代價是忘掉父親對你說的最後一句話——或讓席菈燒掉自己的手換時間。

**特色**
- 改編自原創小說《餘命城》的手工章節，首個可玩段落約 20～30 分鐘
- 重現：讓標記的物件回到原本的樣子 9 秒，代價是永久、看得見的記憶
- 讀得懂的戰鬥：徵兆、弱點、失衡，以及會出錯的「看穿」
- 三個清楚指令就能指揮的同伴
- 完整手把支援、按鍵可重新設定、字幕、音量與畫質分級
- 英文與繁體中文

## 系統需求（暫定，等 Jacky 實機量測後更新）

| | 最低（低畫質 1080p 30 fps） | 建議（中畫質 1080p 60 fps） |
|---|---|---|
| 作業系統 | Windows 10 64-bit | Windows 10／11 64-bit |
| 處理器 | 4 核心（例：Intel i5-6600／Ryzen 3 1200） | 6 核心（例：Intel i5-10400／Ryzen 5 3600） |
| 記憶體 | 8 GB | 16 GB |
| 顯示卡 | 支援 Vulkan 1.1／DX12，4 GB VRAM（例：GTX 1050 Ti／RX 570） | 6 GB VRAM（例：GTX 1660 Super／RX 5600 XT／RTX 2060） |
| 儲存空間 | 2 GB | 2 GB |

> 這張表是依 Godot 4 Forward+ 與目前場景規模的估計，**不是量測結果**。Jacky 照 [playtest.md](../playtest.md) 跑 benchmark 回報後，用實際數字改寫（D-055）。

## 不要寫進商店頁的東西

- 還沒做的章節、系統（城市據點、記憶抉擇以外的分支）——上架後評論會拿來對照。
- 原作後段的劇透（餘命城的真相、第二部之後）。
- 任何「3A」「開放世界」字眼。
