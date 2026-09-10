extends RefCounted

# Presentation metadata only; backends remain the language authority.
const GAME_BUILTINS := ["print", "send", "input", "sensor", "get_stock", "buy_stock", "get_deliveries", "declare_profit", "wait"]

static func get_profile(language: String) -> Dictionary:
	if language == "python_like":
		return {
			"keywords": ["and", "break", "continue", "def", "elif", "else", "for", "if", "in", "not", "or", "return", "while"],
			"constants": ["True", "False", "None"], "builtins": GAME_BUILTINS + ["range", "len"],
			"comments": ["#"], "strings": ['"', "'"], "indent": [":"], "spaces": true
		}
	return {
		"keywords": ["if", "else", "while", "for", "function", "return", "int", "float", "break", "continue"],
		"constants": ["true", "false"], "builtins": GAME_BUILTINS + ["await"],
		"comments": ["//", "/* */"], "strings": ['"'], "indent": ["{"], "spaces": false
	}
