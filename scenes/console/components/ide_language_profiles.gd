extends RefCounted

# Presentation metadata only; backends remain the language authority.
const GAME_BUILTINS := ["print", "send", "input", "sensor", "tabela_produtos", "get_stock", "get_budget", "buy_stock", "promocoes", "get_deliveries", "declare_profit", "wait"]
const BUILTIN_DOCUMENTATION := {
	"promocoes": "promocoes(): Retorna as regras promocionais do atendimento atual. Cada regra informa seu tipo e seus parâmetros (leve_pague ou percentual)."
}

static func get_profile() -> Dictionary:
	return {
		"keywords": ["and", "break", "continue", "def", "elif", "else", "for", "if", "in", "not", "or", "return", "while"],
		"constants": ["True", "False", "None"], "builtins": GAME_BUILTINS + ["range", "len"],
		"builtin_documentation": BUILTIN_DOCUMENTATION,
		"comments": ["#"], "strings": ['"', "'"], "indent": [":"], "spaces": true
	}
