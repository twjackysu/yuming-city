class_name RingTally
extends Control
## 敲鐘刻度（第二輪盤點第 4 項，D-084）：一排小圓點，敲過的亮成暖金色（剛敲的那一下外圈多亮一下再退掉），
## 還沒敲的是淡灰色空心圈，最後一下的圓點大一點。只畫圖形、不畫字（數字照舊在提示那一行，D-060）。

const RUNG: Color = Color(0.95, 0.78, 0.45)
const UNRUNG: Color = Color(0.62, 0.64, 0.68, 0.55)
const GAP: float = 26.0
const RADIUS: float = 5.0
const LAST_RADIUS: float = 7.5
const PULSE_DECAY: float = 2.2

var count: int = 0
var total: int = 0
var pulse: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_count(n: int, of: int) -> void:
	if of == total and n > count:
		pulse = 1.0
	count = clampi(n, 0, maxi(of, 0))
	total = maxi(of, 0)
	queue_redraw()


func _process(delta: float) -> void:
	if pulse > 0.0:
		pulse = maxf(pulse - PULSE_DECAY * delta, 0.0)
		queue_redraw()


## 第 i 個圓點的中心（測試與 _draw 共用）。
func dot_center(i: int) -> Vector2:
	var width: float = GAP * float(maxi(total - 1, 0))
	return Vector2(size.x * 0.5 - width * 0.5 + GAP * float(i), size.y * 0.5)


func _draw() -> void:
	for i: int in total:
		var p: Vector2 = dot_center(i)
		var r: float = LAST_RADIUS if i == total - 1 else RADIUS
		if i < count:
			var halo: float = 0.16 + (0.4 * pulse if i == count - 1 else 0.0)
			draw_circle(p, r * 2.1, Color(RUNG, halo))
			draw_circle(p, r, RUNG)
		else:
			draw_arc(p, r, 0.0, TAU, 24, UNRUNG, 1.5, true)
