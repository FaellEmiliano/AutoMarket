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
	_check(ide.theme.default_font == ThemeFactory.MONO, "UI técnica usa a fonte monoespaçada empacotada")
	_check(ide.theme.get_font("font", "CodeEdit") == ThemeFactory.MONO, "Editor de codigo usa a fonte monoespacada empacotada")
	_check(ide.code_edit.language_id == "python_like" and ide.code_edit.completion_words().has("wait"), "CodeEdit usa somente o perfil Python-like")
	_check(not menu.is_aberto() and menu.get_window_state() == menu.WindowState.CLOSED, "Jogo inicia com a IDE fechada")
	menu.set_aberto(true)
	_check(menu.is_minimizado() and menu.get_window_state() == menu.WindowState.DOCKED, "Launcher abre a IDE em modo docked")
	_check(menu.docked_size_for(Vector2(1280, 720)).is_equal_approx(Vector2(576, 432)), "Docked usa 45% x 60% em 1280x720")
	_check(menu.docked_size_for(Vector2(640, 360)).is_equal_approx(Vector2(520, 360)), "Docked respeita mínimos sem ultrapassar o viewport")
	var usable_size := Vector2(get_window().size)
	var expected_docked := Vector2(clampf(usable_size.x * 0.45, minf(520.0, usable_size.x), usable_size.x), clampf(usable_size.y * 0.60, minf(380.0, usable_size.y), usable_size.y))
	_check(ide.size.is_equal_approx(expected_docked), "Docked editor uses 45% x 60% with practical minimums")
	_check(ide.window_mode_button.tooltip_text == "Maximizar IDE", "Maximize control has a clear tooltip")
	_check(ide.layout_mode_id == ide.LayoutMode.COMPACT and not ide.sidebar.visible and not ide.drawer_scrim.visible, "Docked inicia com Explorer fechado")
	_check(not ide.get_property_list().any(func(property): return property.name in ["language_button", "status_language_button"]), "IDE não possui seletor de linguagem")
	_check(ide.workspace.visible and ide.workspace.size.x >= ide.content_host.size.x - 1.0, "Editor usa toda a largura quando o drawer esta fechado")
	_check(
		ide.toolbar.get_child(1) == ide.explorer_button
		and ide.toolbar.get_child(2) == ide.run_all_button
		and ide.toolbar.get_child(3) == ide.run_button
		and ide.toolbar.get_child(4) == ide.stop_button
		and ide.toolbar.get_child(5) == ide.window_mode_button
		and ide.toolbar.get_child(6) == ide.close_button,
		"Toolbar segue Explorer, Rodar todos, Rodar, Parar, Expandir e Fechar"
	)
	ide.toggle_explorer()
	_check(ide.sidebar.visible and ide.drawer_scrim.visible, "Explorer docked abre como drawer sobreposto")
	ide.drawer_scrim.emit_signal("pressed")
	_check(not ide.sidebar.visible and not ide.drawer_scrim.visible, "Clique fora fecha o drawer")
	ide.toggle_explorer()
	ide.toggle_explorer()
	_check(not ide.sidebar.visible, "Botao Explorer fecha novamente o drawer")
	var headless := DisplayServer.get_name() == "headless"
	var maximize_rect: Rect2 = ide.window_mode_button.get_global_rect()
	var editor_rect: Rect2 = ide.get_global_rect()
	var viewport_rect := get_viewport().get_visible_rect()
	if not headless:
		_check(editor_rect.end.is_equal_approx(viewport_rect.end), "Minimized editor stays anchored to the bottom-right corner")
		_check(ide.window_mode_button.get_parent().get_combined_minimum_size().x <= ide.size.x, "Compact toolbar fits inside the minimized editor")
		_check(ide.window_mode_button.is_visible_in_tree() and editor_rect.encloses(maximize_rect), "Maximize control remains visible inside the minimized editor")
		_check(ide.close_button.is_visible_in_tree() and editor_rect.encloses(ide.close_button.get_global_rect()), "Close control remains visible in docked mode")
	ide.window_mode_button.emit_signal("pressed")
	_check(not menu.is_minimizado() and menu.get_window_state() == menu.WindowState.FULLSCREEN, "Control maximizes the IDE")
	_check(ide.close_button.is_visible_in_tree(), "Close control remains visible in fullscreen")
	ide.window_mode_button.emit_signal("pressed")
	_check(menu.is_minimizado(), "Control restores minimized mode")
	_check(not ide.sidebar.visible and not ide.drawer_scrim.visible, "Docked nao herda Explorer aberto do fullscreen")
	ide.close_button.emit_signal("pressed")
	_check(not menu.is_aberto() and menu.toggle_button.visible, "Close from docked returns to gameplay and restores launcher")
	menu.set_aberto(true)
	ide.window_mode_button.emit_signal("pressed")
	_check(not menu.is_minimizado(), "Remaining tests use the full IDE")
	_check(menu.is_aberto() and ide.is_visible_in_tree(), "IDE abre")
	_check(not ide.output.visible, "Saída inicia recolhida")
	_check(ide.get_code_text() == "int main(){ print(42); }", "Código C-like legado é preservado")
	_check(ide.run_button.disabled and ide.status_label.text.contains("reescreva"), "Script C-like legado é bloqueado com orientação clara")
	InterpreterSystem.load_save_data({})
	ide._sync_documents()
	var first := str(InterpreterSystem.get_active_script().id)
	_check(InterpreterSystem.get_active_script().language == "python_like", "Save novo cria Principal Python-like")
	ide.set_code_text("print(7)\n")
	_check(InterpreterSystem.get_active_source().contains("7"), "Edição persiste")
	ide._on_new_tab_pressed()
	var second := str(InterpreterSystem.get_active_script().id)
	_check(first != second and ide.explorer.script_items.has(second), "Criar atualiza Explorer")
	ide.set_code_text("print(9)\n")
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
	ide.open_document("help", "terminal")
	_check(ide.tabs.active_kind == "help" and ide.documentation.body.text.contains("input"), "Documentação liberada abre")
	_check(str(InterpreterSystem.get_active_script().id) == first, "Docs preservam ativo")
	_check(ide.run_button.disabled and ide.stop_button.disabled, "Ações bloqueadas em docs")
	ide._on_run_pressed()
	_check(not InterpreterSystem.is_script_running(first), "Run não executa docs")
	ide.open_document("help", "stock")
	_check(ide.documentation.topic_id == "stock", "Ajuda de estoque deve estar disponível desde o início")
	_check(ide.explorer.topic_items.has("stock"), "Árvore inclui ajuda de estoque")
	ide.tabs.close_help_tab(ide.tabs.current_tab)
	_check(ide.tabs.active_kind == "script", "Fechar doc retorna ao script")
	_check(ide.code_edit.indent_use_spaces and ide.code_edit.indent_size == 4, "Python quatro espaços")
	_check(ide.code_edit.completion_words().has("wait") and not ide.code_edit.completion_words().has("await"), "wait e não await")
	_check(not ide.code_edit.completion_words().has("int"), "Python sem perfil C")
	FeatureManager.unlock_feature(FeatureManager.FEATURE_STOCK)
	ide.set_code_text("print(42)\nwait(30)\n")
	ide._on_run_pressed()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(InterpreterSystem.is_script_running(first), "Run inicia Python")
	_check(ide.status_label.text.contains("DORMINDO"), "Status sleeping")
	var running_source: String = str(ide.get_code_text())
	menu.set_minimizado(true)
	menu.set_minimizado(false)
	_check(InterpreterSystem.is_script_running(first), "Alternar o tamanho nao interrompe o runtime")
	_check(ide.get_code_text() == running_source and (headless or ide.output.visible), "Alternar preserva codigo e saida")
	get_window().size = Vector2i(1152, 360)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(headless or not ide.output.visible, "Janela baixa recolhe saída para manter o editor utilizável")
	get_window().size = Vector2i(1152, 648)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(ide.output.visible, "Recuperar altura restaura saída aberta")
	ide.open_document("script", second)
	ide.set_code_text("while True:\n    print(1)\n")
	ide._on_run_pressed()
	await get_tree().process_frame
	_check(InterpreterSystem.is_script_running(first) and InterpreterSystem.is_script_running(second), "Multiruntime independente")
	ide._on_stop_pressed()
	_check(InterpreterSystem.is_script_running(first) and not InterpreterSystem.is_script_running(second), "Stop só ativo")
	ide.open_document("script", first)
	ide._on_stop_pressed()
	ide.open_document("script", second)
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
	_check(delivery.is_empty(), "Fluxo legado de Delivery não cria script")
	_check(not ide.explorer.script_items.has(delivery), "Delivery não aparece na experiência ativa")
	StudentIdentity.show_student("Aluno de teste da IDE")
	_check(StudentIdentity.layer > menu.workspace_layer.layer, "Identidade acima da IDE")
	for dimensions in [Vector2i(1152,648), Vector2i(1280,720), Vector2i(1366,768), Vector2i(1920,1080), Vector2i(960,720), Vector2i(640,360)]:
		get_window().size = dimensions
		await get_tree().process_frame
		await get_tree().process_frame
		ide.update_layout(dimensions.x)
		_check(ide.code_edit.size.y >= 150, "Editor utilizável %s" % dimensions)
		_check(ide.size.x <= dimensions.x + 1, "Sem overflow horizontal %s" % dimensions)
		if dimensions.x == 960:
			_check(ide.layout_mode_id == ide.LayoutMode.MEDIUM, "Modo médio")
		if dimensions.x == 1280:
			ide.toggle_explorer()
			_check(not ide.sidebar.visible, "Fullscreen permite ocultar o Explorer")
			menu.set_minimizado(true)
			_check(not ide.sidebar.visible and not ide.drawer_scrim.visible, "Docked mantém seu drawer fechado")
			menu.set_minimizado(false)
			_check(not ide.sidebar.visible, "Fullscreen restaura sua preferência independente de Explorer")
			ide.toggle_explorer()
		if dimensions.x == 640:
			_check(ide.layout_mode_id == ide.LayoutMode.COMPACT, "Modo compacto")
			menu.set_minimizado(true)
			_check(ide.toolbar.get_combined_minimum_size().x <= ide.size.x, "Toolbar minimizada cabe em 640x360")
			_check(ide.window_mode_button.is_visible_in_tree(), "Maximizar permanece acessivel em 640x360")
			_check(ide.close_button.is_visible_in_tree() and ide.get_global_rect().encloses(ide.close_button.get_global_rect()), "Fechar permanece acessivel em 640x360")
			menu.set_minimizado(false)
			ide.toggle_explorer()
			_check(ide.sidebar.visible and ide.drawer_scrim.visible, "Gaveta compacta e fundo acessíveis")
			_check(ide.workspace.visible, "Editor permanece atrás da gaveta")
			ide.open_document("script", first)
			_check(not ide.sidebar.visible and not ide.drawer_scrim.visible, "Selecionar fecha gaveta")
			ide.toggle_output()
			_check(ide.output.visible and not ide.documents.visible, "Saída acessível em janela baixa")
			ide.toggle_output()
			_check(ide.documents.visible, "Recolher saída restaura editor")
		if not headless:
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
