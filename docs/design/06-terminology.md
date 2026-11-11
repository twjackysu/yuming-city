# 06　用詞：玩家看到的字要白話

> 定案 2026-11-08（Jacky：「用詞太中國武俠玄學感，九息、弔鐘人完全看不懂」，D-035）；2026-11-11 只留現在的劇情用到的詞（舊劇情的對照表刪了，D-227）。

## 原則

1. **人名、地名、怪物名可以是名字**：諾恩、席菈、艾妲、霜橋鎮、灰巡者、送葬者。玩家第一次看到時畫面上就有那個人／地方／怪物，不需要懂字面意思。
2. **能力、系統、狀態、按鍵名一律用白話**：玩家要靠這些字決定怎麼玩，看不懂就是設計失敗。用「它做什麼」來命名：中毒／回血／毒藥／反轉欄位。
3. **第一次出現就說清楚效果**：提示用一句完整的白話，數字直接寫出來。
4. **對白用現代口語**：爸（不用「爹」）、我先走了、喘口氣。角色個性靠內容與語氣，不靠古字。
5. **英文同一套規則**：Poisoned／Regenerating／Reversal Slot，不用生造的專有名詞。

## 對照表

| 設計文件 | 程式識別碼 | 玩家看到（中） | 玩家看到（英） | 說明 |
|---|---|---|---|---|
| 中毒 | `poison` | 中毒 | Poisoned | 原本是持續掉血 |
| 回血 | `heal`（`Health.heal`） | 回血 | Regenerating | 中毒被反轉後的結果；HUD 寫「中毒 → 回血」 |
| 反轉 | `ReversalSlots` | 反轉 | Reversed | 負面狀態對諾恩變成好處 |
| 反轉欄位 | `ReversalSlots.slots` | 反轉欄位 | Reversal Slot | 開場兩格；只有裝進去的狀態會反轉 |
| 逆轉體質 | — | 逆轉體質 | Reversal Constitution | 諾恩的能力名，只在第一次覺醒的提示出現 |
| 毒霧 | `PoisonMist` | 毒霧 | Poison Mist | 破藥桶、守衛噴出來的綠霧 |
| 毒藥／霧蛇毒劑 | `mist_serpent_poison` | 霧蛇毒劑（瓶上寫「不可飲用」） | Mist Serpent Venom | 虛構藥劑，只標效果（中毒 20 秒），不寫配方 |
| 藥箱／藥瓶 | `PotionCrate`（`RB_CRATE_HINT`） | 提示寫「拿走藥瓶」；對話裡說「兩瓶封好的」 | the bottles | 守衛背上摔下來的瓶架箱；玩家看到的字只有「藥瓶」 |
| 噴毒 | `spray`（`RB_MOVE_SPRAY`） | 噴毒 | Poison spray | 守衛的新招：胸口的管子往前噴，地上留一團 3 秒的毒霧 |
| 守衛 | `rb_guardian` | 目標寫「守衛」；名字照舊「送葬者」 | the guardian／Undertaker | 胸口裝噴霧罐的單階段送葬者 |
| 地下市場 | — | 地下市場 | the underground market | 貨梯下去的市場；不用「地底城」 |
| 貨梯 | `RbLift` | 貨梯 | the freight lift | 通往地下市場；梨攤後面地窖口上的木吊架 |
| 吊牌 | — | 吊牌 | the tag | 地下市場每件東西都掛一張，寫著副作用（這裡唯一的規矩）；不寫「標籤」「告示」 |
| 認證 | — | 認證／沒通過認證 | certification | 地面上的店賣「通過認證」的東西；地下市場賣沒通過的 |
| 彌夏的藥店 | `MishaShopDoor` | 彌夏的藥店；目標寫「街底那間綠色窗戶的藥店」 | Misha's potion shop | 街底、綠色格子窗、壺形招牌 |
| 測試板 | — | 測試板 | the test board | 彌夏用來驗證的板子（還沒做）；不寫「檢測儀」「鑑定板」 |
| 工錢 | `coins`（`RB_WAGES_PAID`） | 工錢 | pay | 雷德欠的那份（艾妲只代付一半）；不寫「欠薪」「薪資」 |
| 看穿 | `insight` | 看穿 | Insight | 按住顯示已知的弱點與招式 |
| 灰巡者、送葬者 | `Ashwalker`、`Undertaker` | 灰巡者、送葬者 | Ashwalker、Undertaker | 怪物名字 |
| 餘命城 | — | 餘命城 | Yuming City | 作品名 |
| （設定頁分組） | `SET_GROUP_*` | 遊戲／聲音／畫面／操作 | Game／Audio／Display／Input | D-076；英文用 Input，避免跟「Controls（按鍵設定）」那一列重複 |

## 檢查方式

- 新的系統名詞先寫進這張表再用。
- 這些舊詞不可以出現在 `game/i18n/*.csv` 的 `zh_TW`、`en` 欄（`tests/unit/test_i18n.gd::test_no_obscure_terms` 會擋）：九息、弔鐘、薪火、巡界、下城、爹…（清單在測試裡）。
