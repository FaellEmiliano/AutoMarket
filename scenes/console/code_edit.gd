extends CodeEdit

const Profiles = preload("res://scenes/console/components/ide_language_profiles.gd")
const COLORS := {"keywords": Color("c5a0df"), "constants": Color("dfa77e"), "builtins": Color("d5bc80")}
var language_id := "c_like"
var profile: Dictionary
var _diagnostic_lines: Array[int] = []

func _ready() -> void:
	highlight_all_occurrences = true
	highlight_current_line = true
	gutters_draw_line_numbers = true
	auto_brace_completion_enabled = true
	code_completion_enabled = true
	configure_for_language(language_id)

func configure_for_language(language: String) -> void:
	language_id = language
	profile = Profiles.get_profile(language)
	cancel_code_completion()
	var highlighter := CodeHighlighter.new()
	for category in COLORS:
		for word in profile[category]:
			highlighter.add_keyword_color(word, COLORS[category])
	clear_comment_delimiters()
	clear_string_delimiters()
	for comment in profile.comments:
		var parts: PackedStringArray = comment.split(" ")
		var end := parts[1] if parts.size() > 1 else ""
		add_comment_delimiter(parts[0], end, end.is_empty())
		highlighter.add_color_region(parts[0], end, Color("788c88"), end.is_empty())
	for delimiter in profile.strings:
		add_string_delimiter(delimiter, delimiter, true)
		highlighter.add_color_region(delimiter, delimiter, Color("a6c98e"), true)
	highlighter.number_color = Color("dfa77e")
	highlighter.symbol_color = Color("9dafb8")
	highlighter.function_color = COLORS.builtins
	syntax_highlighter = highlighter
	indent_size = 4
	indent_use_spaces = profile.spaces
	indent_automatic = true
	indent_automatic_prefixes = PackedStringArray(profile.indent)

func completion_words() -> Array:
	return profile.keywords + profile.constants + profile.builtins

func set_diagnostics(diagnostics: Array) -> void:
	clear_diagnostics()
	for diagnostic in diagnostics:
		if not diagnostic is Dictionary:
			continue
		var line := int(diagnostic.get("line", 0)) - 1
		if line < 0 or line >= get_line_count() or _diagnostic_lines.has(line):
			continue
		set_line_background_color(line, Color("40282a"))
		_diagnostic_lines.append(line)

func clear_diagnostics() -> void:
	for line in _diagnostic_lines:
		if line >= 0 and line < get_line_count():
			set_line_background_color(line, Color.TRANSPARENT)
	_diagnostic_lines.clear()

func diagnostic_lines() -> Array[int]:
	return _diagnostic_lines.duplicate()

func _request_code_completion(force: bool) -> void:
	if is_in_comment(get_caret_line(), get_caret_column()) != -1 or is_in_string(get_caret_line(), get_caret_column()) != -1:
		return
	for category in COLORS:
		var kind := KIND_FUNCTION if category == "builtins" else KIND_PLAIN_TEXT
		if category == "constants":
			kind = KIND_CONSTANT
		for word in profile[category]:
			add_code_completion_option(kind, word, word, COLORS[category])
	update_code_completion_options(force)
