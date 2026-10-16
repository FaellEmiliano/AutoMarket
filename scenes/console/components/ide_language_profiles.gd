extends RefCounted

# Presentation metadata only; backends remain the language authority.
const GAME_BUILTINS := ["print", "send", "input", "sensor", "tabela_produtos", "get_stock", "get_budget", "buy_stock", "promocoes", "mapa_entrega", "entrega_atual", "enviar_rota", "wait"]
const BUILTIN_DOCUMENTATION := {
	"append": "lista.append(valor): acrescenta ao final da própria lista e retorna None.",
	"pop": "lista.pop([indice]): remove e devolve o elemento. Sem índice, usa o último; aceita índices negativos. Lista vazia ou índice fora dos limites causa erro.",
	"mapa_entrega": "mapa_entrega(): cópia da matriz pendente. 0 terreno, 1 rua, 2 bloqueio; [] sem entrega.",
	"entrega_atual": "entrega_atual(): {id, origem, destino}, coordenadas [linha, coluna]; None sem entrega pendente.",
	"enviar_rota": "enviar_rota(rota): valida a lista completa antes de mover. True aceita; False recusa com explicação. Inclua origem e destino, sem repetir posições.",
	"promocoes": "promocoes(): Retorna as regras promocionais do atendimento atual. Cada regra informa seu tipo e seus parâmetros (leve_pague ou percentual)."
}

static func get_profile() -> Dictionary:
	return {
		"keywords": ["and", "break", "continue", "def", "elif", "else", "for", "if", "in", "not", "or", "return", "while"],
		"constants": ["True", "False", "None"], "builtins": GAME_BUILTINS + ["range", "len"],
		"builtin_documentation": BUILTIN_DOCUMENTATION,
		"comments": ["#"], "strings": ['"', "'"], "indent": [":"], "spaces": true
	}
