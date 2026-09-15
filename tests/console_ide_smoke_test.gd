extends Node

const MenuScene = preload("res://scenes/game/script_menu.tscn")
const ThemeFactory = preload("res://scenes/console/components/ide_theme.gd")
var menu
var ide
var failures: Array[String] = []

func _ready() -> void:
	Saves.clear_current_slot()
	FeatureManager.reset_progression()
	InterpreterSystem.load_save_data({"script_text": "int main(){ print(42); }"})
	menu = MenuScene.instantiate()
	add_child(menu)
	await get_tree().process_frame
	ide = menu.get_console_editor()
	_check(ide.theme.default_font == ThemeFactory.UI, "IDE usa a fonte empacotada em vez de fallback do sistema")
	_check(ide.theme.get_font("font", "CodeEdit") == ThemeFactory.MONO, "Editor de codigo usa a fonte monoespacada empacotada")
	menu.set_aberto(true)
	_check(menu.is_minimizado(), "Direct opening starts minimized")
	var usable_size := get_viewport().get_visible_rect().size * get_viewport().get_stretch_transform().get_scale()
	_check(ide.size.is_equal_approx(usable_size * Vector2(1.0 / 3.0, 1.0 / 2.0)), "Minimized editor uses one third by one half of the viewport")
	_check(ide.window_mode_button.tooltip_text == "Maximizar editor", "Maximize control has a clear tooltip")
	ide.window_mode_button.emit_signal("pressed")
	_check(not menu.is_minimizado(), "Control maximizes the IDE")
	ide.window_mode_button.emit_signal("pressed")
	_check(menu.is_minimizado(), "Control restores minimized mode")
	ide.window_mode_button.emit_signal("pressed")
	_check(not menu.is_minimizado(), "Remaining tests use the full IDE")
	_check(menu.is_aberto() and ide.is_visible_in_tree(), "IDE abre")
	_check(not ide.output.visible, "Saída inicia recolhida")
	var first := str(InterpreterSystem.get_active_script().id)
	_check(ide.get_code_text().contains("42"), "Source inicial")
	ide.set_code_text("int main(){ print(7); }")
	_check(InterpreterSystem.get_active_source().contains("7"), "Edição persiste")
	ide._on_new_tab_pressed()
	var second := str(InterpreterSystem.get_active_script().id)
	_check(first != second and ide.explorer.script_items.has(second), "Criar atualiza Explorer")
	ide.set_code_text("int main(){ print(9); }")
	ide.open_document("script", first)
	_check(ide.get_code_text().contains("7"), "Troca preserva source")
	InterpreterSystem.rename_script(first, "Principal com um título bastante longo para testar a interface sem truncar o valor persistido")
	_check(ide.tabs.get_tab_title(0).contains("bastante longo"), "Rename atualiza tab")
	_check(ide.explorer.script_items[first].get_text(0).contains("bastante longo"), "Rename atualiza Explorer")
	var duplicate := InterpreterSystem.duplicate_script(first)
	_check(ide.explorer.script_items.has(duplicate), "Duplicar atualiza Explorer")
	InterpreterSystem.delete_script(duplicate)
	_check(not ide.explorer.script_items.has(duplicate), "Excluir atualiza Explorer")
	var script_count := InterpreterSystem.get_scripts().size()
	var second_tab := _find_tab("script", second)
	ide.tabs.close_tab(second_tab)
	_check(not ide.tabs.open_script_ids.has(second), "Fechar aba remove somente a apresentação")
	_check(InterpreterSystem.get_scripts().size() == script_count, "Fechar aba não exclui script")
	ide.open_document("script", second)
	_check(ide.tabs.open_script_ids.has(second) and ide.get_code_text().contains("9"), "Explorer reabre aba preservada")
	ide.open_document("script", first)
	ide.open_document("help", "input")
	_check(ide.tabs.active_kind == "help" and ide.documentation.body.text.contains("input"), "Documentação liberada abre")
	_check(str(InterpreterSystem.get_active_script().id) == first, "Docs preservam ativo")
	_check(ide.run_button.disabled and ide.stop_button.disabled and ide.language_button.disabled, "Ações bloqueadas em docs")
	ide._on_run_pressed()
	_check(not InterpreterSystem.is_script_running(first), "Run não executa docs")
	ide.open_document("help", "stock")
	_check(ide.documentation.topic_id != "stock", "Bloqueado não revela conteúdo")
	_check(ide.explorer.topic_items.has("stock"), "Árvore inclui bloqueados")
	ide.tabs.close_help_tab(ide.tabs.current_tab)
	_check(ide.tabs.active_kind == "script", "Fechar doc retorna ao script")
	ide._on_language_selected(1)
	_check(ide.code_edit.language_id == "python_like", "Perfil Python")
	_check(ide.code_edit.indent_use_spaces and ide.code_edit.indent_size == 4, "Python quatro espaços")
	_check(ide.code_edit.completion_words().has("wait") and not ide.code_edit.completion_words().has("await"), "wait e não await")
	_check(not ide.code_edit.completion_words().has("int"), "Python sem perfil C")
	FeatureManager.unlock_feature(FeatureManager.FEATURE_STOCK)
	ide.set_code_text("print(42)\nwait(30)\n")
	ide._on_run_pressed()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(InterpreterSystem.is_script_running(first), "Run inicia Python")
	_check(ide.language_button.disabled, "Language protegido no runtime")
	_check(ide.status_label.text.contains("DORMINDO"), "Status sleeping")
	var running_source := ide.get_code_text()
	menu.set_minimizado(true)
	menu.set_minimizado(false)
	_check(InterpreterSystem.is_script_running(first), "Alternar o tamanho nao interrompe o runtime")
	_check(ide.get_code_text() == running_source and ide.output.visible, "Alternar preserva codigo e saida")
	get_window().size = Vector2i(1152, 360)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not ide.output.visible, "Janela baixa recolhe saída para manter o editor utilizável")
	get_window().size = Vector2i(1152, 648)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(ide.output.visible, "Recuperar altura restaura saída aberta")
	ide._on_language_selected(0)
	_check(InterpreterSystem.get_active_script().language == "python_like", "Guard de linguagem")
	ide.open_document("script", second)
	ide.set_code_text("int main(){ while(true){ print(1); } }")
	ide._on_run_pressed()
	await get_tree().process_frame
	_check(InterpreterSystem.is_script_running(first) and InterpreterSystem.is_script_running(second), "Multiruntime independente")
	ide._on_stop_pressed()
	_check(InterpreterSystem.is_script_running(first) and not InterpreterSystem.is_script_running(second), "Stop só ativo")
	ide.open_document("script", first)
	ide._on_stop_pressed()
	_check(not ide.language_button.disabled, "Language reabilita")
	ide.open_document("script", second)
	ide._on_language_selected(1)
	ide.set_code_text("print(nome_inexistente)\n")
	ide._on_run_pressed()
	await get_tree().process_frame
	await get_tree().process_frame
	var error_runtime := InterpreterSystem.get_runtime_by_script_id(second)
	_check(str(error_runtime.get("status", "")) == "error", "Erro Python-like chega à IDE")
	_check(not error_runtime.get("diagnostics", []).is_empty(), "IDE recebe diagnóstico estruturado")
	_check(ide.code_edit.diagnostic_lines().has(0), "Linha do erro recebe destaque")
	_check(ide.output.visible, "Erro abre painel de saída")
	ide.set_code_text("print(42)\n")
	_check(ide.code_edit.diagnostic_lines().is_empty(), "Editar limpa destaque obsoleto")
	ide.open_document("script", first)
	EventBus.send_debug.emit("saída de teste")
	_check(ide.output.text_label.text == "saída de teste", "Output recebe sinal")
	ide.find_bar.open()
	ide.find_bar.query.text = "print"
	ide.find_bar.find_next()
	_check(ide.code_edit.get_selected_text() == "print", "Find nativo seleciona")
	ide.handle_escape()
	_check(not ide.find_bar.visible and menu.is_aberto(), "Escape fecha Find antes da IDE")
	ide.handle_escape()
	_check(not menu.is_aberto(), "Escape fecha IDE")
	menu.set_aberto(true)
	_check(ide.get_code_text().contains("wait"), "Reabrir preserva source")
	FeatureManager.unlock_feature(FeatureManager.FEATURE_DELIVERY)
	var delivery := InterpreterSystem.get_delivery_script_id()
	_check(ide.explorer.script_items.has(delivery), "Delivery aparece")
	InterpreterSystem.rename_script(delivery, "errado")
	_check(not InterpreterSystem.delete_script(delivery), "Delivery não exclui")
	ide.open_document("script", delivery)
	_check(InterpreterSystem.get_active_script_title() == "Delivery", "Delivery não renomeia")
	ide.set_code_text("int main(){ print(8); }")
	ide._on_run_pressed()
	await get_tree().process_frame
	ide._on_stop_pressed()
	StudentIdentity.show_student("Aluno de teste da IDE")
	_check(StudentIdentity.layer > menu.workspace_layer.layer, "Identidade acima da IDE")
	for dimensions in [Vector2i(1152,648), Vector2i(1280,720), Vector2i(1920,1080), Vector2i(960,720), Vector2i(640,360)]:
		get_window().size = dimensions
		await get_tree().process_frame
		await get_tree().process_frame
		ide.update_layout(dimensions.x)
		_check(ide.code_edit.size.y >= 150, "Editor utilizável %s" % dimensions)
		_check(ide.size.x <= dimensions.x + 1, "Sem overflow horizontal %s" % dimensions)
		if dimensions.x == 960:
			_check(ide.layout_mode_id == ide.LayoutMode.MEDIUM, "Modo médio")
		if dimensions.x == 640:
			_check(ide.layout_mode_id == ide.LayoutMode.COMPACT, "Modo compacto")
			ide.toggle_explorer()
			_check(ide.sidebar.visible and ide.drawer_scrim.visible, "Gaveta compacta e fundo acessíveis")
			_check(ide.workspace.visible, "Editor permanece atrás da gaveta")
			ide.open_document("script", first)
			_check(not ide.sidebar.visible and not ide.drawer_scrim.visible, "Selecionar fecha gaveta")
			ide.toggle_output()
			_check(ide.output.visible and not ide.documents.visible, "Saída acessível em janela baixa")
			ide.toggle_output()
			_check(ide.documents.visible, "Recolher saída restaura editor")
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://ide_%dx%d.png" % [dimensions.x,dimensions.y])
	if failures.is_empty():
		print("CONSOLE_IDE_SMOKE_TEST_OK")
	else:
		push_error("\n".join(failures))
	InterpreterSystem.stop_all()
	await get_tree().create_timer(5).timeout
	get_tree().quit(0 if failures.is_empty() else 1)

func _find_tab(kind: String, id: String) -> int:
	for index in range(ide.tabs.get_tab_count()):
		var data: Dictionary = ide.tabs.get_tab_metadata(index)
		if data.kind == kind and data.id == id:
			return index
	return -1

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
