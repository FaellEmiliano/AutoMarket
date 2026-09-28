class_name ConversationHistory
extends RefCounted

const MAX_MESSAGES := 50

var _messages: Array[Dictionary] = []


func add_message(speaker: String, text: String) -> void:
	var clean_speaker := speaker.strip_edges()
	var clean_text := text.strip_edges()
	if clean_text.is_empty():
		return

	_messages.append({
		"speaker": clean_speaker if not clean_speaker.is_empty() else "Mensagem",
		"text": clean_text,
	})
	while _messages.size() > MAX_MESSAGES:
		_messages.pop_front()


func get_messages() -> Array[Dictionary]:
	return _messages.duplicate(true)


func size() -> int:
	return _messages.size()

