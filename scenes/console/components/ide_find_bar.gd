extends HBoxContainer

var editor: CodeEdit
var query: LineEdit
var result: Label
var _matches: Array[Vector2i] = []
var _index := -1
var _query := ""

func _ready() -> void:
	query = LineEdit.new()
	query.placeholder_text = "Buscar no código"
	query.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	query.text_changed.connect(_search_changed)
	query.text_submitted.connect(func(_text): find_next())
	add_child(query)
	result = Label.new()
	result.theme_type_variation = &"IDESectionLabel"
	add_child(result)
	for entry in [["Anterior", func(): find_next(true)], ["Próxima", find_next], ["Fechar", close]]:
		var button := Button.new()
		button.text = entry[0]
		button.pressed.connect(entry[1])
		add_child(button)
	hide()

func open() -> void:
	show()
	if editor.has_selection():
		query.text = editor.get_selected_text()
	query.grab_focus()
	query.select_all()
	_search_changed(query.text)

func close() -> void:
	hide()
	editor.set_search_text("")
	editor.grab_focus()

func refresh() -> void:
	if visible:
		_search_changed(query.text)

func _search_changed(text: String) -> void:
	_query = text
	_matches.clear()
	_index = -1
	editor.set_search_text(text)
	editor.set_search_flags(0)
	if not text.is_empty():
		# Counts are presentation-only; navigation uses TextEdit's native search.
		for line in range(editor.get_line_count()):
			var source := editor.get_line(line)
			var column := source.findn(text)
			while column >= 0:
				_matches.append(Vector2i(column, line))
				column = source.findn(text, column + maxi(1, text.length()))
	result.text = "%d ocorrências" % _matches.size() if not _matches.is_empty() else "Nenhuma ocorrência"

func find_next(backwards := false) -> void:
	if _query != query.text:
		_search_changed(query.text)
	if _matches.is_empty():
		return
	_index = (_matches.size() - 1 if backwards else 0) if _index < 0 else posmod(_index + (-1 if backwards else 1), _matches.size())
	var start := _matches[_index]
	var hit := editor.search(query.text, 0, start.y, start.x)
	if hit.x < 0:
		return
	editor.set_caret_line(hit.y)
	editor.set_caret_column(hit.x)
	editor.select(hit.y, hit.x, hit.y, hit.x + query.text.length())
	editor.center_viewport_to_caret()
	result.text = "%d / %d" % [_index + 1, _matches.size()]
