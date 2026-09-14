# AutoMarket — instruções para agentes

- Para qualquer tarefa relacionada à edição, execução, depuração ou teste do jogo, use o MCP Godot como interface principal com o projeto e com o editor.
- Considere `D:\AutoMarket\AutoMarket` o caminho raiz do projeto Godot em todas as chamadas ao MCP.
- Para edições e testes do jogo, não substitua o MCP Godot por automação de interface, comandos diretos do executável ou ferramentas genéricas, salvo quando o MCP não oferecer a operação necessária ou estiver indisponível. Nesse caso, informe claramente a limitação antes de usar uma alternativa.


## Projeto

Este repositório contém um jogo educativo desenvolvido em Godot e destinado também à exportação web.

O jogador automatiza sistemas do jogo escrevendo scripts em uma linguagem própria semelhante a C. O interpretador é implementado em GDScript e possui, de forma geral:

* lexer;
* parser;
* nós de AST;
* executor baseado em Visitor;
* ASTPrinter;
* funções built-in;
* modos de execução síncrona e assíncrona.

O projeto prioriza clareza educacional, estabilidade, mudanças incrementais e compatibilidade com sistemas já existentes.

## Princípios gerais

Antes de modificar qualquer código:

1. Leia os arquivos diretamente relacionados à tarefa.
2. Identifique o fluxo atual e as dependências.
3. Confirme nomes reais de arquivos, classes, nós, sinais e funções.
4. Não suponha que uma API existe sem verificar.
5. Faça a menor alteração que resolva corretamente o problema.

Evite:

* refatorações fora do escopo;
* abstrações criadas para uso hipotético;
* duplicação de sistemas existentes;
* renomeações amplas sem necessidade;
* alterações cosméticas misturadas com mudanças funcionais;
* substituir uma solução estável apenas por preferência arquitetural.

Preserve as interfaces públicas existentes sempre que possível.

## Godot

Ao modificar cenas, scripts ou recursos:

* verifique caminhos de nós antes de usá-los;
* preserve conexões de sinais existentes;
* evite conectar o mesmo sinal mais de uma vez;
* considere que um nó pode ainda não estar pronto;
* não invente autoloads, singletons ou EventBus;
* mantenha lógica de domínio fora da interface quando já existir uma camada apropriada;
* considere compatibilidade com exportação web;
* evite operações bloqueantes na thread principal.

Sempre investigue a origem de valores `null` em vez de apenas adicionar verificações defensivas que escondam o problema.

## Interpretador

Mudanças no interpretador exigem atenção especial.

Ao adicionar ou alterar sintaxe, avalie todos os componentes relevantes:

* tokens e lexer;
* regras do parser;
* nós da AST;
* ASTPrinter;
* executor;
* escopos;
* mensagens de erro;
* scripts de teste ou exemplos.

Preserve:

* escopo estático;
* precedência dos operadores;
* comportamento de operadores prefixos e pós-fixos;
* propagação correta de `return`;
* funcionamento de `break` e `continue`;
* arrays estáticos;
* pilhas de chamadas e escopos;
* obrigatoriedade de `main`, quando aplicável.

Não faça uma refatoração profunda do interpretador sem solicitação explícita.

Não implemente funções assíncronas bloqueando a execução principal.

Loops executados pelo modo síncrono não podem travar a Godot. Analise limites, interrupção, orçamento de execução ou o mecanismo assíncrono já existente antes de modificar o comportamento de `while` ou `for`.

Cada alteração funcional no interpretador deve incluir ao menos um script mínimo que demonstre o comportamento esperado e, quando relevante, um caso de erro ou regressão.

## Gameplay

Mudanças de gameplay devem preservar o objetivo educacional.

Antes de concluir uma mecânica, verifique:

* qual conceito de programação ela pretende ensinar;
* se existe uma solução trivial que ignora esse conceito;
* se a regra pode ser explorada;
* se desafios anteriores continuam funcionando;
* se o jogador recebe informação suficiente para entender a tarefa;
* se recompensas, tempos e custos permanecem coerentes.

Não aumente a complexidade do código do jogador apenas para tornar o desafio artificialmente difícil.

Prefira entradas e saídas simples, regras observáveis e resultados determinísticos.

## Saves e progressão

Não altere nomes, tipos ou estruturas persistidas sem verificar o sistema de save.

Quando uma mudança de formato for necessária:

* preserve compatibilidade quando possível;
* forneça migração ou valores padrão;
* não apague progresso silenciosamente;
* documente claramente a alteração.

Mudanças em dinheiro, upgrades, estoque, clientes ou recompensas devem ser verificadas quanto a exploits e regressões de progressão.

## Uso de subagentes

Não use subagentes automaticamente para tarefas pequenas, locais ou de causa evidente.

Use subagentes quando houver:

* investigação independente em vários sistemas;
* revisão especializada do interpretador;
* auditoria ampla de UI;
* análise de gameplay ou economia;
* revisão independente de uma mudança crítica;
* partes realmente independentes que possam ser analisadas em paralelo.

Papéis recomendados:

### Investigador

Trabalha preferencialmente em modo somente leitura.

Entrega:

* arquivos relevantes;
* descrição do fluxo atual;
* causa provável;
* riscos;
* pontos seguros de alteração.

Não edita arquivos e não delega para outros agentes.

### Revisor do interpretador

Analisa mudanças em lexer, parser, AST, executor, escopos e funções built-in.

Entrega:

* incompatibilidades;
* regressões possíveis;
* casos de teste;
* correções necessárias.

Não deve propor uma reescrita completa quando uma alteração incremental for suficiente.

### Revisor Godot

Verifica cenas, sinais, caminhos de nós, recursos, ciclo de vida e compatibilidade web.

### Revisor de gameplay

Avalia clareza, objetivo educacional, soluções triviais, exploits, economia e regressões.

O agente principal continua responsável por:

* decidir a solução;
* editar os arquivos;
* integrar os resultados;
* executar verificações;
* revisar o diff final.

Não permita que dois agentes editem os mesmos arquivos simultaneamente.

Subagentes não devem criar outros subagentes, salvo solicitação explícita.

## Processo de trabalho

Para tarefas não triviais:

1. Investigue o comportamento atual.
2. Identifique os arquivos que realmente precisam mudar.
3. Elabore um plano curto.
4. Implemente em etapas pequenas.
5. Execute as verificações disponíveis.
6. Revise o diff completo.
7. Remova mudanças acidentais ou fora do escopo.
8. Resuma o resultado e as limitações.

Não pare apenas na análise quando a tarefa solicitar implementação.

Não declare que uma mudança funciona sem executar alguma forma relevante de verificação.

## Verificação

Use os testes e comandos existentes no repositório.

Quando não houver teste automatizado adequado:

* crie ou utilize um script mínimo de reprodução;
* valide parsing e execução para alterações no interpretador;
* valide caminhos de nós e sinais para alterações Godot;
* revise o diff;
* informe claramente o que foi e o que não foi testado.

Não introduza ferramentas, frameworks ou dependências apenas para testar uma mudança pequena.

## Escopo e qualidade

Uma tarefa está concluída quando:

* o comportamento solicitado foi implementado;
* a causa do problema foi tratada, não apenas mascarada;
* as mudanças permaneceram dentro do escopo;
* não existem alterações acidentais no diff;
* verificações relevantes foram executadas;
* riscos ou limitações restantes foram informados.

Ao finalizar, apresente:

* resumo do que mudou;
* arquivos principais alterados;
* verificações realizadas;
* limitações ou próximos riscos, apenas quando existirem.

## Agent skills

### Issue tracker

Issues e especificações são rastreadas no GitHub Issues deste repositório. Veja `docs/agents/issue-tracker.md`.

### Triage labels

A triagem usa os cinco rótulos canônicos padrão. Veja `docs/agents/triage-labels.md`.

### Domain docs

A documentação de domínio segue o layout single-context. Veja `docs/agents/domain.md`.
