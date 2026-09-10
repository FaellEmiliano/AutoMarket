extends RefCounted
class_name PythonLikeRuntimeLifecycle


var _resources: Array = []
var _discarded := false


func track(resource):
	if _discarded or resource == null or not resource.has_method("discard"):
		return resource
	_resources.append(resource)
	return resource


func tracked_count() -> int:
	return _resources.size()


func is_discarded() -> bool:
	return _discarded


func discard_all() -> void:
	if _discarded:
		return
	for index in range(_resources.size() - 1, -1, -1):
		var resource = _resources[index]
		if resource != null and resource.has_method("discard"):
			resource.discard()
	_resources.clear()
	_discarded = true
