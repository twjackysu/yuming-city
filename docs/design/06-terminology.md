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
| 測試板 | `TestBoard`（來源 `test_board`） | 測試板 | the test board | 彌夏櫃台上用來驗證的板子：手放上去會中一點很弱的毒，指針往紅色＝受傷、往綠色＝回復（D-231）；不寫「檢測儀」「鑑定板」 |
| 彌夏 | `Misha`（`SPK_MISHA`） | 彌夏 | Misha | 地下市場街底藥店的老闆，調藥與研究裝備；人名 |
| 黑市示範場 | — | 黑市示範場 | the black-market demo | 地下市場裡商人當眾示範商品的地方（下一段的場景）；不寫「競技場」「展演廳」 |
| 解藥 | — | 解藥 | antidote | 一般人中毒之後吃的藥；彌夏的台詞裡出現 |
| 示範台 | `DemoStage`（`UndergroundMarket.DEMO_POS`） | 示範台；目標寫「街中段搭著台子的地方」 | the stage / the demo stage | 黑市示範場裡商人站的台子（街中段西側）；不寫「舞台」「擂台」 |
| 高速護腕 | `Bracer`（守衛手上的節點）；拿到＝`GameState.grants` 裡的 `rb2_demo_bracer`；諾恩試戴之後手上的節點 `NoenBracer`（D-234） | 高速護腕；口語「護腕」 | the speed bracer | 戴上去出手變快、戴久了手會麻痺的詛咒物；商人靠賣它的解藥賺錢 |
| 護腕商人 | `demo_seller`（`SPK_DEMO_SELLER`） | 護腕商人 | Bracer Seller | 示範場上叫賣的人；還沒有名字 |
| 麻痺 | 狀態 `paralysis`（`statuses.json`，`kind: "action"`；D-234）。守衛的「麻」只是他出招後的破綻 `DemoGuard.is_numb()` | 麻痺；反轉之後「麻痺 → 出手加速」；口語「手會麻、會動不了、僵住」 | Paralyzed / Paralyzed → Faster attacks | 護腕的副作用。沒反轉＝這段時間不能出手；裝進反轉欄位＝出手加速（最多 1.5 倍）。不寫「麻痹」「定身」「攻速」 |
| 第二格 | `ReversalSlots.equipped[1]`（`UndergroundMarketStory.SECOND_SLOT`） | 第二格；畫面上「第二格反轉」 | second reversal slot | 開場就有、一直空著的那一格；在彌夏的店裡試戴護腕之後裝進麻痺。不寫「副欄位」「第二槽」 |
| 丟毒瓶的打手 | `DemoGuard.KIND_THROWER`（`demo_thrower`）；瓶子的霧＝來源 `poison_bottle`（D-235） | 丟毒瓶的打手；口語「丟瓶子的」；招式「丟毒瓶（落地一團毒霧）」 | Poison Thrower | 護腕商人帶來的人。瓶子落地的毒霧對諾恩是回血。不寫「投擲手」「毒師」「煉金術士」 |
| 兩格一起用 | 任務 `rb_trial`（D-235） | 兩格一起用 | Two Slots at Once | 中毒（回血）＋麻痺（出手加速）同時在身上。不寫「雙反轉」「連攜」「組合技」 |
| 乾運河 | 下一個地點（還沒做）；「待續」卡 `RB2_END6_TITLE` | 乾運河 | the Dry Canal | 彌夏在地圖上圈出來的地方，story-v2 第三章 |
| 示範場守衛 | `DemoGuard`（`demo_guard`＝拿棍子的、`demo_bracer`＝戴護腕的） | 示範場守衛／戴護腕的守衛 | Demo Guard / Bracer Guard | 護腕商人雇的兩個人，胸前掛紅白布條；不寫「打手」「保鑣」 |
| 守衛的招式 | `swing`／`thrust`／`jab` | 棍子橫掃／棍子直刺／快拳（打完手會麻） | Club swing / Club thrust / Fast punch | 都是直接傷害，沒有狀態 |
| 工錢 | `coins`（`RB_WAGES_PAID`） | 工錢 | pay | 雷德欠的那份（艾妲只代付一半）；不寫「欠薪」「薪資」 |
| 看穿 | `insight` | 看穿 | Insight | 按住顯示已知的弱點與招式 |
| 灰巡者、送葬者 | `Ashwalker`、`Undertaker` | 灰巡者、送葬者 | Ashwalker、Undertaker | 怪物名字 |
| 餘命城 | — | 餘命城 | Yuming City | 作品名 |
| （設定頁分組） | `SET_GROUP_*` | 遊戲／聲音／畫面／操作 | Game／Audio／Display／Input | D-076；英文用 Input，避免跟「Controls（按鍵設定）」那一列重複 |

## 檢查方式

- 新的系統名詞先寫進這張表再用。
- 這些舊詞不可以出現在 `game/i18n/*.csv` 的 `zh_TW`、`en` 欄（`tests/unit/test_i18n.gd::test_no_obscure_terms` 會擋）：九息、弔鐘、薪火、巡界、下城、爹…（清單在測試裡）。
