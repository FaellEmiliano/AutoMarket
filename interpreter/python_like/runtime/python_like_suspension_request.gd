extends RefCounted
class_name PythonLikeSuspensionRequest


const KIND_SLEEP := "sleep"

var kind: String
var seconds: float
var token: int


func _init(request_kind: String, requested_seconds: float,
		request_token: int) -> void:
	kind = request_kind
	seconds = requested_seconds
	token = request_token
