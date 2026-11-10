# 06　用詞：玩家看到的字要白話

> 狀態：**定案**（2026-11-08，回應 Jacky 在 FOR_JACKY 的回覆：「用詞太中國武俠玄學感，九息、弔鐘人完全看不懂」）。決策記錄 D-035。

## 原則

1. **人名、地名、怪物名可以照原作**：諾恩、席菈、艾妲、霜橋鎮、灰巡者、送葬者。它們是名字，玩家第一次看到時畫面上就有那個人／地方／怪物，不需要懂字面意思。
2. **能力、系統、職業、技能、按鍵名一律用白話**：玩家要靠這些字決定怎麼玩，看不懂就是設計失敗。用「它做什麼」來命名，不用文言單字（息、弔、薪、巡界、廢）。
3. **第一次出現就說清楚效果與代價**：提示框用一句完整的白話，例如「可以重現：南街石拱（倒塌前的樣子）／代價：永遠忘掉和父親在石拱下的最後一次對話／按住 V　重現 9 秒」。
4. **對白用現代口語**：爸（不用「爹」）、我先走了、喘口氣。角色個性靠內容與語氣，不靠古字。
5. **原作用詞不必照搬**：原作文字不改（`docs/story/` 不動），遊戲裡看不懂的就換掉；原作名稱可以留在設計文件與程式識別碼裡（例如 `nine_breath`、`kindling`），但不出現在玩家畫面上。
6. **英文同一套規則**：Restore 而不是 Nine Breaths；Burning Blade 而不是 Kindling Blade。

## 對照表（設計文件與程式可以用原作名，玩家畫面一律用右欄）

| 原作／設計文件 | 程式識別碼 | 玩家看到（中） | 玩家看到（英） | 說明 |
|---|---|---|---|---|
| 九息（九息重現） | `nine_breath` | **重現**（重現 9 秒） | **Restore** | 讓毀掉的東西回到原本的樣子 9 秒，代價是一段記憶 |
| 九次呼吸 | `NineBreath.BREATHS` | 9 秒（倒數「還剩 N 秒」） | 9 seconds | 演出上仍是九聲心跳 |
| 可保存物 | `NineBreathSite` | 可以重現：○○ | Can be restored: … | |
| 弔鐘人 | — | **敲鐘人** | **Bell-Ringer** | 諾恩的職業（還沒出現在切片畫面上） |
| 薪火劍 | `kindling` | **燃燒劍**（台詞裡寫「席菈的劍燒了起來」） | **Burning Blade** | 席菈燒自己的劍與手換一擊 |
| 王室巡界隊 | — | **王室巡邏隊** | Royal Wardens | 席菈的職務 |
| 下城 | — | **地底城** | the under-city | 梨販地窖通往的地方 |
| 廢鐘 | — | 舊鐘 | the old bell | |
| 看穿 | `insight` | 看穿 | Insight | 已經夠白話，保留 |
| 灰巡者、送葬者 | `Ashwalker`、`Undertaker` | 照原作 | Ashwalker、Undertaker | 怪物名字 |
| 餘命城 | — | 餘命城 | Yuming City | 作品名，保留 |
| （設定頁分組） | `SET_GROUP_*` | 遊戲／聲音／畫面／操作 | Game／Audio／Display／Input | D-076；英文用 Input，避免跟「Controls（按鍵設定）」那一列重複 |
| 噬日獸（第一部後段） | — | 吞日獸 | the Sun-Eater | 第 2 章結尾第一次出現（只看到一隻眼睛，D-161）；諾恩說「最終章的災厄」 |
| 歸時核（第二部以後） | — | 暫不出現 | — | 之後章節用到再定 |
| 攻略筆記（第 1 章起，`07-chapter1-door.md`） | `guide_notes` | 攻略筆記（每條標「確定」／「我不確定」／「被推翻」） | Guide Notes（Sure／Not sure／Proven wrong） | 諾恩前世記得的攻略；白話，保留（D-142） |
| 攻略先生（席菈對諾恩的稱呼，第 1 章段落 9） | — | 攻略先生 | Mr. Guidebook | 白話，保留（D-156） |
| 壽命石碑（第 1 章） | `life_stone` | 壽命石碑 | Lifespan Stone | 用壽命換水的路口石碑；「壽命」本來就白話 |
| 鐘舌（第 3 章，`08-chapter2-3.md`） | `clapper` | 鐘舌（第一次出現時說明：「鐘裡面那根撞鐘的鐵棒」） | the clapper | **不要叫鐘錘**：鐘錘是諾恩手上的武器 |
| 觀察提示音（第 3 章設定，D-164） | `observe_cue` | 觀察提示音 | Observation Cue Sound | 送葬者轉頭前鏈子先響的那一聲；設定頁「遊戲」分組的開關 |
| 主椅（第 2、3 章） | `main_seat` | 主椅 | the Main Seat | 承受所有轉換損耗的那張銅椅；白話，保留 |
| 白晝城（第 1 章） | — | 白晝城 | Daylight City（暫定） | 地名，照原作 |
| 食歲的僭王（第 2 章） | `usurper` | 食歲的僭王（只在攻略筆記與看穿伊薩的劃字小卡出現，會被劃掉） | the Year-Eating Usurper | 刻意用古字：是攻略裡的稱號，跟真實的伊薩對比（08、D-158） |
| 伊薩（第 2 章） | `isa` | 伊薩 | Isa | 白晝城的城主，人名照原作 |

## 檢查方式

- 新增玩家看得到的文字（`game/i18n/*.csv`）時，對照這張表；表上左欄的詞不可以出現在 CSV 的 `zh_TW`、`en` 欄（`tests/unit/test_i18n.gd::test_no_obscure_terms` 會擋）。
- 新的系統名詞先寫進這張表再用。

## 新版（劇情重寫「負面效果反向增益」，D-201、`09-reboot-first-ten-minutes.md`）

新版照 Jacky 的指示直接用白話名稱；上面舊版的「重現」「敲鐘人」等不出現在新版畫面上。

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
| 地下市場 | — | 地下市場 | the underground market | 白晝城的市場；新版不用「地底城」 |
| 貨梯 | — | 貨梯 | the freight lift | 通往地下市場 |
