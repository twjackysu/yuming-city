extends StoryLevel
## 第 3 章「不准替我答應」：乾運河（白盒，D-163；08-chapter2-3.md）。
## 第 2 章看完窗外的眼睛 → 第 3 章章節卡 → 這裡。第四夜，地底城離穹頂最遠的地方：
## 上方鐘院的白光從一排排石樑的縫透下來，斜斜地切成一條條——**整座地底城只有這裡有影子**（光是斜的，一盞投影子的方向光；
## 第 1 章的規則是「只有油燈投影子」，這裡是第一個例外，D-163）。運河早就乾了，河床比岸邊低 BED_Y，
## 一根橫跨運河的舊吊樑上掛著一隻送葬者（胸口一點銅光＝鐘舌，跟心跳一樣一下一下地亮）；吊樑在亮處，縫裡的光一條條切過牠。
## 再往北一座石橋、更遠是閘道（剪影）。
## 段落 1 乾涸的運河：走到東岸的說話點 → 席菈「我去引開牠。」→「不行。」／（沉默）→「那你有什麼方案？」→ 我說不出來 →
## 攻略筆記多一條**空白**「攻略沒有寫」（guide_blank，D-163）→ 彌夏蹲在渠邊：「牠跟著什麼走？」「心跳。」「多快？」→
## 檢查點 ch3_bank → 段落 2「趴在水溝裡（觀察）」（D-164）：吊樑旁邊的東岸有一道淺水溝（`Drain`）→ 走進去，三個人趴下 →
## 對話 ch3_rhythm：席菈用布包著小石頭隔著銅片敲，**玩家選節奏**（很慢／慢一點／不快不慢／快一點／很快／忽快忽慢，試過的消失）→
## 「敲」那一句出現時判定（RhythmTrial）、送葬者照結果演：不動／偏頭／轉頭（轉頭之前鏈子先響＝觀察提示音，設定可關）→
## 不快不慢＝人的心跳 → 轉頭 →「就是這個速度。」→ 攻略筆記的空白條目變成證實（自己看到的）→ 檢查點 ch3_rhythm →
## 段落 3「假心臟」（D-165）：（第五夜）彌夏把做好的假心臟交給我們（對話 ch3_decoy_make）→ 東岸三個點（`DecoySpot0～2`）：
## 站在點上按互動鍵，把假心臟綁著繩子垂到河床上 → 送葬者聽到（HeartTargets：9 m 內）就鬆開鏈子掉下來、往心跳走 →
## 走到旁邊停下來聽 → 收上來、換下一個點（太遠牠聽不到、不會動；所以只能一段一段帶）→ 走到閘道口 → 檢查點 ch3_lured →
## 段落 4「煤車」（D-166）。**重現會讓諾恩的心跳變快**：在這裡按住重現鍵，牠會停下來轉向諾恩（不是禁止，是自己會發現的規則）。
## 段落 4：閘道（河道裡兩道矮石牆收窄的一段）上方的木架上停著一台堆滿煤的車，車尾的繩子綁在東岸的木柱上（對話 ch3_cart_plan）→
## 把假心臟垂到閘道另一邊（第 3 點，或牠走過頭之後用第 2 點拉回來）→ 牠從煤車底下走過去 → 站在木柱旁按互動鍵割斷繩子 →
## CoalDrop 判定「煤落下那一刻牠在哪」：壓住 → 黑色粉塵、油燈晃 → ch3.cart_dropped → 檢查點 ch3_pinned → 段落 5 倒吊待續；
## 太早／太晚 → 牠掙脫、爬上東岸 → 掙脫戰（D-169：切片送葬者少一招、不會進第二階段）→ 打到牠失衡跪下 → 席菈把牠撞回運河 →
## 回到檢查點 ch3_lured 再來一次（不再重講對話）；戰鬥中倒下也回到 ch3_lured。按住重現讓牠停在正下方再割，一定壓得住。
## 段落 5 倒吊、段落 6 彌夏的圖（D-167）→ 檢查點 ch3_map：彌夏先走、席菈走到東岸回程路上的牆角等 →
## 段落 7 轉角（D-168）：走到牆角 → 對話 ch3_corner（固定鏡頭；抓住領口、換班的鐘聲）→ 日記「轉角的衣領」→
## ch3.corner_talked → 第 3 章完成（自動存檔）→ 結尾卡「第一部　死去的攻略／前半　完」→ 回標題。讀檔回來站在牆角、「下一章還在製作中」。
##
## 座標：運河沿 Z（南 Z_SOUTH → 北 Z_NORTH），河道 x -CANAL_HALF_W～CANAL_HALF_W，兩岸各寬 BANK_W、岸頂 y＝0；
## 諾恩從東岸南端進來，岸邊有矮牆（不會掉下去）。北邊有一座閘道（段落 3 把送葬者引進去的地方，現在只是剪影）。

const QUEST: String = "ch3_main"
const STAGES: PackedStringArray = ["canal_bank", "observe", "decoy", "lure", "coal_cart", "hang"]
const BED_Y: float = -4.5
const CANAL_HALF_W: float = 3.0
const BANK_W: float = 6.0
const Z_SOUTH: float = 12.0
const Z_NORTH: float = -40.0
const SPAWN: Vector3 = Vector3(5.6, 0.0, 9.0)
## 岸邊的矮牆：看得到的高度、擋人的高度
## （第 45 輪截圖：0.8 m 的矮牆從岸上把掛著的送葬者整隻擋住）
const PARAPET_H: float = 0.45
const PARAPET_BLOCK_H: float = 1.8
## 石橋：橋面在岸頂高度、厚 DECK_T
const BRIDGE_Z: float = -20.0
const BRIDGE_W: float = 2.4
const DECK_T: float = 0.5
## 吊樑：擱在兩岸的矮牆上（第 45 輪截圖：掛在橋下整隻在橋的影子裡，看不到）
const HANG_Z: float = -14.5
## 掛點偏東岸一點（從東岸看得到）
const HANG_X: float = 0.7
## 吊樑比岸頂高一截（第 45 輪截圖：掛得太低，從岸上看下去整隻被河道的牆緣擋住）
const BEAM_Y: float = 2.6
## 掛著的送葬者：鏈子多長、怎麼晃
const CHAIN_LEN: float = 1.0
const SWAY_DEG: float = 2.2
const SWAY_RATE: float = 0.55
## 胸口的鐘舌：銅光一下一下地亮，像心跳（每分鐘 HEART_BPM 下，一次兩拍）
const HEART_BPM: float = 46.0
const CLAPPER_ENERGY: float = 1.7
## 段落 1：走到東岸這裡 → 岸邊的對話
const BANK_POS: Vector3 = Vector3(3.9, 0.0, -11.0)
const BANK_RANGE: float = 1.8
const BANK_TALK: String = "ch3_bank"
## 岸邊對話時鏡頭往下看多少（弧度）
const LOOK_DOWN_PITCH: float = -0.55
const BLANK_ENTRY: String = "clapper_heartbeat"
## 段落 2：吊樑旁邊東岸的淺水溝（沿 Z 長 DRAIN_LEN、寬 DRAIN_W，兩側低低的石緣）；走進 DRAIN_RANGE 就趴下開始觀察。
## 三個人沿 Z 並排趴著、頭朝運河（第 46 輪截圖：溝只有 0.9 m 寬，橫著趴的人整個伸出溝外）
const DRAIN_POS: Vector3 = Vector3(4.6, 0.0, -14.2)
const DRAIN_LEN: float = 4.2
const DRAIN_W: float = 2.3
const DRAIN_RANGE: float = 1.4
const RHYTHM_TALK: String = "ch3_rhythm"
const KNOCK_LINE: String = "DLG_CH3_RHY_KNOCK"
## 銅片插在水溝前端的泥裡（席菈敲的地方）
const PLATE_POS: Vector3 = Vector3(3.7, 0.0, -15.5)
## 一次敲幾下；第幾下之後送葬者開始反應
const KNOCK_COUNT: int = 7
const REACT_AFTER: int = 3
## 送葬者的反應：偏頭（上半身繞 Z 歪一點又回來）、轉頭（上半身轉向銅片，停在那裡）
const TILT_DEG: float = 13.0
const TURN_DEG: float = 62.0
## 觀察提示音比轉頭早多久響
const CUE_LEAD: float = 0.7
## 北邊的閘道（段落 3 用）
const SLUICE_Z: float = -29.0
## 段落 3：彌夏交假心臟（找到速度之後等 DECOY_TALK_DELAY 秒、諾恩在她 MISHA_TALK_RANGE 內）
const DECOY_TALK: String = "ch3_decoy_make"
const DECOY_TALK_DELAY: float = 4.3
const MISHA_TALK_RANGE: float = 3.2
## 東岸放假心臟的三個點：人站在 (DECOY_BANK_X, 0, z)，假心臟垂到河床的 (DECOY_BED_X, BED_Y, z)。
## 第 0 點離吊樑 3.5 m（聽得到）；第 1、2 點從吊樑都超過 HeartTargets.HEAR_RANGE——只能一段一段帶（第 0 點不在石橋底下）
const DECOY_ZS: PackedFloat32Array = [-17.5, -24.0, -27.6, -34.0]
## 段落 3 用前三個點；段落 4 用閘道兩邊的第 2、3 點（第 3 點在閘道另一邊，D-166）
const LURE_SPOTS: int = 3
const CART_SPOTS: PackedInt32Array = [2, 3]
const DECOY_BANK_X: float = 3.6
const DECOY_BED_X: float = 2.4
const DECOY_RANGE: float = 1.6
## 醒過來的送葬者：在河床上走多快（m/s）、轉身多快、走到假心臟多近就停下來聽、河道裡能走到的 x
const WALK_SPEED: float = 1.15
const TURN_RATE: float = 2.6
const HEART_REACH: float = 0.9
const BED_LIMIT_X: float = 2.2
## 白盒步伐：一步多久（秒，一抬一晃）、抬多高、左右晃幾弧度
const GAIT_SEC: float = 1.1
const GAIT_LIFT: float = 0.07
const GAIT_ROLL: float = 0.05
## 鏈子鬆開、掉到河床上要多久
const DROP_SEC: float = 0.6
## 諾恩重現時的心跳（每 NOEN_RACE_SEC 秒一聲，比假心臟快）：只在牠醒著、會聽到的時候響——讓玩家聽得出「我的心跳變快了」。
const NOEN_RACE_SEC: float = 0.48
## 走到這裡（z 小於等於）＝進了閘道
const SLUICE_REACH_Z: float = SLUICE_Z + 2.5
## 檢查點 ch3_lured 重來時送葬者站的位置
const LURED_POS: Vector3 = Vector3(2.0, BED_Y, SLUICE_Z + 2.4)
# 段落 4 煤車（D-166）
## 閘道裡兩道矮石牆的高度（從河床算）：比送葬者矮，從岸上看得到牠露出上半身
const SLUICE_PIER_H: float = 2.0
## 閘道的石牆內緣之間，牠走的那一條線（x）；石牆那一段 |x| 夾在 SLUICE_HALF 以內
const SLUICE_PASS_X: float = 0.4
const SLUICE_HALF: float = 1.0
const SLUICE_PIER_HALF_Z: float = 0.7
## 從閘道的哪裡算「穿過去了」（離 SLUICE_Z 多遠）：目標在閘道另一邊時，先往這個出口走
const SLUICE_EXIT: float = 0.9
## 煤車：木架橫樑底的高度、煤落下的位置（沿運河）就是閘道正中
const GANTRY_Y: float = 2.4
const CART_Z: float = SLUICE_Z
const CART_TIP: float = 1.35
const CART_TALK: String = "ch3_cart_plan"
const CART_TALK_DELAY: float = 4.3
## 割繩子的位置：東岸北側木柱旁（離第 2、3 點都夠遠，按互動鍵不會搶）
const ROPE_POS: Vector3 = Vector3(3.7, 0.0, SLUICE_Z - 1.2)
const ROPE_RANGE: float = 1.3
## 壓住：陷進煤堆多深、往前趴多少（繞 X 軸負的是往前，D-052）
const PIN_SINK: float = 0.55
const PIN_TILT: float = -0.3
const COAL: Color = Color(0.09, 0.085, 0.085)
## 閘道裡那堆煤（D-195）：長（X）、高、寬（Z），公尺；CoalPile 的形狀種子
const COAL_HEAP_SIZE: Vector3 = Vector3(2.7, 0.62, 2.3)
const COAL_HEAP_SEED: float = 7.3
## 煤車裡那堆（長、高、寬）：滾出去的小煤塊也要落在車身裡（車身 1.0 × 0.9）
const CART_COAL_SIZE: Vector3 = Vector3(0.75, 0.26, 0.65)
## 閘道木架南邊橫樑下掛的小油燈（第 48、49 輪截圖：煤堆、倒吊都太暗）：掛鉤在橫樑底、鏈子多長、暖光
const SLUICE_LAMP_HOOK: Vector3 = Vector3(2.0, GANTRY_Y, SLUICE_Z + 0.1)
const SLUICE_LAMP_DROP: float = 1.4
const SLUICE_LAMP_ENERGY: float = 2.2
const SLUICE_LAMP_RANGE: float = 9.5
## 頭頂的石樑：一排排橫跨運河，縫裡透下鐘院的光
const SLAT_Y: float = 13.0
const SLAT_PITCH: float = 2.4
const SLAT_GAP: float = 0.85
const OUTER_WALL_H: float = 13.6
## 從縫裡斜斜照下來的白光（投影子）
const SLIT_LIGHT_ROT: Vector3 = Vector3(-57.0, 28.0, 0.0)
const SLIT_LIGHT_ENERGY: float = 1.5
const SLIT_LIGHT_FOG: float = 2.4
const SLIT_COLOR: Color = Color(0.85, 0.9, 1.0)
const SLIT_SPOT_ENERGY: float = 5.0
const LAMP_RANGE: float = 7.0
const LAMP_ENERGY: float = 2.6
const MISHA_GAP: float = 2.2
const MISHA_SPEED: float = 3.6

const STONE: Color = Color(0.36, 0.35, 0.34)
const STONE_LIGHT: Color = Color(0.52, 0.5, 0.47)
const MUD: Color = Color(0.13, 0.11, 0.1)
const ROCK: Color = Color(0.1, 0.1, 0.11)
const WOOD: Color = Color(0.25, 0.19, 0.13)
const IRON: Color = Color(0.17, 0.16, 0.16)
const COPPER: Color = Color(0.95, 0.55, 0.28)
const DRY_MUD_SHADER: String = "res://src/world/dry_mud.gdshader"
## 河床中間還沒乾的那一條（水窪＋濕泥）的中心 x
const PUDDLE_X: float = -0.3

var _misha: Puppet
var _pivot: Node3D
var _undertaker: Undertaker
var _clapper_light: OmniLight3D
var _clapper_mat: StandardMaterial3D
## 美術（第 55 輪，D-173）：河道牆、岸頂石板、矮牆、木架都用 InteriorLook；河床 dry_mud.gdshader。
var interior := InteriorLook.new()
var _bed_mat: ShaderMaterial
var _debris_mat: StandardMaterial3D
var _t: float = 0.0
var _continued_shown: bool = false
## 段落 2：趴在水溝裡（觀察中）、上一次敲的反應（測試讀）、反應的補間
var in_drain: bool = false
var last_reaction: String = ""
var _drain_armed: bool = true
var _reaction_tweens: Array[Tween] = []
## 胸口銅光的心跳速度：平常 HEART_BPM；轉頭之後跟著席菈敲的速度（RhythmTrial.TARGET_BPM）、從那一下開始算
var heart_bpm: float = HEART_BPM
var _heart_phase: float = 0.0
var _torso: Node3D
var _plate: Node3D
## 截圖用（`--canal-at=edge`）：站在岸邊不開對話、彌夏不跟
var _dev_hold_edge: bool = false
## 段落 3：假心臟垂在哪一點（-1＝在手上）、送葬者走到過哪些點、醒了沒（掉到河床上）、正在掉
var heart_spot: int = -1
var reached: Array[bool] = [false, false, false, false]
var awake: bool = false
var _dropping: bool = false
## 送葬者現在跟著什麼（HeartTargets.NONE／DECOY／NOEN；測試讀）
var follow_kind: String = ""
var _decoy_wait: float = 0.8
var _heart: Node3D
var _heart_light: OmniLight3D
var _heart_mat: StandardMaterial3D
var _heart_cord: MeshInstance3D
var _spots: Array[DecoySpot] = []
## 測試用：當作按住重現鍵
var force_restoring: bool = false
## 測試用：送葬者走路的速度倍數（流程測試不用真的等十幾秒）
var walk_scale: float = 1.0
## 步態目前在第幾個半週期（-1＝站著）：換到下一個就是一步落地（D-187）
var _gait_beat: int = -1
## 假心臟上一次「咚」是第幾拍；諾恩重現時自己的心跳聲（變快）下一次在什麼時候
var _heart_beat_i: int = -1
var _noen_beat_at: float = 0.0
# 段落 4
## 牠沿運河走的速度（公尺／秒，帶正負；停著是 0）：割繩子那一刻交給 CoalDrop
var walk_vz: float = 0.0
var cart_cut: bool = false
var cut_result: String = ""
var pinned: bool = false
var _freed: bool = false
var _coal_landed: bool = false
## 掙脫戰打贏、牠摔回運河之後幾秒回到檢查點（測試會調小）
var fail_retry_sec: float = 2.0
var _cart_talk_wait: float = -1.0
var _cart: Node3D
var _cart_rope: MeshInstance3D
var _coal_mass: Node3D
var _coal_heap: Node3D
var _cart_tween: Tween
var _task_heart: MarkerPoint
var _task_rope: MarkerPoint
## 割太早／太晚之後重來（回到 ch3_lured）：不再重講一次煤車的對話（檢查點之後設的旗標會被重讀的存檔蓋掉，
## 所以記在 GameSession 物件的 meta 上，不進存檔；static var 會讓整個腳本在結束時漏掉）
const RETRY_META: StringName = &"ch3_cart_failed"
# 掙脫戰（D-169）：割太早／太晚 → 牠甩開煤、爬上東岸 → 打到失衡跪下 → 席菈把牠撞回運河 → 回到 ch3_lured 再來一次
## 甩開煤之後多久開始爬（秒）、爬上岸要多久
const CLIMB_DELAY: float = 1.1
const CLIMB_SEC: float = 1.5
## 爬上來站在東岸的哪條線（x）、離諾恩至少多遠（沿運河）
const STRUGGLE_LAND_X: float = 5.6
const STRUGGLE_MIN_GAP: float = 3.2
## 跪下之後停多久、被撞回運河要多久
const KNEEL_HOLD_SEC: float = 1.0
const PUSH_SEC: float = 0.8
## 打贏掙脫戰之後重來（回到 ch3_lured）：新關卡開頭提示「煤車重新裝好了」（跟 RETRY_META 一樣記在 GameSession 的 meta）
const STRUGGLE_META: StringName = &"ch3_struggle_won"
## 掙脫戰中彌夏躲在諾恩背後多遠（離牠那一側的反方向）
const MISHA_HIDE_GAP: float = 4.0
## 截圖（`--canal-at=struggle`）時諾恩站的地方
const STRUGGLE_SHOT_NOEN: Vector3 = Vector3(5.0, 0.0, SLUICE_Z - 2.6)
## 掙脫戰中、打贏了（跪下）、正在爬上岸
var struggling: bool = false
var struggle_won: bool = false
var climbing: bool = false
## 測試會調小：跪下之後停多久、撞回運河要多久
var kneel_hold_sec: float = KNEEL_HOLD_SEC
var push_sec: float = PUSH_SEC
var _climb_tween: Tween
var _climb_land: Vector3 = Vector3.ZERO

# ---------------------------------------------------------------- 段落 5：倒吊（D-167）
const HANG_TALK: String = "ch3_hang_plan"
const HANG_END_TALK: String = "ch3_hang_end"
## 諾恩站在東岸抓繩子的位置（閘道木架南邊那根橫樑旁）
const HANG_SPOT: Vector3 = Vector3(3.8, 0.0, SLUICE_Z + 0.9)
const HANG_RANGE: float = 1.4
## 繩子掛過木架橫樑的點：席菈從這裡倒吊下去
const HANG_ANCHOR: Vector3 = Vector3(SLUICE_PASS_X, GANTRY_Y + 0.15, SLUICE_Z + 0.5)
## 擺盪 ±1（撞到鐵架）時繩子偏幾度（弧度）
const HANG_SWAY_RAD: float = 0.2
## 倒吊時的鏡頭（從東岸邊上斜斜往下看：站在岸上的過肩鏡頭會被岸緣擋住）；席菈左右晃＝畫面左右
const HANG_CAM_POS: Vector3 = Vector3(3.2, 1.7, SLUICE_Z + 3.4)
const HANG_CAM_LOOK: Vector3 = Vector3(SLUICE_PASS_X, BED_Y + 1.2, SLUICE_Z + 0.3)
## 抓到鐘舌 → 煤堆塌了 → 幾秒後三個人摔進泥裡
const COLLAPSE_SEC: float = 1.4
## 摔進泥裡（東岸，三個人並排仰躺、頭朝南；諾恩、席菈、彌夏）
const MUD_SPOTS: PackedVector3Array = [Vector3(4.3, 0.0, SLUICE_Z + 3.0), Vector3(5.1, 0.0, SLUICE_Z + 3.1), Vector3(5.9, 0.0, SLUICE_Z + 2.9)]
## 摔進泥裡的鏡頭：從他們頭頂那一側往下看
const MUD_CAM_POS: Vector3 = Vector3(5.1, 2.6, SLUICE_Z + 5.7)
const MUD_CAM_LOOK: Vector3 = Vector3(5.1, 0.1, SLUICE_Z + 3.5)

# ---------------------------------------------------------------- 段落 6：彌夏的圖（D-167）
const MAP_TALK: String = "ch3_misha_map"
## 回程：往南走過這條線，彌夏拉住諾恩（落後席菈幾步）
const MAP_TRIGGER_Z: float = SLUICE_Z + 7.0

# ---------------------------------------------------------------- 段落 7：轉角（D-168）
const CORNER_TALK: String = "ch3_corner"
## 回程路上東岸的一道舊牆（從外側岩壁伸出來，擋住半個岸）：席菈在牆角的另一邊等
const CORNER_WALL_Z: float = 2.0
const CORNER_WALL_X0: float = 6.5
const CORNER_WALL_H: float = 3.2
const CORNER_WALL_T: float = 1.0
## 席菈等的地方（牆角南邊）、對話時諾恩站的地方（牆角北邊）
const CORNER_WAIT: Vector3 = Vector3(6.3, 0.0, 3.1)
const CORNER_NOEN: Vector3 = Vector3(5.7, 0.0, 1.6)
## 走到離她這麼近就開始講
const CORNER_RANGE: float = 2.6
## 牆角的小油燈（回程唯一的暖光，掛在牆的端面上）
const CORNER_LAMP_POS: Vector3 = Vector3(CORNER_WALL_X0 - 0.16, 2.55, CORNER_WALL_Z)
const CORNER_LAMP_COLOR: Color = Color(1.0, 0.66, 0.36)
const CORNER_LAMP_ENERGY: float = 0.9
const CORNER_LAMP_RANGE: float = 5.5
## 對話的鏡頭：從河道那一側斜斜看兩個人（過肩鏡頭靠太近會把席菈淡掉，D-115）
const CORNER_CAM_POS: Vector3 = Vector3(3.5, 1.5, 4.9)
const CORNER_CAM_LOOK: Vector3 = Vector3(6.1, 1.35, 2.2)
## 抓住領口那一句：她走到這麼近；鬆開手那一句：退回一點
const COLLAR_LINE: String = "DLG_CH3_CORNER_005"
const COLLAR_GAP: float = 0.72
const LET_GO_LINE: String = "DLG_CH3_CORNER_012"
const LET_GO_GAP: float = 1.05
## 換班的鐘聲（對話裡那一句出現時，遠遠的一聲）：隔著石頭聽到的那口鐘（D-192，`bell_far`）
const SHIFT_BELL_LINE: String = "DLG_CH3_CORNER_011"
const SHIFT_BELL_SFX: String = "bell_far"
const SHIFT_BELL_DB: float = -11.0
## 講完 → 幾秒後結尾卡（「第一部　死去的攻略」「前半　完」）→「感謝試玩」一頁（D-176）→ 回標題
const END_CARD_DELAY: float = 2.4
const END_CARD_SCALE: float = 1.5
## 彌夏交完圖就先走了：往南走過牆角就不見
const MISHA_EXIT: Vector3 = Vector3(5.0, 0.0, Z_SOUTH - 1.0)
var misha_gone: bool = false
var end_card_shown: bool = false
## 結尾卡＋「感謝試玩」都關掉之後要做什麼（空的＝回標題；測試會換掉，不要真的回標題）
var end_card_done: Callable = Callable()
var _end_card_wait: float = -1.0
## 收尾配樂（D-188）
const PART_END_MUSIC: String = "part_end_theme"
const PART_END_MUSIC_DB: float = -14.0
const PART_END_MUSIC_FADE: float = 4.0
## 配樂進來時乾運河的低風壓到多小（平常 -10）
const PART_END_AMBIENCE_DB: float = -24.0
var part_end_music: AudioStreamPlayer
## 換班的鐘聲播過哪一段音（測試用；播放器播完會自己釋放）
var shift_bell_sound: String = ""
var _corner_node: Node3D
var _corner_cam: Camera3D
var _corner_tween: Tween
var _sheila_follow_dist: float = -1.0

var hang: HangRope = null
var hang_active: bool = false
## 自動測試、截圖用：按住＋照著擺盪往反方向推（HangRope.counter_steer）
var hang_autopilot: bool = false
var clapper_taken: bool = false
var _collapsing: bool = false
var _in_mud: bool = false
var _hang_pivot: Node3D
var _hang_mount: Node3D
var _hang_rope_up: MeshInstance3D
var _hang_cut_sfx: float = 0.0
## 切開胸口的火星（D-193）：她切得到（按住、在正中附近）的時候，鐘舌那裡迸出銅色的火星
var _cut_sparks: CPUParticles3D
const CUT_SPARK_COLOR: Color = Color(1.0, 0.72, 0.4)
var _hang_cam: Camera3D
var _prev_cam: Camera3D


func _ready() -> void:
	_rng.seed = 3006
	# 開發用：`-- --level=canal` 直接進來 → 照正式流程把第 2 章走完、開始第 3 章
	if not Game.session.state.quests.has(QUEST):
		dev_start_chapter3(Game.session)
	_build_environment()
	_build_canal()
	_build_bridge()
	_build_sluice()
	_build_sluice_lamp()
	_build_mud_patch()
	_build_ceiling()
	_build_undertaker()
	_build_drain()
	_build_decoy()
	_build_corner()
	# 段落 5 的目標指引：諾恩站在東岸抓繩子的地方
	var hang_spot := Node3D.new()
	hang_spot.name = "HangSpot"
	add_child(hang_spot)
	hang_spot.position = HANG_SPOT
	_init_story()
	add_to_group("interact_prompts")
	add_to_group(RestoreMix.GROUP)
	var player: Node3D = get_node_or_null("Player") as Node3D
	if player != null:
		_put(player, SPAWN, 0.0)
	_set_up_lamp()
	_build_people()
	_start_ambience()
	Game.dialogue_ended.connect(_on_dialogue_ended)
	Game.dialogue_started.connect(_on_dialogue_started)
	# 截圖用：`--canal-at=bank` 站在岸邊、對話第一句；`--canal-at=edge` 站在岸邊（不開對話）；`--canal-at=after` 岸邊的對話講完
	var dev_args: Dictionary = App.parse_user_args(OS.get_cmdline_user_args())
	var at: String = str(dev_args.get("canal-at", ""))
	if at == "after":
		Game.session.set_flag("ch3.bank_talked", true)
	if at in ["bank", "edge", "after"] and player != null:
		_put(player, BANK_POS + Vector3(0.9, 0.0, 1.6), deg_to_rad(28.0))
		_place_company()
		_look_into_canal()
		(player as PlayerController).snap_camera()
	if at == "bank":
		talk_bank.call_deferred()
	elif at == "edge":
		_dev_hold_edge = true
	# 截圖用：`--canal-at=bed` 站在南段的河床上往北看（碎石、爛木頭、水窪，D-198；正式流程到不了這裡）
	elif at == "bed" and player != null:
		_put(player, Vector3(1.4, BED_Y, 6.0), 0.15)
		_dev_hold_edge = true
	# 截圖用：`--canal-at=drain` 走進水溝、對話第一句；`--canal-at=turn` 趴在水溝裡、送葬者已經轉頭（不開對話）
	if at in ["drain", "turn"]:
		if not bool(Game.session.state.get_flag("ch3.bank_talked", false)):
			StoryLogic.apply({"guide_blank": [BLANK_ENTRY]}, Game.session.state)
			Game.session.set_flag("ch3.bank_talked", true)
		if at == "drain":
			enter_drain.call_deferred()
		else:
			_dev_hold_edge = true
			_lie_down()
			_play_reaction("steady", RhythmTrial.TURN)
			skip_reaction()
	# 截圖用：`--canal-at=heart` 假心臟垂在第 0 點、送葬者已經掉到河床上往那裡走了一半
	if at == "heart" and player != null:
		dev_start_lure(Game.session)
		# 站在西岸往東、往下看：東牆腳垂著的假心臟、走過來的送葬者（從東岸看會被岸緣擋住）
		_put(player, Vector3(-3.7, 0.0, -16.0), 0.0)
		lower_heart(0)
		finish_drop()
		_undertaker.global_position = Vector3(1.3, BED_Y, -15.6)
		_undertaker.rotation.y = atan2(-(DECOY_BED_X - 1.3), -(DECOY_ZS[0] + 15.6))
		_dev_hold_edge = true
		var look: Vector3 = Vector3(1.9, 0.0, -16.4) - player.global_position
		(player as PlayerController).yaw = atan2(-look.x, -look.z)
		(player as PlayerController).pitch = -0.95
		(player as PlayerController).snap_camera()
	# 檢查點 ch3_lured（段落 3 做完）：送葬者已經在閘道口的河床上 → 看一眼上面的煤車（對話 ch3_cart_plan）
	var stage: String = Game.session.quests.stage_of(QUEST)
	if stage == "coal_cart":
		_wake_undertaker(false)
		_undertaker.global_position = LURED_POS
		_undertaker.rotation = Vector3(0.0, PI, 0.0)
		_cart_talk_wait = -1.0 if Game.session.has_meta(RETRY_META) else 1.0
		Game.session.remove_meta(RETRY_META)
		if Game.session.has_meta(STRUGGLE_META):
			Game.session.remove_meta(STRUGGLE_META)
			_banner("CH3_STRUGGLE_RESET", 5.5)
	# 檢查點 ch3_pinned（段落 4 做完）：煤已經倒下去、牠被壓在閘道裡 → 段落 5 倒吊待續
	elif stage == "hang":
		_wake_undertaker(false)
		_undertaker.global_position = Vector3(SLUICE_PASS_X, BED_Y, CART_Z)
		_undertaker.rotation = Vector3(0.0, PI, 0.0)
		cart_cut = true
		cut_result = CoalDrop.PINNED
		_cart.rotation.x = CART_TIP
		_cart_rope.visible = false
		_show_heap()
		_pin_undertaker()
	# 檢查點 ch3_clapper（段落 5 做完）：鐘舌拿到了 → 段落 6 彌夏的圖待續
	elif stage == "misha_map":
		_wake_undertaker(false)
		_undertaker.global_position = Vector3(SLUICE_PASS_X, BED_Y, CART_Z)
		_undertaker.rotation = Vector3(0.0, PI, 0.0)
		cart_cut = true
		cut_result = CoalDrop.PINNED
		_cart.rotation.x = CART_TIP
		_cart_rope.visible = false
		_show_heap()
		_pin_undertaker()
		_take_clapper()
		if player != null:
			_put(player, MUD_SPOTS[0], PI)
	# 檢查點 ch3_map（段落 6 做完）：圖收進口袋了、彌夏先走了 → 往南走，席菈在轉角等（段落 7）
	# 第 3 章做完（ch3_main 完成＝第一部前半的結尾，存檔還是 ch3_map）：站在轉角，「下一章還在製作中」
	elif stage == "corner" or Game.session.quests.is_done(QUEST):
		_settle_after_clapper()
		if stage == "corner":
			if player != null:
				_put(player, Vector3(5.2, 0.0, MAP_TRIGGER_Z + 0.5), PI)
			_sheila_waits(true)
		else:
			if player != null:
				_put(player, CORNER_NOEN, PI)
			var ally_end: Node3D = get_node_or_null("Sheila") as Node3D
			if ally_end != null:
				ally_end.global_position = CORNER_WAIT + Vector3(0.0, 0.05, 0.0)
			_continued_shown = true
			_banner.call_deferred("CH3_END_BANNER", 8.0)
	# 截圖用：`--canal-at=cart` 站在繩子旁、假心臟垂在第 3 點、牠正走進閘道（煤車在頭頂）；
	# `--canal-at=pinned` 同一個位置，煤已經倒下去壓住牠（粉塵剛揚起來）
	if at in ["cart", "pinned"] and player != null:
		dev_start_cart(Game.session)
		_wake_undertaker(false)
		Game.session.set_flag("ch3.cart_planned", true)
		_cart_talk_wait = -1.0
		var u_at: Vector3 = Vector3(1.0, BED_Y, SLUICE_Z + 1.2) if at == "cart" else Vector3(SLUICE_PASS_X, BED_Y, CART_Z)
		_undertaker.global_position = u_at
		_undertaker.rotation.y = atan2(-(SLUICE_PASS_X - u_at.x), -(SLUICE_Z - 2.0 - u_at.z))
		lower_heart(3)
		# 站在西岸往東北看（從東岸的繩子旁看下去會被木柱和岸緣擋住）：木架上的煤車、閘道裡的牠、東岸的繩子
		_put(player, Vector3(-4.0, 0.0, SLUICE_Z + 6.5), 0.0)
		_dev_hold_edge = true
		var look_c: Vector3 = Vector3(SLUICE_PASS_X, 0.0, SLUICE_Z) - player.global_position
		# 往左多轉一點，閘道落在諾恩右邊（不被她擋住）
		(player as PlayerController).yaw = atan2(-look_c.x, -look_c.z) + 0.3
		(player as PlayerController).pitch = -0.5
		(player as PlayerController).snap_camera()
		if at == "pinned":
			cut_rope()
			finish_cut()
	# 截圖用：`--canal-at=struggle` 割太早 → 牠爬上東岸、掙脫戰剛開始（站在繩子旁往南看牠，D-169）
	if at == "struggle" and player != null:
		dev_start_cart(Game.session)
		_wake_undertaker(false)
		Game.session.set_flag("ch3.cart_planned", true)
		_cart_talk_wait = -1.0
		_undertaker.global_position = Vector3(1.0, BED_Y, SLUICE_Z + 1.2)
		lower_heart(3)
		# 割完往岸中間退開幾步（站在木柱旁邊，過肩鏡頭會被木柱推進諾恩的頭裡）
		_put(player, STRUGGLE_SHOT_NOEN, 0.0)
		cut_rope()
		finish_cut()
		finish_climb()
		var ally_s: Node3D = get_node_or_null("Sheila") as Node3D
		if ally_s != null:
			ally_s.global_position = STRUGGLE_SHOT_NOEN + Vector3(1.6, 0.05, 1.4)
		if _misha != null:
			_misha.global_position = misha_hide_spot(STRUGGLE_SHOT_NOEN, _undertaker.global_position)
		var look_s: Vector3 = _undertaker.global_position - player.global_position
		# 往左多轉一點，牠落在諾恩右邊（不被他擋住）
		(player as PlayerController).yaw = atan2(-look_s.x, -look_s.z) + 0.3
		(player as PlayerController).pitch = -0.12
		(player as PlayerController).snap_camera()
	# 截圖用：`--canal-at=hang` 段落 5：席菈倒吊在閘道裡、往右晃一點（鏡頭從東岸往下看）；
	# `--canal-at=mud` 抓到鐘舌、三個人摔在泥裡（對話第一句）
	if at in ["hang", "mud"] and player != null:
		dev_start_cart(Game.session)
		_wake_undertaker(false)
		Game.session.set_flag("ch3.cart_planned", true)
		_cart_talk_wait = -1.0
		_undertaker.global_position = Vector3(SLUICE_PASS_X, BED_Y, CART_Z)
		_undertaker.rotation = Vector3(0.0, PI, 0.0)
		cut_rope()
		finish_cut()
		_begin_hang()
		_dev_hold_edge = true
		if at == "hang":
			hang.sway = 0.3
			hang.progress = 0.4
			hang.holding = true
			_update_hang_rig()
			_update_cut_sparks()
		else:
			_grab_clapper()
			_fall_in_mud.call_deferred()
	# 截圖用：`--canal-at=map` 段落 6：回程往南走，彌夏拉住諾恩（對話第一句）
	if at == "map" and player != null:
		dev_start_cart(Game.session)
		_wake_undertaker(false)
		Game.session.set_flag("ch3.cart_planned", true)
		_cart_talk_wait = -1.0
		_undertaker.global_position = Vector3(SLUICE_PASS_X, BED_Y, CART_Z)
		_undertaker.rotation = Vector3(0.0, PI, 0.0)
		cut_rope()
		finish_cut()
		_take_clapper()
		Game.session.set_flag("ch3.clapper_taken", true)
		# 煤壓住牠的提示（4 秒）是好幾分鐘前的事：直接跳到這裡時收掉，不然會疊在彌夏的對話上方（盤點截圖 33）
		var dev_hud: Hud = get_node_or_null("Hud") as Hud
		if dev_hud != null:
			dev_hud.hide_banner()
		_put(player, Vector3(5.2, 0.0, MAP_TRIGGER_Z + 0.5), PI)
		(player as PlayerController).yaw = PI + 0.5
		(player as PlayerController).snap_camera()
		_dev_hold_edge = true
		talk_misha_map.call_deferred()
	# 截圖用：`--canal-at=corner` 段落 7：轉角，她抓住領口那一句（鏡頭換成對話的固定鏡頭）；
	# `--canal-at=end` 講完之後的結尾卡（停在字完整出現）；`--canal-at=thanks` 結尾卡之後的「感謝試玩」（D-176）
	if at in ["corner", "end", "thanks"] and player != null:
		dev_start_cart(Game.session)
		for flag: String in ["ch3.cart_planned", "ch3.cart_dropped", "ch3.clapper_taken", "ch3.map_accepted", "ch3.misha_map_given"]:
			Game.session.set_flag(flag, true)
		_cart_talk_wait = -1.0
		_settle_after_clapper()
		_sheila_waits(true)
		_put(player, CORNER_NOEN + Vector3(0.0, 0.0, -0.6), PI)
		(player as PlayerController).snap_camera()
		_dev_hold_edge = true
		if at == "corner":
			_dev_corner_to_collar.call_deferred()
		elif at == "thanks":
			end_card_done = func() -> void: pass
			_dev_thanks.call_deferred()
		else:
			end_card_done = func() -> void: pass
			_dev_end_card.call_deferred()


## 開發旗標與測試用：照正式流程把第 2 章走完（第 3 章跟著開始）。已經開始第 3 章就不動。
static func dev_start_chapter3(s: GameSession) -> void:
	if s.state.quests.has(QUEST):
		return
	var ach: AchievementTracker = s.achievements
	s.achievements = null
	var hall: Resource = load("res://scenes/levels/bell_hall.gd")
	hall.call("dev_start_chapter2", s)
	hall.call("dev_reach_inner_room", s, true)
	for i: int in 4:
		s.state.set_flag("ch2.carving_%d" % i, true)
	s.set_flag("ch2.read_wall_carvings", true)
	s.state.set_flag("ch2.plan_break", true)
	s.set_flag("ch2.curtain_talked", true)
	s.set_flag("ch2.curtain_opened", true)
	s.attach_achievements(ach)


## 開發旗標與測試用：照正式流程推到段落 3（拿到假心臟，檢查點 ch3_decoy）。
static func dev_start_lure(s: GameSession) -> void:
	dev_start_chapter3(s)
	if s.quests.stage_of(QUEST) == "canal_bank":
		StoryLogic.apply({"guide_blank": [BLANK_ENTRY]}, s.state)
		s.set_flag("ch3.bank_talked", true)
	if s.quests.stage_of(QUEST) == "observe":
		s.set_flag(RhythmTrial.FLAG_FOUND, true)
	if s.quests.stage_of(QUEST) == "decoy":
		s.set_flag("ch3.decoy_received", true)


## 開發旗標與測試用：照正式流程推到段落 4（牠在閘道口，檢查點 ch3_lured）。
static func dev_start_cart(s: GameSession) -> void:
	dev_start_lure(s)
	if s.quests.stage_of(QUEST) == "lure":
		for i: int in LURE_SPOTS:
			s.state.set_flag("ch3.decoy_reached_%d" % i, true)
		s.set_flag("ch3.decoy_done", true)


func _put(node: Node3D, p: Vector3, yaw: float) -> void:
	node.global_position = p + Vector3(0, 0.05, 0)
	node.rotation.y = yaw
	if node is PlayerController:
		(node as PlayerController).yaw = yaw
		(node as PlayerController).velocity = Vector3.ZERO
		(node as PlayerController).snap_camera()


func _set_up_lamp() -> void:
	var light: OmniLight3D = lamp_light()
	if light != null:
		light.omni_range = LAMP_RANGE
		light.light_energy = LAMP_ENERGY
		light.shadow_enabled = true


## 地底的環境音（空洞的低風、有回音的滴水、吊樑的嘎吱；10 秒循環，照 daylight 的做法）。
func _start_ambience() -> void:
	Ambience.play(self, "canal_ambience", -10.0)


func lamp_light() -> OmniLight3D:
	var player: Node3D = get_node_or_null("Player") as Node3D
	return player.find_child("LanternLight", true, false) as OmniLight3D if player != null else null


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# ---------------------------------------------------------------- 流程

func _physics_process(delta: float) -> void:
	var player: PlayerController = get_node_or_null("Player") as PlayerController
	if player == null:
		return
	_follow_misha(player, delta)
	if struggling:
		_update_struggle()
	if Game.is_player_locked() or _dev_hold_edge:
		return
	var stage: String = Game.session.quests.stage_of(QUEST)
	if stage == "canal_bank" and _flat(player.global_position, BANK_POS) <= BANK_RANGE:
		talk_bank()
	elif stage == "observe" and not in_drain:
		var d: float = _flat(player.global_position, DRAIN_POS)
		if d > DRAIN_RANGE + 0.6:
			_drain_armed = true
		elif d <= DRAIN_RANGE and _drain_armed:
			enter_drain()
	elif stage == "decoy":
		_decoy_wait -= delta
		if _decoy_wait <= 0.0 and _misha != null and _flat(player.global_position, _misha.global_position) <= MISHA_TALK_RANGE:
			talk_misha()
	elif stage == "lure":
		if Input.is_action_just_pressed("interact") and nearest_spot() >= 0:
			use_spot(nearest_spot())
	elif stage == "coal_cart":
		if _cart_talk_wait >= 0.0 and not bool(Game.session.state.get_flag("ch3.cart_planned", false)):
			_cart_talk_wait -= delta
			if _cart_talk_wait < 0.0:
				Game.start_dialogue(CART_TALK)
		if Input.is_action_just_pressed("interact"):
			if near_rope():
				cut_rope()
			elif nearest_spot() >= 0:
				use_spot(nearest_spot())
	elif stage == "hang":
		if hang_active:
			var hold: bool = hang_autopilot or Input.is_action_pressed("interact")
			var steer: float = HangRope.counter_steer(hang) if hang_autopilot else Input.get_axis("move_left", "move_right")
			hang_tick(delta, hold, steer)
		elif near_hang_spot() and Input.is_action_just_pressed("interact"):
			grab_hang_rope()
	elif stage == "misha_map":
		if player.global_position.z >= MAP_TRIGGER_Z:
			talk_misha_map()
	elif stage == "corner":
		_update_corner_wait(player)
		if _flat(player.global_position, CORNER_WAIT) <= CORNER_RANGE:
			talk_corner()
	if awake and not _dropping:
		_update_follow(player, delta)
	_place_task_marker()


func _process(delta: float) -> void:
	_t += delta
	if _end_card_wait >= 0.0:
		_end_card_wait -= delta
		if _end_card_wait < 0.0:
			play_end_card()
	if _pivot != null:
		_pivot.rotation.z = deg_to_rad(SWAY_DEG) * sin(_t * SWAY_RATE)
		_pivot.rotation.x = deg_to_rad(SWAY_DEG * 0.45) * sin(_t * SWAY_RATE * 0.71 + 1.3)
	var beat: float = heartbeat(_t - _heart_phase, heart_bpm)
	if _clapper_light != null:
		_clapper_light.light_energy = CLAPPER_ENERGY * (0.35 + 0.65 * beat)
	if _clapper_mat != null:
		_clapper_mat.emission_energy_multiplier = 1.2 + 4.0 * beat
	_update_heart()


## 鐘舌的光：一次心跳兩拍（咚、咚——停），0～1。
static func heartbeat(t: float, beats_per_minute: float = HEART_BPM) -> float:
	var period: float = 60.0 / beats_per_minute
	var p: float = fposmod(t, period) / period
	var first: float = exp(-pow((p - 0.06) / 0.045, 2.0))
	var second: float = 0.6 * exp(-pow((p - 0.24) / 0.05, 2.0))
	return clampf(first + second, 0.0, 1.0)


## 走到岸邊（測試也用）：岸邊的對話。只開一次。
func talk_bank() -> void:
	if Game.is_in_dialogue() or bool(Game.session.state.get_flag("ch3.bank_talked", false)):
		return
	_place_company()
	_look_into_canal()
	Game.start_dialogue(BANK_TALK)


## 對話開始時鏡頭轉向橋下、往下看（從岸邊看得到掛著的送葬者和胸口的銅光）。
func _look_into_canal() -> void:
	var player: PlayerController = get_node_or_null("Player") as PlayerController
	if player == null:
		return
	var to: Vector3 = Vector3(HANG_X, 0.0, HANG_Z) - player.global_position
	player.yaw = atan2(-to.x, -to.z)
	player.pitch = LOOK_DOWN_PITCH


func _on_dialogue_ended(dialogue_id: String) -> void:
	if dialogue_id == RHYTHM_TALK:
		_on_rhythm_ended()
		return
	if dialogue_id == CART_TALK:
		Game.session.state.set_flag("ch3.cart_planned", true)
		return
	if dialogue_id == HANG_TALK:
		_begin_hang()
		return
	if dialogue_id == HANG_END_TALK:
		_on_hang_end()
		return
	if dialogue_id == MAP_TALK:
		# 跳過也一樣：圖一定會被塞進手裡（收不收只記旗標）→ 檢查點 ch3_map → 彌夏先走、席菈走到轉角等（段落 7）
		if not bool(Game.session.state.get_flag("ch3.misha_map_given", false)):
			Game.session.set_flag("ch3.misha_map_given", true)
			_misha_leaves(false)
			_sheila_waits(false)
		return
	if dialogue_id == CORNER_TALK:
		_on_corner_end()
		return
	if dialogue_id == DECOY_TALK:
		# 跳過也一樣：拿到假心臟 → 段落 3 正式開始（檢查點 ch3_decoy）
		Game.session.set_flag("ch3.decoy_received", true)
		return
	if dialogue_id != BANK_TALK or bool(Game.session.state.get_flag("ch3.bank_talked", false)):
		return
	# 跳過也一樣：攻略筆記多一條空白（「攻略沒有寫」）→ 檢查點 ch3_bank → 段落 2 待續
	StoryLogic.apply({"guide_blank": [BLANK_ENTRY]}, Game.session.state)
	Game.session.set_flag("ch3.bank_talked", true)
	_banner("GUIDE_BLANK_NOTE", 4.0)
	if not _continued_shown:
		_continued_shown = true
		get_tree().create_timer(4.3).timeout.connect(_banner.bind("CH1_TO_BE_CONTINUED", 6.0))


# ---------------------------------------------------------------- 段落 2：趴在水溝裡（觀察）

## 走進水溝（測試也用）：三個人趴下、鏡頭對著掛著的送葬者 → 對話 ch3_rhythm（選節奏）。
func enter_drain() -> void:
	if in_drain or Game.is_in_dialogue() or Game.session.quests.stage_of(QUEST) != "observe":
		return
	in_drain = true
	_drain_armed = false
	_lie_down()
	Game.start_dialogue(RHYTHM_TALK)


## 趴下：諾恩在水溝中段、席菈在前端（伸手就碰得到銅片）、彌夏在後面；都面向吊樑。
func _lie_down() -> void:
	var player: PlayerController = get_node_or_null("Player") as PlayerController
	var face_at: Vector3 = Vector3(HANG_X, 0.0, HANG_Z)
	var spots: Array[Vector3] = [DRAIN_POS, DRAIN_POS + Vector3(-0.1, 0.0, -1.25), DRAIN_POS + Vector3(0.1, 0.0, 1.25)]
	var people: Array[Node3D] = [player, get_node_or_null("Sheila") as Node3D, _misha]
	for i: int in people.size():
		var who: Node3D = people[i]
		if who == null:
			continue
		var to: Vector3 = face_at - spots[i]
		var yaw: float = atan2(-to.x, -to.z)
		who.global_position = spots[i] + Vector3(0.0, 0.03, 0.0)
		var pup: Puppet = _puppet_of(who)
		if who is PlayerController:
			var pc: PlayerController = who as PlayerController
			pc.rotation.y = 0.0
			pc.velocity = Vector3.ZERO
			var body: Node3D = pc.get_node_or_null("Body") as Node3D
			if body != null:
				body.rotation.y = yaw
			pc.yaw = yaw + 0.22
			pc.pitch = -0.2
			pc.snap_camera()
		else:
			who.rotation.y = yaw
		if pup != null:
			pup.lying = "front"


func _stand_up() -> void:
	for who: Node3D in [get_node_or_null("Player") as Node3D, get_node_or_null("Sheila") as Node3D, _misha]:
		var pup: Puppet = _puppet_of(who)
		if pup != null:
			pup.lying = ""


func _puppet_of(who: Node3D) -> Puppet:
	if who == null:
		return null
	if who is Puppet:
		return who as Puppet
	if who.has_method("puppet"):
		return who.call("puppet") as Puppet
	return null


func is_lying(who: Node3D) -> bool:
	var pup: Puppet = _puppet_of(who)
	return pup != null and pup.lying == "front"


## 仰躺著（段落 5 摔進泥裡）。
func is_on_back(who: Node3D) -> bool:
	var pup: Puppet = _puppet_of(who)
	return pup != null and pup.lying == "back"


func _on_dialogue_started(runner: DialogueRunner) -> void:
	if runner != null and runner.dialogue_id == RHYTHM_TALK and not runner.line_shown.is_connected(_on_rhythm_line):
		runner.line_shown.connect(_on_rhythm_line)
	if runner != null and runner.dialogue_id == CORNER_TALK and not runner.line_shown.is_connected(_on_corner_line):
		runner.line_shown.connect(_on_corner_line)


## 「敲」那一句出現：照剛剛選的節奏判定（寫進 ch3.react，下一句讀它），送葬者照結果演。
func _on_rhythm_line(_speaker_key: String, text_key: String) -> void:
	if text_key != KNOCK_LINE:
		return
	var tempo: String = str(Game.session.state.get_flag(RhythmTrial.FLAG_LAST, ""))
	var r: String = RhythmTrial.try_last(Game.session.state)
	if r != "":
		_play_reaction(tempo, r)


## 席菈照 tempo 敲 KNOCK_COUNT 下（悶悶的布包石頭敲銅片）；第 REACT_AFTER 下之後送葬者反應。
## 轉頭：先回到正面 → 提示音（設定可關）→ 上半身轉向銅片、停住；胸口的銅光跟著敲的速度亮。
func _play_reaction(tempo: String, r: String) -> void:
	skip_reaction()
	heart_bpm = HEART_BPM
	last_reaction = r
	if _torso == null:
		return
	_torso.rotation = Vector3.ZERO
	var times: PackedFloat32Array = RhythmTrial.knock_times(tempo, KNOCK_COUNT)
	var knocks := create_tween()
	var prev: float = 0.0
	for i: int in times.size():
		knocks.tween_interval(maxf(times[i] - prev, 0.001))
		knocks.tween_callback(_knock)
		prev = times[i]
	var react_at: float = times[mini(REACT_AFTER, times.size() - 1)]
	var tw := create_tween()
	tw.tween_interval(react_at)
	match r:
		RhythmTrial.TURN:
			if Settings.observe_cue:
				tw.tween_callback(_cue)
			tw.tween_interval(CUE_LEAD)
			tw.tween_property(_torso, "rotation:y", deg_to_rad(_turn_sign() * TURN_DEG), 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.tween_callback(_sync_heart)
		RhythmTrial.TILT:
			tw.tween_property(_torso, "rotation:z", deg_to_rad(TILT_DEG), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tw.tween_interval(1.1)
			tw.tween_property(_torso, "rotation:z", 0.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_:
			if RhythmTrial.bpm(tempo) <= 0.0 and _pivot != null:
				# 不規則：鏈子抖一下又靜下來（沒有提示音：牠沒有要轉頭）
				tw.tween_property(_pivot, "position:y", BEAM_Y + 0.04, 0.08)
				tw.tween_property(_pivot, "position:y", BEAM_Y, 0.25)
	_reaction_tweens = [knocks, tw]


## 測試、截圖用：反應直接跳到結果（轉頭的停在轉過去的樣子）。
func skip_reaction() -> void:
	for t: Tween in _reaction_tweens:
		if t != null and t.is_valid():
			t.kill()
	_reaction_tweens.clear()
	if _torso == null:
		return
	_torso.rotation = Vector3(0.0, deg_to_rad(_turn_sign() * TURN_DEG) if last_reaction == RhythmTrial.TURN else 0.0, 0.0)
	if _pivot != null:
		_pivot.position.y = BEAM_Y
	if last_reaction == RhythmTrial.TURN:
		_sync_heart()


## 轉頭之後：胸口的銅光跟著敲的速度一起亮。
func _sync_heart() -> void:
	heart_bpm = RhythmTrial.TARGET_BPM
	_heart_phase = _t


## 上半身往哪邊轉才是對著銅片（牠面朝東南，銅片在東岸）。
func _turn_sign() -> float:
	if _undertaker == null:
		return 1.0
	var to: Vector3 = PLATE_POS - _undertaker.global_position
	var fwd: Vector3 = -_undertaker.global_basis.z
	return 1.0 if fwd.cross(Vector3(to.x, 0.0, to.z)).y >= 0.0 else -1.0


## 送葬者上半身現在轉了多少度（測試讀）。
func torso_turn_deg() -> float:
	return rad_to_deg(_torso.rotation.y) if _torso != null else 0.0


func _knock() -> void:
	if _plate != null:
		Sfx.play_at(self, "cloth_knock", _plate.global_position + Vector3(0, 0.25, 0), -2.0, 0.03)


func _cue() -> void:
	if _pivot != null:
		Sfx.play_at(self, "chain_creak", _pivot.global_position + Vector3(0, -CHAIN_LEN * 0.5, 0), 0.0, 0.02, 9.0)


## 觀察的對話結束：找到速度 → 站起來、攻略筆記提示（空白條目已經由旗標變成證實）→ 段落 3 待續。
func _on_rhythm_ended() -> void:
	in_drain = false
	_stand_up()
	if not bool(Game.session.state.get_flag(RhythmTrial.FLAG_FOUND, false)):
		return
	_banner("GUIDE_SELF_NOTE", 4.0)
	_decoy_wait = DECOY_TALK_DELAY


## 水溝：東岸上一道沿 Z 的淺溝（兩側低低的石緣、底下爛泥），前端插著一片銅片。
func _build_drain() -> void:
	var drain := Node3D.new()
	drain.name = "Drain"
	drain.position = DRAIN_POS
	add_child(drain)
	var curb: ShaderMaterial = coping_mat()
	for side: float in [-1.0, 1.0]:
		_solid("DrainCurb%d" % int(side), Vector3(DRAIN_W + 0.32, 0.18, 0.16), Vector3(0.0, 0.09, side * (DRAIN_LEN * 0.5 + 0.08)), curb, false, drain)
		_solid("DrainSide%d" % int(side), Vector3(0.16, 0.12, DRAIN_LEN), Vector3(side * (DRAIN_W * 0.5 + 0.08), 0.06, 0.0), curb, false, drain)
	# 溝底的爛泥：河床同一個 shader、整片是濕的（暗、亮）
	var mud := ShaderMaterial.new()
	mud.shader = load(DRY_MUD_SHADER) as Shader
	mud.set_shader_parameter("mud_color", Color(0.17, 0.14, 0.12))
	mud.set_shader_parameter("wet_x", DRAIN_POS.x)
	mud.set_shader_parameter("wet_half", 9.0)
	_solid("DrainMud", Vector3(DRAIN_W, 0.02, DRAIN_LEN), Vector3(0.0, 0.012, 0.0), mud, false, drain)
	_plate = Node3D.new()
	_plate.name = "CopperPlate"
	_plate.position = PLATE_POS - DRAIN_POS
	drain.add_child(_plate)
	var copper := _mat(Color(0.55, 0.33, 0.18), 0.4)
	copper.metallic = 0.85
	var sheet: MeshInstance3D = _solid("Sheet", Vector3(0.36, 0.42, 0.02), Vector3(0.0, 0.2, 0.0), copper, false, _plate)
	sheet.rotation.y = 0.5
	if _undertaker != null:
		_torso = _undertaker.find_child("Torso", true, false) as Node3D


## 對話開始時：席菈站在諾恩東北邊（不擋往橋下看的視線）、彌夏在諾恩左手邊的渠邊（往橋那邊看）。
func _place_company() -> void:
	var ally: Node3D = get_node_or_null("Sheila") as Node3D
	if ally != null:
		ally.global_position = BANK_POS + Vector3(2.3, 0.05, -1.6)
	if _misha != null:
		_misha.global_position = BANK_POS + Vector3(-0.4, -0.05, 1.3)
		var to: Vector3 = Vector3(0.0, 0.0, HANG_Z) - _misha.global_position
		_misha.rotation.y = atan2(-to.x, -to.z)


func _follow_misha(player: Node3D, delta: float) -> void:
	if _misha == null or Game.is_player_locked() or _dev_hold_edge or misha_gone:
		if _misha != null:
			_misha.set_move_speed(0.0)
		if misha_gone and _misha != null and _misha.visible and not Game.is_player_locked():
			_misha_walk_off(delta)
		return
	if (struggling or climbing) and _undertaker != null:
		_misha_hide(player, delta)
		return
	var gap: Vector3 = Vector3(_misha.global_position.x - player.global_position.x, 0.0, _misha.global_position.z - player.global_position.z)
	var dist: float = gap.length()
	var mstep: float = clampf(dist - MISHA_GAP, 0.0, MISHA_SPEED * delta)
	if dist - MISHA_GAP > 10.0:
		mstep = dist - MISHA_GAP
	if mstep > 0.001 and dist > 0.001:
		_misha.global_position -= gap / dist * mstep
		_misha.rotation.y = atan2(gap.x, gap.z)
	_misha.set_move_speed(mstep / maxf(delta, 0.0001))


## 掙脫戰中彌夏躲開（D-169）：跑到諾恩背後（離牠那一側的反方向）、貼著外側岩壁，看著牠。
func _misha_hide(player: Node3D, delta: float) -> void:
	var target: Vector3 = misha_hide_spot(player.global_position, _undertaker.global_position)
	var to: Vector3 = Vector3(target.x - _misha.global_position.x, 0.0, target.z - _misha.global_position.z)
	var step: float = minf(to.length(), MISHA_SPEED * 1.2 * delta)
	if step > 0.001:
		_misha.global_position += to.normalized() * step
		_misha.rotation.y = atan2(-to.x, -to.z)
	else:
		var look: Vector3 = _undertaker.global_position - _misha.global_position
		_misha.rotation.y = atan2(-look.x, -look.z)
	_misha.set_move_speed(step / maxf(delta, 0.0001))


## 彌夏躲的地方：諾恩背後 MISHA_HIDE_GAP 公尺（牠在哪一側就往另一側）、外側岩壁邊。
static func misha_hide_spot(noen: Vector3, undertaker_pos: Vector3) -> Vector3:
	var side: float = 1.0 if noen.z >= undertaker_pos.z else -1.0
	return Vector3(CANAL_HALF_W + BANK_W - 0.7, 0.0, clampf(noen.z + side * MISHA_HIDE_GAP, Z_NORTH + 1.0, CORNER_WALL_Z - 1.5))


func undertaker() -> Undertaker:
	return _undertaker


func clapper_light() -> OmniLight3D:
	return _clapper_light


# ---------------------------------------------------------------- 段落 3：假心臟（D-165）

## 找到速度、提示過攻略筆記之後（測試也用）：（第五夜）彌夏交出假心臟。只開一次。
## 「給我一晚」之後過了一夜：畫面先黑一下（D-194），第一句旁白「第五夜」在黑幕上出現，再慢慢亮回來。
func talk_misha() -> void:
	if Game.is_in_dialogue() or Game.session.quests.stage_of(QUEST) != "decoy":
		return
	_night_pass()
	Game.start_dialogue(DECOY_TALK)


## 過了一夜的黑幕（D-194）：HUD 之上、對話框之下（字照樣看得到）；很快變黑、停一下、慢慢亮回來。
const NIGHT_FADE_IN: float = 0.35
const NIGHT_FADE_HOLD: float = 1.4
const NIGHT_FADE_OUT: float = 1.3
const NIGHT_FADE_LAYER: int = 12


func _night_pass() -> void:
	var old: Node = get_node_or_null("NightFade")
	if old != null:
		old.free()
	var layer := CanvasLayer.new()
	layer.name = "NightFade"
	layer.layer = NIGHT_FADE_LAYER
	var rect := ColorRect.new()
	rect.color = Color.BLACK
	rect.modulate.a = 0.0
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	add_child(layer)
	var tw: Tween = layer.create_tween()
	tw.tween_property(rect, "modulate:a", 1.0, NIGHT_FADE_IN)
	tw.tween_interval(NIGHT_FADE_HOLD)
	tw.tween_property(rect, "modulate:a", 0.0, NIGHT_FADE_OUT)
	tw.tween_callback(layer.queue_free)


## 東岸的三個點（矮牆上一根小木樁）、假心臟（小銅盒＋一下一下亮的銅光）、垂下去的繩子。
func _build_decoy() -> void:
	var wood: StandardMaterial3D = _mat(WOOD, 0.9)
	for i: int in DECOY_ZS.size():
		var spot := DecoySpot.new()
		spot.name = "DecoySpot%d" % i
		spot.index = i
		spot.level = self
		spot.position = Vector3(DECOY_BANK_X, 0.0, DECOY_ZS[i])
		add_child(spot)
		_spots.append(spot)
		_solid("Peg", Vector3(0.08, 0.34, 0.08), Vector3(CANAL_HALF_W + 0.22 - DECOY_BANK_X, PARAPET_H + 0.17, 0.0), wood, false, spot)
	_heart = Node3D.new()
	_heart.name = "FakeHeart"
	_heart.visible = false
	add_child(_heart)
	_heart_mat = _mat(Color(0.5, 0.3, 0.16), 0.4)
	_heart_mat.metallic = 0.8
	_heart_mat.emission_enabled = true
	_heart_mat.emission = COPPER
	_solid("Box", Vector3(0.2, 0.16, 0.18), Vector3(0.0, 0.08, 0.0), _heart_mat, false, _heart)
	_heart_light = OmniLight3D.new()
	_heart_light.name = "HeartLight"
	_heart_light.light_color = COPPER
	_heart_light.omni_range = 3.2
	_heart_light.shadow_enabled = false
	_heart_light.light_volumetric_fog_energy = 1.2
	_heart_light.position = Vector3(0.0, 0.3, 0.0)
	_heart.add_child(_heart_light)
	_heart_cord = MeshInstance3D.new()
	_heart_cord.name = "HeartCord"
	var cm := CylinderMesh.new()
	cm.top_radius = 0.008
	cm.bottom_radius = 0.008
	cm.height = 1.0
	_heart_cord.mesh = cm
	_heart_cord.material_override = _mat(Color(0.3, 0.27, 0.22), 1.0)
	_heart_cord.visible = false
	add_child(_heart_cord)


## 第 i 點的假心臟垂到河床上的位置。
func heart_bed_pos(i: int) -> Vector3:
	return Vector3(DECOY_BED_X, BED_Y, DECOY_ZS[i])


## 這一點現在能不能動手（目標指引也用）：假心臟在手上 → 送葬者還沒走到過的點；垂下去了 → 只有垂著的那一點。
func spot_actionable(i: int) -> bool:
	var stage: String = Game.session.quests.stage_of(QUEST)
	if _dropping:
		return false
	if stage == "lure":
		if heart_spot < 0:
			return i < LURE_SPOTS and not reached[i]
		return heart_spot == i
	if stage == "coal_cart" and not cart_cut and i in CART_SPOTS:
		return heart_spot < 0 or heart_spot == i
	return false


## 諾恩站在哪一點旁邊（而且能動手）；沒有回傳 -1。
func nearest_spot() -> int:
	var player: Node3D = get_node_or_null("Player") as Node3D
	if player == null:
		return -1
	for i: int in DECOY_ZS.size():
		if spot_actionable(i) and _flat(player.global_position, Vector3(DECOY_BANK_X, 0.0, DECOY_ZS[i])) <= DECOY_RANGE:
			return i
	return -1


func interact_hint() -> Dictionary:
	if hang_active and hang != null:
		return {"fmt": TranslationServer.translate("CH3_HANG_HOLD_HINT"), "action": "interact", "progress": hang.progress}
	if near_hang_spot():
		return {"fmt": TranslationServer.translate("CH3_HANG_GRAB_HINT"), "action": "interact", "progress": -1.0}
	if near_rope():
		return {"fmt": TranslationServer.translate("CH3_CART_CUT_HINT"), "action": "interact", "progress": -1.0}
	var i: int = nearest_spot()
	if i < 0:
		return {}
	var key: String = "CH3_DECOY_RAISE_HINT" if heart_spot == i else "CH3_DECOY_LOWER_HINT"
	return {"fmt": TranslationServer.translate(key), "action": "interact", "progress": -1.0}


## 在第 i 點按互動鍵（測試也用）：垂下去／收上來。
func use_spot(i: int) -> void:
	if not spot_actionable(i):
		return
	if heart_spot == i:
		raise_heart()
	elif heart_spot < 0:
		lower_heart(i)


## 把假心臟垂到第 i 點的河床上：送葬者聽得到（HeartTargets.HEAR_RANGE）就醒過來／往這裡走；聽不到就提示太遠。
func lower_heart(i: int) -> void:
	heart_spot = i
	var at: Vector3 = heart_bed_pos(i)
	_heart.global_position = at
	_heart.visible = true
	var top: Vector3 = Vector3(CANAL_HALF_W + 0.22, PARAPET_H + 0.3, DECOY_ZS[i])
	var bottom: Vector3 = at + Vector3(0.0, 0.16, 0.0)
	var d: Vector3 = top - bottom
	_heart_cord.visible = true
	_heart_cord.scale = Vector3(1.0, d.length(), 1.0)
	_heart_cord.global_position = (top + bottom) * 0.5
	_heart_cord.rotation = Vector3(0.0, 0.0, -atan2(d.x, d.y))
	Sfx.play_at(self, "cloth_knock", at + Vector3(0, 0.2, 0), -8.0, 0.05)
	if _undertaker == null:
		return
	if _flat(_undertaker.global_position, at) > HeartTargets.HEAR_RANGE:
		_banner("CH3_DECOY_TOO_FAR", 3.5)
	elif not awake:
		_wake_undertaker(true)
		_banner("CH3_DECOY_WOKE", 3.5)


func raise_heart() -> void:
	heart_spot = -1
	_heart.visible = false
	_heart_cord.visible = false


## 鏈子鬆開：送葬者從吊樑下掉到河床上（drop＝false 直接站在河床上，重來用）。之後每幀跟著心跳走。
func _wake_undertaker(drop: bool) -> void:
	if awake or _undertaker == null:
		return
	awake = true
	var gt: Transform3D = _undertaker.global_transform
	_pivot.remove_child(_undertaker)
	add_child(_undertaker)
	_undertaker.global_transform = gt
	_undertaker.rotation = Vector3(0.0, _undertaker.rotation.y, 0.0)
	if _torso != null:
		_torso.rotation = Vector3.ZERO
	for c: Node in _pivot.get_children():
		if str(c.name).begins_with("Chain"):
			(c as Node3D).visible = false
	if not drop:
		_undertaker.global_position.y = BED_Y
		return
	_dropping = true
	_cue()
	var tw := create_tween()
	tw.tween_property(_undertaker, "global_position:y", BED_Y, DROP_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_on_landed)


func _on_landed() -> void:
	_dropping = false
	if _undertaker != null:
		Sfx.play_at(self, "blunt", _undertaker.global_position + Vector3(0, 0.3, 0), -4.0, 0.03)


## 測試用：掉下來的補間直接跳到結果。
func finish_drop() -> void:
	if _dropping and _undertaker != null:
		_undertaker.global_position.y = BED_Y
		_on_landed()


## 重現時諾恩的心跳變快（切片裡重現有心跳聲）：在這裡按住重現鍵就算。
func noen_restoring() -> bool:
	if force_restoring:
		return true
	return not Game.is_player_locked() and Input.is_action_pressed("nine_breath")


## 重現期間的混音（D-183）：牠醒著、諾恩按住重現（心跳變快）時，其他聲音悶下去。
func restore_mix_active() -> bool:
	return awake and noen_restoring()


## 醒著的送葬者：問 HeartTargets 現在聽起來最近的心跳 → 轉過去；是假心臟就走過去、走到旁邊停下來聽；
## 是重現中的諾恩就停下來轉向他（第一次提示「牠聽得到」）；走到閘道口 → 段落 3 完成。
func _update_follow(player: PlayerController, delta: float) -> void:
	walk_vz = 0.0
	if pinned or _freed:
		return
	var from: Vector3 = _undertaker.global_position
	var decoys: Array[Vector3] = []
	if heart_spot >= 0:
		decoys.append(heart_bed_pos(heart_spot))
	var pick: Dictionary = HeartTargets.pick(from, decoys, player.global_position, noen_restoring())
	var kind: String = str(pick["kind"])
	if kind == HeartTargets.NOEN and not bool(Game.session.state.get_flag("ch3.heard_noen", false)):
		Game.session.state.set_flag("ch3.heard_noen", true)
		_banner("CH3_HEARS_NOEN", 4.5)
	follow_kind = kind
	if kind != HeartTargets.DECOY:
		_gait(false)
	if kind == HeartTargets.NONE:
		return
	var target: Vector3 = pick["pos"] as Vector3
	var to: Vector3 = Vector3(target.x - from.x, 0.0, target.z - from.z)
	var dist: float = to.length()
	# 目標在閘道另一邊：先往閘道出口走（石牆中間那條線），穿過去再轉向假心臟
	var aim: Vector3 = steer_through_sluice(from, target) if kind == HeartTargets.DECOY else target
	var to_aim: Vector3 = Vector3(aim.x - from.x, 0.0, aim.z - from.z)
	if to_aim.length() < 0.02:
		aim = target
		to_aim = to
	if to_aim.length() > 0.01:
		_undertaker.rotation.y = rotate_toward(_undertaker.rotation.y, atan2(-to_aim.x, -to_aim.z), TURN_RATE * delta)
	if kind != HeartTargets.DECOY:
		return
	# x 被河道寬度夾住時只會無限逼近 HEART_REACH，留一點餘裕
	if dist <= HEART_REACH + 0.05:
		_gait(false)
		if not reached[heart_spot]:
			reached[heart_spot] = true
			Game.session.state.set_flag("ch3.decoy_reached_%d" % heart_spot, true)
		_check_lured()
		return
	var step: float = WALK_SPEED * walk_scale * delta
	var np: Vector3
	if aim == target:
		np = from + to / dist * minf(step, dist - HEART_REACH)
	else:
		np = from + to_aim.normalized() * minf(step, to_aim.length())
	var lim: float = bed_limit_x(np.z)
	np.x = clampf(np.x, -lim, lim)
	walk_vz = (np.z - from.z) / maxf(delta, 0.0001)
	_undertaker.global_position = np
	_gait(true)
	_check_lured()


## 河床能走的寬度（|x| 上限）：閘道石牆那一段比較窄。
static func bed_limit_x(z: float) -> float:
	return SLUICE_HALF if absf(z - SLUICE_Z) <= SLUICE_PIER_HALF_Z else BED_LIMIT_X


## 目標在閘道另一邊（還沒穿過出口、目標在出口外）→ 先往出口那一點走；否則直接走向目標。
static func steer_through_sluice(from: Vector3, target: Vector3) -> Vector3:
	var s: float = signf(target.z - SLUICE_Z)
	if s == 0.0:
		return target
	var exit_z: float = SLUICE_Z + s * SLUICE_EXIT
	if (from.z - exit_z) * s < 0.0 and (target.z - exit_z) * s > 0.0:
		return Vector3(SLUICE_PASS_X, target.y, exit_z + s * 0.2)
	return target


## 沒有走路動畫的白盒步伐：走的時候整隻一頓一頓地往上抬、左右晃（沉重、拖著鐵架）；停下來就站穩。
func _gait(walking: bool) -> void:
	if _undertaker == null:
		return
	if not walking:
		_undertaker.global_position.y = BED_Y
		_undertaker.rotation.z = 0.0
		_gait_beat = -1
		return
	var ph: float = _t * TAU / GAIT_SEC
	_undertaker.global_position.y = BED_Y + GAIT_LIFT * absf(sin(ph))
	_undertaker.rotation.z = GAIT_ROLL * sin(ph)
	# 腳步聲（D-187）：每半個步態週期身體落回河床一次＝一步（牠這時 process_mode 停著，聲音掛在關卡上）
	var beat: int = int(floor(ph / PI))
	if _gait_beat >= 0 and beat != _gait_beat and _undertaker.footsteps != null:
		_undertaker.footsteps.stomp(_undertaker, false, self)
	_gait_beat = beat


## 走到閘道口：段落 3 完成（ch3.decoy_done → 檢查點 ch3_lured）→ 段落 4 煤車待續。
func _check_lured() -> void:
	if _undertaker.global_position.z > SLUICE_REACH_Z or Game.session.quests.stage_of(QUEST) != "lure":
		return
	if heart_spot >= 0:
		reached[heart_spot] = true
	raise_heart()
	Game.session.set_flag("ch3.decoy_done", true)
	_banner("CH3_LURED_NOTE", 4.0)
	# 段落 4：停一下，抬頭看見閘道上面的煤車（對話 ch3_cart_plan）
	_cart_talk_wait = CART_TALK_DELAY


func _update_heart() -> void:
	if awake and noen_restoring():
		if _t >= _noen_beat_at:
			_noen_beat_at = _t + NOEN_RACE_SEC
			Sfx.play_flat(self, "heartbeat", -7.0, Sfx.HEART_BUS)
	if _heart == null or not _heart.visible:
		_heart_beat_i = -1
		return
	# 假心臟自己的「咚—咚」（每分鐘 RhythmTrial.TARGET_BPM 下，從河床上傳來，近的時候才聽得清楚）
	var k: int = int(floor(_t * RhythmTrial.TARGET_BPM / 60.0))
	if k != _heart_beat_i:
		_heart_beat_i = k
		Sfx.play_at(self, "heartbeat", _heart.global_position + Vector3(0, 0.15, 0), -3.0, 0.02, 3.0)
	var hb: float = heartbeat(_t, RhythmTrial.TARGET_BPM)
	_heart_light.light_energy = 0.5 + 3.5 * hb
	_heart_mat.emission_energy_multiplier = 1.0 + 6.0 * hb
	_heart.scale = Vector3.ONE * (1.0 + 0.1 * hb)


# ---------------------------------------------------------------- 段落 4：煤車（D-166）

## 諾恩站在繩子旁邊（而且還能割）。
func near_rope() -> bool:
	if cart_cut or Game.session.quests.stage_of(QUEST) != "coal_cart":
		return false
	var player: Node3D = get_node_or_null("Player") as Node3D
	return player != null and _flat(player.global_position, ROPE_POS) <= ROPE_RANGE


## 目標指引（MarkerPoint）：「heart」＝假心臟在手上、「rope」＝已經垂下去了（該去繩子那裡等）。
func marker_available(query: String) -> bool:
	if cart_cut or Game.session.quests.stage_of(QUEST) != "coal_cart" or Game.is_in_dialogue():
		return false
	if query == "heart":
		return heart_spot < 0
	if query == "rope":
		return heart_spot >= 0
	return false


## 放心臟的指引點跟著牠在哪一邊換：牠在煤車南邊 → 閘道另一邊的第 3 點；已經走過頭 → 第 2 點（拉回來）。
func _place_task_marker() -> void:
	if _task_heart == null or _undertaker == null:
		return
	var i: int = 3 if _undertaker.global_position.z > CART_Z else 2
	_task_heart.position = Vector3(DECOY_BANK_X, 0.0, DECOY_ZS[i])


## 割斷繩子（測試也用）：這一刻就照 CoalDrop 判定（看煤落下那一刻牠在哪）；煤車往南傾倒、一團煤落下 FALL_SEC 秒。
func cut_rope() -> void:
	if cart_cut or _undertaker == null or Game.session.quests.stage_of(QUEST) != "coal_cart":
		return
	cart_cut = true
	cut_result = CoalDrop.judge(_undertaker.global_position.z, signf(walk_vz), absf(walk_vz), CART_Z)
	_cart_rope.visible = false
	Sfx.play_at(self, "whoosh", ROPE_POS + Vector3(0, 1.0, 0), -6.0, 0.05)
	Sfx.play_at(self, "brace_creak", _cart.global_position, -2.0, 0.05)
	_coal_mass.global_position = _cart.global_position + Vector3(0.0, 0.5, 0.2)
	_coal_mass.visible = true
	_cart_tween = create_tween()
	_cart_tween.set_parallel(true)
	_cart_tween.tween_property(_cart, "rotation:x", CART_TIP, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var land: Vector3 = Vector3(SLUICE_PASS_X, BED_Y + 0.45, CART_Z)
	_cart_tween.tween_property(_coal_mass, "global_position", land, CoalDrop.FALL_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_cart_tween.chain().tween_callback(_on_coal_landed)


## 測試用：煤直接落地。
func finish_cut() -> void:
	if not cart_cut or _coal_landed:
		return
	if _cart_tween != null and _cart_tween.is_valid():
		_cart_tween.kill()
	_cart.rotation.x = CART_TIP
	_on_coal_landed()


## 煤落地：煤堆、黑色粉塵、震動、油燈晃。壓住 → ch3.cart_dropped（檢查點 ch3_pinned）；太早／太晚 → 牠掙脫 → 回到 ch3_lured。
func _on_coal_landed() -> void:
	if _coal_landed:
		return
	_coal_landed = true
	_coal_mass.visible = false
	_show_heap()
	_coal_dust(Vector3(SLUICE_PASS_X, BED_Y + 0.3, CART_Z))
	Sfx.play_at(self, "rubble_scrape", Vector3(SLUICE_PASS_X, BED_Y + 0.5, CART_Z), 0.0, 0.05)
	Sfx.play_flat(self, "deep_rumble", -6.0)
	var player: PlayerController = get_node_or_null("Player") as PlayerController
	if player != null:
		player.shake(0.55)
	_sway_lamp()
	if cut_result == CoalDrop.PINNED:
		_pin_undertaker()
		Sfx.play_at(self, "iron_clang", _undertaker.global_position + Vector3(0, 1.0, 0), -4.0, 0.05)
		Game.session.set_flag("ch3.cart_dropped", true)
		_banner("CH3_CART_PINNED", 4.0)
		return
	_shake_free()
	_banner("CH3_CART_EARLY" if cut_result == CoalDrop.EARLY else "CH3_CART_LATE", CLIMB_DELAY + CLIMB_SEC)
	get_tree().create_timer(CLIMB_DELAY).timeout.connect(_climb_out)


func _show_heap() -> void:
	_coal_heap.global_position = Vector3(SLUICE_PASS_X, BED_Y, CART_Z)
	_coal_heap.visible = true


## 壓住：陷進煤堆、往前趴，不再跟著心跳走；胸口的鐘舌還在亮（段落 5 要切開的地方）。
func _pin_undertaker() -> void:
	pinned = true
	follow_kind = ""
	walk_vz = 0.0
	raise_heart()
	_undertaker.global_position.y = BED_Y - PIN_SINK
	_undertaker.rotation = Vector3(PIN_TILT, _undertaker.rotation.y, 0.0)


# ---------------------------------------------------------------- 段落 5：倒吊（D-167）

## 站在東岸抓繩子的地方（段落 5 還沒開始）。
func near_hang_spot() -> bool:
	if hang_active or clapper_taken or _collapsing or Game.session.quests.stage_of(QUEST) != "hang":
		return false
	var player: Node3D = get_node_or_null("Player") as Node3D
	return player != null and _flat(player.global_position, HANG_SPOT) <= HANG_RANGE


## 按互動鍵抓住繩子（測試也用）：先講一段（席菈綁繩子、彌夏催），講完／跳過才倒吊下去。
func grab_hang_rope() -> void:
	if hang_active or clapper_taken or _collapsing or Game.is_in_dialogue():
		return
	Game.start_dialogue(HANG_TALK)


## 倒吊開始：諾恩站定抓著繩子、鏡頭往下看；席菈倒過來掛在木架橫樑下、頭在牠胸口上方。
func _begin_hang() -> void:
	if hang_active or clapper_taken:
		return
	hang = HangRope.new()
	hang_active = true
	var player: PlayerController = get_node_or_null("Player") as PlayerController
	if player != null:
		player.held_in_place = true
		player.global_position = HANG_SPOT
		player.velocity = Vector3.ZERO
		var body: Node3D = player.get_node_or_null("Body") as Node3D
		if body != null:
			body.rotation.y = hang_yaw()
		player.yaw = hang_yaw()
		player.snap_camera()
	_build_hang_rig()
	_build_cut_sparks()
	_use_hang_camera(true)
	var ally: Node3D = get_node_or_null("Sheila") as Node3D
	if ally != null:
		var pup: Puppet = _puppet_of(ally)
		if pup != null:
			pup.set_move_speed(0.0)
		ally.process_mode = Node.PROCESS_MODE_DISABLED
	_update_hang_rig()
	if _misha != null:
		_misha.global_position = HANG_SPOT + Vector3(0.6, -0.05, 1.3)
		_misha.rotation.y = hang_yaw()


## 倒吊鏡頭的朝向（水平）：擺盪的軸跟著它，左右晃就是畫面左右。
static func hang_yaw() -> float:
	var to: Vector3 = HANG_CAM_LOOK - HANG_CAM_POS
	return atan2(-to.x, -to.z)


## 倒吊時換成固定的鏡頭；結束換回玩家的鏡頭。
func _use_hang_camera(on: bool) -> void:
	if on:
		if _hang_cam == null:
			_hang_cam = Camera3D.new()
			_hang_cam.name = "HangCam"
			_hang_cam.fov = 62.0
			add_child(_hang_cam)
			_hang_cam.look_at_from_position(HANG_CAM_POS, HANG_CAM_LOOK)
		_prev_cam = get_viewport().get_camera_3d()
		_hang_cam.make_current()
	elif _hang_cam != null:
		_hang_cam.current = false
		if _prev_cam != null and is_instance_valid(_prev_cam):
			_prev_cam.make_current()


## 繩子從諾恩手上拉到木架橫樑、再垂下去綁在席菈腰上（倒吊的時候她跟著轉軸擺）。
func _build_hang_rig() -> void:
	if _hang_pivot != null:
		_hang_pivot.visible = true
		return
	var rope_mat: StandardMaterial3D = _mat(Color(0.42, 0.36, 0.26), 1.0)
	_hang_pivot = Node3D.new()
	_hang_pivot.name = "HangPivot5"
	add_child(_hang_pivot)
	_hang_pivot.global_position = HANG_ANCHOR
	_hang_pivot.rotation = Vector3(0.0, hang_yaw(), 0.0)
	var length: float = hang_rope_length()
	var down := MeshInstance3D.new()
	down.name = "HangRopeDown"
	var cm := CylinderMesh.new()
	cm.top_radius = 0.016
	cm.bottom_radius = 0.016
	cm.height = length
	cm.radial_segments = 6
	cm.material = rope_mat
	down.mesh = cm
	down.position = Vector3(0.0, -length * 0.5, 0.0)
	down.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_hang_pivot.add_child(down)
	# 倒過來（繞 X 轉半圈：頭朝下、臉朝東岸的鏡頭）；腳在上、腰在繩子末端
	_hang_mount = Node3D.new()
	_hang_mount.name = "HangMount"
	_hang_mount.position = Vector3(0.0, -length + Puppet.HIP_HEIGHT, 0.0)
	_hang_mount.rotation = Vector3(PI, 0.0, 0.0)
	_hang_pivot.add_child(_hang_mount)
	var hand: Vector3 = HANG_SPOT + Vector3(-0.35, 1.05, 0.0)
	_hang_rope_up = _line_between("HangRopeUp", hand, HANG_ANCHOR, 0.016, rope_mat)


## 繩子多長：倒吊下去之後她的頭剛好在鐘舌上方一點。
func hang_rope_length() -> float:
	var target_y: float = BED_Y + 1.0
	if _clapper_light != null and _clapper_light.is_inside_tree():
		target_y = _clapper_light.global_position.y
	# 腳到頭約 1.7 m，腰在腳下 HIP_HEIGHT
	return clampf(HANG_ANCHOR.y - (target_y + 0.35) - (1.7 - Puppet.HIP_HEIGHT), 2.0, 7.0)


func _update_hang_rig() -> void:
	if _hang_pivot == null or hang == null:
		return
	_hang_pivot.rotation.z = hang.sway * HANG_SWAY_RAD
	var ally: Node3D = get_node_or_null("Sheila") as Node3D
	# 摔進泥裡之後就不再跟著繩子（繩子猛拉的補間結束時還會叫一次）
	if ally != null and _hang_mount != null and not _in_mud:
		ally.global_transform = _hang_mount.global_transform


## 倒吊的一幀（測試也用）：hold＝按住拉住、steer＝左右（-1～1）。切完 → 抓到鐘舌。
func hang_tick(delta: float, hold: bool, steer: float) -> void:
	if not hang_active or hang == null:
		return
	var bumped: bool = hang.step(delta, hold, steer)
	_update_hang_rig()
	var player: PlayerController = get_node_or_null("Player") as PlayerController
	if bumped:
		var ally: Node3D = get_node_or_null("Sheila") as Node3D
		var at: Vector3 = ally.global_position if ally != null else HANG_ANCHOR
		Sfx.play_at(self, "iron_clang", at, -8.0, 0.08)
		if player != null:
			player.shake(0.18)
		_banner("CH3_HANG_BUMP", 1.6)
	_update_cut_sparks()
	_hang_cut_sfx -= delta
	if hang.cutting() and _hang_cut_sfx <= 0.0:
		_hang_cut_sfx = 0.55
		Sfx.play_at(self, "whoosh", _undertaker.global_position + Vector3(0.0, 1.5, 0.0), -12.0, 0.1)
	if hang.done:
		_grab_clapper()


## 切開胸口的地方：鐘舌的光（被拿走之前一直在），找不到就用牠胸口的高度。
func cut_point() -> Vector3:
	if _clapper_light != null and _clapper_light.is_inside_tree():
		return _clapper_light.global_position
	return (_undertaker.global_position if _undertaker != null else HANG_ANCHOR) + Vector3(0.0, 1.5, 0.0)


## 火星（D-193）：一直掛著、只在她切得到的時候噴；很小、很亮（加法混色），往上迸、很快落下。
func _build_cut_sparks() -> void:
	if _cut_sparks != null:
		return
	var ps := CPUParticles3D.new()
	ps.name = "CutSparks"
	ps.amount = 40
	ps.lifetime = 0.55
	ps.randomness = 0.4
	ps.direction = Vector3.UP
	ps.spread = 65.0
	ps.initial_velocity_min = 1.2
	ps.initial_velocity_max = 3.2
	ps.gravity = Vector3(0, -7.0, 0)
	ps.damping_min = 0.5
	ps.damping_max = 1.5
	ps.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	ps.emission_sphere_radius = 0.12
	ps.scale_amount_min = 0.6
	ps.scale_amount_max = 1.4
	var quad := QuadMesh.new()
	quad.size = Vector2(0.09, 0.09)
	quad.material = ParticleLook.material(CUT_SPARK_COLOR, true)
	ps.mesh = quad
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1.0, 0.45, 0.25, 0))
	ps.color_ramp = ramp
	ps.emitting = false
	add_child(ps)
	ps.global_position = cut_point()
	_cut_sparks = ps


## 切得到才噴（測試、截圖也用）。
func _update_cut_sparks() -> void:
	if _cut_sparks == null:
		return
	_cut_sparks.emitting = hang != null and hang_active and hang.cutting()


func cut_sparks() -> CPUParticles3D:
	return _cut_sparks


## 她抓到鐘舌的瞬間煤堆塌了：繩子猛拉、畫面一震、彌夏撲過來壓住繩尾 → COLLAPSE_SEC 秒後三個人摔進泥裡。
func _grab_clapper() -> void:
	if _collapsing or clapper_taken:
		return
	hang_active = false
	_collapsing = true
	_update_cut_sparks()
	_take_clapper()
	var heap_at: Vector3 = Vector3(SLUICE_PASS_X, BED_Y + 0.3, CART_Z)
	_coal_dust(heap_at)
	Sfx.play_at(self, "rubble_scrape", heap_at, 0.0, 0.05)
	Sfx.play_flat(self, "deep_rumble", -4.0)
	var player: PlayerController = get_node_or_null("Player") as PlayerController
	if player != null:
		player.shake(0.9)
	_sway_lamp()
	if _coal_heap != null:
		var tw_heap := create_tween()
		tw_heap.tween_property(_coal_heap, "scale:y", _coal_heap.scale.y * 0.55, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# 繩子猛地一拉：她整個人往上彈
	if _hang_pivot != null:
		var tw := create_tween()
		tw.tween_property(_hang_pivot, "position:y", _hang_pivot.position.y + 1.1, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_callback(_update_hang_rig)
	if _misha != null:
		_misha.global_position = HANG_SPOT + Vector3(0.45, -0.05, 0.7)
	# 補間綁在關卡上：關卡換掉（重來）就一起停掉
	var wait := create_tween()
	wait.tween_interval(COLLAPSE_SEC)
	wait.tween_callback(_fall_in_mud)


## 鐘舌被拿走：胸口不再亮。
func _take_clapper() -> void:
	clapper_taken = true
	if _clapper_light != null:
		_clapper_light.visible = false
	if _undertaker != null:
		var rod: Node3D = _undertaker.find_child("Clapper", true, false) as Node3D
		if rod != null:
			rod.visible = false


## 測試用：不等 COLLAPSE_SEC，直接摔進泥裡。
func finish_collapse() -> void:
	_fall_in_mud()


## 三個人一起摔在泥裡（黑一下）：仰躺在東岸 → 對話 ch3_hang_end（高手。嗯？下次換你倒吊。）
func _fall_in_mud() -> void:
	if _in_mud or not is_inside_tree() or not _collapsing:
		return
	_in_mud = true
	_cut_black(1.0)
	if _hang_pivot != null:
		_hang_pivot.visible = false
	if _hang_rope_up != null:
		_hang_rope_up.visible = false
	if _hang_cam != null:
		_hang_cam.look_at_from_position(MUD_CAM_POS, MUD_CAM_LOOK)
	var player: PlayerController = get_node_or_null("Player") as PlayerController
	var ally: Node3D = get_node_or_null("Sheila") as Node3D
	if ally != null:
		ally.process_mode = Node.PROCESS_MODE_INHERIT
		ally.rotation = Vector3.ZERO
	var people: Array[Node3D] = [player, ally, _misha]
	for i: int in people.size():
		var who: Node3D = people[i]
		if who == null:
			continue
		who.global_position = MUD_SPOTS[i] + Vector3(0.0, 0.03, 0.0)
		# 仰躺、頭朝南（+Z，鏡頭那一側）
		if who is PlayerController:
			var pc: PlayerController = who as PlayerController
			pc.held_in_place = false
			pc.velocity = Vector3.ZERO
			pc.rotation.y = 0.0
			var body: Node3D = pc.get_node_or_null("Body") as Node3D
			if body != null:
				body.rotation.y = 0.0
			# 站起來之後的鏡頭：往北看閘道
			pc.yaw = 0.0
			pc.pitch = -0.3
			pc.snap_camera()
		else:
			who.rotation.y = 0.0
		var pup: Puppet = _puppet_of(who)
		if pup != null:
			pup.lying = "back"
	Game.start_dialogue(HANG_END_TALK)


## 對話講完／跳過：站起來、鐘舌拿到了（日記多一條「乾運河的泥」）→ 檢查點 ch3_clapper → 段落 6 待續。
func _on_hang_end() -> void:
	_stand_up()
	_use_hang_camera(false)
	_collapsing = false
	if bool(Game.session.state.get_flag("ch3.clapper_taken", false)):
		return
	Game.session.set_flag("ch3.clapper_taken", true)


# ---------------------------------------------------------------- 段落 6：彌夏的圖（D-167）

## 回程往南走（測試也用）：彌夏拉住諾恩 → 對話 ch3_misha_map（重置主椅要有人接替；收下／不收都會被塞進手裡）。只開一次。
func talk_misha_map() -> void:
	if Game.is_in_dialogue() or Game.session.quests.stage_of(QUEST) != "misha_map":
		return
	var player: Node3D = get_node_or_null("Player") as Node3D
	if player != null and _misha != null:
		_misha.global_position = player.global_position + Vector3(0.9, -0.05, -0.8)
		var to: Vector3 = player.global_position - _misha.global_position
		_misha.rotation.y = atan2(-to.x, -to.z)
	var ally: Node3D = get_node_or_null("Sheila") as Node3D
	if ally != null and player != null:
		# 席菈走在前面幾步
		ally.global_position = player.global_position + Vector3(-0.6, 0.0, 4.5)
	Game.start_dialogue(MAP_TALK)


# ---------------------------------------------------------------- 段落 7：轉角（D-168）

## 東岸回程路上的一道舊牆（從外側岩壁伸出來、擋住半個岸）＋牆頂的壓頂石＋端面上的小油燈；席菈等的點（目標指引跟著她）。
func _build_corner() -> void:
	var stone: ShaderMaterial = canal_wall_mat()
	var x1: float = CANAL_HALF_W + BANK_W
	var w: float = x1 - CORNER_WALL_X0
	_solid("CornerWall", Vector3(w, CORNER_WALL_H, CORNER_WALL_T), Vector3(CORNER_WALL_X0 + w * 0.5, CORNER_WALL_H * 0.5, CORNER_WALL_Z), stone)
	_solid("CornerCoping", Vector3(w + 0.1, 0.14, CORNER_WALL_T + 0.12), Vector3(CORNER_WALL_X0 + w * 0.5 - 0.05, CORNER_WALL_H + 0.07, CORNER_WALL_Z), coping_mat(), false)
	# 牆角磨圓的護角石（一塊塊疊上去，看得出是轉角）
	for i: int in 4:
		var h: float = CORNER_WALL_H / 4.0
		var q: MeshInstance3D = _solid("CornerQuoin%d" % i, Vector3(0.28, h - 0.04, CORNER_WALL_T + (0.08 if i % 2 == 0 else 0.0)), Vector3(CORNER_WALL_X0 + 0.12, h * (i + 0.5), CORNER_WALL_Z), coping_mat(), false)
		q.position.x -= 0.02
	# 油燈：鐵臂＋小燈罩（自發光）＋一盞暖色的點光（投影子：席菈的影子落在牆上）
	var iron: StandardMaterial3D = _mat(IRON, 0.6)
	_solid("CornerLampArm", Vector3(0.3, 0.04, 0.04), CORNER_LAMP_POS + Vector3(0.1, 0.22, 0.0), iron, false)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.3, 0.2, 0.12)
	glow.emission_enabled = true
	glow.emission = CORNER_LAMP_COLOR
	glow.emission_energy_multiplier = 1.6
	_solid("CornerLampHousing", Vector3(0.16, 0.24, 0.16), CORNER_LAMP_POS, glow, false)
	var light := OmniLight3D.new()
	light.name = "CornerLamp"
	light.light_color = CORNER_LAMP_COLOR
	light.light_energy = CORNER_LAMP_ENERGY
	light.omni_range = CORNER_LAMP_RANGE
	light.omni_attenuation = 1.4
	light.shadow_enabled = true
	light.light_volumetric_fog_energy = 0.6
	light.position = CORNER_LAMP_POS + Vector3(-0.15, -0.05, 0.0)
	add_child(light)
	_corner_node = Node3D.new()
	_corner_node.name = "CornerWait"
	add_child(_corner_node)
	_corner_node.position = CORNER_WAIT


func corner_lamp() -> OmniLight3D:
	return get_node_or_null("CornerLamp") as OmniLight3D


## 閘道的小油燈：掛在木架南邊橫樑下（鏈子＋燈罩＋暖色點光、投影子），照亮煤車、閘道裡的牠和倒吊的席菈；
## 煤落地時跟著晃（`_sway_lamp`）。整個掛在 SluiceLampPivot（轉軸在掛鉤）底下。
func _build_sluice_lamp() -> void:
	var pivot := Node3D.new()
	pivot.name = "SluiceLampPivot"
	add_child(pivot)
	pivot.position = SLUICE_LAMP_HOOK
	var iron: StandardMaterial3D = _mat(IRON, 0.6)
	iron.metallic = 0.7
	_solid("SluiceLampChain", Vector3(0.025, SLUICE_LAMP_DROP, 0.025), Vector3(0.0, -SLUICE_LAMP_DROP * 0.5, 0.0), iron, false, pivot)
	_solid("SluiceLampCap", Vector3(0.2, 0.05, 0.2), Vector3(0.0, -SLUICE_LAMP_DROP - 0.02, 0.0), iron, false, pivot)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.3, 0.2, 0.12)
	glow.emission_enabled = true
	glow.emission = CORNER_LAMP_COLOR
	glow.emission_energy_multiplier = 1.8
	_solid("SluiceLampHousing", Vector3(0.15, 0.22, 0.15), Vector3(0.0, -SLUICE_LAMP_DROP - 0.16, 0.0), glow, false, pivot)
	var light := OmniLight3D.new()
	light.name = "SluiceLamp"
	light.light_color = CORNER_LAMP_COLOR
	light.light_energy = SLUICE_LAMP_ENERGY
	light.omni_range = SLUICE_LAMP_RANGE
	light.omni_attenuation = 1.2
	light.shadow_enabled = true
	light.light_volumetric_fog_energy = 0.6
	light.position = Vector3(0.0, -SLUICE_LAMP_DROP - 0.3, 0.0)
	pivot.add_child(light)


func sluice_lamp() -> OmniLight3D:
	return get_node_or_null("SluiceLampPivot/SluiceLamp") as OmniLight3D


## 檢查點 ch3_map 之後（重來、讀檔、截圖）：煤堆壓著牠、鐘舌拿走了、彌夏先走了。
func _settle_after_clapper() -> void:
	_wake_undertaker(false)
	_undertaker.global_position = Vector3(SLUICE_PASS_X, BED_Y, CART_Z)
	_undertaker.rotation = Vector3(0.0, PI, 0.0)
	cart_cut = true
	cut_result = CoalDrop.PINNED
	_cart.rotation.x = CART_TIP
	_cart_rope.visible = false
	_show_heap()
	_pin_undertaker()
	_take_clapper()
	_misha_leaves(true)


## 彌夏交完圖就先走了（原作「她離開後」）：往南走、過了牆角就不見。now＝直接不見（重來、截圖）。
func _misha_leaves(now: bool) -> void:
	misha_gone = true
	if _misha != null and now:
		_misha.visible = false
		_misha.global_position = MISHA_EXIT


func _misha_walk_off(delta: float) -> void:
	var to: Vector3 = MISHA_EXIT - _misha.global_position
	to.y = 0.0
	var d: float = to.length()
	if d < 0.3 or _misha.global_position.z > CORNER_WALL_Z + 2.5:
		_misha.visible = false
		_misha.set_move_speed(0.0)
		return
	var step: float = minf(MISHA_SPEED * 1.15 * delta, d)
	_misha.global_position += to / d * step
	_misha.rotation.y = atan2(-to.x, -to.z)
	_misha.set_move_speed(step / maxf(delta, 0.0001))


## 席菈先走到轉角等（跟著的對象換成轉角的點、跟得很近＝走到那裡停下）。snap＝直接站在那裡（重來、截圖）。
func _sheila_waits(snap: bool) -> void:
	var ally: Sheila = get_node_or_null("Sheila") as Sheila
	if ally == null or _corner_node == null:
		return
	if _sheila_follow_dist < 0.0:
		_sheila_follow_dist = ally.brain.follow_dist
	ally.leader = _corner_node
	ally.brain.follow_dist = 0.35
	if snap:
		ally.global_position = CORNER_WAIT + Vector3(0.0, 0.05, 0.0)
		ally.face_toward(CORNER_NOEN + Vector3(0.0, 0.0, -3.0))


## 她站好了就看著諾恩走過來。
func _update_corner_wait(player: Node3D) -> void:
	var ally: Sheila = get_node_or_null("Sheila") as Sheila
	if ally != null and ally.leader == _corner_node and _flat(ally.global_position, CORNER_WAIT) < 0.6:
		ally.face_toward(player.global_position)


func is_sheila_waiting() -> bool:
	var ally: Sheila = get_node_or_null("Sheila") as Sheila
	return ally != null and ally.leader == _corner_node


## 走到轉角（測試也用）：兩個人站好、鏡頭換成對話的固定鏡頭 → 對話 ch3_corner。只開一次。
func talk_corner() -> void:
	if Game.is_in_dialogue() or Game.session.quests.stage_of(QUEST) != "corner":
		return
	var player: PlayerController = get_node_or_null("Player") as PlayerController
	var ally: Sheila = get_node_or_null("Sheila") as Sheila
	if player != null:
		_put(player, CORNER_NOEN, 0.0)
		player.velocity = Vector3.ZERO
	if ally != null:
		ally.global_position = CORNER_WAIT + Vector3(0.0, 0.05, 0.0)
		ally.velocity = Vector3.ZERO
		if player != null:
			ally.face_toward(player.global_position)
			_face_noen_to(ally.global_position)
	_use_corner_camera(true)
	Game.start_dialogue(CORNER_TALK)


func _face_noen_to(p: Vector3) -> void:
	var player: PlayerController = get_node_or_null("Player") as PlayerController
	if player == null:
		return
	var to: Vector3 = p - player.global_position
	var yaw: float = atan2(-to.x, -to.z)
	var body: Node3D = player.get_node_or_null("Body") as Node3D
	if body != null:
		body.global_rotation.y = yaw
	player.yaw = yaw
	player.pitch = -0.1
	player.snap_camera()


## 對話的固定鏡頭（從河道那一側斜斜看兩個人、牆角的油燈在後面）；結束換回玩家的鏡頭。
func _use_corner_camera(on: bool) -> void:
	if on:
		if _corner_cam == null:
			_corner_cam = Camera3D.new()
			_corner_cam.name = "CornerCam"
			_corner_cam.fov = 50.0
			add_child(_corner_cam)
			_corner_cam.look_at_from_position(CORNER_CAM_POS, CORNER_CAM_LOOK)
		var cur: Camera3D = get_viewport().get_camera_3d()
		if cur != _corner_cam:
			_prev_cam = cur
		_corner_cam.make_current()
	elif _corner_cam != null:
		_corner_cam.current = false
		if _prev_cam != null and is_instance_valid(_prev_cam):
			_prev_cam.make_current()


## 對話裡的幾句：抓住領口 → 她走到很近；換班的鐘聲（遠遠的一聲）；鬆開手 → 退回一點。
func _on_corner_line(_speaker_key: String, text_key: String) -> void:
	if text_key == COLLAR_LINE:
		_sheila_step_to(COLLAR_GAP)
	elif text_key == LET_GO_LINE:
		_sheila_step_to(LET_GO_GAP)
	elif text_key == SHIFT_BELL_LINE:
		if Sfx.play_flat(self, SHIFT_BELL_SFX, SHIFT_BELL_DB) != null:
			shift_bell_sound = SHIFT_BELL_SFX


func _sheila_step_to(gap: float) -> void:
	var player: Node3D = get_node_or_null("Player") as Node3D
	var ally: Node3D = get_node_or_null("Sheila") as Node3D
	if player == null or ally == null:
		return
	var away: Vector3 = ally.global_position - player.global_position
	away.y = 0.0
	if away.length() < 0.01:
		return
	var goal: Vector3 = player.global_position + away.normalized() * gap
	goal.y = ally.global_position.y
	if _corner_tween != null and _corner_tween.is_valid():
		_corner_tween.kill()
	_corner_tween = create_tween()
	_corner_tween.tween_property(ally, "global_position", goal, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func sheila_gap() -> float:
	var player: Node3D = get_node_or_null("Player") as Node3D
	var ally: Node3D = get_node_or_null("Sheila") as Node3D
	if player == null or ally == null:
		return INF
	return _flat(player.global_position, ally.global_position)


## 對話講完／跳過：日記多一條「轉角的衣領」→ ch3.corner_talked → 第 3 章完成（ch3.complete，自動存檔）→ 幾秒後結尾卡 → 回標題。
func _on_corner_end() -> void:
	_use_corner_camera(false)
	var ally: Sheila = get_node_or_null("Sheila") as Sheila
	if ally != null:
		ally.leader = get_node_or_null("Player") as Node3D
		if _sheila_follow_dist > 0.0:
			ally.brain.follow_dist = _sheila_follow_dist
	if bool(Game.session.state.get_flag("ch3.corner_talked", false)):
		return
	Game.session.set_flag("ch3.corner_talked", true)
	_end_card_wait = END_CARD_DELAY


## 結尾卡（重用章節卡）：「第一部　死去的攻略」「前半　完」→「感謝試玩」一頁 → 回標題（end_card_done 測試會換掉）。
func play_end_card() -> ChapterCard:
	_end_card_wait = -1.0
	if end_card_shown:
		return get_node_or_null("ChapterCard") as ChapterCard
	end_card_shown = true
	_start_part_end_music()
	return ChapterCard.play(self, "PART1_END_NUMBER", "PART1_END_TITLE", show_thanks, END_CARD_SCALE)


## 第一部前半的收尾配樂（D-188）：結尾卡一出來就慢慢漲起來，一路墊到感謝試玩頁；乾運河的低風同時壓下去。
## 照 03「配樂放在哪裡」：說完、安靜下來的地方才放。
func _start_part_end_music() -> void:
	if part_end_music != null:
		return
	part_end_music = Ambience.music(self, PART_END_MUSIC, PART_END_MUSIC_DB, PART_END_MUSIC_FADE, "PartEndMusic")
	var wind: AudioStreamPlayer = get_node_or_null("Ambience") as AudioStreamPlayer
	if wind != null:
		wind.create_tween().tween_property(wind, "volume_db", PART_END_AMBIENCE_DB, PART_END_MUSIC_FADE)


## 「感謝試玩」一頁（D-176）：結尾卡播完（或跳過）之後蓋在全黑上；關掉 → end_card_done（空的＝回標題）。
## 諾恩停住（黑幕底下不會被按鍵推著走、不會跳出互動提示）。
func show_thanks() -> ThanksPage:
	var old: ThanksPage = get_node_or_null("ThanksPage") as ThanksPage
	if old != null:
		return old
	var player: Node = get_node_or_null("Player")
	if player != null:
		player.process_mode = Node.PROCESS_MODE_DISABLED
	var done: Callable = end_card_done if end_card_done.is_valid() else Game.back_to_title
	return ThanksPage.show_on(self, Game.session.state, done)


## 截圖用：轉角的對話推到她抓住領口那一句。
func _dev_corner_to_collar() -> void:
	talk_corner()
	var runner: DialogueRunner = Game.dialogue
	if runner == null:
		return
	for i: int in 12:
		if not runner.is_running() or runner.current_text() == COLLAR_LINE:
			break
		if not runner.visible_choices.is_empty():
			runner.choose(0)
		else:
			runner.advance()
	if _corner_tween != null and _corner_tween.is_valid():
		_corner_tween.custom_step(1.0)


## 截圖用：結尾卡停在字完整出現。
func _dev_end_card() -> void:
	var card: ChapterCard = play_end_card()
	if card != null:
		card.hold_still()


## 截圖用：結尾卡直接播完，停在「感謝試玩」完全淡入。
func _dev_thanks() -> void:
	var card: ChapterCard = play_end_card()
	if card != null:
		card.finish()
	var page: ThanksPage = get_node_or_null("ThanksPage") as ThanksPage
	if page != null:
		page.hold_still()


## 畫面黑一下再亮回來（摔進泥裡的那一下）。
func _cut_black(seconds: float) -> void:
	var old: Node = get_node_or_null("CutFade")
	if old != null:
		old.free()
	var layer := CanvasLayer.new()
	layer.name = "CutFade"
	layer.layer = 5
	var rect := ColorRect.new()
	rect.color = Color.BLACK
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	add_child(layer)
	var tw: Tween = layer.create_tween()
	tw.tween_interval(seconds * 0.3)
	tw.tween_property(rect, "color:a", 0.0, seconds * 0.7)
	tw.tween_callback(layer.queue_free)


## 太早／太晚：煤沒有壓住，牠甩了一下、轉向諾恩；CLIMB_DELAY 秒後爬上東岸（掙脫戰，D-169）。
func _shake_free() -> void:
	_freed = true
	follow_kind = ""
	walk_vz = 0.0
	raise_heart()
	_gait(false)
	var player: Node3D = get_node_or_null("Player") as Node3D
	if player != null:
		var to: Vector3 = player.global_position - _undertaker.global_position
		_undertaker.rotation.y = atan2(-to.x, -to.z)
	var tw := create_tween()
	tw.tween_property(_undertaker, "rotation:z", 0.22, 0.12)
	tw.tween_property(_undertaker, "rotation:z", -0.18, 0.16)
	tw.tween_property(_undertaker, "rotation:z", 0.0, 0.2)
	Sfx.play_at(self, "chain_creak", _undertaker.global_position + Vector3(0, 1.5, 0), 0.0, 0.05)


## 爬上東岸（D-169）：從河床攀上岸邊的矮牆、翻過來站在 STRUGGLE_LAND_X 那條線上（沿運河照牠所在的位置，
## 離諾恩太近就往外讓開 STRUGGLE_MIN_GAP），爬完開始掙脫戰。
func _climb_out() -> void:
	if not is_inside_tree() or not _freed or climbing or struggling or struggle_won or _undertaker == null:
		return
	if Game.session.quests.stage_of(QUEST) != "coal_cart":
		return
	climbing = true
	var player: Node3D = get_node_or_null("Player") as Node3D
	var noen_z: float = player.global_position.z if player != null else ROPE_POS.z
	_climb_land = Vector3(STRUGGLE_LAND_X, 0.0, struggle_land_z(_undertaker.global_position.z, noen_z))
	var from: Vector3 = _undertaker.global_position
	_undertaker.rotation = Vector3(0.0, -PI * 0.5, 0.0)  # 面朝東（岸壁）
	var wall: Vector3 = Vector3(CANAL_HALF_W - 0.55, BED_Y + 1.6, lerpf(from.z, _climb_land.z, 0.4))
	var lip: Vector3 = Vector3(CANAL_HALF_W + 0.5, PARAPET_H + 0.25, lerpf(from.z, _climb_land.z, 0.8))
	Sfx.play_at(self, "rubble_scrape", wall, -2.0, 0.05)
	_climb_tween = create_tween()
	_climb_tween.tween_property(_undertaker, "global_position", wall, CLIMB_SEC * 0.45).set_trans(Tween.TRANS_SINE)
	_climb_tween.tween_property(_undertaker, "global_position", lip, CLIMB_SEC * 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_climb_tween.tween_callback(func() -> void: Sfx.play_at(self, "iron_clang", lip + Vector3(0, 1.0, 0), -3.0, 0.05))
	_climb_tween.tween_property(_undertaker, "global_position", _climb_land, CLIMB_SEC * 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_climb_tween.tween_callback(_begin_struggle)


## 爬上來站在哪裡（沿運河）：照牠爬的位置，離諾恩不到 STRUGGLE_MIN_GAP 就往牠那一側讓開；夾在東岸的範圍內。
static func struggle_land_z(undertaker_z: float, noen_z: float) -> float:
	var z: float = undertaker_z
	if absf(z - noen_z) < STRUGGLE_MIN_GAP:
		var side: float = 1.0 if z >= noen_z else -1.0
		z = noen_z + side * STRUGGLE_MIN_GAP
	return clampf(z, Z_NORTH + 3.0, CORNER_WALL_Z - 3.0)


## 測試用：直接爬上來。
func finish_climb() -> void:
	if not climbing:
		_climb_out()
	if not climbing:
		return
	if _climb_tween != null and _climb_tween.is_valid():
		_climb_tween.kill()
	_undertaker.global_position = _climb_land
	_begin_struggle()


## 掙脫戰開始：牠變回一般的敵人（加回 enemies／damageable、自己的物理），席菈跟著打；
## Undertaker.begin_struggle()：少一招、不會進第二階段。倒下就回到 ch3_lured（不再重講對話）。
func _begin_struggle() -> void:
	if struggling or struggle_won or _undertaker == null:
		return
	climbing = false
	struggling = true
	Game.session.set_meta(RETRY_META, true)
	var player: Node3D = get_node_or_null("Player") as Node3D
	var yaw: float = _undertaker.rotation.y
	if player != null:
		var to: Vector3 = player.global_position - _undertaker.global_position
		yaw = atan2(-to.x, -to.z)
	_undertaker.rotation = Vector3.ZERO
	_undertaker.global_position.y = 0.0
	_undertaker.set_facing(yaw)
	_undertaker.add_to_group("enemies")
	_undertaker.add_to_group("damageable")
	_undertaker.process_mode = Node.PROCESS_MODE_INHERIT
	_undertaker.set_physics_process(true)
	_undertaker.velocity = Vector3.ZERO
	_undertaker.begin_struggle()
	if player is PlayerController:
		(player as PlayerController).shake(0.35)
	_banner("CH3_STRUGGLE_START", 4.5)
	_struggle_objective(true)


## 掙脫戰中 HUD 的目標換成「跟席菈一起把牠打到跪下」；打贏換回煤車那一句。
func _struggle_objective(on: bool) -> void:
	var hud: Hud = get_node_or_null("Hud") as Hud
	if hud != null:
		hud.override_objective("CH3_STRUGGLE_OBJ" if on else "")


## 掙脫戰中每物理幀：打到失衡跪下（或打掉一半的生命）就算贏。
func _update_struggle() -> void:
	if _undertaker == null:
		return
	var low: bool = _undertaker.health.hp <= CombatTuning.num("undertaker.phase2_hp", 450.0)
	if _undertaker.brain.state == EnemyBrain.State.STAGGERED or low:
		_struggle_kneel()


## 跪下了：不再是敵人（席菈停手、戰鬥 HUD 收起來）、一直跪著；停一下 → 席菈把牠撞回運河 → 回到 ch3_lured。
func _struggle_kneel() -> void:
	struggling = false
	struggle_won = true
	_undertaker.remove_from_group("enemies")
	_undertaker.remove_from_group("damageable")
	_undertaker.brain.force_kneel(60.0)
	var player: PlayerController = get_node_or_null("Player") as PlayerController
	if player != null and player.lock_target == _undertaker:
		player.lock_target = null
	Game.session.set_flag("ch3.struggle_won", true)
	_struggle_objective(false)
	_banner("CH3_STRUGGLE_KNEEL", kneel_hold_sec + push_sec + fail_retry_sec)
	var tw := create_tween()
	tw.tween_interval(maxf(kneel_hold_sec, 0.001))
	tw.tween_callback(_push_back_into_canal)


## 席菈用肩膀把牠撞回運河：翻過矮牆、摔回河床（撞地聲、鏡頭小震）→ fail_retry_sec 秒後回到 ch3_lured。
func _push_back_into_canal() -> void:
	if not is_inside_tree() or _undertaker == null:
		return
	_undertaker.set_physics_process(false)
	_undertaker.process_mode = Node.PROCESS_MODE_DISABLED
	var from: Vector3 = _undertaker.global_position
	var lip: Vector3 = Vector3(CANAL_HALF_W + 0.3, PARAPET_H + 0.6, from.z)
	var bed: Vector3 = Vector3(CANAL_HALF_W - 1.1, BED_Y, from.z)
	Sfx.play_at(self, "whoosh", from + Vector3(0, 1.2, 0), -4.0, 0.05)
	var tw := create_tween()
	tw.tween_property(_undertaker, "global_position", lip, push_sec * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_undertaker, "rotation:z", 0.5, push_sec * 0.4)
	tw.tween_property(_undertaker, "global_position", bed, push_sec * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_on_pushed_down)


func _on_pushed_down() -> void:
	Sfx.play_at(self, "blunt", _undertaker.global_position + Vector3(0, 0.4, 0), -2.0, 0.03)
	var player: PlayerController = get_node_or_null("Player") as PlayerController
	if player != null:
		player.shake(0.4)
	get_tree().create_timer(maxf(fail_retry_sec, 0.001)).timeout.connect(_struggle_retry)


## 打贏掙脫戰 → 回到段落 3 的檢查點（ch3_lured）再來一次：不再重講對話、新關卡開頭提示「煤車重新裝好了」。
## 關卡已經換掉（測試先重來）就不動。
func _struggle_retry() -> void:
	if not is_inside_tree() or not struggle_won or Game.session.quests.stage_of(QUEST) != "coal_cart":
		return
	Game.session.set_meta(RETRY_META, true)
	Game.session.set_meta(STRUGGLE_META, true)
	Game.retry()


## 煤落地揚起的黑色粉塵（柔邊圓點，D-056）：被縫裡的光照到才看得見。
func _coal_dust(at: Vector3) -> void:
	var ps := CPUParticles3D.new()
	ps.name = "CoalDust"
	ps.one_shot = true
	ps.explosiveness = 0.85
	ps.amount = 70
	ps.lifetime = 2.6
	ps.direction = Vector3.UP
	ps.spread = 80.0
	ps.initial_velocity_min = 0.8
	ps.initial_velocity_max = 3.0
	ps.gravity = Vector3(0, -0.5, 0)
	ps.damping_min = 1.2
	ps.damping_max = 2.4
	ps.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	ps.emission_box_extents = Vector3(1.3, 0.3, 1.0)
	ps.scale_amount_min = 1.0
	ps.scale_amount_max = 2.6
	var quad := QuadMesh.new()
	quad.size = Vector2(0.7, 0.7)
	quad.material = ParticleLook.material(Color(0.2, 0.19, 0.18, 0.85))
	ps.mesh = quad
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.9))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ps.color_ramp = ramp
	add_child(ps)
	ps.global_position = at
	ps.emitting = true


## 油燈晃：燈光一明一暗幾下再回來；閘道的小油燈跟著木架晃幾下。
func _sway_lamp() -> void:
	var pivot: Node3D = get_node_or_null("SluiceLampPivot") as Node3D
	if pivot != null:
		var sw := create_tween()
		for a: float in [0.32, -0.24, 0.15, -0.08]:
			sw.tween_property(pivot, "rotation:z", a, 0.32).set_trans(Tween.TRANS_SINE)
		sw.tween_property(pivot, "rotation:z", 0.0, 0.4).set_trans(Tween.TRANS_SINE)
	var l: OmniLight3D = lamp_light()
	if l == null:
		return
	var tw := create_tween()
	for k: float in [0.35, 1.25, 0.55, 1.1, 0.8]:
		tw.tween_property(l, "light_energy", LAMP_ENERGY * k, 0.14)
	tw.tween_property(l, "light_energy", LAMP_ENERGY, 0.3)


# ---------------------------------------------------------------- 場景

func _mat(color: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m


## 地底城的夜：幾乎全黑的背景、很弱的冷色環境光、體積霧（斜光切成一條條就是靠它看得到）、SSAO 開著（這裡有影子）。
func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.006, 0.008, 0.012)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.48, 0.55, 0.7)
	env.ambient_light_energy = 0.07
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_hdr_threshold = 1.0
	env.ssao_enabled = true
	env.ssao_intensity = 1.6
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.024
	env.volumetric_fog_albedo = Color(0.82, 0.86, 0.92)
	env.volumetric_fog_emission = Color(0.003, 0.004, 0.006)
	env.volumetric_fog_anisotropy = 0.55
	env.volumetric_fog_length = 64.0
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "SlitLight"
	sun.rotation_degrees = SLIT_LIGHT_ROT
	sun.light_color = SLIT_COLOR
	sun.light_energy = SLIT_LIGHT_ENERGY
	sun.light_volumetric_fog_energy = SLIT_LIGHT_FOG
	sun.shadow_enabled = true
	sun.shadow_bias = 0.04
	sun.directional_shadow_max_distance = 60.0
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(sun)


## 一顆煤塊（D-195）：CoalPile 的不規則八面體，取代原本的小方塊
func _coal_lump(node_name: String, size: float, pos: Vector3, seed: float, mat: Material, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = CoalPile.lump_mesh(size, seed)
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


## 河床上的一塊碎石（D-198）：CoalPile.lump_mesh 的形狀（半徑 DEBRIS_LUMP_R）、照原本方塊的大小縮放、
## 平面著色；材質是泡過水的牆石色（不用方石 shader：小石塊上會畫出灰縫，像一截磚牆）。不擋人。
func _debris_stone(node_name: String, size: Vector3, pos: Vector3, seed: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = CoalPile.lump_mesh(DEBRIS_LUMP_R, seed)
	mi.scale = size
	mi.material_override = debris_stone_mat()
	mi.position = pos
	add_child(mi)
	return mi


func _solid(node_name: String, size: Vector3, pos: Vector3, mat: Material, collide: bool = true, parent: Node3D = null) -> MeshInstance3D:
	var host: Node3D = parent if parent != null else self
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	host.add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		body.name = node_name + "Body"
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		cs.shape = box
		body.add_child(cs)
		body.position = pos
		host.add_child(body)
	return mi


func _blocker(node_name: String, size: Vector3, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	body.add_child(cs)
	body.position = pos
	add_child(body)


# ---------------------------------------------------------------- 材質（第 55 輪，D-173）

const WALL_STONE: Color = Color(0.3, 0.29, 0.275)
const WALL_MORTAR: Color = Color(0.07, 0.066, 0.062)
## 河道牆上的舊水位線（離河床多高）：線下暗、偏綠灰、往下一道道水痕
const TIDE_Y: float = BED_Y + 2.3
const BANK_TOP_T: float = 0.06
const MUD_DRY: Color = Color(0.17, 0.142, 0.118)
const DECK_WOOD: Color = Color(0.23, 0.175, 0.12)
## 河床碎石（D-198）：牆石 × 舊水位線下的偏綠灰（0.56, 0.6, 0.54）再亮一點（斷面）
const DEBRIS_STONE: Color = Color(0.21, 0.212, 0.188)
## 碎石的多面體半徑（CoalPile.lump_mesh）：乘上原本方塊的大小，跟救援點的碎石同一個比例（D-197）
const DEBRIS_LUMP_R: float = 0.85
## 碎石形狀的種子（不用 _rng，免得改掉後面的配置）
const DEBRIS_SEED: float = 41.0


## 河道牆：大方石（一排約 0.6 m）、深灰縫、舊水位線。閘道的矮石牆、橋墩也用這個。
func canal_wall_mat() -> ShaderMaterial:
	return interior.wall("canal_wall", WALL_STONE, WALL_STONE, 99.0, {
		"block_scale": 1.7, "mortar_color": WALL_MORTAR, "soot": 0.0,
		"tide_amount": 1.0, "tide_y": TIDE_Y,
	})


## 最外側的高牆與南北兩端：很大、很粗的暗色石塊（一排約 1.2 m），只有縫裡的光掃過的地方看得出來。
func outer_wall_mat() -> ShaderMaterial:
	return interior.wall("canal_outer", ROCK * 1.5, ROCK * 1.5, 99.0, {
		"block_scale": 3.3, "mortar_color": Color(0.035, 0.035, 0.04), "soot": 0.0,
	})


## 岸頂：沿著運河鋪的石板，常走的地方磨亮一點。
func bank_top_mat() -> ShaderMaterial:
	return interior.flagstone("canal_bank", Color(0.25, 0.24, 0.23), 0.75, {"along_z": true, "wear": 0.35, "seam_dark": 0.72})


## 壓頂石、矮牆、橋欄：比牆石淺一點的整塊條石（沿運河一塊塊接起來）。
func coping_mat() -> ShaderMaterial:
	return interior.flagstone("canal_coping", Color(0.4, 0.385, 0.36), 0.5, {"along_z": true, "seam_dark": 0.8, "base_roughness": 0.8})


## 河床：龜裂的乾泥＋中間一條還沒乾的濕泥（跟水窪同一條）。
func bed_mat() -> ShaderMaterial:
	var key: String = "canal_bed"
	if _bed_mat == null:
		_bed_mat = ShaderMaterial.new()
		_bed_mat.shader = load(DRY_MUD_SHADER) as Shader
		_bed_mat.set_shader_parameter("mud_color", MUD_DRY)
		_bed_mat.set_shader_parameter("wet_x", PUDDLE_X)
		_bed_mat.set_shader_parameter("wet_half", 1.05)
		_bed_mat.resource_name = key
	return _bed_mat


## 河床上的碎石（D-198）：河道牆的石頭泡過水（照 half_timber 舊水位線以下的偏綠灰），斷面比牆面亮一點；很粗糙。
func debris_stone_mat() -> StandardMaterial3D:
	if _debris_mat == null:
		_debris_mat = StandardMaterial3D.new()
		_debris_mat.albedo_color = DEBRIS_STONE
		_debris_mat.roughness = 0.93
		_debris_mat.resource_name = "canal_debris_stone"
	return _debris_mat


## 木架、吊樑：整根舊木頭。
func timber_mat() -> ShaderMaterial:
	return interior.timber(WOOD, 0.88)


## 煤車底下的木板、拉起來的木閘門、車身：一片片木板。
func deck_mat() -> ShaderMaterial:
	return interior.plank("canal_deck", DECK_WOOD, 0.22, 2.4, {"seam_dark": 0.85, "base_roughness": 0.86})


func cart_mat() -> ShaderMaterial:
	return interior.plank("canal_cart", Color(0.2, 0.155, 0.11), 0.125, 1.2, {"seam_dark": 0.9, "base_roughness": 0.84})


## 段落 5 三個人摔下來的那一片泥（東岸 MUD_SPOTS 一帶）：不規則的一大片＋幾滴濺出去的小泥點，
## 用河床同一個 shader 但整片是濕的（暗、亮）；平的扇形 mesh 貼在石板上 1 cm。一開始就在（地底到處是爛泥）。
const MUD_PATCH_CENTER: Vector3 = Vector3(5.25, 0.0, SLUICE_Z + 3.0)
const MUD_PATCH_RADIUS: Vector2 = Vector2(1.35, 0.95)
const MUD_PATCH_LIFT: float = 0.01


func _build_mud_patch() -> void:
	var m := ShaderMaterial.new()
	m.shader = load(DRY_MUD_SHADER) as Shader
	m.set_shader_parameter("mud_color", Color(0.22, 0.17, 0.125))
	m.set_shader_parameter("wet_x", MUD_PATCH_CENTER.x)
	m.set_shader_parameter("wet_half", 9.0)
	var root := Node3D.new()
	root.name = "MudPatch"
	root.position = MUD_PATCH_CENTER + Vector3(0.0, MUD_PATCH_LIFT, 0.0)
	add_child(root)
	var main := MeshInstance3D.new()
	main.name = "Main"
	main.mesh = mud_blob_mesh(MUD_PATCH_RADIUS, 7)
	main.material_override = m
	main.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(main)
	for i: int in 6:
		var a: float = i * TAU / 6.0 + 0.4 * sin(i * 3.1)
		var d: float = 1.0 + 0.25 * float(i % 3)
		var splat := MeshInstance3D.new()
		splat.name = "Splat%d" % i
		var r: float = 0.09 + 0.05 * float((i * 7) % 3)
		splat.mesh = mud_blob_mesh(Vector2(r, r * 0.8), 20 + i)
		splat.material_override = m
		splat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		splat.position = Vector3(cos(a) * MUD_PATCH_RADIUS.x * d, 0.0, sin(a) * MUD_PATCH_RADIUS.y * d)
		root.add_child(splat)


## 不規則的扁平泥塊（XZ 平面、朝上）：半徑 radius（x、z），邊緣用幾個正弦疊出凹凸；seed 換形狀。
static func mud_blob_mesh(radius: Vector2, seed_i: int) -> ArrayMesh:
	var n: int = 28
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var rim: PackedVector3Array = []
	for i: int in n:
		var a: float = float(i) / float(n) * TAU
		var k: float = 1.0 + 0.16 * sin(a * 3.0 + seed_i * 1.7) + 0.09 * sin(a * 7.0 + seed_i * 0.9) + 0.05 * sin(a * 13.0 + seed_i * 2.3)
		rim.append(Vector3(cos(a) * radius.x * k, 0.0, sin(a) * radius.y * k))
	for i: int in n:
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3.ZERO)
		st.set_normal(Vector3.UP)
		st.add_vertex(rim[i])
		st.set_normal(Vector3.UP)
		st.add_vertex(rim[(i + 1) % n])
	st.index()
	return st.commit()


## 兩岸（岸頂 y＝0）、河床（龜裂的乾泥＋中間一條還沒乾的淺水）、岸邊的壓頂石與矮牆、最外側的岩壁、南北兩端的牆。
## 岸分成看得到的兩塊：河道牆（方石，頂在 -BANK_TOP_T）＋岸頂一層石板；碰撞是一整塊。
func _build_canal() -> void:
	var length: float = Z_SOUTH - Z_NORTH
	var mid_z: float = (Z_SOUTH + Z_NORTH) * 0.5
	var rock: ShaderMaterial = outer_wall_mat()
	var bank_depth: float = -BED_Y + 0.5
	var wall_h: float = bank_depth - BANK_TOP_T
	for side: float in [-1.0, 1.0]:
		var cx: float = side * (CANAL_HALF_W + BANK_W * 0.5)
		var tag: String = "E" if side > 0.0 else "W"
		_solid("Bank" + tag, Vector3(BANK_W, wall_h, length), Vector3(cx, -BANK_TOP_T - wall_h * 0.5, mid_z), canal_wall_mat(), false)
		_blocker("Bank" + tag + "Body", Vector3(BANK_W, bank_depth, length), Vector3(cx, -bank_depth * 0.5, mid_z))
		_solid("BankTop" + tag, Vector3(BANK_W, BANK_TOP_T, length), Vector3(cx, -BANK_TOP_T * 0.5, mid_z), bank_top_mat(), false)
		_solid("Coping" + tag, Vector3(0.5, 0.12, length), Vector3(side * (CANAL_HALF_W + 0.25), 0.06, mid_z), coping_mat(), false)
		_solid("Parapet" + tag, Vector3(0.35, PARAPET_H, length), Vector3(side * (CANAL_HALF_W + 0.22), PARAPET_H * 0.5, mid_z), coping_mat(), false)
		_blocker("Parapet" + tag + "Block", Vector3(0.35, PARAPET_BLOCK_H, length), Vector3(side * (CANAL_HALF_W + 0.22), PARAPET_BLOCK_H * 0.5, mid_z))
		_solid("OuterWall" + tag, Vector3(1.0, OUTER_WALL_H - BED_Y, length + 2.0), Vector3(side * (CANAL_HALF_W + BANK_W + 0.5), (OUTER_WALL_H + BED_Y) * 0.5, mid_z), rock)
	_solid("CanalBed", Vector3(CANAL_HALF_W * 2.0, 0.4, length), Vector3(0.0, BED_Y - 0.2, mid_z), bed_mat())
	# 河床中間一條還沒乾的淺水：低粗糙度，接得到從縫裡下來的光（四周的濕泥是河床 shader 畫的）
	var water := _mat(Color(0.05, 0.055, 0.06), 0.08)
	water.metallic_specular = 0.8
	_solid("Puddle", Vector3(1.1, 0.02, length * 0.8), Vector3(PUDDLE_X, BED_Y + 0.01, mid_z - 2.0), water, false)
	# 河床上的碎石與爛木頭
	for i: int in 26:
		var size := Vector3(_rng.randf_range(0.2, 0.7), _rng.randf_range(0.1, 0.35), _rng.randf_range(0.2, 0.8))
		var p := Vector3(_rng.randf_range(-CANAL_HALF_W + 0.4, CANAL_HALF_W - 0.4), BED_Y + size.y * 0.5, _rng.randf_range(Z_NORTH + 2.0, Z_SOUTH - 2.0))
		# 掉下來的石塊：有稜角的碎石（CoalPile 的不規則多面體放大，D-198）；之前是貼著方石紋的方塊，看起來像一小截磚牆。
		# 泡爛的木頭照舊是方塊。亂數照舊每塊呼叫同樣次數（不改後面的配置）。
		var debris: MeshInstance3D
		if i % 3:
			debris = _debris_stone("Debris%d" % i, size, p, DEBRIS_SEED + 3.7 * float(i))
		else:
			debris = _solid("Debris%d" % i, size, p, timber_mat(), false)
		debris.rotation.y = _rng.randf_range(-PI, PI)
	for z: float in [Z_SOUTH + 0.5, Z_NORTH - 0.5]:
		_solid("EndWall%d" % int(z), Vector3((CANAL_HALF_W + BANK_W + 1.0) * 2.0, OUTER_WALL_H - BED_Y, 1.0), Vector3(0.0, (OUTER_WALL_H + BED_Y) * 0.5, z), rock)
	var edge := Node3D.new()
	edge.name = "BankEdge"
	edge.position = BANK_POS
	add_child(edge)


## 石橋：橋面（石板）、兩側欄杆（條石）、兩座橋墩貼在河道牆上（方石）。
func _build_bridge() -> void:
	var span: float = CANAL_HALF_W * 2.0 + 0.8
	_solid("BridgeDeck", Vector3(span, DECK_T, BRIDGE_W), Vector3(0.0, -DECK_T * 0.5, BRIDGE_Z), bank_top_mat())
	for side: float in [-1.0, 1.0]:
		_solid("BridgeRail%d" % int(side), Vector3(span, 0.7, 0.25), Vector3(0.0, 0.35, BRIDGE_Z + side * (BRIDGE_W * 0.5 - 0.125)), coping_mat())
		_solid("BridgeHaunch%d" % int(side), Vector3(0.6, 0.9, BRIDGE_W), Vector3(side * (CANAL_HALF_W - 0.3), -DECK_T - 0.45, BRIDGE_Z), canal_wall_mat(), false)


## 北邊的閘道：河道裡兩道矮石牆把河道收窄（比送葬者矮，從岸上看得到牠露出上半身）；
## 上方一座木架（兩岸各兩根立柱、兩根橫樑、樑上鋪木板），木板上停著一台堆滿煤的車，往南邊的邊緣斜著，
## 車尾一條繩子拉到東岸北側的木柱上綁著（段落 4，D-166）。拉起來的木閘門掛在北邊的橫樑下。
func _build_sluice() -> void:
	var stone: ShaderMaterial = canal_wall_mat()
	var wood: ShaderMaterial = timber_mat()
	var iron: StandardMaterial3D = _mat(IRON, 0.6)
	iron.metallic = 0.6
	for side: float in [-1.0, 1.0]:
		_solid("SluicePier%d" % int(side), Vector3(0.9, SLUICE_PIER_H, SLUICE_PIER_HALF_Z * 2.0), Vector3(side * 1.7, BED_Y + SLUICE_PIER_H * 0.5, SLUICE_Z), stone, false)
		_solid("SluiceCap%d" % int(side), Vector3(1.0, 0.12, SLUICE_PIER_HALF_Z * 2.0 + 0.1), Vector3(side * 1.7, BED_Y + SLUICE_PIER_H + 0.06, SLUICE_Z), coping_mat(), false)
		for zz: float in [SLUICE_Z + 0.1, SLUICE_Z - 1.2]:
			_solid("GantryPost%d_%d" % [int(side), int(absf(zz) * 10.0)], Vector3(0.26, GANTRY_Y, 0.26), Vector3(side * (CANAL_HALF_W + 0.22), GANTRY_Y * 0.5, zz), wood, false)
	var span: float = (CANAL_HALF_W + 0.35) * 2.0
	_solid("SluiceBeam", Vector3(span, 0.3, 0.3), Vector3(0.0, GANTRY_Y + 0.15, SLUICE_Z + 0.1), wood, false)
	_solid("SluiceBeamN", Vector3(span, 0.3, 0.3), Vector3(0.0, GANTRY_Y + 0.15, SLUICE_Z - 1.2), wood, false)
	_solid("CartDeck", Vector3(2.2, 0.08, 1.6), Vector3(SLUICE_PASS_X, GANTRY_Y + 0.34, SLUICE_Z - 0.55), deck_mat(), false)
	_solid("SluiceGate", Vector3(2.5, 1.2, 0.12), Vector3(0.0, GANTRY_Y - 0.6, SLUICE_Z - 1.4), deck_mat(), false)
	# 煤車：轉軸在木板南緣（往南傾倒），車身在轉軸北邊；一開始就微微往南斜，靠繩子拉住
	var deck_top: float = GANTRY_Y + 0.38
	_cart = Node3D.new()
	_cart.name = "CoalCart"
	_cart.position = Vector3(SLUICE_PASS_X, deck_top, SLUICE_Z + 0.2)
	_cart.rotation.x = 0.1
	add_child(_cart)
	_solid("CartBody", Vector3(1.0, 0.5, 0.9), Vector3(0.0, 0.42, -0.5), cart_mat(), false, _cart)
	_solid("CartBand", Vector3(1.04, 0.06, 0.94), Vector3(0.0, 0.62, -0.5), iron, false, _cart)
	var heap_mat: StandardMaterial3D = CoalPile.material()
	# 車裡堆得冒出車沿的煤（D-195）：小一號的 CoalPile，外圈埋在車身裡（原本是一塊平的黑方塊）
	var cart_coal := MeshInstance3D.new()
	cart_coal.name = "CartCoal"
	cart_coal.mesh = CoalPile.build(CART_COAL_SIZE.x, CART_COAL_SIZE.z, CART_COAL_SIZE.y, COAL_HEAP_SEED + 3.0)
	cart_coal.material_override = heap_mat
	cart_coal.position = Vector3(0.0, 0.64, -0.5)
	_cart.add_child(cart_coal)
	for i: int in 6:
		_coal_lump("CartLump%d" % i, 0.12, Vector3(-0.32 + 0.13 * i, 0.86 + 0.04 * (i % 2), -0.5 + 0.18 * sin(i * 1.7)), 3.0 + i, heap_mat, _cart)
	for wx: float in [-0.42, 0.42]:
		for wz: float in [-0.15, -0.85]:
			var wheel := MeshInstance3D.new()
			wheel.name = "CartWheel"
			var wm := CylinderMesh.new()
			wm.top_radius = 0.13
			wm.bottom_radius = 0.13
			wm.height = 0.06
			wheel.mesh = wm
			wheel.material_override = iron
			wheel.position = Vector3(wx * 1.12, 0.13, wz)
			wheel.rotation.z = PI * 0.5
			_cart.add_child(wheel)
	# 繩子：車尾 → 東岸北側木柱上的繩樁
	var tail: Vector3 = _cart.position + Vector3(0.3, 0.55, -0.95)
	var cleat: Vector3 = Vector3(CANAL_HALF_W + 0.22, 1.05, ROPE_POS.z)
	_cart_rope = _line_between("CartRopeLine", tail, cleat, 0.014, _mat(Color(0.42, 0.36, 0.26), 1.0))
	_solid("RopeCleat", Vector3(0.1, 0.1, 0.3), cleat, iron, false)
	# 倒下去的煤：落下途中的一團（補間）＋落地之後的煤堆
	_coal_mass = Node3D.new()
	_coal_mass.name = "CoalMass"
	_coal_mass.visible = false
	add_child(_coal_mass)
	for i: int in 7:
		_coal_lump("Chunk%d" % i, 0.26 * (0.7 + 0.12 * (i % 3)), Vector3(0.35 * sin(i * 2.1), 0.3 * cos(i * 1.3), 0.3 * cos(i * 2.7)), 11.0 + i, heap_mat, _coal_mass)
	_coal_heap = Node3D.new()
	_coal_heap.name = "CoalHeap"
	_coal_heap.visible = false
	add_child(_coal_heap)
	# 一堆倒出來的煤（D-195）：錐形高度場＋塊狀起伏、平面著色（一塊塊切面各自反光）、散落的小煤塊
	var mound := MeshInstance3D.new()
	mound.name = "Mound"
	mound.mesh = CoalPile.build(COAL_HEAP_SIZE.x, COAL_HEAP_SIZE.z, COAL_HEAP_SIZE.y, COAL_HEAP_SEED)
	mound.material_override = heap_mat
	_coal_heap.add_child(mound)
	# 正好有一道縫的光落在煤車正下方（跟斜光同一個方向的窄聚光）：陷阱在哪裡一眼看得到，牠走進去時也被照亮
	var spot := SpotLight3D.new()
	spot.name = "SlitOnSluice"
	spot.light_color = SLIT_COLOR
	spot.light_energy = SLIT_SPOT_ENERGY * 0.8
	spot.light_volumetric_fog_energy = 1.0
	spot.spot_range = 12.0
	spot.spot_angle = 14.0
	spot.shadow_enabled = false
	var sluice_target: Vector3 = Vector3(SLUICE_PASS_X, BED_Y + 1.2, CART_Z + 0.3)
	var slit_dir: Vector3 = Basis.from_euler(SLIT_LIGHT_ROT * PI / 180.0) * Vector3.FORWARD
	add_child(spot)
	spot.look_at_from_position(sluice_target - slit_dir * 8.0, sluice_target)
	# 目標指引：假心臟在手上 → 指向閘道另一邊的點；垂下去了 → 指向繩子
	_task_heart = MarkerPoint.new()
	_task_heart.name = "CartTaskHeart"
	_task_heart.query = "heart"
	_task_heart.level = self
	_task_heart.position = Vector3(DECOY_BANK_X, 0.0, DECOY_ZS[3])
	add_child(_task_heart)
	_task_rope = MarkerPoint.new()
	_task_rope.name = "CartTaskRope"
	_task_rope.query = "rope"
	_task_rope.level = self
	_task_rope.position = ROPE_POS
	add_child(_task_rope)


## 兩點之間的一條細圓柱（繩子）。
func _line_between(node_name: String, a: Vector3, b: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = a.distance_to(b)
	mi.mesh = cm
	mi.material_override = mat
	add_child(mi)
	mi.global_position = (a + b) * 0.5
	var up: Vector3 = (b - a).normalized()
	var side: Vector3 = up.cross(Vector3.FORWARD)
	if side.length() < 0.01:
		side = up.cross(Vector3.RIGHT)
	side = side.normalized()
	mi.global_basis = Basis(side, up, side.cross(up)).orthonormalized()
	return mi


## 頭頂的石樑：一排排橫跨整個運河（含兩岸），之間留縫——鐘院的光從縫裡透下來。
func _build_ceiling() -> void:
	var rock: ShaderMaterial = outer_wall_mat()
	var width: float = (CANAL_HALF_W + BANK_W + 1.0) * 2.0
	var depth: float = SLAT_PITCH - SLAT_GAP
	var ceiling := Node3D.new()
	ceiling.name = "CeilingSlats"
	add_child(ceiling)
	var i: int = 0
	var z: float = Z_SOUTH + 1.0
	while z > Z_NORTH - 1.0:
		_solid("Slat%d" % i, Vector3(width, 1.2, depth), Vector3(0.0, SLAT_Y + 0.6, z - depth * 0.5), rock, false, ceiling)
		z -= SLAT_PITCH
		i += 1


## 掛著的送葬者：重用 Undertaker 的外觀，但不動、不打、不在敵人名單裡（段落 2 才醒）。
## 兩條鐵鏈從鐵架掛到吊樑；整個掛點慢慢晃。胸口一點銅光＝鐘舌（像心跳一樣亮）。
func _build_undertaker() -> void:
	var wood: ShaderMaterial = timber_mat()
	_solid("HangBeam", Vector3(CANAL_HALF_W * 2.0 + 1.4, 0.32, 0.36), Vector3(0.0, BEAM_Y + 0.16, HANG_Z), wood, false)
	for side: float in [-1.0, 1.0]:
		_solid("HangBeamPost%d" % int(side), Vector3(0.3, BEAM_Y - PARAPET_H, 0.3), Vector3(side * (CANAL_HALF_W + 0.22), PARAPET_H + (BEAM_Y - PARAPET_H) * 0.5, HANG_Z), wood, false)
	_pivot = Node3D.new()
	_pivot.name = "HangPivot"
	_pivot.position = Vector3(HANG_X, BEAM_Y, HANG_Z)
	add_child(_pivot)
	var u := Undertaker.new()
	u.name = "ClapperUndertaker"
	# 鐵架頂（約 2.6 m）掛在鏈子下；腳懸在河床上方三公尺多
	u.position = Vector3(0.0, -CHAIN_LEN - 2.6, 0.0)
	# 面朝東南（從東岸的說話點看得到胸口）
	u.rotation.y = atan2(-0.55, -0.83)
	_pivot.add_child(u)
	u.remove_from_group("enemies")
	u.remove_from_group("damageable")
	u.process_mode = Node.PROCESS_MODE_DISABLED
	u.set_physics_process(false)
	_undertaker = u
	var iron: StandardMaterial3D = _mat(IRON, 0.6)
	iron.metallic = 0.7
	for side: float in [-1.0, 1.0]:
		var chain := MeshInstance3D.new()
		chain.name = "Chain%d" % int(side)
		var cm := CylinderMesh.new()
		cm.top_radius = 0.035
		cm.bottom_radius = 0.035
		cm.height = CHAIN_LEN + 0.15
		chain.mesh = cm
		chain.material_override = iron
		chain.position = Vector3(side * 0.42, -(CHAIN_LEN + 0.15) * 0.5, 0.15)
		_pivot.add_child(chain)
	# 鐘舌：一根短短的銅棒斜插在胸口，自己會發光；旁邊一盞小小的銅色點光（不投影子）
	_clapper_mat = StandardMaterial3D.new()
	_clapper_mat.albedo_color = Color(0.55, 0.32, 0.16)
	_clapper_mat.metallic = 0.8
	_clapper_mat.roughness = 0.35
	_clapper_mat.emission_enabled = true
	_clapper_mat.emission = COPPER
	_clapper_mat.emission_energy_multiplier = 2.0
	var rod := MeshInstance3D.new()
	rod.name = "Clapper"
	var rm := CylinderMesh.new()
	rm.top_radius = 0.035
	rm.bottom_radius = 0.07
	rm.height = 0.42
	rod.mesh = rm
	rod.material_override = _clapper_mat
	rod.position = Vector3(0.0, 1.5, -0.4)
	rod.rotation_degrees = Vector3(70.0, 0.0, 18.0)
	u.add_child(rod)
	_clapper_light = OmniLight3D.new()
	_clapper_light.name = "ClapperLight"
	_clapper_light.light_color = COPPER
	_clapper_light.light_energy = CLAPPER_ENERGY
	_clapper_light.omni_range = 2.2
	_clapper_light.shadow_enabled = false
	_clapper_light.light_volumetric_fog_energy = 0.4
	_clapper_light.position = Vector3(0.0, 1.5, -0.55)
	u.add_child(_clapper_light)
	# 正好有一道縫的光落在牠身上：跟斜光同一個方向的窄聚光（不投影子；第 45 輪截圖：只靠斜光，暗色大衣在河道裡看不出來）
	var spot := SpotLight3D.new()
	spot.name = "SlitOnUndertaker"
	spot.light_color = SLIT_COLOR
	spot.light_energy = SLIT_SPOT_ENERGY
	spot.light_volumetric_fog_energy = 1.2
	spot.spot_range = 9.0
	spot.spot_angle = 16.0
	spot.shadow_enabled = false
	var target: Vector3 = _pivot.position + Vector3(0.0, -CHAIN_LEN - 1.4, 0.0)
	var dir: Vector3 = Basis.from_euler(SLIT_LIGHT_ROT * PI / 180.0) * Vector3.FORWARD
	add_child(spot)
	spot.look_at_from_position(target - dir * 5.5, target)


# ---------------------------------------------------------------- 人：席菈、彌夏跟著

func _build_people() -> void:
	var player: Node3D = get_node_or_null("Player") as Node3D
	var from: Vector3 = player.global_position if player != null else SPAWN
	_misha = Puppet.new()
	_misha.name = "Misha"
	_misha.coat_color = Color(0.16, 0.27, 0.21)
	_misha.trim_color = Color(0.3, 0.26, 0.2)
	add_child(_misha)
	var hammer: Node = _misha.hand("R").get_node_or_null("BellHammer") if _misha.hand("R") != null else null
	if hammer != null:
		hammer.queue_free()
	_misha.global_position = from + Vector3(1.6, -0.05, -1.4)
	var ally := Sheila.new()
	ally.name = "Sheila"
	ally.position = from + Vector3(-1.0, 0.0, -1.2)
	add_child(ally)
