# Delivery: navegação pelo bairro

Implementado em 15/10/2026. Sem commit ou push.

## Comportamento e progressão

Estoque, checkout e promoções continuam na experiência ativa. Delivery Online
aparece após Sistema de promoções, custa R$370 e habilita a aba Delivery e o mapa.
O objetivo inicial são três chegadas; o progresso fica em ChallengeSystem,
campos deliveries e delivery_completed, sem alterar o objetivo Mercado Automatizado.
A automação continua após a meta. Cada chegada rende R$40 via update_money.
O próximo pedido surge após 15 segundos de tempo ativo. Não há ganhos offline.
A nova navegação não concede diamantes nem reativa o upgrade legado Zerar.

## Geração e validação

DeliveryMapGenerator.generate usa DFS aleatorizada para abrir uma árvore geradora
na grade completa dos cruzamentos. Os demais segmentos viram bloqueios. Uma árvore
conexa de V vértices com V-1 arestas possui exatamente um caminho simples entre
qualquer par de cruzamentos. Todos continuam conectados; só trechos são fechados.
A matriz subdivide cada aresta em uma célula de rua e preserva a geometria base.

O padrão é 5×5 cruzamentos, matriz 9×9, origem [0, 0], distância Manhattan mínima
4 e rota com pelo menos 6 movimentos de matriz. São configuráveis tamanho (2–15 por
lado), distância, movimentos, mínimo de becos e tentativas (limite 128, padrão 32).
O gerador evita o destino anterior e as últimas 32 configurações. Se parâmetros
impossíveis esgotarem as tentativas, retorna uma árvore válida e marca
constraints_met=false. Conectividade e unicidade nunca são relaxadas.

DeliveryRouteValidator.validate verifica tipos, inteiros estritos, limites,
origem/destino, passos ortogonais de uma célula, ruas transitáveis e não repetição.
DeliverySystem valida o estado pendente e o id do mapa antes de iniciar a viagem.
A rota inteira é validada antes de qualquer movimento. O mapa permanece congelado
enquanto pendente ou em viagem. O id é encerrado antes de emitir crédito/save,
impedindo pagamentos duplicados e chamadas reentrantes após a chegada.

DeliveryConfig.gd centraliza geração, velocidade (4 células/s), recompensa, meta e
intervalo. DeliverySystem.advance_driver interpola coordenadas da matriz de forma
independente da renderização, sem bloquear o mercado ou o agendador de scripts.

## API Python-like definitiva

- mapa_entrega(): cópia da matriz pendente; [] sem pedido pendente.
  0 = terreno, 1 = rua/cruzamento, 2 = trecho bloqueado.
- entrega_atual(): cópia de {"id": inteiro, "origem": [linha, coluna],
  "destino": [linha, coluna]}; None durante viagem, cooldown ou bloqueio.
- enviar_rota(rota): True se aceita, False com explicação se recusada.
  Inclua origem e destino. Sem diagonais, saltos, bloqueios ou posições repetidas.
  Leia as duas consultas para o mesmo id antes de enviar.

Cada bridge guarda os ids de suas duas leituras. Um script com snapshots antigos
não pode enviar uma rota para outro pedido sem renovar ambas as consultas.
A conversão da rota inspeciona no máximo dois níveis e 841 coordenadas, evitando
conversão recursiva arbitrária de listas profundamente aninhadas ou cíclicas.

O runtime já oferece def, listas, dicionários, indexação, concatenação, len, range,
if, for, while e espera cooperativa. Nenhuma mudança de sintaxe foi necessária.
Listas suportam append(valor), pop() e pop(indice), incluindo índices negativos.
Não há igualdade estrutural de coleções. Compare componentes das
coordenadas e use a condição if entrega: para verificar a presença do pedido.

Exemplos completos executados pelo interpretador real:

- [BFS iterativa com automação contínua](examples/delivery_bfs.py)
- [DFS iterativa com automação contínua](examples/delivery_dfs.py)

Ambos marcam visitação na cópia da matriz, guardam pais e reconstroem a rota.
Use wait(1) entre verificações; só o script atual é suspenso.
input() e send() não foram alterados e continuam associados ao caixa.

## Persistência e migração

O bloco delivery usa schema_version=2 dentro do formato global existente.
Persiste mapa, destino, ids, contador, intervalo restante e histórico.
O carregamento normaliza os números do JSON e verifica dimensões, geometria,
conectividade e contagem de arestas. Viagens interrompidas voltam a pendente com
o mesmo mapa e origem, sem recompensa parcial. Cooldown retoma do tempo restante.

Saves antigos conservam dinheiro, upgrades, diamantes, scripts e ids já pagos.
Relatórios antigos pendentes são substituídos pelo primeiro pedido de navegação
quando o delivery estiver liberado. Não contam como entregas concluídas.
Scripts antigos são preservados, mas get_deliveries()/declare_profit() agora
orientam a usar a nova API e não concedem crédito. Os analisadores legados continuam
disponíveis para compatibilidade, mas não avaliam as novas rotas.

## Renderização e futuras sprites

Somente scenes/delivery/delivery_map_renderer.gd desenha o mapa.
COLORS centraliza a paleta; cell_gap e padding configuram a geometria visual.
centerline_width controla as linhas brancas centrais tracejadas: horizontais e verticais
se encontram nos cruzamentos, com os bloqueios e marcadores desenhados por cima.
Ruas, cruzamentos, terrenos e bloqueios ocupam células quadradas de mesmo tamanho,
com separação discreta para destacar a grade da matriz. Bloqueios preservam o
fundo cinza da rua e recebem uma marcação central laranja (barricada) ou marrom
(buraco), sem preencher a célula inteira.
_draw desenha ruas, cruzamentos, terrenos, bloqueios e rota; _draw_marker desenha
destino, centro e motorista. Substitua esses dois métodos por sprites/atlas quando
estiverem prontos. O snapshot recebido por set_view já inclui matrix, destination,
route e driver; geração, validação, movimento e bridge não precisam mudar.
Nenhum sprite ou textura foi criado/importado para o bairro.

O painel reutiliza o tema do jogo e ocupa a esquerda, deixando a IDE acoplada à
direita. Fecha sem parar a automação, recalcula dimensões e oferece rolagem em
janelas pequenas. A IDE em tela cheia mantém a precedência da CanvasLayer existente.

## Verificação

22 suítes com asserções funcionais aprovadas:

- delivery_system_test: 500 sementes padrão + 30 mapas de tamanhos 2/3/7;
  conectividade de todas as células transitáveis, V-1 segmentos, geometria,
  diversidade e remoção independente de cada aresta da rota para provar unicidade.
  Rotas vazias/incompletas, diagonais, saltos, bloqueios, terrenos, limites,
  tipos, repetição, id antigo, sem pedido, durante viagem e entradas cíclicas.
  Cópias defensivas, chegada, duplicação de crédito, round-trip JSON, viagem
  interrompida, corrupção de mapa, cooldown e meta de três entregas.
  Oito entregas contínuas com BFS e uma com DFS reais. Máximo de 200 operações
  por script/frame durante a BFS; nenhuma alteração no orçamento do agendador.
- delivery_ui_test: indicadores, matriz observada e layout em quatro resoluções.
- python_like_lexer_test, python_like_parser_test, python_like_runtime_model_test,
  python_like_executor_test, script_runtime_manager_test, script_workspace_smoke_test.
- help_menu_smoke_test (inclui execução dos exemplos), console_ide_smoke_test,
  ui_viewport_contract_test, stock_only_experience_test.
- stock_contracts_test, stock_builtins_test, checkout_codes_integration_test,
  promotions_checkout_test, integrated_automation_test, integrated_progression_test,
  upgrade_economy_test, delivery_program_analyzers_test.
- save_slots_smoke_test e save_security_test, com backup/restauração dos slots.

Execute usando as cenas res://tests/<nome>.tscn. Exemplo:

    godot --headless --path . res://tests/delivery_system_test.tscn

A cena delivery_visual_preview.tscn foi executada pelo Godot MCP com renderização
nativa: mapa ao lado da IDE e interpolação/rota observadas em capturas.
Capturas temporárias ficam em .tmp quando a cena é rodada.

A exportação Web debug com templates 4.7.2 produziu HTML, JS, WASM e PCK.
Não foi possível validar a execução no navegador: o navegador integrado retornou
ERR_CONNECTION_TIMED_OUT ao acessar o servidor localhost. A exportação emite um
aviso de capitalização do caminho antigo scenes/client/dialog_screen.gd; a cena
no disco já referencia scenes/Client/dialog_screen.gd. Recursos de diálogo fora
do escopo foram preservados. O editor também emite aviso do diretório user://.

Algumas suítes reportam recursos/EnvContext não liberados ao encerrar; a inspeção
verbose identifica env_context.gd como Node órfão. A refatoração desse ciclo de vida
do runtime fica fora deste delivery. Testes sem slot emitem os avisos esperados;
save_security_test exercita intencionalmente um slot corrompido. Não houve falhas
nas asserções finais destas 22 suítes.

## Arquivos criados ou modificados

Criados:

- systems/DeliveryMapGenerator.gd
- systems/DeliveryMapGenerator.gd.uid
- systems/DeliveryRouteValidator.gd
- systems/DeliveryRouteValidator.gd.uid
- scenes/delivery/delivery_map_renderer.gd
- scenes/delivery/delivery_map_renderer.gd.uid
- tests/delivery_visual_preview.gd
- tests/delivery_visual_preview.gd.uid
- tests/delivery_visual_preview.tscn
- docs/examples/delivery_bfs.py
- docs/examples/delivery_dfs.py
- docs/delivery-navigation.md

Modificados:

- README.md
- autoload/SaveManager.gd
- data/ActiveExperience.gd
- data/DeliveryConfig.gd
- data/HelpTopics.gd
- data/UpgradeData.gd
- graphify-out/GRAPH_REPORT.md
- graphify-out/graph.json
- interpreter/python_like/runtime/python_like_automarket_bridge.gd
- interpreter/python_like/runtime/python_like_executor.gd
- interpreter/runtime/godot_automarket_python_bridge.gd
- scenes/console/components/ide_language_profiles.gd
- scenes/delivery/delivery_panel.gd
- scenes/delivery/delivery_panel.tscn
- scenes/game/game.gd
- systems/ChallengeSystem.gd
- systems/DeliverySystem.gd
- systems/ScriptWorkspace.gd
- tests/console_ide_smoke_test.gd
- tests/delivery_program_analyzers_test.gd
- tests/delivery_system_test.gd
- tests/delivery_ui_test.gd
- tests/fake_python_like_automarket_bridge.gd
- tests/help_menu_smoke_test.gd
- tests/save_slots_smoke_test.gd
- tests/script_runtime_manager_test.gd
- tests/script_workspace_smoke_test.gd
- tests/stock_only_experience_test.gd

O Graphify recebeu apenas a comunidade de navegação verificada no código, sem
rebuild geral do grafo antigo. Logs preexistentes foram preservados.

## Correções de 16/10/2026

A instância DeliveryPanel em game.tscn herdava PROCESS_MODE_DISABLED do fluxo
antigo. Removida essa configuração: o botão Fechar volta a receber eventos GUI.
O teste de UI agora clica na instância real do HUD, sem chamar close_panel direto.

Append/pop usam as operações de ListValue existentes. Um AttributeReadFrame resolve
a lista uma vez e devolve somente os métodos permitidos, reutilizando as regras
de chamada, aridade e indexação do runtime. Métodos vinculados são reutilizados
por lista e descartados com o ciclo de vida do executor; acessos repetidos não
retêm um novo método a cada volta. Não são expostos atributos do GDScript.

A nova suíte python_like_list_methods_test cobre mutação, retorno, apelidos,
indexação negativa, erros, ordem de avaliação, métodos guardados em variáveis,
listas aninhadas/cíclicas, espera cooperativa, parada e descarte. Os exemplos
de BFS e DFS agora usam os métodos; o teste delivery_system_test os executa.

Nesta correção, 14 suítes passaram nas asserções: métodos de listas, lexer, parser,
modelo de valores, executor, agendador, ajuda, delivery lógico/UI, promoções/checkout,
automação integrada, estoque, IDE e contrato de viewport. Mantêm-se os avisos de
recursos ao encerrar já descritos acima. O teste do botão reproduziu a falha antes
da remoção de PROCESS_MODE_DISABLED e passou com a mesma entrada de mouse depois.
