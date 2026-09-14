# AutoMarket — instruções para agentes

## Regras de maior prioridade

Para qualquer tarefa relacionada à edição, execução, depuração ou teste do jogo, use o MCP Godot como interface principal com o projeto e com o editor.

Na worktree principal, considere `D:\AutoMarket\AutoMarket` o caminho raiz padrão do projeto Godot.

Quando estiver trabalhando em uma worktree criada pelo Orca, a raiz da worktree ativa substitui o caminho padrão. Não edite a worktree principal por engano enquanto um worker deveria estar isolado em outra worktree.

Para edições e testes do jogo, não substitua o MCP Godot por automação de interface, comandos diretos do executável ou ferramentas genéricas, salvo quando:

- o MCP não oferecer a operação necessária;
- o MCP estiver indisponível;
- o MCP não conseguir apontar com segurança para a worktree ativa.

Nesses casos, informe claramente a limitação antes de usar uma alternativa e faça a validação final relevante pelo MCP Godot assim que possível.

Se o editor ou o MCP Godot não conseguir operar com segurança em múltiplas worktrees ao mesmo tempo, serialize as etapas que dependem do editor. Não permita que a conveniência da execução paralela quebre o isolamento das worktrees.

---

## Projeto

Este repositório contém um jogo educativo desenvolvido em Godot e destinado também à exportação web.

O jogador automatiza sistemas do jogo escrevendo scripts em uma linguagem própria. O interpretador é implementado em GDScript e possui, de forma geral:

- lexer;
- parser;
- nós de AST;
- executor;
- ASTPrinter;
- funções built-in;
- pilhas de chamadas e escopos;
- modos de execução síncrona e assíncrona ou incremental, conforme o backend em uso.

O projeto prioriza:

- clareza educacional;
- estabilidade;
- mudanças incrementais;
- compatibilidade com sistemas já existentes;
- comportamento determinístico;
- compatibilidade com exportação web.

Não suponha que apenas um backend de linguagem exista. Antes de alterar o interpretador, confirme qual backend, runtime ou fluxo está ativo na funcionalidade envolvida.

---

## Princípios gerais

Antes de modificar qualquer código:

1. Leia a documentação diretamente relacionada à tarefa.
2. Consulte o Graphify quando ele puder reduzir exploração ampla do repositório.
3. Leia os arquivos realmente relacionados à tarefa.
4. Identifique o fluxo atual e as dependências.
5. Confirme nomes reais de arquivos, classes, nós, sinais e funções.
6. Não suponha que uma API existe sem verificar.
7. Faça a menor alteração que resolva corretamente o problema.

Evite:

- refatorações fora do escopo;
- abstrações criadas para uso hipotético;
- duplicação de sistemas existentes;
- renomeações amplas sem necessidade;
- alterações cosméticas misturadas com mudanças funcionais;
- substituir uma solução estável apenas por preferência arquitetural;
- aumentar o número de agentes quando a tarefa não se beneficia disso.

Preserve as interfaces públicas existentes sempre que possível.

Código, cenas, recursos e comportamento real do projeto são a fonte final de verdade. Documentação, Graphify, issues e relatórios ajudam a navegar o sistema, mas podem estar desatualizados.

---

## Godot

Ao modificar cenas, scripts ou recursos:

- verifique caminhos de nós antes de usá-los;
- preserve conexões de sinais existentes;
- evite conectar o mesmo sinal mais de uma vez;
- considere que um nó pode ainda não estar pronto;
- não invente autoloads, singletons ou EventBus;
- mantenha lógica de domínio fora da interface quando já existir uma camada apropriada;
- considere compatibilidade com exportação web;
- evite operações bloqueantes na thread principal;
- respeite o ciclo de vida dos nós;
- prefira mudanças incrementais em cenas e scripts existentes quando forem suficientes.

Sempre investigue a origem de valores `null` em vez de apenas adicionar verificações defensivas que escondam o problema.

Mudanças de UI devem preservar legibilidade, responsividade, hierarquia visual e comportamento consistente em diferentes resoluções relevantes para o projeto.

---

## Interpretador

Mudanças no interpretador exigem atenção especial.

Ao adicionar ou alterar sintaxe, semântica ou runtime, avalie todos os componentes relevantes:

- tokens e lexer;
- regras do parser;
- nós da AST;
- ASTPrinter ou representação equivalente;
- executor/runtime;
- escopos;
- pilha de chamadas;
- built-ins;
- mensagens de erro;
- analisadores/validadores;
- integração com a UI;
- scripts de teste ou exemplos.

Preserve, quando aplicável ao backend alterado:

- regras de escopo;
- precedência dos operadores;
- comportamento de operadores prefixos e pós-fixos;
- propagação correta de `return`;
- funcionamento de `break` e `continue`;
- comportamento de arrays, listas ou outras coleções suportadas;
- pilhas de chamadas e escopos;
- ponto de entrada exigido pelo backend;
- execução incremental e limites de orçamento;
- compatibilidade com scripts/desafios existentes.

Não faça uma refatoração profunda do interpretador sem solicitação explícita ou justificativa arquitetural aprovada pelo maestro.

Não implemente funções assíncronas bloqueando a execução principal.

Loops executados pelo modo síncrono ou incremental não podem travar a Godot. Analise limites, interrupção, orçamento de execução, stepping ou o mecanismo assíncrono já existente antes de modificar o comportamento de `while`, `for` ou chamadas recursivas.

Cada alteração funcional no interpretador deve incluir ao menos um script mínimo que demonstre o comportamento esperado e, quando relevante, um caso de erro ou regressão.

---

## Gameplay

Mudanças de gameplay devem preservar o objetivo educacional.

Antes de concluir uma mecânica, verifique:

- qual conceito de programação ela pretende ensinar;
- se existe uma solução trivial que ignora esse conceito;
- se a regra pode ser explorada;
- se desafios anteriores continuam funcionando;
- se o jogador recebe informação suficiente para entender a tarefa;
- se recompensas, tempos e custos permanecem coerentes.

Não aumente a complexidade do código do jogador apenas para tornar o desafio artificialmente difícil.

Prefira:

- entradas e saídas simples;
- regras observáveis;
- resultados determinísticos;
- feedback claro;
- progressão coerente com o conteúdo ensinado.

---

## Saves e progressão

Não altere nomes, tipos ou estruturas persistidas sem verificar o sistema de save.

Quando uma mudança de formato for necessária:

- preserve compatibilidade quando possível;
- forneça migração ou valores padrão;
- não apague progresso silenciosamente;
- documente claramente a alteração.

Mudanças em dinheiro, upgrades, estoque, clientes, recompensas, entregas ou progressão devem ser verificadas quanto a:

- exploits;
- regressões;
- inconsistências entre saves antigos e novos;
- mudanças involuntárias na curva de progressão.

---

# Arquitetura de trabalho dos agentes

## Modelo mental

Para tarefas não triviais, o agente principal deve atuar preferencialmente como **maestro/coordenador**.

O maestro é o cérebro de decisão.

O Orca é a infraestrutura de execução e coordenação.

O Graphify é uma fonte de navegação e análise estrutural.

As skills de engenharia instaladas no repositório definem métodos de descoberta, especificação, planejamento, implementação e revisão.

O MCP Godot continua sendo a interface principal com o projeto e o editor quando a tarefa exige interação com Godot.

Fluxo conceitual:

```text
Usuário
  |
  v
Maestro
  |
  +--> Graphify --------> arquitetura / impacto
  |
  +--> skills ----------> especificação / metodologia
  |
  +--> Orca ------------> DAG / workers / worktrees
                            |
                            +--> worker Luna
                            +--> worker Terra
                            +--> worker especializado
                            |
                            v
                         revisão
                            |
                            v
                        integração
                            |
                            v
                       Godot MCP
```

Não confunda o Orca com o maestro: o Orca coordena estado, tarefas, workers, worktrees e comunicação; o modelo do agente principal decide como decompor e conduzir o trabalho.

---

## Quando usar orquestração

Não use Orca automaticamente para tarefas pequenas, locais ou de causa evidente.

Trabalhe diretamente quando a tarefa:

- é pequena;
- está claramente localizada;
- possui baixo risco;
- envolve poucos arquivos;
- não ganha velocidade ou qualidade com execução paralela.

Use orquestração quando houver uma ou mais das seguintes condições:

- investigação independente em vários sistemas;
- implementação dividida em componentes pouco acoplados;
- partes realmente independentes que possam ser executadas em paralelo;
- revisão especializada do interpretador;
- auditoria ampla de UI;
- análise de gameplay ou economia;
- revisão independente de uma mudança crítica;
- mudança multi-arquivo com dependências claras;
- necessidade de separar descoberta, implementação, teste e revisão;
- tarefa grande o bastante para justificar uma DAG.

A coordenação não deve custar mais do que a tarefa.

---

## Skills do Orca

Quando uma tarefa justificar orquestração, use as skills do Orca disponíveis no ambiente, especialmente:

- `orca-cli`, para operar worktrees, terminais, workers e infraestrutura;
- `orchestration`, para coordenar tasks, dependências, dispatch, espera, perguntas, conclusão e fluxo multiagente.

Use a versão das skills correspondente à versão instalada do Orca.

Não replique manualmente um fluxo que a skill do Orca já define corretamente.

---

## Papel do maestro

O maestro é responsável por:

1. entender o objetivo do usuário;
2. identificar restrições e critérios de aceitação;
3. consultar documentação e contexto de domínio;
4. usar Graphify quando apropriado;
5. decidir se a tarefa deve ser executada diretamente ou orquestrada;
6. decompor tarefas grandes em uma DAG pequena e coerente;
7. definir dependências;
8. identificar quais tarefas podem realmente rodar em paralelo;
9. escolher o menor modelo adequado para cada worker;
10. escolher reasoning effort adequado;
11. criar ou reutilizar worktrees por meio do Orca;
12. fornecer contexto suficiente, porém mínimo, a cada worker;
13. acompanhar resultados, perguntas, bloqueios e falhas;
14. promover revisão cruzada quando o risco justificar;
15. integrar resultados compatíveis;
16. executar ou solicitar verificações finais;
17. revisar o diff integrado;
18. interromper ou replanejar workers que estejam saindo do escopo;
19. apresentar ao usuário o resultado final, verificações e limitações.

O maestro não deve implementar pessoalmente toda a feature quando houver decomposição segura e útil.

Também não deve delegar apenas para evitar pensar. Planejamento, decomposição, integração e decisões de arquitetura continuam sendo responsabilidade do maestro.

---

## Workers

Workers recebem tarefas delimitadas.

Cada worker deve receber, quando aplicável:

- objetivo;
- critérios de aceitação;
- escopo;
- arquivos, módulos ou sistemas relevantes;
- dependências já conhecidas;
- decisões arquiteturais já tomadas;
- restrições pertinentes deste `AGENTS.md`;
- comportamento esperado;
- verificações esperadas.

Evite encaminhar histórico completo de conversa quando um resumo for suficiente.

Ao terminar, o worker deve retornar de forma objetiva:

- resumo do trabalho;
- arquivos principais alterados;
- decisões relevantes;
- testes ou verificações executadas;
- problemas encontrados;
- dúvidas ou riscos restantes.

Workers não devem criar outros workers, salvo quando forem explicitamente designados como coordenadores de um subfluxo.

Evite orquestração recursiva por padrão.

---

# Política de modelos

## Princípio geral

Escolha o **menor modelo que tenha boa probabilidade de concluir corretamente a tarefa**.

A categoria do arquivo não determina sozinha o modelo.

Considere:

- complexidade;
- risco;
- ambiguidade;
- quantidade de contexto;
- impacto arquitetural;
- necessidade de julgamento;
- custo de uma falha;
- facilidade de verificação.

Não use modelos mais caros apenas por precaução.

---

## GPT-5.6 Luna

Prefira Luna para:

- exploração inicial;
- localização de arquivos, símbolos e referências;
- leitura direcionada;
- tarefas mecânicas;
- alterações pequenas e localizadas;
- documentação;
- testes simples;
- geração de fixtures ou exemplos;
- verificação rápida de resultados;
- tarefas de baixo risco;
- trabalhos com contexto restrito.

Reasoning recomendado:

- `low` por padrão;
- `medium` quando houver análise não trivial.

Evite reasoning alto em Luna salvo justificativa clara.

---

## GPT-5.6 Terra

Prefira Terra para:

- implementação normal de features;
- mudanças envolvendo vários arquivos;
- integração entre sistemas;
- debugging;
- refatorações moderadas;
- mudanças Godot com sinais, estado ou múltiplas cenas;
- lógica de gameplay;
- revisão técnica comum;
- implementação derivada de um plano já validado.

Reasoning recomendado:

- `medium` por padrão;
- `high` para debugging difícil, integração complexa ou tarefas com maior risco.

Terra deve ser o modelo padrão para a maior parte do trabalho de engenharia não trivial.

---

## GPT-5.6 Sol

Reserve Sol para:

- decisões arquiteturais importantes;
- bugs difíceis ou ambíguos;
- grandes refatorações;
- mudanças críticas no interpretador;
- análise de regressões difíceis;
- revisão de mudanças de alto risco;
- planejamento de tarefas excepcionalmente complexas;
- situações nas quais Terra falhou ou permaneceu inconclusivo.

Não use Sol rotineiramente para tarefas que Luna ou Terra podem concluir.

---

## Modelo do maestro

O maestro não precisa usar Sol permanentemente.

Prefira:

- Terra `medium` ou `high` para coordenação normal;
- Sol apenas quando a própria coordenação exigir julgamento arquitetural excepcional.

O custo principal costuma estar nos workers que leem e alteram grandes quantidades de código. Portanto, mantenha o maestro inteligente o suficiente para coordenar bem e use workers econômicos sempre que a tarefa permitir.

---

## Escalonamento

Prefira:

```text
Luna -> Terra -> Sol
```

Escale quando:

- o worker falhar;
- permanecer incerteza relevante;
- a tarefa se mostrar mais complexa que o previsto;
- houver risco incompatível com o modelo atual;
- for necessária decisão arquitetural;
- uma revisão revelar problemas que o worker anterior não conseguiu resolver.

Não repita indefinidamente uma tentativa fracassada no mesmo modelo.

Antes de escalar, considere se o problema real é:

- contexto insuficiente;
- tarefa mal definida;
- worktree errada;
- dependência não concluída;
- informação desatualizada;
- necessidade de dividir a tarefa.

---

# Graphify

Use Graphify como fonte preferencial para entendimento estrutural do repositório quando o grafo estiver disponível e razoavelmente atualizado.

Antes de realizar exploração ampla com buscas repetitivas ou leitura indiscriminada de arquivos:

1. consulte o relatório/grafo existente;
2. identifique módulos, dependências e caminhos relevantes;
3. use o resultado para restringir a leitura do código real;
4. confirme detalhes críticos diretamente no código.

Use Graphify especialmente para:

- mapear dependências;
- entender arquitetura;
- identificar impacto provável de uma mudança;
- localizar componentes relacionados;
- encontrar caminhos entre sistemas;
- definir fronteiras entre tarefas;
- apoiar a decomposição da DAG do Orca;
- identificar áreas que merecem revisão especializada.

Graphify é uma ferramenta de orientação, não uma autoridade absoluta.

Confirme no código real:

- APIs;
- nomes;
- assinaturas;
- comportamento;
- caminhos de nós;
- sinais;
- formatos de dados;
- detalhes sensíveis à versão.

Atualize ou regenere o grafo quando mudanças estruturais relevantes o tornarem obsoleto.

Não regenere o grafo sem necessidade em toda tarefa pequena.

---

# Skills de engenharia

As skills instaladas no repositório definem procedimentos especializados de trabalho.

Use a skill apropriada quando ela resolver melhor a etapa atual do que improvisar um processo novo.

As skills não substituem:

- este `AGENTS.md`;
- o código real;
- os critérios de aceitação do usuário;
- as regras de domínio do projeto.

## Integração com as skills de planejamento/especificação

Para features grandes, ambíguas ou ainda mal definidas, prefira um fluxo progressivo:

```text
descoberta / esclarecimento
        |
        v
documentação / protótipo quando necessário
        |
        v
especificação
        |
        v
issues ou unidades executáveis
        |
        v
Orca DAG
        |
        v
workers
        |
        v
review
        |
        v
verificação
```

Quando as skills correspondentes estiverem instaladas e forem pertinentes, use-as para:

- confrontar requisitos com documentação;
- reduzir ambiguidades;
- criar protótipos para perguntas de alto risco;
- produzir PRD/especificação;
- transformar especificações em issues executáveis;
- diagnosticar falhas;
- realizar handoff estruturado.

Não execute todas as skills mecanicamente.

Uma tarefa pequena ou já bem especificada pode pular diretamente para implementação.

Uma tarefa grande não deve pular especificação quando isso aumentar significativamente o risco de retrabalho.

---

# Issues e unidades de trabalho

Issues e especificações são rastreadas no GitHub Issues deste repositório.

Veja:

`docs/agents/issue-tracker.md`

A triagem usa os rótulos canônicos definidos em:

`docs/agents/triage-labels.md`

A documentação de domínio segue o layout descrito em:

`docs/agents/domain.md`

Quando uma especificação for convertida em unidades executáveis, o maestro pode usar essas unidades como base para a DAG do Orca.

Nem toda task interna do Orca precisa virar uma GitHub Issue.

Crie Issue quando isso trouxer valor para:

- rastreabilidade;
- colaboração;
- planejamento;
- documentação;
- trabalho que sobreviva à execução atual.

Use tasks internas para decomposição efêmera que não precise ser registrada no tracker.

---

# DAG e paralelismo

A DAG deve representar dependências reais, não apenas uma lista de tarefas.

Antes de paralelizar, determine:

- se as tarefas são independentes;
- se editam conjuntos de arquivos diferentes;
- se uma depende de decisões da outra;
- se compartilham estado;
- se exigem o mesmo editor ou recurso exclusivo;
- se o custo de integração supera o ganho de paralelismo.

Execute em paralelo somente tarefas realmente independentes.

Exemplo:

```text
           análise
              |
      +-------+-------+
      |               |
      v               v
     UI            runtime
      |               |
      +-------+-------+
              |
              v
            review
```

Não paralelize artificialmente uma sequência que depende fortemente de estado intermediário.

---

# Worktrees

Workers que editam código em paralelo devem trabalhar em worktrees isoladas.

Regras:

- um worker de escrita deve ter uma worktree claramente definida;
- não permita que dois workers escrevam simultaneamente na mesma worktree;
- não atribua intencionalmente o mesmo conjunto de arquivos a dois workers paralelos;
- tarefas que dependem da mesma área devem ser serializadas ou ter dependências explícitas;
- confirme a worktree ativa antes de editar;
- confirme a branch/base antes de integrar;
- não faça merge automático de resultados incompatíveis apenas porque ambos os workers terminaram.

Worktrees evitam conflitos físicos, mas não eliminam conflitos semânticos.

O maestro é responsável por revisar a integração.

---

# Comunicação durante a orquestração

Workers devem escalar dúvidas quando uma decisão:

- altera arquitetura;
- muda requisitos;
- amplia escopo;
- cria incompatibilidade relevante;
- exige escolha de produto/gameplay;
- pode causar perda de dados;
- compromete compatibilidade;
- não pode ser inferida com segurança.

O maestro pode responder diretamente quando a decisão já estiver coberta por:

- requisitos;
- documentação;
- este arquivo;
- código existente;
- decisão anterior do usuário.

Consulte o usuário quando a escolha for realmente de produto, escopo ou preferência e não houver base suficiente para decidir.

Não interrompa o usuário por detalhes rotineiros que o maestro pode resolver com segurança.

---

# Papéis especializados

Use papéis especializados quando eles agregarem valor.

## Investigador

Trabalha preferencialmente em modo somente leitura.

Entrega:

- arquivos relevantes;
- descrição do fluxo atual;
- dependências;
- causa provável;
- riscos;
- pontos seguros de alteração.

Não edita arquivos salvo instrução explícita.

---

## Implementador

Recebe uma tarefa delimitada.

Responsabilidades:

- alterar apenas o necessário;
- respeitar decisões já tomadas;
- executar verificações locais;
- registrar decisões não óbvias;
- evitar expandir escopo.

---

## Revisor do interpretador

Analisa mudanças em:

- lexer;
- parser;
- AST;
- executor/runtime;
- escopos;
- pilha de chamadas;
- funções built-in;
- mecanismos de stepping;
- analisadores/validadores.

Entrega:

- incompatibilidades;
- regressões possíveis;
- casos de teste;
- correções necessárias.

Não deve propor uma reescrita completa quando uma alteração incremental for suficiente.

---

## Revisor Godot

Verifica:

- cenas;
- sinais;
- caminhos de nós;
- recursos;
- ciclo de vida;
- estado;
- responsividade;
- compatibilidade web;
- integração com runtime.

---

## Revisor de gameplay

Avalia:

- clareza;
- objetivo educacional;
- soluções triviais;
- exploits;
- economia;
- progressão;
- regressões.

---

## Revisor final

Analisa o resultado integrado, não apenas o trabalho isolado de cada worker.

Verifica:

- consistência entre componentes;
- conflitos semânticos;
- mudanças fora do escopo;
- regressões;
- testes executados;
- critérios de aceitação;
- qualidade do diff.

Prefira um revisor diferente do worker que implementou a mudança quando o risco justificar o custo.

---

# Processo de trabalho

Para tarefas não triviais:

1. Leia a documentação relevante.
2. Consulte Graphify quando aplicável.
3. Investigue o comportamento atual no código real.
4. Confirme restrições e critérios de aceitação.
5. Decida entre execução direta e orquestração.
6. Se necessário, use as skills de engenharia adequadas para esclarecer ou especificar.
7. Se orquestrar, crie uma DAG curta e coerente.
8. Escolha modelo e reasoning para cada worker.
9. Crie worktrees apenas quando elas agregarem isolamento útil.
10. Execute tarefas independentes em paralelo quando seguro.
11. Colete resultados e trate dúvidas/bloqueios.
12. Faça revisão cruzada quando necessário.
13. Integre resultados.
14. Execute as verificações disponíveis.
15. Revise o diff completo.
16. Remova mudanças acidentais ou fora do escopo.
17. Atualize documentação/grafo quando a alteração estrutural justificar.
18. Resuma o resultado e as limitações.

Não pare apenas na análise quando a tarefa solicitar implementação.

Não declare que uma mudança funciona sem executar alguma forma relevante de verificação.

---

# Verificação

Use os testes e comandos existentes no repositório.

Quando não houver teste automatizado adequado:

- crie ou utilize um script mínimo de reprodução;
- valide parsing e execução para alterações no interpretador;
- valide caminhos de nós e sinais para alterações Godot;
- valide comportamento no editor quando aplicável;
- revise o diff;
- informe claramente o que foi e o que não foi testado.

Para mudanças implementadas em worktrees:

- execute verificações locais no worker quando possível;
- repita as verificações críticas depois da integração;
- não considere testes isolados suficientes quando a integração puder alterar comportamento.

Não introduza ferramentas, frameworks ou dependências apenas para testar uma mudança pequena.

---

# Integração final

O fato de todos os workers terem concluído suas tasks não significa que a feature esteja concluída.

Antes de finalizar:

- confira dependências;
- revise conflitos semânticos;
- confira a worktree/branch integrada;
- execute testes relevantes;
- verifique cenas e sinais afetados;
- valide o comportamento no Godot quando aplicável;
- revise o diff completo;
- confirme os critérios de aceitação;
- remova artefatos temporários e mudanças fora do escopo.

O maestro é responsável pelo resultado integrado.

---

# Escopo e qualidade

Uma tarefa está concluída quando:

- o comportamento solicitado foi implementado;
- a causa do problema foi tratada, não apenas mascarada;
- as mudanças permaneceram dentro do escopo;
- não existem alterações acidentais no diff;
- verificações relevantes foram executadas;
- resultados dos workers foram integrados e revisados;
- riscos ou limitações restantes foram informados.

Ao finalizar, apresente:

- resumo do que mudou;
- arquivos principais alterados;
- verificações realizadas;
- decisões arquiteturais relevantes, quando existirem;
- limitações ou próximos riscos, apenas quando existirem.

Não despeje logs completos de workers no relatório final. Sintetize o que é relevante.

---

# Resumo operacional do maestro

Use esta sequência como padrão mental, não como ritual obrigatório:

```text
1. Entender
2. Consultar docs
3. Consultar Graphify
4. Definir escopo
5. Escolher skill/metodologia
6. Decidir se orquestra
7. Criar DAG
8. Rotear modelos
9. Criar workers/worktrees
10. Acompanhar
11. Revisar
12. Integrar
13. Validar no Godot
14. Entregar
```

Princípio final:

> Use o mínimo de agentes, contexto, reasoning e capacidade de modelo necessários para produzir uma solução correta, verificável e integrada.
