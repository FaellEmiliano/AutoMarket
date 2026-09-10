# Especificação técnica da linguagem Python-like do AutoMarket

Status: proposta normativa para implementação incremental

ID da linguagem: `python_like`

Escopo deste documento: linguagem, runtime e integração; nenhuma implementação é definida aqui.

Os termos **DEVE**, **NÃO DEVE**, **PODE** e **PENDENTE** indicam, respectivamente, requisito obrigatório, proibição, opção de implementação compatível e decisão ainda não tomada.

## 1. Objetivo e limites

A linguagem Python-like será o segundo backend de programação do AutoMarket. Ela deve reduzir o custo sintático para que a dificuldade dos desafios venha de decomposição, condições, repetição, funções e estruturas de dados, e não de declarações de tipos, chaves ou gerenciamento manual de arrays.

Ela é Python-like, e não Python completo, porque:

- implementa somente o subconjunto necessário ao jogo e à progressão pedagógica;
- precisa pausar depois de uma quantidade controlada de operações, inclusive no meio de expressões, chamadas e loops;
- precisa ser interrompível sem threads e sem bloquear a thread principal da Godot;
- expõe APIs próprias do gameplay e fatos pedagógicos que não existem em Python;
- precisa ter consumo de memória, recursão, saída e custo de operações limitados;
- não carrega a biblioteca padrão, o sistema de imports nem o modelo de objetos completo do Python.

Sempre que este documento não registrar uma diferença, o comportamento observável deve seguir Python 3: precedência, ordem de avaliação, escopo de função, truthiness, short-circuit, indexação negativa, mutabilidade e representação textual básica. Uma coincidência acidental com o interpretador C-like atual não constitui regra.

As diferenças exigidas pelo runtime controlado são normativas:

- o programa executa no nível superior e não exige `main()`;
- `wait(segundos)` suspende cooperativamente somente o runtime chamador;
- toda execução é incremental e sujeita aos budgets do scheduler;
- profundidade de chamadas, tamanho de valores e saída são limitáveis;
- operações potencialmente grandes devem ser decomponíveis ou cobrar custo proporcional;
- mutação da coleção iterada falha de forma determinística;
- erros carregam posição e identidade da fonte em formato estruturado;
- somente nomes e métodos documentados estão disponíveis; não há introspecção irrestrita.

O backend deve implementar `LanguageRuntimeBackend`: configurar a identidade do runtime, iniciar fonte e contexto, executar um orçamento de operações, responder a stop, informar estado e encaminhar saída, término, erro e pedido de sleep. A implementação deve funcionar na exportação web da Godot e não pode depender de threads, subprocessos, reflexão de Python ou código nativo externo.

## 2. Fases da linguagem

### 2.1 MVP

O MVP inclui:

- execução sequencial no nível superior;
- literais `int`, `float`, `str`, `True`, `False` e `None`;
- variáveis e tipagem dinâmica;
- atribuição simples e `+=`, `-=`, `*=`, `/=`, `//=`, `%=`;
- operadores aritméticos, comparações e `and`, `or`, `not`;
- `if`/`elif`/`else`, `while`, `for` e `range`;
- `def`, chamadas posicionais, `return`, `break` e `continue`;
- listas e dicionários, indexação, atribuição por índice e índices negativos de listas;
- `len`, associação com `in`/`not in`, `list.append`, `list.pop`, `dict.get` e `dict.pop`;
- built-ins atuais do jogo, apresentados como valores neutros;
- `wait(segundos)` cooperativo; `await` não existe;
- execução incremental, stop, isolamento entre abas, limite de recursão e erros posicionais;
- metadados suficientes para fatos pedagógicos e suporte futuro da IDE.

### 2.2 Expansão imediata

Depois da estabilidade do MVP:

- `list.extend`, `insert`, `remove`, `sort` e `reverse`;
- `dict.items`, `keys`, `values` e `update`;
- iteração e indexação de strings;
- associação em strings;
- atribuição encadeada, se houver necessidade pedagógica;
- mensagens e recuperação de parser mais abrangentes;
- fatos pedagógicos e consultas semânticas expostos aos desafios;
- limites configuráveis por desafio, preservando um mínimo global seguro.

### 2.3 Recursos futuros

- tuples e sets, necessários posteriormente para coordenadas, mapas e posições visitadas;
- módulos educacionais controlados e imports por lista permitida;
- anotações de tipo opcionais e análise estática mais forte;
- slicing;
- comprehensions;
- f-strings;
- argumentos nomeados e valores padrão;
- recursos adicionais de IDE e refatoração segura.

Esses itens não são promessa de sintaxe idêntica ao Python até receberem especificação própria.

### 2.4 Explicitamente fora de escopo

No MVP e na expansão imediata ficam fora:

- classes e herança;
- imports e módulos;
- exceções definidas pelo jogador e `raise`;
- `try`/`except`/`finally`;
- decorators;
- generators e `yield`;
- comprehensions;
- lambdas;
- argumentos nomeados;
- valores padrão em parâmetros;
- `*args` e `**kwargs`;
- type annotations;
- pattern matching;
- `async`/`await`;
- operator overloading;
- slicing;
- f-strings;
- tuples e sets;
- metaclasses, descriptors, reflexão e acesso arbitrário a objetos Godot.

## 3. Léxico

### 3.1 Identificadores

Um identificador começa por `_` ou por uma letra Unicode e continua com `_`, letras Unicode ou dígitos. A normalização Unicode não altera silenciosamente a fonte: dois identificadores só são iguais se suas sequências de caracteres forem iguais. Keywords são reservadas exatamente com a capitalização documentada.

O MVP não permite nomes reservados do host nem acesso por identificadores iniciados e terminados por `__`. Essa restrição impede a aparência de um modelo de objetos Python que não existe. O diagnóstico deve apontar o identificador completo.

### 3.2 Keywords do MVP

Lista exata:

```text
and  break  continue  def  elif  else  False  for  if  in
None  not  or  return  True  while
```

`await`, `async`, `class`, `import`, `pass`, `try`, `except`, `lambda`, `yield` e demais palavras do Python não são keywords implementadas nem recebem tokens próprios no MVP. Elas são grafias reservadas: o lexer pode entregá-las como `NAME`, mas o parser deve reconhecê-las pelo lexema e produzir erro sintático de recurso não suportado quando aparecerem onde um nome seria aceito. Assim, não viram variáveis ou APIs implícitas e a lista de tokens permanece fechada.

### 3.3 Números

- Inteiro decimal: `0` ou uma sequência de dígitos; `_` entre dígitos segue Python, por exemplo `1_000`.
- Float decimal: `1.0`, `.5`, `2.`, `1e3`, `2.5e-2`; `_` pode separar dígitos, nunca tocar ponto ou expoente.
- Prefixos binário, octal e hexadecimal ficam fora do MVP.
- Sinal não pertence ao token numérico; `-2` é operador `-` seguido por `INT`.
- Sufixos, infinitos e NaN literais não existem.

O lexer rejeita `_` duplicado, `_` nas extremidades e expoente incompleto com erro léxico posicionado.

### 3.4 Strings e escapes

O MVP aceita strings delimitadas por aspas simples ou duplas em uma única linha. Escapes aceitos: `\\`, `\'`, `\"`, `\n`, `\r`, `\t`, `\b`, `\f`, `\uXXXX` e `\UXXXXXXXX`. Escape desconhecido é erro léxico; não é preservado silenciosamente.

Strings triplas, raw strings, bytes e f-strings ficam fora do MVP. Nova linha ou EOF antes do delimitador final produz `LEX_UNTERMINATED_STRING` na posição da abertura.

### 3.5 Comentários

`#` inicia comentário até a nova linha ou EOF, exceto dentro de string. Comentários não geram statements e não alteram a pilha de indentação. Não existem comentários multilinha especiais.

### 3.6 Operadores e delimitadores

Operadores do MVP:

```text
+  -  *  /  //  %  **
==  !=  <  <=  >  >=
=  +=  -=  *=  /=  //=  %=
and  or  not  in  not in
```

Normativamente, a lista é: `+`, `-`, `*`, `/`, `//`, `%`, `**`, `==`, `!=`, `<`, `<=`, `>`, `>=`, `=`, `+=`, `-=`, `*=`, `/=`, `//=`, `%=` e os operadores-keyword `and`, `or`, `not`, `in`, `not in`. O lexer usa maximal munch: por exemplo, `//=` é um token, não `//` seguido de `=`.

Delimitadores: `(`, `)`, `[`, `]`, `{`, `}`, `:`, `,` e `.`. Ponto e vírgula não é aceito. Não há múltiplos statements na mesma linha.

### 3.7 Novas linhas

Uma nova linha lógica produz `NEWLINE`. Linhas vazias e linhas apenas com comentário não produzem `NEWLINE` adicional relevante ao parser. Dentro de `()`, `[]` ou `{}`, novas linhas físicas e sua indentação são ignoradas, permitindo literais e chamadas multilinha. Continuação explícita com barra invertida fica fora do MVP.

### 3.8 Indentação e dedentação

- A unidade canônica é exatamente 4 espaços.
- O editor deverá converter Tab em quatro espaços antes de inserir texto.
- Uma nova suite deve avançar exatamente uma unidade em relação à linha que a abre.
- Dedent deve retornar a um nível existente da pilha de indentação.
- Linhas vazias e comentários não abrem nem fecham suites.
- Indentação inesperada, salto maior que uma unidade e dedent para coluna inexistente são erros de indentação.
- Fonte colada usando somente tabs de forma consistente pode ser interpretada com cada tab valendo uma unidade de quatro colunas, mas não é a forma canônica.
- Se tabs e espaços forem usados para indentação em linhas significativas da mesma fonte, o lexer produz `INDENT_MIXED_WHITESPACE`, mesmo que as colunas visuais coincidam.

Dentro de delimitadores abertos, espaços iniciais servem apenas à formatação e não produzem `INDENT`/`DEDENT`.

### 3.9 Posição e fim de arquivo

Linha e coluna são baseadas em 1. Coluna e comprimento contam pontos de código Unicode na fonte normalizada para `\n`. Cada token preserva offsets inicial e final, linha, coluna e comprimento. Tokens sintéticos `INDENT`, `DEDENT`, `NEWLINE` e `EOF` preservam a posição que os originou.

No EOF, o lexer:

1. fecha uma linha lógica pendente com `NEWLINE`, se necessário;
2. emite um `DEDENT` para cada nível ainda aberto;
3. emite exatamente um `EOF`.

Delimitador ou string não fechado tem precedência sobre dedents sintéticos e produz erro na abertura relevante.

### 3.10 Lista exata de tokens do MVP

```text
# Estruturais
EOF NEWLINE INDENT DEDENT

# Valores e nomes
NAME INT FLOAT STRING

# Keywords
KW_AND KW_BREAK KW_CONTINUE KW_DEF KW_ELIF KW_ELSE
KW_FALSE KW_FOR KW_IF KW_IN KW_NONE KW_NOT KW_OR
KW_RETURN KW_TRUE KW_WHILE

# Aritmética e atribuição
PLUS MINUS STAR SLASH DOUBLE_SLASH PERCENT DOUBLE_STAR
ASSIGN PLUS_ASSIGN MINUS_ASSIGN STAR_ASSIGN SLASH_ASSIGN
DOUBLE_SLASH_ASSIGN PERCENT_ASSIGN

# Comparação
EQ NOT_EQ LT LT_EQ GT GT_EQ

# Delimitadores
LPAREN RPAREN LBRACKET RBRACKET LBRACE RBRACE
COLON COMMA DOT
```

`not in` é reconhecido pelo parser como dois tokens-keyword adjacentes. Whitespace e comentários não são tokens entregues ao parser, mas seus intervalos devem poder ser preservados por uma camada de trivia para IDE.

## 4. Gramática

A EBNF abaixo define apenas o subconjunto do jogo. `{x}` significa repetição, `[x]` significa opcional e literais aparecem entre aspas.

```ebnf
program          = { NEWLINE | statement }, EOF ;

statement        = simple_statement, NEWLINE
                 | compound_statement ;

simple_statement = assignment
                 | expression_statement
                 | return_statement
                 | break_statement
                 | continue_statement ;

assignment       = target, assignment_operator, expression ;
assignment_operator
                 = "=" | "+=" | "-=" | "*=" | "/=" | "//=" | "%=" ;
target           = NAME | index_target ;
index_target     = primary, "[", expression, "]" ;
expression_statement
                 = expression ;
return_statement = "return", [ expression ] ;
break_statement  = "break" ;
continue_statement
                 = "continue" ;

compound_statement
                 = if_statement
                 | while_statement
                 | for_statement
                 | function_definition ;

if_statement     = "if", expression, ":", suite,
                   { "elif", expression, ":", suite },
                   [ "else", ":", suite ] ;
while_statement  = "while", expression, ":", suite ;
for_statement    = "for", NAME, "in", expression, ":", suite ;
function_definition
                 = "def", NAME, "(", [ parameters ], ")", ":", suite ;
parameters       = NAME, { ",", NAME }, [ "," ] ;
suite            = NEWLINE, INDENT, statement, { statement }, DEDENT ;

expression       = or_expression ;
or_expression    = and_expression, { "or", and_expression } ;
and_expression   = not_expression, { "and", not_expression } ;
not_expression   = "not", not_expression | comparison ;
comparison       = sum, { comparison_operator, sum } ;
comparison_operator
                 = "==" | "!=" | "<" | "<=" | ">" | ">="
                 | "in" | "not", "in" ;
sum              = term, { ( "+" | "-" ), term } ;
term             = factor, { ( "*" | "/" | "//" | "%" ), factor } ;
factor           = ( "+" | "-" ), factor | power ;
power            = primary, [ "**", factor ] ;

primary          = atom, { trailer } ;
trailer          = call_trailer | index_trailer | method_trailer ;
call_trailer     = "(", [ arguments ], ")" ;
index_trailer    = "[", expression, "]" ;
method_trailer   = ".", NAME ;
arguments        = expression, { ",", expression }, [ "," ] ;

atom             = INT | FLOAT | STRING | "True" | "False" | "None"
                 | NAME
                 | list_display
                 | dict_display
                 | "(", expression, ")" ;
list_display     = "[", [ expression, { ",", expression }, [ "," ] ], "]" ;
dict_display     = "{", [ dict_item, { ",", dict_item }, [ "," ] ], "}" ;
dict_item        = expression, ":", expression ;
```

Restrições semânticas da gramática:

- uma `suite` nunca pode ser vazia; `pass` não existe;
- suites inline como `if ok: print(ok)` não são aceitas no MVP;
- `return` só é válido dentro de função;
- `break` e `continue` só são válidos dentro de loop da mesma função;
- o alvo do `for` é um único nome; unpacking fica fora;
- method trailer só pode terminar em chamada a um método permitido, como `lista.append(x)`; obter `lista.append` como valor fica fora do MVP;
- chamada de qualquer valor só é válida quando o valor é função do jogador ou built-in chamável;
- parênteses agrupam uma expressão; vírgula não cria tuple;
- `{}` é dicionário vazio; não existe literal de set;
- atribuição encadeada e atribuição a atributo ficam fora do MVP.

### 4.1 Precedência e associatividade

Da menor para a maior precedência:

1. `or`;
2. `and`;
3. `not`;
4. comparações, `in` e `not in`;
5. `+`, `-` binários;
6. `*`, `/`, `//`, `%`;
7. `+`, `-` unários;
8. `**`;
9. chamadas, indexação e acesso a método.

`**` associa à direita e mantém o comportamento Python: `-2 ** 2` vale `-4`, e `2 ** -1` vale `0.5`. Comparações encadeadas avaliam cada operando uma vez e fazem short-circuit: `a < f() < c` não equivale a `a < f() and f() < c`.

## 5. Semântica

### 5.1 Execução no nível superior

O backend executa statements do programa em ordem textual. Definições de função são executáveis: o nome passa a existir quando o `def` é alcançado. Chamar uma função antes da execução de sua definição produz erro de nome. Ao consumir o último statement sem erro ou suspensão, o runtime termina com sucesso.

### 5.2 Variáveis e lookup

Não há declaração separada. `nome = valor` cria ou substitui um binding no escopo determinado pelas regras lexicais. Ler um nome inexistente produz `NAME_NOT_DEFINED`.

Escopos:

- o módulo/programa possui um escopo global por runtime;
- cada chamada de função possui novo escopo local;
- `if`, `while` e `for` não criam escopo;
- uma função captura lexicalmente o ambiente em que seu `def` foi executado;
- cada runtime/aba tem seu próprio global; nenhum binding de jogador é compartilhado entre abas.

Como em Python, qualquer nome atribuído em uma função é local a essa função inteira, salvo parâmetros. Ler esse local antes de sua primeira atribuição produz `NAME_UNBOUND_LOCAL`, mesmo que exista um global homônimo. `global` e `nonlocal` não existem no MVP. Uma função interna pode ler bindings externos capturados, mas não reatribuí-los; pode mutar uma lista ou dicionário capturado.

### 5.3 Funções, argumentos e retorno

`def` cria um valor função com nome, parâmetros ordenados, corpo, intervalo de fonte e ambiente léxico. Argumentos são avaliados da esquerda para a direita antes da entrada na função. A aridade deve ser exata; não há argumentos nomeados, defaults ou variádicos em funções do jogador.

Parâmetros recebem referências aos mesmos valores passados. Atribuir outro valor ao parâmetro não altera o binding do chamador; mutar lista ou dicionário recebido altera o objeto compartilhado. Cair ao fim da função equivale a `return None`. `return expressão` avalia a expressão, encerra somente a chamada corrente e entrega o valor ao chamador.

A profundidade máxima inicial é 64 chamadas ativas, preservando a proteção já usada pelo runtime atual. O limite deve ser configurável sem ser removível. Excedê-lo produz `RECURSION_LIMIT` e encerra somente o runtime afetado.

### 5.4 Controle de loop

`break` termina o loop mais interno da mesma função. `continue` inicia a próxima iteração do loop mais interno. Nenhum dos dois atravessa uma fronteira de função. `return` encerra a função e, portanto, todos os loops ativos dentro dela.

`while` reavalia a condição a cada iteração. `for` solicita um elemento por iteração ao mecanismo mínimo definido na seção 8. Loops não possuem limite fixo de iterações: loops infinitos são permitidos, mas permanecem orçamentados e interrompíveis.

### 5.5 Truthiness

São falsos:

- `False`;
- `None`;
- zero inteiro ou float, incluindo `-0.0`;
- string vazia;
- lista vazia;
- dicionário vazio.

Funções, ranges não vazios e demais valores são verdadeiros. Truthiness não chama métodos definidos pelo jogador.

### 5.6 Lógica e comparações

`and` e `or` fazem short-circuit e retornam um dos operandos, não um `bool` forçado. `x and y` não avalia `y` quando `x` é falso; `x or y` não avalia `y` quando `x` é verdadeiro. `not` sempre retorna `bool`.

`==` e `!=` usam as regras de igualdade da seção 6. Comparações de ordem são aceitas entre números ou entre strings. Outros pares produzem `TYPE_UNSUPPORTED_COMPARISON`; não há ordenação arbitrária entre tipos. Comparações encadeadas param na primeira relação falsa.

`in` em lista testa igualdade dos elementos. Em dicionário testa chaves. Associação em string entra na expansão imediata.

### 5.7 Ordem de avaliação e operações inválidas

Ordem normativa:

- operandos binários: esquerda, depois direita;
- chamada: chamável, depois argumentos da esquerda para a direita;
- indexação: coleção, depois índice;
- lista: elementos da esquerda para a direita;
- dicionário: cada chave e depois seu valor, pares da esquerda para a direita;
- atribuição simples: resolve o alvo sem mutá-lo, avalia o lado direito e só então grava;
- atribuição composta a índice: coleção e índice são avaliados uma vez, depois o lado direito.

Uma operação incompatível nunca converte silenciosamente string em número nem coleção em escalar. Ela produz erro de tipo estruturado. Efeitos já concluídos antes do erro não são revertidos automaticamente; cada API do jogo deve documentar sua atomicidade.

## 6. Tipos do runtime

Os valores abaixo são do backend Python-like. Eles não podem reutilizar como contrato público o dicionário C-like `{element_type, dimensions, data}`. A implementação pode usar tipos Godot internamente, desde que preserve tags, identidade, semântica e conversão pela camada neutra de APIs.

### 6.1 `int`

- Imutável; inteiro assinado de 64 bits no MVP.
- Overflow produz `RUNTIME_INTEGER_OVERFLOW`; não faz wrap silencioso.
- Igualdade e ordem numéricas; `bool` participa numericamente como em Python (`True == 1`).
- Falso somente quando zero.
- `print`: decimal sem sufixo.
- Operações: `+ - * / // % **`, unários `+ -`, comparações.
- `/` sempre retorna `float`; `//` usa floor, inclusive com negativos; divisão ou módulo por zero é erro.

O limite de 64 bits é diferença deliberada em relação aos inteiros arbitrários do Python, necessária para custo previsível e interoperabilidade web.

### 6.2 `float`

- Imutável; IEEE-754 binary64.
- Igualdade e ordem numéricas com `int`/`bool`.
- Falso em `0.0` e `-0.0`.
- `print`: forma decimal determinística e independente de locale; deve preservar `.0` quando necessário para distinguir float.
- Operações aritméticas e comparações numéricas.
- Resultados não finitos gerados por operação devem produzir erro de runtime no MVP; não há literais `nan` ou `inf`.

### 6.3 `bool`

- Imutável; valores únicos `True` e `False`.
- Comportamento numérico compatível com Python quando usado em aritmética: `True` corresponde a 1 e `False` a 0.
- `False` é falso; `True` é verdadeiro.
- `print`: exatamente `True` ou `False`.
- Operações preferenciais: lógica, igualdade e comparação; aritmética segue a compatibilidade numérica acima.

### 6.4 `str`

- Imutável, Unicode.
- Igualdade por conteúdo e ordem lexicográfica por pontos de código.
- Falsa quando vazia.
- `print`: conteúdo sem aspas; dentro de lista/dict usa representação com aspas e escapes determinísticos.
- MVP: `+` para concatenação, `*` por inteiro, `== != < <= > >=`, `len`. Multiplicador zero ou negativo produz string vazia, como em Python.
- Indexação, iteração e `in` entram na expansão imediata.

### 6.5 `None`

- Imutável e singleton.
- Igual somente a `None`.
- Sempre falso.
- `print`: `None`.
- Não aceita aritmética, ordem nem indexação.

### 6.6 `list`

- Mutável e compartilhada por referência.
- Igualdade estrutural, ordenada e recursiva, com proteção contra ciclos.
- Falsa quando vazia.
- `print`: `[valor1, valor2]`, usando representação recursiva. Ciclo direto é abreviado como `[...]`.
- Operações MVP: criação, `len`, `in`, concatenação `+`, repetição `*`, indexação, atribuição por índice, `append`, `pop` e iteração. Na repetição, multiplicador zero ou negativo produz lista vazia, como em Python.
- Comparação de ordem entre listas fica fora do MVP.

### 6.7 `dict`

- Mutável, compartilhado por referência e com ordem de inserção preservada.
- Igualdade por pares chave/valor, independentemente da ordem de inserção.
- Falso quando vazio.
- `print`: `{chave: valor}` em ordem de inserção. Ciclo direto é abreviado como `{...}`.
- Chaves do MVP: `int`, `float`, `bool`, `str` e `None`; listas, dicionários e funções não são chaves.
- Operações MVP: criação, `len`, `in`, consulta, atribuição, `get`, `pop` e iteração sobre chaves.
- Chaves numericamente iguais compartilham entrada, como `1`, `1.0` e `True` no Python.

Restringir chaves a escalares imutáveis é diferença deliberada; evita expor um protocolo de hash ainda não especificado.

### 6.8 Função

- Imutável; captura ambiente léxico.
- Igualdade por identidade.
- Sempre verdadeira.
- `print`: `<function nome>`; sem endereço de memória, para saída determinística.
- Operação permitida: chamada posicional. Não há atributos públicos, serialização nem hashing como chave no MVP.

### 6.9 Valores retornados por built-ins

`range` retorna um valor interno imutável e iterável, representado como `range(stop)`, `range(start, stop)` ou `range(start, stop, step)`. Ele não é lista e não é mutável.

APIs do jogo retornam somente valores neutros desta seção:

| Built-in | Retorno Python-like do MVP |
|---|---|
| `print(...)` | `None` |
| `send(...)` | `bool` indicando aceitação da resposta |
| `input()` | próximo escalar do contexto; `0` quando o contexto atual estiver esgotado, preservando a capacidade atual |
| `sensor(nome)` | valor do sensor, atualmente em geral `bool`; sensor inexistente resulta `False` |
| `get_stock()` | nova `list[int]`, snapshot independente |
| `buy_stock(lista)` | `None`; falha de validação vira erro, compra parcial pode emitir aviso |
| `get_deliveries()` | nova `list[int]`, snapshot independente |
| `declare_profit(lista)` | `None`; feedback do desafio pode ser saída ou erro conforme autoridade do gameplay |
| `wait(segundos)` | `None`, após solicitar suspensão cooperativa |
| `len(valor)` | `int` |
| `range(...)` | range interno iterável |

O sentinel `0` de `input()` esgotado é preservado para compatibilidade com desafios atuais; uma API futura com EOF explícito é decisão pendente.

## 7. Listas e dicionários

### 7.1 Listas no MVP

Criação: `[]` ou `[expressao, ...]`; elementos podem ter tipos diferentes. Cada literal cria objeto novo.

Indexação aceita somente `int` (e `bool` pela compatibilidade numérica). Índices negativos contam do fim: `-1` é o último. Fora do intervalo produz `INDEX_OUT_OF_RANGE`. Atribuição por índice substitui a referência armazenada.

Operações:

- `len(lista)` retorna quantidade de elementos;
- `valor in lista` busca da esquerda para a direita por igualdade;
- `lista.append(valor)` adiciona ao fim e retorna `None`;
- `lista.pop()` remove e retorna o último; `lista.pop(indice)` usa índice positivo ou negativo;
- `+` cria uma nova lista com referências aos elementos das duas entradas;
- `* n` cria nova lista repetida; os elementos internos continuam compartilhados, como em Python.

### 7.2 Listas na expansão imediata

- `extend(iteravel)`: acrescenta itens e retorna `None`;
- `insert(indice, valor)`: insere com regras de clamp do Python e retorna `None`;
- `remove(valor)`: remove a primeira ocorrência ou gera erro de valor;
- `sort()`: ordenação estável in-place, sem `key` nem `reverse` no primeiro incremento;
- `reverse()`: inverte in-place e retorna `None`.

`sort` deve ser incremental ou cobrar custo proporcional ao número de comparações/movimentos; não pode bloquear um frame. Mistura não ordenável gera erro de tipo sem prometer rollback parcial até que a implementação defina estratégia atômica. **PENDENTE:** decidir se `sort` será transacional para listas pequenas.

### 7.3 Dicionários no MVP

Criação: `{}` ou `{chave: valor, ...}`. Chaves e valores são avaliados da esquerda para a direita. Chave repetida substitui o valor sem alterar a posição de inserção original.

Consulta `d[chave]` retorna o valor ou produz `KEY_NOT_FOUND`. Atribuição `d[chave] = valor` substitui ou insere. `chave in d` testa somente chaves. `len(d)` conta entradas.

Métodos:

- `d.get(chave)` retorna valor ou `None`;
- `d.get(chave, fallback)` retorna valor ou o fallback;
- `d.pop(chave)` remove e retorna o valor ou gera `KEY_NOT_FOUND`;
- `d.pop(chave, fallback)` retorna fallback se ausente.

### 7.4 Dicionários na expansão imediata

- `items()` retorna snapshot em uma lista de listas de dois elementos, por exemplo `[["arroz", 2], ["feijao", 3]]`; isso substitui temporariamente os pares-tupla que não existem no subconjunto;
- `keys()` retorna snapshot das chaves em lista;
- `values()` retorna snapshot dos valores em lista;
- `update(outro_dict)` aplica entradas em ordem e retorna `None`;
- variantes adicionais de `pop` só podem ser adicionadas mantendo a aridade acima.

Como tuples estão fora do MVP, o retorno de `items()` como `list[list]` é uma diferença explícita e estável do subconjunto. A futura introdução de tuples não deve mudar silenciosamente esse retorno; qualquer migração exigirá versão de linguagem e decisão própria. Nenhum desses métodos usa array C-like ou formato oculto.

### 7.5 Referência, cópia e limites

Atribuição e passagem de parâmetro não copiam listas/dicionários. APIs que retornam snapshots (`get_stock`, `get_deliveries`) criam novas coleções para impedir mutação do estado autoritativo do jogo.

O runtime deve impor limites configuráveis de tamanho e profundidade de representação. **PENDENTE:** valores numéricos exatos de máximo de elementos, profundidade e bytes de string. A implementação não pode deixar uma única criação ou formatação monopolizar o frame; deve decompor ou falhar antes da alocação excessiva.

## 8. Iteração

O MVP não expõe classes de iterador, `iter()` ou `next()`. O executor usa cursores internos:

- lista: índices `0..len-1` sobre a versão observada no início;
- dicionário: chaves em ordem de inserção;
- range: progressão aritmética lazy, stop exclusivo;
- string: reservada para expansão imediata, por ponto de código Unicode.

`range` aceita:

```text
range(stop)
range(start, stop)
range(start, stop, step)
```

Todos os argumentos devem ser `int`; `step == 0` produz erro. Ranges ascendentes e descendentes seguem Python.

Cada lista/dicionário mantém uma versão de mutação. Se a própria coleção iterada for alterada estruturalmente durante o loop — inclusive por alias ou por função chamada — a próxima operação do iterador produz `RUNTIME_COLLECTION_MUTATED`. Para listas, substituir um elemento existente por índice não altera o tamanho, mas ainda conta como mutação no MVP para manter comportamento determinístico. Para dicionários, substituir valor de chave existente também conta.

Essa regra é deliberadamente mais estrita que Python para evitar loops dependentes de detalhes de implementação. Mutar uma coleção diferente é permitido. Iterar um snapshot retornado por `keys()` no futuro permite modificar o dicionário original sem invalidar o snapshot.

## 9. Modelo de execução incremental

### 9.1 Unidade de operação

Uma operação do scheduler é uma transição atômica, retomável e limitada de estado do backend. Toda transição que progride o programa deve consumir pelo menos uma operação. O custo não é definido por classes concretas de AST ou executor.

Contagem mínima normativa:

| Construção | Operações cobradas |
|---|---|
| literal ou lookup de nome | 1 |
| aplicação de operador unário/binário ou comparação | 1 após operandos |
| leitura/escrita de índice | 1, além de coleção e índice |
| entrada/conclusão de statement | ao menos 1 transição total além das subexpressões |
| seleção de ramo | 1 após a condição |
| teste de `while` | condição normal + 1 decisão por iteração |
| avanço de `for` | 1 tentativa de obter próximo item |
| criação de frame de chamada | 1; argumentos e corpo são cobrados separadamente |
| retorno e remoção do frame | 1 |
| short-circuit | 1 decisão; lado omitido custa 0 |
| criação de coleção | avaliação de cada item + ao menos 1 inserção por item |
| método/built-in | 1 para despacho + custo proporcional do trabalho interno |

Nenhuma expressão complexa pode ser avaliada recursivamente de forma indivisível. O estado de avaliação deve poder ser suspenso entre operandos, argumentos, elementos e chamadas, preservando ordem e valores temporários.

Built-ins que apenas consultam estado pequeno podem terminar em uma transição. Trabalho proporcional a entrada — busca linear, igualdade profunda, `extend`, `remove`, `sort`, formatação de coleção — precisa:

- ser retomável e cobrar operações internas; ou
- verificar um limite pequeno documentado e cobrar antecipadamente custo equivalente.

Não é permitido declarar custo 1 para trabalho arbitrariamente grande.

### 9.2 Scheduler e estados

O backend participa do scheduler compartilhado pelo contrato `LanguageRuntimeBackend`. Valores atuais de referência são 200 operações por script por frame e 1000 operações globais por frame; eles pertencem ao manager e podem mudar sem alterar a linguagem.

O backend deve:

1. preparar contabilização/saída em `begin_scheduler_frame()`;
2. executar no máximo o budget recebido;
3. retornar o número real de operações consumidas, nunca maior que o budget;
4. consolidar saída em `end_scheduler_frame()`;
5. informar sleep, erro ou término de modo consistente.

Um backend ativo que ainda pode progredir não pode retornar repetidamente zero operações sem mudar de estado; isso seria erro interno. Abas distintas mantêm pilhas, globais, temporários e erros isolados. Elas compartilham somente serviços autoritativos do jogo chamados por built-ins.

### 9.3 Stop, sleep, erro e término

- **Stop:** deve ser observado antes da próxima operação e descartar frames/temporários do runtime sem afetar outras abas. Nenhum `finally` de jogador existe.
- **Sleep:** `wait(segundos)` valida um único número finito não negativo, solicita `sleep_requested(segundos)`, retorna `None` e suspende depois da chamada. Número negativo produz `RUNTIME_INVALID_VALUE`; não é convertido silenciosamente para zero.
- **Erro:** interrompe o runtime afetado, preserva saída anterior e emite representação textual do erro estruturado pelo sinal atual.
- **Término:** ocorre ao finalizar o último statement de nível superior. Não há valor de programa observável.
- **Recursão:** máximo inicial de 64 chamadas ativas. O limite é checado antes de criar novo frame.
- **Loop infinito:** é comportamento permitido; continua entre frames sob budget até stop, erro ou `wait`. Nunca há execução síncrona ilimitada na thread principal.

Saída deve ser limitada por runtime. Como referência compatível, o sistema atual mantém até 200 linhas e limita prints por frame. **PENDENTE:** confirmar os limites normativos do Python-like; eles devem ser configuráveis e nunca superiores a um teto global seguro.

### 9.4 Web

Lexer, parser, análise e executor devem ser GDScript/recursos compatíveis com exportação web. Não podem usar threads, acesso a filesystem do usuário, sockets, subprocessos, `eval`, carregamento de código Python ou APIs bloqueantes. Relógios para sleep vêm do manager Godot, não de busy-wait.

## 10. Modelo de erros

### 10.1 Estrutura neutra

Todo erro deve existir internamente como registro equivalente a:

```json
{
  "category": "syntax",
  "code": "PARSE_EXPECTED_COLON",
  "message": "Esperado ':' após a condição do if.",
  "line": 3,
  "column": 8,
  "length": 1,
  "script_id": "script_004",
  "source_name": "Principal",
  "runtime_id": "runtime_012",
  "details": {
    "expected": ["COLON"],
    "found": "NEWLINE"
  }
}
```

Regras:

- `category`, `code`, `message`, `line`, `column`, `length` e `script_id` são obrigatórios;
- `source_name`, `runtime_id` e `details` são opcionais quando ainda não existem na fase de análise;
- posições são baseadas em 1 e `length >= 1`, salvo EOF, que pode usar `length = 0`;
- `code` é estável e não localizado; `message` é texto localizado para o jogador;
- `details` só contém valores neutros e nunca nós concretos de AST ou stack trace do host;
- erros internos podem incluir diagnóstico técnico em log de desenvolvimento, mas a UI recebe mensagem segura.

O contrato atual emite `execution_error(text)`. O backend deve reter a estrutura neutra e renderizá-la deterministicamente para esse sinal. Uma consulta estruturada futura do manager é **PENDENTE**; não se deve degradar a estrutura para texto dentro do lexer/parser.

### 10.2 Categorias

| Categoria | Exemplos de código | Momento |
|---|---|---|
| lexical | `LEX_INVALID_CHARACTER`, `LEX_UNTERMINATED_STRING`, `LEX_INVALID_ESCAPE` | tokenização |
| indentation | `INDENT_UNEXPECTED`, `INDENT_INVALID_DEDENT`, `INDENT_MIXED_WHITESPACE` | tokenização estrutural |
| syntax | `PARSE_EXPECTED_EXPRESSION`, `PARSE_EXPECTED_COLON`, `PARSE_UNSUPPORTED_FEATURE` | parsing |
| name | `NAME_NOT_DEFINED`, `NAME_UNBOUND_LOCAL` | resolução/execução |
| type | `TYPE_UNSUPPORTED_OPERATOR`, `TYPE_NOT_CALLABLE`, `TYPE_UNHASHABLE_KEY` | análise parcial ou runtime |
| index | `INDEX_OUT_OF_RANGE`, `INDEX_NOT_INTEGER` | runtime |
| key | `KEY_NOT_FOUND` | runtime |
| arity | `ARITY_MISMATCH` | análise parcial ou chamada |
| recursion | `RECURSION_LIMIT` | criação de frame |
| runtime | `RUNTIME_DIVISION_BY_ZERO`, `RUNTIME_COLLECTION_MUTATED`, `RUNTIME_RESOURCE_LIMIT` | execução |
| internal | `INTERNAL_INVALID_STATE`, `INTERNAL_BACKEND_FAILURE` | falha de implementação |

Erros léxicos, de indentação e sintáticos podem ser acumulados quando houver recuperação segura. Erros de runtime são fatais para aquela execução. Um erro em uma aba não encerra outros runtimes.

### 10.3 Posição do diagnóstico

- operador inválido: intervalo do operador;
- nome ausente: intervalo do nome;
- aridade: intervalo da chamada, com detalhes de esperado/recebido;
- índice/chave: intervalo da expressão de índice;
- indentação: prefixo inicial da linha;
- falta de token: posição de inserção esperada, comprimento zero quando apropriado;
- erro dentro de built-in: intervalo da chamada e, se possível, do argumento ofensivo.

O backend deve manter uma pilha neutra de frames com nome da função e posição da chamada para futura exibição. O MVP pode mostrar apenas o erro principal, mas não deve perder esses metadados internamente.

## 11. Integração com as APIs do jogo

### 11.1 Camada de valores neutros

Built-ins Python-like são adaptadores de linguagem para serviços do jogo. A fronteira converte explicitamente:

- escalares neutros ↔ escalares Godot permitidos;
- `list` ↔ snapshot `Array` validado;
- `dict` ↔ `Dictionary` neutro quando a API documentar esse formato;
- retorno/erro do domínio ↔ valor Python-like ou erro estruturado.

O gameplay não deve receber objetos de AST, ambientes ou representações internas do backend. O backend não deve expor o formato C-like `{element_type, dimensions, data}`. Snapshots vindos do jogo são copiados; mutá-los não altera estoque ou relatório ativo.

Cada chamada recebe internamente contexto com `runtime_id`, `script_id` e dados do desafio. Isso preserva autoridade, isolamento, leases do Delivery e validação da aba reservada.

### 11.2 Built-ins atuais

| API | Assinatura Python-like | Comportamento |
|---|---|---|
| `print` | `print(*valores)` | Concatena para a saída do runtime usando representação Python-like; retorna `None`. A assinatura variádica é exclusiva do built-in. |
| `send` | `send(*valores)` | Envia resposta ao atendimento corrente, na ordem; retorna `bool`. Preserva validação e efeitos autoritativos do `TransactionManager`. |
| `input` | `input()` | Lê o próximo valor do atendimento/contexto. Aridade diferente de zero é erro. |
| `sensor` | `sensor(nome)` | Consulta sensor liberado; exige um argumento `str`; bloqueio por progressão gera erro orientativo. |
| `get_stock` | `get_stock()` | Retorna snapshot `list[int]` na ordem da prateleira. |
| `buy_stock` | `buy_stock(quantidades)` | Exige uma lista numérica do tamanho configurado pelo jogo; valida integralidade, negativos, capacidade e dinheiro. |
| `get_deliveries` | `get_deliveries()` | Disponível no contexto/aba Delivery; retorna snapshot `list[int]` e associa relatório ao runtime. |
| `declare_profit` | `declare_profit(lucros)` | Exige lista de três inteiros e submete ao relatório associado ao mesmo runtime/script. |
| `wait` | `wait(segundos)` | Suspende cooperativamente o runtime; requer feature correspondente quando a progressão assim determinar. |

O `*valores` usado nesta tabela é metanotação de assinatura variádica do built-in. A sintaxe `*` para expandir argumentos não faz parte da linguagem do jogador no MVP.

`await` não é alias nem função no Python-like. Se usado, deve gerar erro de recurso não suportado com sugestão de `wait`.

`print` deve separar argumentos de forma compatível com Python (`" "` entre eles e nova linha por chamada), em vez da concatenação sem separador do C-like. Parâmetros `sep`, `end` e `file` ficam fora do MVP porque argumentos nomeados não existem. A saída continua prefixada/agrupada pelo runtime manager conforme UI.

### 11.3 APIs planejadas

- `tabela_produtos()` está reservada para o novo caixa. Sua aridade inicial é zero. O formato exato dos registros, chaves e mutabilidade do retorno é **PENDENTE**; até a decisão, exemplos só iteram ou imprimem os valores retornados.
- API do scanner da compra: **PENDENTE — nome, assinatura, bloqueio e retorno não definidos**.
- API de finalização da compra: **PENDENTE — nome, assinatura, atomicidade e retorno não definidos**.

Nenhum nome provisório para scanner ou finalização deve entrar no lexer, autocomplete ou runtime.

### 11.4 Contexto dos desafios

O backend recebe cópia do contexto de entrada da execução. Os desafios atuais usam uma sequência de entradas, quantidade/ID e respostas esperadas; transações vivas podem fornecer entradas diretamente pelo `TransactionManager`. A especificação não transforma esses campos em globais do jogador: acesso ocorre por built-ins.

APIs podem estar bloqueadas por feature, limitadas a uma aba reservada ou depender de estado autoritativo. Erros de contexto devem identificar a API e orientar o jogador, sem revelar internals. Chamadas concorrentes devem carregar o `runtime_id`/`script_id` corretos; erro no Delivery não interrompe Estoque ou Principal.

## 12. Fatos pedagógicos

O backend poderá produzir um `PedagogicalFacts` neutro, independente da AST concreta:

```text
version: 1
script_id: string
language_id: "python_like"
syntactic_facts: Fact[]
runtime_facts: Fact[]
heuristic_facts: Fact[]
```

Cada `Fact` contém ao menos `kind`, `source_range` opcional, `symbol_id` opcional, `count` opcional, `evidence` neutra e `confidence` (`certain`, `probable`, `unknown`).

### 12.1 Fatos sintáticos

Derivados do parse/AST, portanto certos para a fonte analisada:

- `loop_present`, com subtipo `for`/`while`;
- `function_defined`, nome e símbolo;
- `function_call_present`, alvo resolvido quando possível;
- `self_call_present` e ciclos no grafo de chamadas;
- `return_present`;
- `conditional_present`;
- `collection_literal_used`, tipo lista/dict;
- `api_call_present`, nome canônico;
- candidato a condição de parada em loop/recursão.

### 12.2 Fatos observados em runtime

Derivados de eventos executados, nunca inferidos de código não alcançado:

- `function_called`, contagem;
- `recursion_executed`, com função e profundidade máxima;
- `loop_iteration_executed`, contagem limitada/agregada;
- `branch_taken`;
- `collection_operation_executed`;
- `api_called`, argumentos resumidos de forma segura e resultado categórico;
- `wait_requested`, `runtime_stopped`, `runtime_limit_hit`.

“Recursão detectada” sintaticamente e “recursão realmente executada” são fatos diferentes. Desafios como Delivery podem exigir ambos sem acessar a AST C-like.

### 12.3 Inferências heurísticas

Possíveis, mas nunca tratadas como prova única de correção:

- `probable_loop_stop_condition`;
- `probable_recursive_base_case`;
- `probable_accumulator_pattern`;
- `probable_collection_traversal`;
- `probable_dead_code`.

Inferências devem informar evidência e confiança. A autoridade final de recompensa continua no sistema de gameplay e em resultados observáveis. O formato detalhado, armazenamento e API de consulta são **PENDENTES** e não serão implementados nesta tarefa.

## 13. Suporte futuro à IDE

### 13.1 Lexer

Deve preservar:

- tipo, lexema, valor e intervalo completo de cada token;
- offsets físicos e linhas lógicas;
- trivia de comentários e whitespace quando solicitada pela IDE;
- origem de `INDENT`/`DEDENT` e estilo de indentação;
- estado suficiente para retokenização incremental por linha.

Isso suporta syntax highlighting, indent guides e diagnóstico de tabs/espaços.

### 13.2 Parser e árvore sintática

Cada nó deve preservar intervalo completo, intervalos de keywords/delimitadores relevantes e relações pai/filho. Nós de erro recuperáveis não podem apagar o restante do arquivo. A árvore sintática para IDE pode ser lossless; a representação executável pode ser derivada dela.

Metadados necessários:

- chamadas, argumentos e vírgulas para signature help;
- membro após `.` para métodos por tipo;
- posição do alvo e valor de atribuição;
- suites e seus níveis de indentação;
- definições, parâmetros e referências;
- literais com tipo inferível.

### 13.3 Análise semântica parcial

Uma tabela de símbolos por escopo deve atribuir IDs estáveis a globais, locais, parâmetros, funções e built-ins. Referências registram símbolo resolvido ou motivo da falha. Tipos são conjuntos aproximados, por exemplo `list[int] | None`, sem alterar a tipagem dinâmica.

Isso permitirá:

- erros inline e painel de problemas a partir do modelo estruturado;
- autocomplete por keywords, nomes visíveis, APIs liberadas e métodos possíveis;
- símbolos por escopo e navegação definição/referência;
- métodos filtrados pelo tipo aproximado;
- signature help para funções e built-ins;
- tooltips com assinatura, fase, bloqueio de gameplay e tipo aproximado;
- avisos, distintos de erros, quando a análise não puder provar um tipo.

Autocomplete não deve sugerir APIs ainda bloqueadas sem marcá-las como tal, nem inventar scanner/finalização antes da decisão de nomes.

## 14. Exemplos oficiais

Todos os exemplos válidos abaixo pertencem à gramática do MVP, salvo indicação explícita.

### 14.1 Hello World

```python
print("Hello, AutoMarket!")
```

Saída: `Hello, AutoMarket!`

### 14.2 Variáveis

```python
preco = 12.5
quantidade = 3
total = preco * quantidade
print(total)
```

Saída: `37.5`

### 14.3 Condição

```python
total = 72.0
if total > 50:
    total *= 0.9
elif total == 50:
    print("limite")
else:
    print("sem desconto")
print(total)
```

Saída final: `64.8`.

### 14.4 Loop

```python
soma = 0
for numero in range(1, 6):
    soma += numero
print(soma)
```

Saída: `15`.

### 14.5 Função e escopo léxico

```python
taxa = 0.1

def aplicar_taxa(valor):
    return valor + valor * taxa

print(aplicar_taxa(100))
```

Saída: `110.0`.

### 14.6 Lista

```python
precos = [10, 20, 5]
precos.append(15)
total = 0
for preco in precos:
    total += preco
print(total)
```

Saída: `50`.

### 14.7 Dicionário

```python
estoque = {"arroz": 3, "feijao": 2}
estoque["arroz"] += 1
if "arroz" in estoque:
    print(estoque.get("arroz"))
```

Saída: `4`.

### 14.8 Novo caixa com `tabela_produtos()`

```python
produtos = tabela_produtos()
for produto in produtos:
    print(produto)
```

Este exemplo é sintaticamente válido, mas depende de API planejada. Não presume chaves, scanner ou função de finalização ainda não definidos.

### 14.9 Wait cooperativo

```python
while True:
    print(sensor("cliente_na_tela"))
    wait(1)
```

O runtime imprime no máximo uma observação por segundo e pode ser parado entre operações.

### 14.10 Exemplos inválidos

Indentação ausente:

```python
if True:
print("erro")
```

Erro: `PARSE_EXPECTED_INDENT` na segunda linha, coluna 1.

Mistura de indentação:

```python
if True:
    print("espaços")
	print("tab")
```

Erro: `INDENT_MIXED_WHITESPACE` no prefixo da terceira linha.

Nome inexistente:

```python
print(total)
```

Erro: `NAME_NOT_DEFINED` cobrindo `total`.

Aridade incorreta:

```python
def dobro(valor):
    return valor * 2

print(dobro())
```

Erro: `ARITY_MISMATCH` na chamada `dobro()`.

Recurso fora do MVP:

```python
valores = [x * 2 for x in range(3)]
```

Erro: `PARSE_UNSUPPORTED_FEATURE`, indicando comprehension fora do MVP.

Mutação durante iteração:

```python
valores = [1, 2, 3]
for valor in valores:
    valores.append(valor)
```

Erro: `RUNTIME_COLLECTION_MUTATED` na próxima tentativa de avançar o `for`.

## 15. Matriz de compatibilidade

| Recurso | Python real | AutoMarket | Fase | Diferença conhecida |
|---|---|---|---|---|
| nível superior | executa diretamente | igual | MVP | nenhuma |
| `main()` | não obrigatório | não existe requisito | MVP | difere do C-like, não de Python |
| blocos | indentação flexível | incremento exato de 4 espaços | MVP | mais estrito |
| tabs | expansão contextual | tabs consistentes valem 4; mistura rejeitada | MVP | mais estrito/diferente |
| suites inline | permitidas | não permitidas | fora do MVP | subconjunto |
| comentários | `#` | igual | MVP | nenhuma |
| inteiros | precisão arbitrária | signed 64-bit com erro de overflow | MVP | limite controlado |
| floats | binary64 | binary64 finito | MVP | NaN/inf não expostos |
| strings | vários prefixos e multilinha | aspas simples/duplas, uma linha | MVP | subconjunto |
| booleanos/None | `True`, `False`, `None` | igual | MVP | nenhuma |
| operadores lógicos | retornam operandos, short-circuit | igual | MVP | nenhuma |
| comparações encadeadas | suportadas | igual | MVP | nenhuma |
| `is` | suportado | não suportado | fora do MVP | subconjunto |
| variáveis | dinâmicas | igual | MVP | sem `global`/`nonlocal` |
| escopo | função léxica; blocos não criam escopo | igual | MVP | nenhuma no subconjunto |
| funções | muitos tipos de parâmetros | apenas posicionais e aridade exata | MVP | subconjunto |
| closures | suportadas | leitura/mutação de objetos capturados | MVP | sem `nonlocal` |
| listas | mutáveis por referência | igual no subconjunto | MVP | limites de recurso |
| dicionários | chaves hashable gerais | escalares imutáveis permitidos | MVP | mais restrito |
| `dict.items()` | view de pares-tupla | snapshot `list[list]` | expansão imediata | tuples ainda não existem |
| `dict.keys()`/`values()` | views dinâmicas | snapshots em listas | expansão imediata | resultado não acompanha mutações futuras |
| tuples/sets | suportados | não suportados | futuro | ausentes no MVP |
| índices negativos | suportados | listas no MVP | MVP | strings depois |
| slicing | suportado | não suportado | futuro | ausente |
| mutação durante `for` em lista | permitida com semântica do iterador | erro determinístico | MVP | mais estrito |
| mutação durante `for` em dict | em geral erro por tamanho | qualquer mutação observada gera erro | MVP | mais estrito |
| range | objeto lazy | valor interno lazy | MVP | sem API completa de objeto |
| built-ins padrão | biblioteca ampla | somente `print`, `len`, `range` e APIs documentadas | MVP | construtores e reflexão ausentes |
| `input` | lê texto e aceita prompt | lê próximo valor do contexto, sem argumentos | MVP | API orientada ao jogo |
| imports/biblioteca padrão | extensos | indisponíveis | fora de escopo | sandbox educacional |
| exceptions | suportadas | erros encerram runtime | fora de escopo | sem captura pelo jogador |
| async/await | coroutines | indisponível | fora de escopo | usar `wait` cooperativo |
| `wait` | não é built-in | suspensão do runtime | MVP | extensão do jogo |
| execução | contínua no processo | incremental por budget | MVP | diferença essencial |
| concorrência | threads/processos/async | runtimes cooperativos no scheduler | MVP | sem threads |
| `print` | separa por espaço | separa por espaço | MVP | UI pode prefixar aba |
| APIs do jogo | inexistentes | built-ins contextuais | MVP | extensão do jogo |
| type annotations | suportadas | não aceitas | futuro | ausentes |
| IDE/introspecção | runtime completo | metadados controlados | futuro | sem reflexão arbitrária |

## 16. Casos de teste de aceitação

Cada caso deve ser executado pelo backend através do `ScriptRuntimeManager`, não por um caminho síncrono alternativo. Salvo indicação, espera-se status `finished`, nenhum erro e saída listada.

### 16.1 Léxico, literais e nível superior

```python
inteiro = 1_000
decimal = .5
texto = "linha\nseguinte"
print(inteiro, decimal, True, False, None)
```

Espera: saída `1000 0.5 True False None`; programa executa sem `main`.

Erro de string:

```python
print("aberta)
```

Espera: `LEX_UNTERMINATED_STRING`, linha 1, coluna 7, intervalo iniciado na aspa.

### 16.2 Atribuição e operadores

```python
x = 7
x += 5
x //= 3
print(x, 2 ** 3 ** 2, -2 ** 2)
```

Espera: `4 512 -4`.

Demais operadores e atribuições compostas:

```python
a = 10
a -= 3
a *= 2
a /= 4
b = 10
b %= 4
print(a, b, 7 % 4, 7 >= 7)
```

Espera: `3.5 2 3 True`.

Comparação encadeada:

```python
def meio():
    return 2

print(1 < meio() < 3)
```

Espera: `True`; o operando produzido por `meio()` é avaliado uma única vez.

Divisão inválida:

```python
print(1 / 0)
```

Espera: `RUNTIME_DIVISION_BY_ZERO` no `/`.

### 16.3 Condicionais e truthiness

```python
if []:
    print("erro")
elif {"ok": 1}:
    print("certo")
else:
    print("erro")
```

Espera: `certo`.

```python
vazio = None
print(not vazio, "uva" not in {"arroz": 1})
```

Espera: `True True`.

Operações básicas de string e lista:

```python
texto = "Auto" + "Market"
marcas = [1] + [2, 3]
print(texto, "ha" * 2, len(texto), marcas)
```

Espera: `AutoMarket haha 10 [1, 2, 3]`.

### 16.4 Short-circuit

```python
def falhar():
    return 1 / 0

print(False and falhar())
print(True or falhar())
```

Espera: `False` e `True`; `falhar` não é chamada e não há erro.

### 16.5 While, break e continue

```python
i = 0
soma = 0
while i < 10:
    i += 1
    if i == 3:
        continue
    if i == 6:
        break
    soma += i
print(soma)
```

Espera: `12`.

`break` fora de loop:

```python
break
```

Espera: erro sintático/semântico posicionado `PARSE_BREAK_OUTSIDE_LOOP` cobrindo `break`.

### 16.6 For e range

```python
valores = []
for i in range(5, 0, -2):
    valores.append(i)
print(valores)
```

Espera: `[5, 3, 1]`.

```python
for i in range(0, 3, 0):
    print(i)
```

Espera: `RUNTIME_INVALID_VALUE` na chamada de `range`.

### 16.7 Funções, retorno e recursão

```python
def fatorial(n):
    if n <= 1:
        return 1
    return n * fatorial(n - 1)

print(fatorial(5))
```

Espera: `120`; fatos registram self-call e recursão executada.

Função sem retorno explícito:

```python
def registrar():
    print("ok")

resultado = registrar()
print(resultado)
```

Espera: `ok` e `None`.

Recursão ilimitada:

```python
def repetir():
    return repetir()

repetir()
```

Espera: `RECURSION_LIMIT` ao tentar ultrapassar 64 chamadas; Godot continua responsiva.

### 16.8 Escopo léxico

```python
taxa = 2

def externa(base):
    adicional = 3
    def interna(valor):
        return valor * taxa + adicional
    return interna(base)

print(externa(5))
```

Espera: `13`.

Local não inicializado:

```python
x = 10
def problema():
    print(x)
    x = 20

problema()
```

Espera: `NAME_UNBOUND_LOCAL` cobrindo `x` dentro de `print`.

### 16.9 Mutabilidade e referência compartilhada

```python
def adicionar(lista):
    lista.append(3)

a = [1, 2]
b = a
adicionar(b)
print(a)
```

Espera: `[1, 2, 3]`; `a` e `b` referenciam a mesma lista.

Repetição preserva referências internas:

```python
linha = [0]
matriz = [linha] * 2
matriz[0].append(1)
print(matriz)
```

Espera: `[[0, 1], [0, 1]]`.

Índice negativo e `pop`:

```python
valores = [10, 20, 30]
ultimo = valores[-1]
removido = valores.pop(-2)
print(ultimo, removido, valores)
```

Espera: `30 20 [10, 30]`.

### 16.10 Dicionários

```python
quantidades = {"arroz": 2}
quantidades["feijao"] = 3
print(len(quantidades), "arroz" in quantidades, quantidades.get("uva", 0))
print(quantidades.pop("feijao"))
```

Espera: `2 True 0` e `3`.

Iteração usa chaves em ordem de inserção:

```python
quantidades = {"arroz": 2, "feijao": 3}
for produto in quantidades:
    print(produto)
```

Espera: `arroz` e depois `feijao`.

Chave ausente:

```python
d = {}
print(d["ausente"])
```

Espera: `KEY_NOT_FOUND` cobrindo `"ausente"`.

### 16.11 Mutação durante iteração

```python
itens = [1, 2]
for item in itens:
    itens.append(item)
```

Espera: primeira mutação ocorre; antes do próximo item, `RUNTIME_COLLECTION_MUTATED`. O teste confirma que stop/error fica restrito ao runtime.

Operação entre tipos incompatíveis:

```python
print("total: " + 10)
```

Espera: categoria `type`, código `TYPE_UNSUPPORTED_OPERATOR`, cobrindo `+`; não há conversão silenciosa.

### 16.12 APIs do jogo

```python
valores = []
valor = input()
while valor != -1:
    valores.append(valor)
    valor = input()
send(len(valores))
```

Espera: consome contexto até sentinel e envia uma resposta sem bloquear.

```python
if sensor("cliente_na_tela"):
    print("cliente disponível")
```

Espera: consulta contextual retorna `bool`; se a feature Sensor não estiver liberada, ocorre erro orientativo restrito a esse runtime.

```python
estoque = get_stock()
compra = [0, 0, 0, 0, 0, 0]
if estoque[0] < 3:
    compra[0] = 3 - estoque[0]
buy_stock(compra)
```

Espera: snapshot não compartilha estado; compra validada pela autoridade do estoque.

```python
entregas = get_deliveries()
lucros = [0, 0, 0]
for i in range(3):
    lucros[i] = entregas[i]
declare_profit(lucros)
```

Espera: valores neutros chegam à API e `runtime_id`/`script_id` correspondem à aba Delivery. A aprovação pedagógica pode rejeitar este algoritmo se o desafio exigir função/recursão; essa rejeição é gameplay, não falha da linguagem.

### 16.13 Wait e loop infinito interrompível

```python
while True:
    wait(0.1)
```

Espera: status alterna entre `running` e `sleeping`, outros runtimes progridem e stop encerra somente este runtime.

```python
wait(-1)
```

Espera: `RUNTIME_INVALID_VALUE` no argumento; o runtime não entra em sleep.

```python
while True:
    print("tick")
```

Espera: cada frame consome no máximo o budget concedido; saída é limitada; UI permanece responsiva; stop é observado.

### 16.14 Posições de erro

```python
precos = [10]
print(precos[2])
```

Espera: categoria `index`, código `INDEX_OUT_OF_RANGE`, linha 2, coluna correspondente ao literal `2`, comprimento 1 e `script_id` correto.

```python
if True
    print("x")
```

Espera: `PARSE_EXPECTED_COLON`, linha 1, coluna após `True`, comprimento 0 ou posição do `NEWLINE`.

### 16.15 Execução concorrente

Aba A:

```python
while True:
    print("A")
```

Aba B:

```python
contador = 0
while contador < 3:
    print("B")
    contador += 1
```

Espera:

- runtimes distintos com `language = "python_like"`;
- budgets individuais e global respeitados;
- B termina mesmo enquanto A continua;
- parar A não muda o status final de B;
- erro inserido numa terceira aba não altera A ou B;
- saída permanece atribuída ao script correto.

## 17. Decisões pendentes e riscos de implementação

### 17.1 Decisões pendentes

- limites exatos de elementos, strings, profundidade de valores e saída;
- interface do manager para consultar erros estruturados e fatos pedagógicos;
- atomicidade de `list.sort()` quando ocorre comparação inválida;
- esquema retornado por `tabela_produtos()`;
- nomes, assinaturas e retornos das APIs de scanner e finalização da compra;
- política futura para EOF de `input()` sem sentinel numérico;
- localização das mensagens e idioma dos nomes de categorias na UI;
- se limites de recursão podem variar por desafio acima/abaixo do padrão 64, sempre respeitando teto global.

### 17.2 Riscos

- avaliar expressões ou formatar coleções de forma síncrona recriaria travamentos apesar do scheduler;
- reutilizar arrays C-like contaminaria mutabilidade, tipos, print, snapshots e análise do novo backend;
- implementar escopo por pilha dinâmica em vez de closures léxicas quebraria compatibilidade Python e desafios pedagógicos;
- validar Delivery diretamente contra classes de AST Python-like criaria novo acoplamento; fatos neutros devem substituir isso incrementalmente;
- limites silenciosos podem alterar algoritmos; todo limite atingido deve gerar erro ou aviso documentado;
- métodos mutáveis e aliases exigem identidade/versão de coleção, não cópias automáticas;
- diferenças não registradas em relação ao Python gerariam expectativas erradas no ensino;
- uma operação de scheduler muito ampla permitiria que `sort`, igualdade profunda ou `print` bloqueassem a exportação web.

## 18. Referências da integração atual

Esta especificação preserva capacidades observadas, sem tornar detalhes C-like normativos:

- contrato comum: `interpreter/runtime/language_runtime_backend.gd`;
- adaptador e stepping C-like usados como referência de integração: `interpreter/runtime/c_like_runtime_backend.gd` e `interpreter/runtime/interpretador.gd`;
- budgets, estados, isolamento, stop e sleep: `systems/ScriptRuntimeManager.gd`;
- APIs registradas atualmente: `interpreter/builtins/builtins.gd`;
- entradas e respostas dos desafios: `interpreter/runtime/env_context.gd`, `systems/ChallengeSystem.gd` e `systems/TransactionManager.gd`;
- autoridade e contexto do Delivery: `systems/DeliverySystem.gd`;
- requisitos pedagógicos atuais que motivam fatos neutros: `systems/DeliveryProgramValidator.gd`;
- limite atual de chamadas: `data/DeliveryConfig.gd`.

Erros, arrays estáticos, exigência de `main()` e acessos diretos à AST do C-like são somente características da implementação existente. Não definem a semântica Python-like.
