class_name TestCase
extends RefCounted
## 極簡測試基底類別。測試檔放在 res://tests/unit/test_*.gd，方法名以 test_ 開頭。
## 方法可以是協程（內含 await），runner 會等它完成。

var failures: PackedStringArray = []
var current_test: String = ""
## runner 會在執行前設定，給需要場景樹的測試使用。
var tree: SceneTree


func before_each() -> void:
	pass


func after_each() -> void:
	pass


func fail(message: String) -> void:
	failures.append("%s: %s" % [current_test, message])


func assert_true(value: bool, message: String = "預期為 true") -> void:
	if not value:
		fail(message)


func assert_false(value: bool, message: String = "預期為 false") -> void:
	if value:
		fail(message)


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		fail("%s 預期 <%s>，實際 <%s>" % [message, var_to_str(expected), var_to_str(actual)])


func assert_ne(actual: Variant, unexpected: Variant, message: String = "") -> void:
	if typeof(actual) == typeof(unexpected) and actual == unexpected:
		fail("%s 不應為 <%s>" % [message, var_to_str(unexpected)])


func assert_not_null(value: Variant, message: String = "預期不為 null") -> void:
	if value == null:
		fail(message)
