extends RefCounted
class_name LanguageBackendFactory

const DEFAULT_LANGUAGE_ID := "c_like"
const CLikeBackend = preload("res://interpreter/runtime/c_like_runtime_backend.gd")

static func create(language_id: String):
	match language_id:
		DEFAULT_LANGUAGE_ID:
			return CLikeBackend.new()
		_:
			return null
