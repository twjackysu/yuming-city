extends TestCase
## 狀態邏輯：生命的三種變化、中毒開始／刷新／結束、反轉（諾恩全部反轉、其他人照吃）、麻痺、可攜藥劑。


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
	var fx := StatusEffects.new(_rules())
	var h := _hurt(50.0)
	assert_eq(fx.apply("poison", 6.0, 4.0, "miasma"), "start")
	fx.tick(1.0, h)
	assert_true(absf(h.hp - 44.0) < 0.001, "沒有反轉（NPC）照常掉血")


func test_reversed_poison_heals_from_the_first_frame() -> void:
	var fx := StatusEffects.new(_rules(), true)
	var h := _hurt(55.0)
	var took_damage: Array[bool] = [false]
	h.status_damaged.connect(func(_a: float, _i: Dictionary) -> void: took_damage[0] = true)
	fx.apply_source("miasma")
	fx.tick(0.5, h)
	assert_true(absf(h.hp - 58.0) < 0.001, "6／秒 × 0.5 秒＝回 3")
	assert_false(took_damage[0], "反轉發生在扣血之前：不會先扣一次再補回")


## 劇本：落在諾恩身上的異常狀態**全部**反轉——資料表裡的每一種都是，不用解鎖、不用裝備、沒有格子數。
func test_every_status_reverses_at_once_with_nothing_to_unlock() -> void:
	var fx := StatusEffects.new(_rules(), true)
	var h := _hurt(50.0)
	var took_damage: Array[bool] = [false]
	h.status_damaged.connect(func(_a: float, _i: Dictionary) -> void: took_damage[0] = true)
	for id: Variant in _rules().statuses:
		assert_eq(fx.apply(str(id), 1.2, 5.0, "test"), "start", "%s 上得了身" % id)
	assert_eq(fx.ids().size(), _rules().statuses.size(), "每一種同時都在身上")
	fx.tick(1.0, h)
	assert_false(took_damage[0], "沒有任何一種在扣血")
	assert_false(fx.blocks_attack(), "也沒有任何一種擋住出手")
	assert_true(h.hp > 50.0, "中毒在回血（%s）" % h.hp)
	assert_true(fx.attack_speed() > 1.0, "麻痺在加速（%s）" % fx.attack_speed())


func test_poison_refresh_does_not_stack() -> void:
	var fx := StatusEffects.new(_rules())
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
	var fx := StatusEffects.new(_rules(), true)
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
	var fx := StatusEffects.new(_rules(), true)
	var h := _hurt(10.0)
	fx.apply("poison", 50.0, 2.0, "boss")
	fx.tick(1.0, h)
	assert_true(absf(h.hp - 18.0) < 0.001, "反轉回血最多 8／秒（特殊敵技再強也一樣）")


func test_tick_zero_is_paused() -> void:
	var fx := StatusEffects.new(_rules())
	var h := _hurt(50.0)
	fx.apply("poison", 6.0, 4.0)
	fx.tick(0.0, h)
	assert_eq(fx.remaining("poison"), 4.0, "暫停（沒有推進時間）不計時")
	assert_eq(h.hp, 50.0)


func test_unknown_status_and_bad_values_ignored() -> void:
	var fx := StatusEffects.new(_rules(), true)
	assert_eq(fx.apply("time_stop", 1.0, 1.0), "ignored", "還沒定義的狀態不上身")
	assert_eq(fx.apply("poison", 0.0, 4.0), "ignored")
	assert_eq(fx.apply("poison", 3.0, -1.0), "ignored")
	assert_eq(fx.apply_source("nope"), "ignored")
	assert_true(fx.ids().is_empty())


func test_status_save_round_trip_keeps_negative_effects() -> void:
	var fx := StatusEffects.new(_rules(), true)
	fx.apply("poison", 3.0, 20.0, "sera_poison_vial")
	fx.tick(5.0, null)
	var again := StatusEffects.new(_rules(), true)
	again.load_array(fx.to_array())
	assert_eq(again.remaining("poison"), 15.0, "讀檔照原樣：不清掉、不補滿時間")
	assert_eq(again.source_of("poison"), "sera_poison_vial")
	again.load_array([{"id": "poison", "rate": 3.0, "remaining": 999.0}, {"id": "ghost", "rate": 1, "remaining": 5}, "junk"])
	assert_eq(again.remaining("poison"), 30.0, "壞值夾到上限")
	assert_eq(again.ids().size(), 1, "不認得的略過")


func test_potion_belt_grant_once_and_use() -> void:
	var state := GameState.new()
	var belt := PotionBelt.new(state, _rules())
	var fx := StatusEffects.new(_rules(), true)
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
	assert_eq(fx.remaining("poison"), 20.0, "席菈的毒藥：中毒 20 秒")
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
	var fx := StatusEffects.new(_rules())
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


## 麻痺反轉：出手加速，有上限；同一種只有一份，怎麼疊都不會更快、時間不超過上限；中毒照舊回血，互不影響。
func test_reversed_paralysis_speeds_attacks_with_a_cap_and_does_not_stack() -> void:
	var fx := StatusEffects.new(_rules(), true)
	var h := _hurt(50.0)
	fx.apply_source("miasma")
	fx.apply_source("sera_paralysis_vial")
	assert_false(fx.blocks_attack(), "反轉了：不擋出手")
	var vial_rate: float = float(_rules().source("sera_paralysis_vial")["rate"])
	assert_true(absf(fx.attack_speed() - vial_rate) < 0.001, "席菈的藥：出手 %s 倍" % vial_rate)
	# 同一來源再來十次：還是一份、一樣快、時間不超過上限
	for i: int in 10:
		assert_eq(fx.apply_source("sera_paralysis_vial"), "refresh")
	assert_eq(fx.ids().size(), 2, "一個中毒＋一個麻痺")
	assert_true(absf(fx.attack_speed() - vial_rate) < 0.001, "不會越疊越快")
	assert_true(fx.remaining("paralysis") <= _rules().max_duration("paralysis") + 0.001)
	# 很強的來源也有上限
	fx.apply("paralysis", 9.0, 999.0, "test")
	assert_true(absf(fx.attack_speed() - _rules().max_reversed_rate("paralysis")) < 0.001, "倍率有上限")
	assert_true(absf(fx.remaining("paralysis") - _rules().max_duration("paralysis")) < 0.001, "時間有上限")
	# 兩種一起：中毒照舊回血、麻痺不碰生命
	var before: float = h.hp
	fx.tick(1.0, h)
	assert_true(absf(h.hp - before - 6.0) < 0.001, "只有中毒的回血（%s）" % (h.hp - before))
	# 存檔照原樣存、讀回來還是加速
	var again := StatusEffects.new(_rules(), true)
	again.load_array(fx.to_array())
	assert_true(again.has("paralysis"))
	assert_true(again.attack_speed() > 1.0)


## 打中人時給自己的麻痺：每次命中只是重新計時——一份、一樣快、不超過 6 秒；停手 6 秒就退，退了之後不擋出手。
## 史萊姆的毒：諾恩回血、其他人扣血。
func test_paralysis_on_hit_refreshes_without_stacking_and_fades_when_you_stop() -> void:
	var fx := StatusEffects.new(_rules(), true)
	var h := _hurt(50.0)
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
	# 被史萊姆撞到：回血（每秒 5 點），加上麻痺一共兩種狀態
	fx.apply_source("slime_touch")
	fx.apply_source("paralysis_on_hit")
	fx.tick(1.0, h)
	assert_true(absf(h.hp - 55.0) < 0.01, "一秒回 5 點（%s）" % h.hp)
	assert_eq(fx.ids().size(), 2)
	# 沒有反轉的人：同一種毒是扣血
	var other := StatusEffects.new(_rules())
	var oh := _hurt(50.0)
	other.apply_source("slime_touch")
	other.tick(1.0, oh)
	assert_true(absf(oh.hp - 45.0) < 0.01, "沒反轉：一秒扣 5 點（%s）" % oh.hp)
