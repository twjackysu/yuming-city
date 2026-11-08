# 05　垂直切片計畫：《霜橋鎮的第九聲鐘》

> 狀態：**定稿 v1**（2026-11-08）。目標與驗收清單見 [`../vertical-slice.md`](../vertical-slice.md)。里程碑同步在 [`../PLAN.md`](../PLAN.md)。每天都要讓 main 能開、測試全綠；M1.4 之後隨時能從頭玩到尾。

## 切片流程與時長（目標 25 分鐘）

| 段落 | 檢查點 id | 內容 | 時長 |
|---|---|---|---|
| 1 霜橋鎮黃昏 | `start` | 自由走動、梨販與艾妲（買梨）、看見南街石拱（日記記下父親的記憶） | 5 分 |
| 2 九聲鐘 | `bell_tower` | 爬鐘樓、親手敲九下、北街陷落 | 3 分 |
| 3 救援 | `rescue` | 搬瓦礫、帶傷者到南邊，`slice.rescued_count` | 5 分 |
| 4 席菈 | `sheila_meet` | 夾板、「你敲了幾下」（說實話／說謊）、灰巡者協作教學 | 5 分 |
| 5 送葬者 | `undertaker` | 車隊護送、兩階段精英戰、九息石拱或薪火劍 | 5 分 |
| 6 收束 | `aftermath` | 日記被剪掉的記憶、死者名單、走向梨販家地窖 | 2 分 |

## 每日排程

| 日期 | 目標（當天結束時 main 上可驗證的東西） |
|---|---|
| 11/8–11/9 | 設計 01～05 定稿；任務／旗標系統（QuestDB、QuestRunner）＋主線流程測試；Game autoload（新遊戲、檢查點、存讀檔） |
| **M1.1 核心框架** | |
| 11/10 | `scenes/dev/sandbox`：Forward+、體積霧、地面；第三人稱膠囊角色移動＋SpringArm 鏡頭；標題「新遊戲」進入 sandbox |
| 11/11 | 暫停選單、設定選單（語言、音量、字幕、畫質三級、減少晃動）；「繼續」讀存檔（11/8 已完成） |
| 11/12 | 效能 overlay（F3）＋benchmark 場景＋`--benchmark`；FOR_JACKY 寫實機量測步驟 |
| 11/13 | 程序人偶（程式動畫：待機、走、跑、閃避、揮擊；11/8 已完成，改用 Node3D 關節，D-017）；按鍵重新綁定、裝置圖示切換 |
| 11/14 | 對話系統（DialogueDB／Runner）＋字幕 UI（11/8 已完成）＋過場跳過；M1.1 驗收 |
| **M1.2 戰鬥與九息** | |
| 11/15 | CombatTuning、受傷／死亡、閃避無敵、鈍擊、hit stop、鏡頭震動（11/8 已完成） |
| 11/16 | 灰巡者：前兆、弱點左膝、失衡；看穿顯示（11/8 已完成） |
| 11/17 | 席菈：CompanionBrain、跟隨、攻擊、三個指令、拒絕指令、倒下拉起（11/8 已完成） |
| 11/18 | 送葬者第一階段（三招＋前兆霜紋）、鎖定鏡頭（被擋解除、切換目標）、戰鬥 HUD（11/8 已完成） |
| 11/19 | 送葬者第二階段（連續下砸、抓取＋掙扎、未證實資訊）、車隊護送目標（11/8 已完成） |
| 11/20 | 九息石拱場景物件（預覽、按住確認、心跳倒數、去飽和、化灰、推出碰撞體）＋薪火劍替代路線（11/8 已完成） |
| 11/21 | 死亡重試、難度三級；M1.2 驗收（sandbox 內可打完送葬者，兩條路線有流程測試）（11/8 已完成） |
| **M1.3 霜橋鎮內容** | |
| 11/22 | 霜橋鎮白盒：街道、梨販攤、鐘樓、南街石拱、北街；VoxelGI、霧、燈（11/8 已完成白盒＋StaticBatch、濕石板路、半木構房子＋石牆、門口掛燈、目標指引、主街往鐘樓爬坡（D-048）；VoxelGI 未做） |
| 11/23 | 段落 1：梨販、艾妲對話、買梨；日記與記憶條目（11/8 已完成日記與石拱回憶：走進南街 → 日記解鎖） |
| 11/24 | 段落 2：敲鐘九下演出、北街崩塌；程序鐘聲（11/8 已在霜橋鎮可玩） |
| 11/25 | 段落 3：救援互動、救出計數（11/8 已完成） |
| 11/26 | 段落 4：席菈登場對話、灰巡者教學戰（11/8 已完成：對話＋灰巡者＋看穿教學提示＋諾恩夾板） |
| 11/27 | 段落 5、6 串進霜橋鎮；死者名單、收束；M1.3 驗收（11/8 已串進：南街送葬者戰、艾妲＋地窖、死者名單 29／30／31／33） |
| **M1.4 串接驗收** | |
| 11/28 | 主線流程測試從新遊戲走到結尾（兩條路線：九息／薪火劍）；任務恢復測試（11/8 已完成：`test_slice_playthrough.gd`，真的換場景＋每個檢查點重來） |
| 11/29 | 手把全流程檢查、字幕／音量／畫質／暫停逐項；打包版 smoke test（CI 跑匯出版的截圖模式）（11/8 已完成：`test_gamepad_route`、`scripts/smoke_export.sh`） |
| 11/30 | 「必須驗證」清單逐項打勾；寫試玩指南給 Jacky；修 bug（11/8 已完成：[`docs/playtest.md`](../playtest.md)） |

## 驗收清單（對應 vertical-slice.md）

| 項目 | 驗證方式 |
|---|---|
| 普通＋精英敵人、同伴協作、讀招清楚 | 單元測試（前兆、時機窗、指令）＋截圖（霜紋、看穿）＋Jacky 試玩 |
| 九息：預覽、代價、視聽回饋、結束狀態；讀檔不重複付費、不卡死 | `test_nine_breath`＋流程測試在九息中途存讀檔 |
| 鍵鼠與手把皆可完成 | 每個動作都有兩種綁定（`test_input`）；Jacky 手把試玩 |
| 字幕、音量、畫質、暫停 | 設定測試＋截圖 |
| 存讀檔、死亡重試、過場跳過、任務恢復 | 流程測試：每個檢查點存檔 → 讀檔 → 任務階段一致 |
| 實機效能 | benchmark JSON（Jacky 實機） |
| 代表最終方向的一小段場景 | 段落 1 的鎮區黃昏＋段落 5 的九息瞬間，截圖放 README |

## M1.4「必須驗證」對照（2026-11-08 第 10 輪）

✅＝自動測試或 CI 擋住　👤＝要 Jacky 實機／手把確認　⬜＝還沒有

| 必須驗證 | 狀態 | 證據（測試名在 `game/tests/`） |
|---|---|---|
| 普通敵人（灰巡者）：前兆、讀招、失衡、弱點 | ✅ | `test_enemy::test_brain_cycle`、`test_ashwalker_claws_player_and_dodge_avoids`、`test_insight::*`、`test_sheila_meet` |
| 精英敵人（送葬者）：兩階段、讀招、鐵架拋擲 | ✅ | `test_undertaker::*`（13 項）、`test_convoy_encounter::*`、`test_convoy_flow::*` |
| 可協作同伴（席菈）：三指令、時機窗、拒絕、倒下拉起 | ✅ | `test_companion::*`、`test_combat_hud::test_pull_sheila_up_and_after_combat`、`test_lock_on::test_sheila_attacks_locked_target` |
| 九秒能力：預覽、代價、視聽回饋、結束狀態 | ✅ | `test_nine_breath_site::*`、`test_journal::test_arch_preview_highlights_memory`、`test_restored_arch_is_glowing_stone` |
| 讀檔不重複付費、不卡死 | ✅ | `test_nine_breath::test_save_mid_restoration_loads_as_spent_without_double_charge`、`test_save::test_memory_cost_is_paid_once` |
| 鍵鼠與手把都能完成 | ✅／👤 | 每個動作兩種綁定 `test_input::test_every_action_has_keyboard_and_gamepad`；改鍵 `test_controls_menu_rebind_cancel_reset`；**只用手把事件**走梨販 → 敲九下、救援（按住 A）、灰巡者（LT 看穿、X 揮擊、十字鍵上指令）、送葬者戰（右搖桿鎖定、B 翻滾、被抓連按 B 掙脫、按住 Y 重現石拱）、暫停選單 → 設定 → 返回、按鍵設定頁用十字鍵＋A 改鍵（交換、Start 取消、還原預設）`test_gamepad_route`（這個測試抓到 A 按不下選項的 bug，D-047）；A／B 確認返回 `test_input::test_ui_actions_have_pad_buttons`；手感要 Jacky 試玩 |
| 字幕 | ✅ | 開關存檔 `test_settings::test_settings_round_trip`；作用範圍（D-045）`test_companion::test_sheila_barks_follow_subtitle_setting` |
| 音量 | ✅ | `test_settings::test_audio_buses`、`test_sfx::test_play_uses_sfx_bus_and_missing_is_silent` |
| 基本畫質 | ✅ | `test_quality::*`（三級切換套到已載入場景） |
| 暫停 | ✅ | `test_ui::test_pause_menu_pauses_and_resumes`（暫停中開設定、再按繼續）、`test_nine_breath_site::test_pause_freezes_restoration_and_caravan`（暫停中倒數與車隊不動） |
| 存檔／讀檔 | ✅ | `test_save::*`（版本、遷移、壞檔、備份）、`test_quests::test_runner_resumes_from_saved_state` |
| 死亡重試 | ✅ | `test_main_flow::test_player_death_retries_from_checkpoint` |
| 過場跳過 | ✅ | `test_cutscene::test_skip_applies_remaining_effects_once`、`test_game_skip_from_view_input` |
| 任務恢復（每個檢查點重來） | ✅ | `test_slice_playthrough::*`（真的換場景，兩條路線） |
| 從頭玩到尾 | ✅／👤 | 同上（場景層面）；20～30 分鐘的實際體感要 Jacky 試玩 |
| 打包版有全部資源 | ✅ | CI `scripts/verify_package.py`（D-044） |
| 打包版能開到關卡 | ✅ | CI `scripts/smoke_export.sh`：匯出的 Linux 執行檔在 xvfb 開到霜橋鎮主街截圖（D-049） |
| 實機效能（打包版） | 👤 | `--benchmark` JSON（FOR_JACKY 第 1 項） |
| 代表最終方向的一小段場景 | 🔨 | 霜橋鎮廣場＋送葬者戰燃燒劍／石拱瞬間；正式角色模型到了再定 |

手把整段（第 11～13 輪）：`test_gamepad_route` 分段——梨販 → 敲完九下、救援三人（按住 A）、灰巡者（LT 看穿、X 揮擊打中、十字鍵上叫席菈打弱點）、送葬者戰（右搖桿鎖定／解除、B 翻滾無敵、被抓住連按 B 掙脫、左搖桿走到石拱按住 Y 重現）、暫停選單；第 14 輪補上按鍵設定頁用手把改鍵（抓到最後一列往下焦點跑到後面設定選單的 bug，D-057）。手把整段的自動測試到這裡齊了。

## 主街往鐘樓爬坡（第 11 輪，D-048）

```
 z:  -10 ─────────── -24.2  -25.2 ── -29.2 ─────────── -46 ── -50 ── -55.5
     主街（平地 y=0）      │ 石階 4 級 │ 台地 y=0.9：北街（陷落）、鐘樓、北城牆
                          │ ╱斜坡碰撞（穿過每級前緣，10°）
```

- 每級高 0.18 m、深 1.0 m；最後一級就是台地邊。看得到的是石塊台階（踏面前緣一條薄雪），碰撞是一片看不到的斜坡——角色不用跨階、腳最多離踏面 0.18 m。
- 台地本體用石牆 shader（南面露出的那一階看得到石塊），上面再鋪一層濕石板路（世界座標，跟主街接得起來）。
- 跟著抬高：北街兩排房子、受困者、灰巡者、北街路燈、鐘樓、觸發區、敲鐘鏡頭、北城牆。`StoryLevel.ground_y()` 給測試與瞬移用。

## 風險與備案

| 風險 | 備案 |
|---|---|
| 沒有角色模型／動畫 | 程序人偶＋剪影設計（03）；Jacky 提供後替換，介面不變 |
| 軟體渲染截圖看不出效能 | benchmark 場景＋實機量測步驟；畫質選項分級保守預設 |
| 內容做不完 | 優先序：5（送葬者＋九息）＞ 4 ＞ 2 ＞ 3 ＞ 1 ＞ 6；段落 1、3 可縮成對話與短互動 |
| 戰鬥手感只能靠 Jacky 試玩判斷 | 所有數值資料化＋`user://tuning.json` 熱重載，讓他可以自己調 |
