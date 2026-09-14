extends Node
class_name ErroInterpretador

enum TipoErro {
	LEXICO,
	SINTATICO,
	SEMANTICO,
	RUNTIME
}

var mensagem: String
var linha: int
var coluna: int
var tipo: TipoErro
var codigo: String
var comprimento: int

func _init(msg: String, l: int, c: int, t: TipoErro = TipoErro.RUNTIME,
		code: String = "", length: int = 0):
	mensagem = msg
	linha = l
	coluna = c
	tipo = t
	codigo = code
	comprimento = maxi(0, length)

func formatar() -> String:
	var prefixo = ""
	match tipo:
		TipoErro.LEXICO:     prefixo = "[Léxico]"
		TipoErro.SINTATICO:  prefixo = "[Sintático]"
		TipoErro.SEMANTICO:  prefixo = "[Semântico]"
		TipoErro.RUNTIME:    prefixo = "[Runtime]"
	if linha >= 0:
		return "%s Linha %d, Col %d: %s" % [prefixo, linha, coluna, mensagem]
	return "%s %s" % [prefixo, mensagem]

func to_dictionary() -> Dictionary:
	var categories := {
		TipoErro.LEXICO: "lexical",
		TipoErro.SINTATICO: "syntax",
		TipoErro.SEMANTICO: "semantic",
		TipoErro.RUNTIME: "runtime",
	}
	return {
		"category": categories.get(tipo, "runtime"),
		"code": codigo,
		"message": mensagem,
		"line": linha if linha > 0 else 0,
		"column": coluna if coluna > 0 else 0,
		"length": comprimento,
		"details": {},
	}
