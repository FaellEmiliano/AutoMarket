extends RefCounted
class_name LanguageBackendFactory

const DEFAULT_LANGUAGE_ID := "python_like"
const LEGACY_C_LIKE_LANGUAGE_ID := "c_like"
const CLikeBackend = preload("res://interpreter/runtime/c_like_runtime_backend.gd")
const PythonLikeBackend = preload("res://interpreter/runtime/python_like_runtime_backend.gd")

static func create(language_id: String):
	match language_id:
		LEGACY_C_LIKE_LANGUAGE_ID:
			return CLikeBackend.new()
		DEFAULT_LANGUAGE_ID:
			return PythonLikeBackend.new()
		_:
			return null
