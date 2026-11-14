extends TestCase
## 新版（劇情重寫）的狀態邏輯：生命的三種變化、中毒開始／刷新／結束、反轉欄位、可攜藥劑。


func _rules() -> StatusRules:
	var r: StatusRules = StatusRules.load_default()
	assert_true(r.errors.is_empty(), "狀態資料沒有錯：%s" % ", ".join(r.errors))
	return r


func _hurt(hp: float) -> Health:
	var h := Health.new(100.0)
	h.hp = hp
	return h


func test_health_keeps_damage_status_damage_and_heal_apart() -> void:
	var h := _hurt(50.0)
	var log: Array[String] = []
	h.damaged.connect(func(_a: float, _i: Dictionary) -> void: log.append("damaged"))
	h.status_damaged.connect(func(_a: float, _i: Dictionary) -> void: log.append("status"))
	h.healed.connect(func(_a: float, _i: Dictionary) -> void: log.append("healed"))
	h.invulnerable_check = func() -> bool: return true
	assert_false(h.apply_damage(10.0), "閃避無敵擋得住直接傷害")
	assert_eq(h.apply_status_damage(5.0), 5.0, "狀態傷害不被閃避擋")
	assert_eq(h.heal(20.0), 20.0)
	assert_eq(h.heal(100.0), 35.0, "治療不超過上限，回傳實際補到的量")
	assert_eq(h.heal(5.0), 0.0, "滿血再補是 0")
	assert_eq(log, ["status", "healed", "healed"], "狀態傷害、治療各有自己的訊號，不發 damaged")
	assert_false(h.apply_damage(-10.0), "負數傷害不會變成治療")
	assert_eq(h.hp, 100.0)


func test_heal_does_not_revive() -> void:
	var h := _hurt(0.0)
	assert_eq(h.heal(30.0), 0.0, "死了不能補")
	assert_true(h.is_dead())


func test_poison_without_reversal_hurts() -> void:
	var fx := StatusEffects.new(_rules(), null)
	var h := _hurt(50.0)
	assert_eq(fx.apply("poison", 6.0, 4.0, "miasma"), "start")
	fx.tick(1.0, h)
	assert_true(absf(h.hp - 44.0) < 0.001, "沒有反轉（NPC）照常掉血")


func test_first_poison_awakens_reversal_and_heals_from_first_frame() -> void:
	var rev := ReversalSlots.new()
	var fx := StatusEffects.new(_rules(), rev)
	var awakened: Array[String] = []
	rev.awakened.connect(func(id: String) -> void: awakened.append(id))
	var h := _hurt(55.0)
	var took_damage: Array[bool] = [false]
	h.status_damaged.connect(func(_a: float, _i: Dictionary) -> void: took_damage[0] = true)
	fx.apply_source("miasma")
	assert_eq(awakened, ["poison"], "第一次中毒自動覺醒")
	assert_true(rev.is_reversed("poison"))
	assert_eq(rev.equipped[0], "poison", "裝進第一格")
	assert_eq(rev.free_slots(), 1, "第二格空著")
	fx.tick(0.5, h)
	assert_true(absf(h.hp - 58.0) < 0.001, "6／秒 × 0.5 秒＝回 3")
	assert_false(took_damage[0], "反轉發生在扣血之前：不會先扣一次再補回")
	fx.apply_source("miasma")
	assert_eq(awakened.size(), 1, "覺醒只發生一次")


func test_poison_refresh_does_not_stack() -> void:
	var fx := StatusEffects.new(_rules(), null)
	var events: Array[String] = []
	fx.changed.connect(func(_id: String, e: String) -> void: events.append(e))
	fx.apply("poison", 3.0, 20.0, "sera_poison_vial")
	assert_eq(fx.apply("poison", 3.0, 20.0, "sera_poison_vial"), "refresh")
	assert_eq(fx.rate("poison"), 3.0, "同強度不疊加")
	assert_eq(fx.remaining("poison"), 20.0, "時間取較長者，不相加")
	fx.apply("poison", 8.0, 3.0, "boss_miasma")
	assert_eq(fx.rate("poison"), 8.0, "比較強的來源換掉強度")
	assert_eq(fx.source_of("poison"), "boss_miasma")
	assert_eq(fx.remaining("poison"), 20.0, "時間不會被比較短的縮短")
	fx.apply("poison", 1.0, 25.0, "x")
	assert_eq(fx.rate("poison"), 8.0, "比較弱的不會降強度")
	for i: int in 10:
		fx.apply("poison", 3.0, 20.0, "sera_poison_vial")
	assert_true(fx.remaining("poison") <= 30.0, "最長 30 秒：喝一百瓶也不會永久")
	fx.apply("poison", 3.0, 999.0, "x")
	assert_eq(fx.remaining("poison"), 30.0)
	assert_eq(fx.ids().size(), 1, "同一種只有一份")
	assert_eq(events[0], "start")


func test_poison_ends_and_regen_stops() -> void:
	var rev := ReversalSlots.new()
	var fx := StatusEffects.new(_rules(), rev)
	var events: Array[String] = []
	fx.changed.connect(func(_id: String, e: String) -> void: events.append(e))
	var h := _hurt(50.0)
	fx.apply_source("miasma")  # 6／秒、4 秒
	for i: int in 50:
		fx.tick(0.1, h)
	assert_false(fx.has("poison"), "4 秒後結束")
	assert_eq(events, ["start", "end"])
	assert_true(absf(h.hp - 74.0) < 0.01, "只回 4 秒份（24），之後停：%s" % h.hp)
	fx.tick(1.0, h)
	assert_true(absf(h.hp - 74.0) < 0.01, "結束後不再回血")


func test_reversed_regen_is_capped() -> void:
	var rev := ReversalSlots.new()
	var fx := StatusEffects.new(_rules(), rev)
	var h := _hurt(10.0)
	fx.apply("poison", 50.0, 2.0, "boss")
	fx.tick(1.0, h)
	assert_true(absf(h.hp - 18.0) < 0.001, "反轉回血最多 8／秒（特殊敵技再強也一樣）")


func test_regen_cannot_outheal_standing_in_combos() -> void:
	# 守衛噴毒 8／秒；橫掃 28、約 2 秒一輪（tuning.json）＝站著吃會輸
	var rev := ReversalSlots.new()
	rev.on_status_applied("poison")
	var fx := StatusEffects.new(_rules(), rev)
	var h := _hurt(100.0)
	var sweep: float = CombatTuning.num("undertaker.moves.sweep.damage", 28.0)
	for round_i: int in 3:
		fx.apply_source("boss_miasma")
		h.apply_damage(sweep)
		fx.tick(2.0, h)
	assert_true(h.hp < 100.0 - 20.0, "三輪站著吃還是一路往下掉：%s" % h.hp)


func test_tick_zero_is_paused() -> void:
	var fx := StatusEffects.new(_rules(), null)
	var h := _hurt(50.0)
	fx.apply("poison", 6.0, 4.0)
	fx.tick(0.0, h)
	assert_eq(fx.remaining("poison"), 4.0, "暫停（沒有推進時間）不計時")
	assert_eq(h.hp, 50.0)


func test_unknown_status_and_bad_values_ignored() -> void:
	var fx := StatusEffects.new(_rules(), ReversalSlots.new())
	assert_eq(fx.apply("time_stop", 1.0, 1.0), "ignored", "還沒定義的狀態不上身")
	assert_eq(fx.apply("poison", 0.0, 4.0), "ignored")
	assert_eq(fx.apply("poison", 3.0, -1.0), "ignored")
	assert_eq(fx.apply_source("nope"), "ignored")
	assert_false(fx.reversal.awakened_once, "沒有真的中毒就不會覺醒")


func test_status_save_round_trip_keeps_negative_effects() -> void:
	var rev := ReversalSlots.new()
	var fx := StatusEffects.new(_rules(), rev)
	fx.apply("poison", 3.0, 20.0, "sera_poison_vial")
	fx.tick(5.0, null)
	var again := StatusEffects.new(_rules(), ReversalSlots.from_dict(rev.to_dict()))
	again.load_array(fx.to_array())
	assert_eq(again.remaining("poison"), 15.0, "讀檔照原樣：不清掉、不補滿時間")
	assert_eq(again.source_of("poison"), "sera_poison_vial")
	assert_true(again.is_reversed("poison"))
	again.load_array([{"id": "poison", "rate": 3.0, "remaining": 999.0}, {"id": "ghost", "rate": 1, "remaining": 5}, "junk"])
	assert_eq(again.remaining("poison"), 30.0, "壞值夾到上限")
	assert_eq(again.ids().size(), 1, "不認得的略過")


func test_reversal_slots_rules() -> void:
	var rev := ReversalSlots.new()
	assert_eq(rev.equipped.size(), 2, "開場兩格")
	assert_false(rev.equip("poison"), "沒解鎖不能裝")
	assert_false(rev.on_status_applied("paralysis"), "只有中毒會自動覺醒")
	assert_true(rev.on_status_applied("poison"))
	assert_false(rev.equip("poison"), "同一種不能裝兩格")
	var loaded: ReversalSlots = ReversalSlots.from_dict({"slots": 2, "unlocked": ["poison"], "equipped": ["poison", "poison", "x"], "awakened_once": true})
	assert_eq(Array(loaded.equipped), ["poison", ""], "壞檔：重複、多出來的、沒解鎖的都不裝")
	assert_true(loaded.awakened_once)


func test_potion_belt_grant_once_and_use() -> void:
	var state := GameState.new()
	var belt := PotionBelt.new(state, _rules())
	var rev := ReversalSlots.new()
	rev.on_status_applied("poison")
	var fx := StatusEffects.new(_rules(), rev)
	assert_true(belt.grant_once("ch1.guardian_crate", "sera_poison_vial", 2))
	assert_false(belt.grant_once("ch1.guardian_crate", "sera_poison_vial", 2), "同一個藥箱只給一次")
	assert_eq(belt.count("sera_poison_vial"), 2)
	var full := Health.new(100.0)
	assert_eq(belt.use("sera_poison_vial", fx, full), "confirm_full", "滿血先問，不直接喝")
	assert_eq(belt.count("sera_poison_vial"), 2, "問的時候沒扣")
	assert_false(fx.has("poison"))
	var hurt := _hurt(60.0)
	assert_eq(belt.use("sera_poison_vial", fx, hurt), "used")
	assert_eq(belt.count("sera_poison_vial"), 1)
	assert_eq(fx.remaining("poison"), 20.0, "霧蛇毒劑：中毒 20 秒")
	fx.tick(1.0, hurt)
	assert_true(absf(hurt.hp - 63.0) < 0.001, "喝下去確實回血（3／秒）")
	assert_eq(belt.use("sera_poison_vial", fx, full, true), "used", "滿血選「還是要喝」可以喝")
	assert_eq(belt.use("sera_poison_vial", fx, hurt), "none_left")
	assert_eq(belt.use("not_a_potion", fx, hurt), "unknown")
	var reloaded: GameState = SaveCodec.decode(SaveCodec.encode(state))["state"]
	assert_eq(PotionBelt.new(reloaded, _rules()).count("sera_poison_vial"), 0, "數量跟著存檔")
	assert_false(PotionBelt.new(reloaded, _rules()).grant_once("ch1.guardian_crate", "sera_poison_vial", 2), "讀檔後也不會重複領")


## 麻痺：不碰生命。沒反轉＝這段時間不能出手；時間到就恢復。
func test_paralysis_without_reversal_blocks_attacks_but_never_touches_health() -> void:
	var fx := StatusEffects.new(_rules(), null)
	var h := _hurt(50.0)
	assert_eq(_rules().kind("paralysis"), "action")
	assert_eq(_rules().kind("poison"), "dot")
	assert_eq(fx.apply_source("sera_paralysis_vial"), "start")
	assert_true(fx.has("paralysis"))
	assert_true(fx.blocks_attack(), "沒反轉：不能出手")
	assert_eq(fx.attack_speed(), 1.0, "沒反轉不會變快")
	fx.tick(3.0, h)
	assert_eq(h.hp, 50.0, "麻痺不扣血也不回血")
	fx.tick(float(_rules().source("sera_paralysis_vial")["duration"]), h)
	assert_false(fx.has("paralysis"), "時間到就退")
	assert_false(fx.blocks_attack())
	assert_eq(h.hp, 50.0)


## 麻痺裝進第二格：出手加速，有上限；同一種只有一份，怎麼疊都不會更快、時間不超過上限；中毒照舊回血，兩格互不影響。
func test_reversed_paralysis_speeds_attacks_with_a_cap_and_does_not_stack() -> void:
	var slots := ReversalSlots.new()
	var fx := StatusEffects.new(_rules(), slots)
	var h := _hurt(50.0)
	fx.apply_source("miasma")
	assert_eq(slots.equipped[0], "poison", "第一次中毒：第一格")
	assert_eq(slots.equipped[1], "", "第二格開場是空的")
	# 沒解鎖不能裝；第一次麻痺不會像中毒那樣自動覺醒
	assert_false(slots.equip("paralysis"), "沒解鎖不能裝")
	fx.apply_source("sera_paralysis_vial")
	assert_false(slots.unlocked.has("paralysis"), "麻痺不會自動解鎖（開場的中毒是唯一的特例）")
	assert_true(fx.blocks_attack())
	# 安全測試之後解鎖、裝進第二格
	slots.unlock("paralysis")
	assert_true(slots.equip("paralysis"))
	assert_eq(slots.equipped[1], "paralysis")
	assert_false(slots.equip("paralysis"), "已經裝了不會再佔一格")
	assert_eq(slots.free_slots(), 0)
	assert_false(fx.blocks_attack(), "反轉了")
	assert_true(absf(fx.attack_speed() - 1.35) < 0.001, "板子的麻痺：出手 1.35 倍")
	# 同一來源再來十次：還是一份、一樣快、時間不超過上限
	for i: int in 10:
		assert_eq(fx.apply_source("sera_paralysis_vial"), "refresh")
	assert_eq(fx.ids().size(), 2, "一個中毒＋一個麻痺")
	assert_true(absf(fx.attack_speed() - 1.35) < 0.001, "不會越疊越快")
	assert_true(fx.remaining("paralysis") <= _rules().max_duration("paralysis") + 0.001)
	# 很強的來源也有上限
	fx.apply("paralysis", 9.0, 999.0, "test")
	assert_true(absf(fx.attack_speed() - _rules().max_reversed_rate("paralysis")) < 0.001, "倍率有上限")
	assert_true(absf(fx.remaining("paralysis") - _rules().max_duration("paralysis")) < 0.001, "時間有上限")
	# 兩格一起：中毒照舊回血、麻痺不碰生命
	var before: float = h.hp
	fx.tick(1.0, h)
	assert_true(absf(h.hp - before - 6.0) < 0.001, "只有中毒的回血（%s）" % (h.hp - before))
	# 存檔照原樣存、讀回來還是反轉的
	var saved: Array = fx.to_array()
	var again := StatusEffects.new(_rules(), ReversalSlots.from_dict(slots.to_dict()))
	again.load_array(saved)
	assert_true(again.has("paralysis") and again.is_reversed("paralysis"))
	assert_true(again.attack_speed() > 1.0)
	# 沒有麻痺的舊存檔：兩格、第二格是空的
	var old := ReversalSlots.from_dict({"slots": 2, "unlocked": ["poison"], "equipped": ["poison"], "awakened_once": true})
	assert_eq(old.equipped.size(), 2)
	assert_eq(old.equipped[1], "")
	assert_false(old.is_reversed("paralysis"))


## 戴著護腕打中人的麻痺：每次命中只是重新計時——一份、一樣快、不超過 6 秒；停手 6 秒就退，退了之後不擋出手。
## 丟毒瓶的霧：沒反轉扣血、反轉回血，比守衛噴的淡。
func test_paralysis_on_hit_refreshes_without_stacking_and_fades_when_you_stop() -> void:
	var slots := ReversalSlots.new()
	var fx := StatusEffects.new(_rules(), slots)
	var h := _hurt(50.0)
	slots.unlock("paralysis")
	assert_true(slots.equip("paralysis", 1))
	assert_eq(fx.apply_source("paralysis_on_hit"), "start")
	assert_true(absf(fx.attack_speed() - 1.35) < 0.001)
	assert_true(absf(fx.remaining("paralysis") - 6.0) < 0.001)
	# 每 0.5 秒打中一下、連打 20 秒：一直是一份、一樣快、剩下的時間不超過 6 秒
	for i: int in 40:
		fx.tick(0.5, h)
		assert_eq(fx.apply_source("paralysis_on_hit"), "refresh")
		assert_true(fx.remaining("paralysis") <= 6.0 + 0.001)
	assert_eq(fx.ids().size(), 1, "只有一份")
	assert_true(absf(fx.attack_speed() - 1.35) < 0.001, "不會越打越快")
	assert_eq(h.hp, 50.0, "麻痺不碰生命")
	# 停手：6 秒後退掉，出手回到原本的速度，也不會擋出手
	fx.tick(5.9, h)
	assert_true(fx.has("paralysis"))
	fx.tick(0.2, h)
	assert_false(fx.has("paralysis"), "停手 6 秒就退")
	assert_eq(fx.attack_speed(), 1.0)
	assert_false(fx.blocks_attack())
	# 丟毒瓶的霧：第一次中毒覺醒 → 回血（每秒 5 點），加上麻痺一共兩種狀態
	fx.apply_source("slime_touch")
	fx.apply_source("paralysis_on_hit")
	fx.tick(1.0, h)
	assert_true(absf(h.hp - 55.0) < 0.01, "一秒回 5 點（%s）" % h.hp)
	assert_eq(fx.ids().size(), 2)
	# 沒有反轉的人（席菈）：同一團霧是扣血
	var other := StatusEffects.new(_rules(), null)
	var oh := _hurt(50.0)
	other.apply_source("slime_touch")
	other.tick(1.0, oh)
	assert_true(absf(oh.hp - 45.0) < 0.01, "沒反轉：一秒扣 5 點（%s）" % oh.hp)
