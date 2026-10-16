extends RefCounted
class_name HelpTopics

# Os IDs existentes permanecem válidos para upgrades e navegação.
const TOPICS = [
	{
		"id": "python_blocks",
		"title": "Indentação e blocos",
		"category": "Aprender a programar",
		"requirement": "start",
		"text": """[b]A linguagem do jogo[/b]
Você escreve em uma linguagem parecida com Python. Ela oferece o subconjunto descrito nesta ajuda; nem toda biblioteca ou método do Python está disponível. O código começa na primeira linha: não é necessário criar main().

[b]Espaços fazem parte da estrutura[/b]
if, elif, else, for e while terminam com dois-pontos. O bloco seguinte entra [b]quatro espaços à direita[/b]. Para sair do bloco, volte à indentação anterior. O editor usa quatro espaços; não misture tabs e espaços.

[b]Exemplo: o que está dentro do if?[/b]
[code]quantidade = 2
if quantidade > 0:
    print("Há produtos")
    print(quantidade)
print("Fim da verificação")[/code]
As duas linhas recuadas dependem da condição. A última sempre executa. A saída é “Há produtos”, depois 2, depois “Fim da verificação”.

[b]Valores e nomes[/b]
Use ponto em decimais (3.5), aspas em textos ("carrinho") e True/False em booleanos. Nomes distinguem maiúsculas de minúsculas. # inicia um comentário. = atribui; == compara.
[code]total = 10
print(total == 10)  # True[/code]""",
		"hint": """Confira a linha indicada pelo erro e a indentação do bloco anterior."""
	},
	{
		"id": "python_lists",
		"title": "Listas e índices",
		"category": "Aprender a programar",
		"requirement": "start",
		"text": """[b]Uma sequência de valores[/b]
Em Python, a estrutura usada aqui é chamada [b]lista (list)[/b], equivalente a um [b]array dinâmico[/b]. Você não declara seu tamanho: escreve os valores entre colchetes. Cada posição tem um índice, começando em zero.

[b]Ler, alterar e aumentar[/b]
[code]quantidades = [2, 1]
print(quantidades[0])  # 2
quantidades[1] = 3
quantidades = quantidades + [4]
print(quantidades)  # [2, 3, 4]
print(len(quantidades))  # 3[/code]
A concatenação cria uma lista nova. Alterar uma posição não aumenta o tamanho: quantidades[3] seria inválido nesta lista com três elementos.

[b]Percorrer[/b]
[code]for quantidade in [2, 3, 4]:
    print(quantidade)[/code]
A saída tem uma linha para cada valor: 2, 3 e 4.

[b]Lista ou dicionário?[/b]
Listas usam posições. O carrinho do mercado usa códigos de produtos como chaves, portanto é um dicionário. promocoes() retorna uma lista de dicionários.

[b]No jogo[/b]
Use + para criar uma lista concatenada e len() para medir o tamanho.

[b]Adicionar e remover[/b]
append(valor) acrescenta um elemento ao final da própria lista e retorna None. pop() remove e devolve o último elemento. pop(indice) remove e devolve a posição escolhida; índices negativos contam do fim.
[code]numeros = [10, 20]
resultado = numeros.append(30)
print(numeros)  # [10, 20, 30]
print(resultado)  # None
print(numeros.pop())  # 30
print(numeros.pop(0))  # 10
print(numeros)  # [20][/code]
Uma lista vazia ou um índice fora dos limites causa erro. Apelidos da mesma lista veem as alterações. Não altere uma lista enquanto um for a percorre; use uma fila com índice ou um while com pop().""",
		"hint": """O último índice positivo é len(lista) - 1."""
	},
	{
		"id": "python_dicts",
		"title": "Dicionários e chaves",
		"category": "Aprender a programar",
		"requirement": "start",
		"text": """[b]Associar uma chave a um valor[/b]
Um dicionário usa chaves entre {}. Em cada par, a chave vem antes dos dois-pontos e o valor depois. No carrinho, a [u]chave[/u] é o [b]código inteiro do produto[/b] e o [u]valor[/u] é a [b]quantidade[/b].

[code]carrinho = {101: 2, 102: 1}
print(carrinho[101])  # 2
carrinho[102] = 3[/code]
101 é uma chave, não a posição 101 de uma lista. A chave 101 é diferente do texto "101".

[b]Dicionário dentro de dicionário[/b]
[code]pedido = {"carrinho": {101: 2, 102: 1}}
print(pedido["carrinho"][101])  # 2[/code]
O primeiro acesso encontra o carrinho. O segundo encontra a quantidade do produto 101.

[b]Percorrer as chaves[/b]
[code]for codigo in carrinho:
    print(codigo, carrinho[codigo])[/code]
for percorre as chaves, não os valores. Com o carrinho alterado acima, mostra 101 2 e 102 3.

[b]Cuidados[/b]
Acessar uma chave ausente gera erro. Use in para verificar sua presença. Não adicione chaves nem altere valores de uma coleção enquanto o for a percorre. Métodos como .items() não estão disponíveis no jogo.""",
		"hint": """Leia pedido["carrinho"] como dois passos: encontrar o carrinho, depois encontrar uma chave dentro dele."""
	},
	{
		"id": "python_if",
		"title": "Decisões — if, elif e else",
		"category": "Aprender a programar",
		"requirement": "start",
		"text": """[b]Escolher um bloco[/b]
if testa a primeira condição. elif testa outra quando as anteriores falham. else trata os demais casos. [b]Apenas um ramo[/b] dessa sequência executa.

[code]quantidade = 3
if quantidade == 0:
    print("Sem unidades")
elif quantidade < 5:
    print("Poucas unidades")
else:
    print("Quantidade suficiente")[/code]
A saída é “Poucas unidades”. elif e else ficam alinhados com if.

[b]Comparar e combinar[/b]
Use ==, !=, <, <=, > e >= para comparar. and exige as duas condições; or aceita pelo menos uma; not inverte uma condição.
[code]saldo = 20
custo = 15
print(saldo >= custo and custo > 0)  # True[/code]

[b]No mercado[/b]
Decisões permitem testar se há cliente, se uma promoção é do produto atual e se o saldo comporta uma compra. A regra deve vir do desafio; if não cria descontos por conta própria.""",
		"hint": """Uma comparação produz True ou False. A atribuição = guarda o valor."""
	},
	{
		"id": "python_loops",
		"title": "Repetições — for e while",
		"category": "Aprender a programar",
		"requirement": "start",
		"text": """[b]for: para cada elemento[/b]
Use for quando já tem uma coleção. Em listas ele recebe os valores; em dicionários recebe as chaves.
[code]for codigo in {101: 2, 102: 1}:
    print(codigo)[/code]
Mostra 101 e 102. Não confunda a chave com a quantidade.

[b]while: enquanto a condição for verdadeira[/b]
[code]vezes = 0
while vezes < 3:
    print(vezes)
    vezes = vezes + 1[/code]
Mostra 0, 1 e 2. [b]A atualização[/b] permite que a condição deixe de ser verdadeira.

[b]Controle e contagem[/b]
break encerra o laço mais próximo; continue pula para a próxima volta. range(3) produz 0, 1 e 2: o limite final não entra na sequência.
[code]for indice in range(3):
    print(indice)[/code]

[b]Automação contínua[/b]
while True mantém o script ativo. Em um ciclo do mercado, use wait() para espaçar as verificações. PARAR interrompe o script. Não altere a coleção durante sua própria iteração.""",
		"hint": """Escolha for para percorrer um carrinho e while para manter uma automação ativa."""
	},
	{
		"id": "input",
		"title": "Ler o pedido — input()",
		"category": "Comandos do jogo",
		"requirement": "start",
		"text": """[b]Para que serve[/b]
Lê o pedido do cliente atual. Não abre uma pergunta para digitar no teclado.

[b]Como chamar[/b]
[code]pedido = input()
print(pedido)[/code]

[b]Formato retornado[/b]
Um pedido inicial pode ser literalmente:
[code]{"carrinho": {101: 2, 102: 1}}[/code]
"carrinho" contém outro dicionário. 101 e 102 são [b]códigos inteiros[/b]; 2 e 1 são [b]quantidades, não preços[/b].

[b]Acessar os dados[/b]
[code]carrinho = pedido["carrinho"]
print(carrinho[101])  # 2, para o pedido acima[/code]
O preço vem de tabela_produtos(), não do carrinho. O pagamento passa a integrar o mesmo pedido quando o upgrade Troco automático estiver ativo; veja o desafio Devolver o troco.

[b]Cuidados[/b]
Leia input() [b]uma vez por atendimento[/b] e guarde o resultado. Sem pedido disponível ou após consumir a entrada, retorna 0; acessar ["carrinho"] nesse número gera erro. Verifique sensor("cliente_na_tela") antes de ler. input() não é uma consulta repetível ao mesmo pedido.""",
		"hint": """Use print(pedido) logo após a leitura para conferir a estrutura real."""
	},
	{
		"id": "product_table",
		"title": "Consultar preços — tabela_produtos()",
		"category": "Comandos do jogo",
		"requirement": "start",
		"text": """[b]Para que serve[/b]
Retorna o catálogo, indexado por códigos inteiros. Cada código aponta para um dicionário com as informações do produto.

[b]Como chamar[/b]
[code]produtos = tabela_produtos()
print(produtos[101]["preco"])  # 3 no catálogo atual[/code]

[b]Formato retornado[/b]
Este recorte mostra duas entradas e somente seus campos nome/preco:
[code]{101: {"nome": "Arroz", "preco": 3}, 102: {"nome": "Feijao", "preco": 4}}[/code]
O catálogo real também contém custo, capacidade, lote, minimo, alvo e imagem em cada produto. [b]Não é um dicionário simples de código para preço.[/b]

[b]Interpretar o acesso[/b]
produtos[101] encontra as informações do arroz. produtos[101]["preco"] encontra seu preço unitário de venda. ["custo"] é o custo de reposição; ["lote"] é o múltiplo aceito na compra.

[b]Exemplo pequeno[/b]
[code]preco = produtos[101]["preco"]
quantidade = 2
print(preco * quantidade)  # 6[/code]
Consulte o catálogo para o preço atual: o recorte é uma explicação da estrutura, não uma tabela para fixar no programa.

[b]Campos usados para comprar estoque[/b]
Este recorte mostra os campos de reposição do arroz no catálogo atual:
[code]{101: {"custo": 3, "capacidade": 20, "lote": 5, "minimo": 5, "alvo": 15}}[/code]
• [b]"custo"[/b]: dinheiro gasto [u]por unidade[/u] comprada. Para repor, use custo; para cobrar do cliente, use preco. São campos diferentes, mesmo quando seus valores coincidem.
• [b]"capacidade"[/b]: quantidade máxima que cabe no estoque desse produto. A quantidade atual vem de get_stock(), não deste campo.
• [b]"lote"[/b]: múltiplo de unidades permitido na reposição. Com lote 5, compre 5, 10, 15… unidades; 1 ou 7 não respeitam o lote.
• [b]"minimo"[/b]: referência de estoque baixo para orientar sua automação.
• [b]"alvo"[/b]: quantidade desejada como referência de reposição. Não é a capacidade máxima.
[b]minimo e alvo não acionam compras automáticas[/b] nem são exigências de buy_stock(): seu programa decide quando e quanto comprar.

[b]Lote é uma regra da quantidade[/b]
Em buy_stock({101: 10}), o 10 significa dez unidades adicionais, ou dois lotes de cinco. Não significa dez lotes nem deixar o estoque com dez unidades. O custo é 10 × 3 = 30, não 2 × 3.

[b]Exemplo pequeno de reposição[/b]
Suponha que haja 5 unidades de arroz no estoque e saldo 30. Há espaço para 20 − 5 = 15 unidades. Comprar 10 respeita o lote, custa 30 e deixa 15 unidades no estoque.
[code]atual = get_stock()[101]
quantidade_compra = 10
print(produtos[101]["capacidade"] - atual)  # 15 neste exemplo
print(produtos[101]["custo"] * quantidade_compra)  # 30
print(quantidade_compra % produtos[101]["lote"] == 0)  # True
resultado = buy_stock({101: 10})
print(resultado["ok"])[/code]
% calcula o resto da divisão: resto zero significa que a quantidade respeita o lote. Execute a compra apenas quando houver espaço e saldo suficientes; confira o retorno. Comprar 15 caberia na prateleira, mas custaria 45 e falharia com saldo 30.

[b]Consultar não é comprar[/b]
tabela_produtos() somente informa as regras. get_stock() e get_budget() informam a disponibilidade atual; buy_stock() realiza a compra. Veja Comprar estoque — buy_stock() para os formatos de sucesso e falha.""",
		"hint": """Use o mesmo código para relacionar carrinho[codigo] e produtos[codigo]["preco"]."""
	},
	{
		"id": "send",
		"title": "Enviar a resposta — send()",
		"category": "Comandos do jogo",
		"requirement": "start",
		"text": """[b]Para que serve[/b]
Entrega a resposta final ao cliente e encerra a tentativa de atendimento. print() apenas mostra informações.

[b]Como chamar[/b]
[code]send(total)[/code]
Inicialmente, envie um único número: o total do carrinho inteiro. Quando Troco automático estiver ativo, a resposta passa a ter dois números na ordem total, troco; veja Devolver o troco.

[b]Exemplo isolado[/b]
Em uma compra cujo total já foi conferido como 10:
[code]total = 10
send(total)[/code]
10 é a resposta desse exemplo. Outros carrinhos precisam de outros resultados.

[b]Cuidados[/b]
[b]Não envie uma resposta para cada produto.[/b] Calcule tudo antes de chamar send(). Uma resposta errada também encerra a tentativa: confira com print() antes de enviar. O retorno booleano informa se a resposta foi aceita, mas não substitui os valores enviados.""",
		"hint": """Uma chamada final deve conter todos os valores pedidos pelo desafio."""
	},
	{
		"id": "print",
		"title": "Inspecionar valores — print()",
		"category": "Comandos do jogo",
		"requirement": "start",
		"text": """[b]Para que serve[/b]
Mostra valores no painel Saída do editor. É útil para conferir o que foi recebido e acompanhar cálculos.

[b]Como chamar[/b]
[code]print(valor)
print("Quantidade:", 2)
print({"carrinho": {101: 2}})[/code]
Você pode imprimir números, textos, listas e dicionários, inclusive mais de um valor na mesma linha.

[b]Exemplo pequeno[/b]
[code]preco = 3
quantidade = 2
print("Subtotal:", preco * quantidade)[/code]
A saída é “Subtotal: 6”.

[b]Cuidados[/b]
[b]print() não responde ao cliente[/b], não compra estoque e não altera o saldo. Ainda é necessário executar o comando que realiza a ação. Em uma repetição contínua, evite imprimir a cada verificação sem necessidade.""",
		"hint": """Compare o dado recebido com o valor calculado antes de executar uma ação."""
	},
	{
		"id": "sensor",
		"title": "Detectar clientes — sensor()",
		"category": "Comandos do jogo",
		"requirement": "sensor",
		"text": """[b]Para que serve[/b]
Consulta um estado da loja. Para saber se há um cliente pronto para receber uma resposta, use o nome "cliente_na_tela".

[b]Como chamar[/b]
[code]tem_cliente = sensor("cliente_na_tela")
print(tem_cliente)[/code]
Retorna [b]True ou False[/b].

[b]Exemplo pequeno[/b]
[code]if sensor("cliente_na_tela"):
    print("Há um pedido para atender")[/code]
Este trecho só detecta o cliente: não lê nem responde ao pedido.

[b]Cuidados[/b]
O nome deve ser texto entre aspas e escrito exatamente como acima. Depois de send(), esse sensor fica False durante o fechamento do atendimento. Para acompanhar se a transação ainda existe, há também sensor("atendimento_em_andamento").

Para manter a observação ativa, combine a consulta com uma repetição e wait(); veja Atendimento automático.""",
		"hint": """O sensor decide quando agir; input() fornece os dados para a ação."""
	},
	{
		"id": "wait",
		"title": "Pausar o script — wait()",
		"category": "Comandos do jogo",
		"requirement": "estoque",
		"text": """[b]Para que serve[/b]
Suspende [b]apenas o script que fez a chamada[/b] pelo número de segundos indicado. O jogo e os outros scripts continuam.

[b]Como chamar[/b]
[code]wait(0.1)[/code]
Use ponto para a parte decimal.

[b]Exemplo pequeno[/b]
[code]print("Antes da pausa")
wait(1)
print("Depois da pausa")[/code]
A segunda mensagem aparece após a espera.

[b]Cuidados[/b]
Use uma duração positiva em ciclos contínuos para espaçar as verificações. wait() não atende clientes, não repõe estoque e não aumenta a velocidade com que eles chegam. PARAR interrompe também um script que está aguardando.""",
		"hint": """Coloque uma pausa no ciclo mesmo quando não houver cliente."""
	},
	{
		"id": "stock_query",
		"title": "Consultar quantidades — get_stock()",
		"category": "Comandos do jogo",
		"requirement": "estoque",
		"text": """[b]Para que serve[/b]
Retorna as quantidades disponíveis no estoque, indexadas por código inteiro.

[b]Como chamar e formato[/b]
[code]estoque = get_stock()
print(estoque)[/code]
Um exemplo de retorno é:
[code]{101: 5, 102: 10, 103: 0, 104: 5, 105: 0, 106: 5}[/code]
São quantidades disponíveis, não preços nem itens de um pedido.

[b]Exemplo pequeno[/b]
[code]print(estoque[101])  # 5 no exemplo acima[/code]
Compare com tabela_produtos()[101]["capacidade"] para saber quanto cabe.

[b]Cuidados[/b]
O resultado é uma cópia do estado no momento da consulta. [b]Alterar esse dicionário não altera o estoque real.[/b] Faça uma nova consulta depois de vendas ou compras. Para repor de verdade, use buy_stock().""",
		"hint": """Diferencie carrinho (pedido do cliente) de estoque (disponibilidade da loja)."""
	},
	{
		"id": "budget",
		"title": "Consultar saldo — get_budget()",
		"category": "Comandos do jogo",
		"requirement": "estoque",
		"text": """[b]Para que serve[/b]
Retorna um número inteiro com o dinheiro disponível no caixa para reposição.

[b]Como chamar[/b]
[code]saldo = get_budget()
print(saldo)[/code]
Se houver 30 no caixa, o retorno é 30.

[b]Exemplo pequeno[/b]
[code]custo = tabela_produtos()[101]["custo"] * 5
print(saldo >= custo)[/code]
Com saldo 30 e custo unitário 3, um lote de 5 custa 15; a comparação retorna True.

[b]Cuidados[/b]
O saldo não é o pagamento do cliente nem o total de sua compra. Ao planejar uma reposição, use o campo [b]"custo"[/b]. Consulte novamente antes de comprar: outras ações podem alterar o saldo.""",
		"hint": """Calcule o custo da compra inteira antes de compará-lo com o saldo."""
	},
	{
		"id": "stock_buy",
		"title": "Comprar estoque — buy_stock()",
		"category": "Comandos do jogo",
		"requirement": "estoque",
		"text": """[b]Para que serve[/b]
Compra quantidades adicionais de produtos pelo código.

[b]Como chamar[/b]
[code]resultado = buy_stock({101: 5, 103: 10})
print(resultado)[/code]
O pedido compra 5 unidades de arroz e 10 de farinha, respeitando os lotes atuais de 5. Não significa “deixar o estoque com essas quantidades”.

[b]Formato retornado[/b]
Se a compra custar 55 e restarem 45:
[code]{"ok": True, "total": 55, "saldo": 45}[/code]
Em uma falha de orçamento:
[code]{"ok": False, "erro": "ORCAMENTO_INSUFICIENTE", "mensagem": "O saldo e insuficiente para esta compra."}[/code]

[b]Conferir[/b]
[code]if resultado["ok"]:
    print("Compra concluída")
else:
    print(resultado["mensagem"])[/code]
"erro" identifica o motivo; "mensagem" é a explicação para leitura.

[b]Cuidados[/b]
Códigos válidos, quantidades inteiras não negativas, múltiplos de lote, espaço e saldo são validados. A compra é [b]atômica[/b]: se um produto falhar, [b]nenhum é comprado e nenhum dinheiro é descontado[/b]. Os campos de sucesso e de falha são diferentes.""",
		"hint": """Confira espaço, lote e custo antes da compra; leia resultado["ok"] depois dela."""
	},
	{
		"id": "promotions_api",
		"title": "Consultar ofertas — promocoes()",
		"category": "Comandos do jogo",
		"requirement": "desconto",
		"text": """[b]Para que serve[/b]
Retorna as regras promocionais do atendimento atual. Cada regra informa seu tipo e seus parâmetros. Depois do upgrade, a lista contém uma ou duas regras; antes dele, retorna []. Consulte a cada pedido: as ofertas podem mudar entre clientes. Chamadas repetidas no mesmo atendimento retornam cópias equivalentes.

[b]Como chamar e formato[/b]
[code]regras = promocoes()
print(regras)[/code]
Contratos de cada regra:
[code]{"tipo": "leve_pague", "produto": 105, "leve": 3, "pague": 2}
{"tipo": "percentual", "produto": 102, "desconto": 0.40}[/code]
"produto" é o código. Em leve_pague, "leve" é a quantidade de cada grupo e "pague" é a quantidade cobrada por grupo. Em percentual, "desconto" é uma fração: 0.40 significa 40%. Os descontos possíveis são 0.20, 0.30 e 0.40.

[b]Exemplo pequeno[/b]
[code]for regra in regras:
    print(regra["tipo"], regra["produto"])[/code]
Cada regra pode se aplicar a um produto diferente. Duas ofertas simultâneas sempre usam produtos distintos. Confira o campo "tipo" antes de calcular; a posição na lista não identifica o tipo.

[b]Cuidados[/b]
A regra não é o carrinho e não fornece o total final. Relacione seu código com o produto comprado e consulte seu preço no catálogo. Em leve_pague, somente [b]grupos completos[/b] ganham a oferta. Em percentual, o desconto afeta [b]todas as unidades[/b] daquele produto presente no carrinho, mesmo uma única unidade. Uma oferta de produto ausente não altera o total. Veja Aplicar promoções.""",
		"hint": """Uma lista contém regras; cada regra é um dicionário com chaves textuais."""
	},
	{
		"id": "terminal",
		"title": "Total do carrinho",
		"category": "Desafios do mercado",
		"requirement": "start",
		"text": """[b]Objetivo[/b]
Calcular o valor de todos os produtos pedidos e responder ao cliente.

[b]Entrada[/b]
Uma leitura de input() fornece o pedido. Exemplo:
[code]{"carrinho": {101: 2, 102: 1}}[/code]
Consulte tabela_produtos() para os preços: no catálogo atual, arroz (101) custa 3 e feijão (102) custa 4.

[b]Saída esperada[/b]
Um número enviado com send(total). Para esse pedido, o total é 10.

[b]Regras[/b]
Cada subtotal é [b]preço unitário × quantidade[/b]. Some todos os subtotais. O número de tipos e as quantidades podem variar: não fixe o resultado nem conte apenas um produto. Os valores do carrinho são quantidades, nunca preços.

[b]Exemplo calculado[/b]
Arroz: 2 × 3 = 6.
Feijão: 1 × 4 = 4.
Total: 6 + 4 = 10.

[b]Como conferir[/b]
Use print() para inspecionar pedido, códigos, quantidades e subtotais. Confira também um carrinho com apenas um tipo e outro com quantidades diferentes. Envie uma única resposta final. Quando troco e promoções forem liberados, siga também suas regras.

[b]Usar o editor[/b]
RODAR inicia o arquivo visível. RODAR TODOS inicia os arquivos juntos. Você pode reunir a automação em um arquivo ou separá-la; evite dois scripts lendo o mesmo atendimento.""",
		"hint": """Guarde pedido e catálogo. Percorra as chaves do carrinho, relacione quantidade e preço pelo mesmo código e acumule os subtotais."""
	},
	{
		"id": "change_client",
		"title": "Devolver o troco",
		"category": "Desafios do mercado",
		"requirement": "troco",
		"text": """[b]Objetivo[/b]
Enviar o total da compra e o troco devido ao cliente.

[b]Entrada[/b]
O mesmo pedido de input() agora contém pagamento:
[code]{"carrinho": {101: 2, 102: 1}, "pagamento": 20}[/code]
Leia o valor por pedido["pagamento"]. Não faça outra chamada a input() para buscar o pagamento.

[b]Saída esperada[/b]
Dois números, nesta ordem:
[code]send(total, troco)[/code]
Para a compra acima, sem promoções: total 10, troco 10.

[b]Regras[/b]
Calcule primeiro o total final do carrinho. O troco é [b]pagamento menos total final[/b]. Quando houver promoções, aplique-as antes de calcular o troco. Pagamento não faz parte da soma dos produtos.

[b]Exemplo calculado[/b]
2 × 3 + 1 × 4 = 10.
Pagamento 20 − total 10 = troco 10.

[b]Como conferir[/b]
Imprima total, pagamento e troco. A soma total + troco deve ser igual ao pagamento. Confira a ordem da resposta; enviar apenas o total ou inverter os valores faz a tentativa ser recusada.""",
		"hint": """Use o pagamento do mesmo pedido. Confira total + troco antes de responder."""
	},
	{
		"id": "promotions",
		"title": "Aplicar promoções",
		"category": "Desafios do mercado",
		"requirement": "desconto",
		"text": """[b]Objetivo[/b]
Calcular o total com as ofertas ativas e devolver o troco sobre esse total.

[b]Entrada[/b]
Exemplo de pedido:
[code]{"carrinho": {104: 7, 101: 2}, "pagamento": 50}[/code]
Exemplo de promocoes():
[code][{"tipo": "leve_pague", "produto": 104, "leve": 3, "pague": 2}][/code]
No catálogo atual, morango custa 5 e arroz custa 3.

[b]Saída esperada[/b]
Total 31 e troco 19, enviados nessa ordem pelo comando de resposta.

[b]Regras[/b]
Confira o campo "tipo" de cada regra. A oferta leve_pague vale somente para [b]o código indicado[/b] e para [b]grupos completos[/b]. As unidades restantes custam o preço normal. Já a oferta percentual aplica sua fração de desconto a todas as unidades do produto indicado. Nenhuma oferta afeta outros produtos. Consulte todas as regras de cada atendimento, sem fixar código, tipo ou posição na lista.

[b]Exemplo calculado[/b]
7 morangos formam 2 grupos de 3 e sobra 1.
Cada grupo cobra 2: são 2 × 2 + 1 = 5 unidades pagas.
Morango: 5 × 5 = 25. Arroz: 2 × 3 = 6.
Total 31; pagamento 50 − 31 = troco 19.
O estoque perde todos os 7 morangos levados.

[b]Outro tipo: percentual[/b]
[code]{"tipo": "percentual", "produto": 102, "desconto": 0.40}[/code]
0.40 significa 40%. Três feijões a R$4 somam R$12; com essa oferta, custam R$7,20. O estoque continua perdendo três unidades. Os descontos possíveis são 20%, 30% e 40%. Se o produto não estiver no carrinho, a regra não altera o total. Uma ou duas regras podem estar ativas, sempre em produtos diferentes.

[b]Como conferir[/b]
Teste quantidades menores que um grupo, exatamente um grupo e um grupo com sobra. Confira também uma unidade com percentual e um produto sem oferta. O operador // conta grupos inteiros; % calcula o resto. Some os subtotais e arredonde o total final para duas casas decimais; calcule o troco sobre esse total.""",
		"hint": """Leia o tipo de cada regra e relacione seu produto ao carrinho. Cada formato possui seus próprios parâmetros."""
	},
	{
		"id": "stock",
		"title": "Repor o estoque",
		"category": "Desafios do mercado",
		"requirement": "estoque",
		"text": """[b]Objetivo[/b]
Repor produtos sem ultrapassar capacidade ou gastar além do saldo.

[b]Entrada[/b]
get_stock() informa quantidades; get_budget(), saldo; tabela_produtos(), custo, lote e capacidade de cada código.
Exemplo: arroz tem quantidade 5, capacidade 20, lote 5, custo unitário 3; o saldo é 30.

[b]Saída e ação esperadas[/b]
Envie a compra para buy_stock(), depois confira resultado["ok"]. Esta tarefa não usa send().

[b]Regras[/b]
Compre quantidades adicionais em múltiplos do lote. Compare [b]o custo de todos os itens[/b] com o saldo. Todas as validações são feitas antes da alteração: uma falha cancela a compra inteira.

[b]Exemplo calculado[/b]
Há espaço para 20 − 5 = 15 unidades de arroz.
Adicionar 10 custa 10 × 3 = 30, respeita o lote e cabe no saldo.
Depois da compra: 15 unidades e saldo 0.
Adicionar 15 caberia na prateleira, mas custaria 45 e falharia por orçamento.

[b]Como conferir[/b]
Consulte novamente estoque e saldo depois de comprar. Confira também falta de espaço, saldo insuficiente e quantidade fora do lote. Você pode repor pela interface Estoque.

[b]Bônus[/b]
Com todos os produtos no limite, a recompensa de cada atendimento vale 1,5x. O total enviado ao cliente não muda. Após uma venda, reponha para reativar o bônus.""",
		"hint": """Antes de comprar, compare quantidade, lote, capacidade e orçamento. Depois confira o resultado."""
	},
	{
		"id": "automation",
		"title": "Atendimento automático",
		"category": "Desafios do mercado",
		"requirement": "sensor",
		"text": """[b]Objetivo[/b]
Manter o script pronto para atender novos clientes sem apertar RODAR a cada compra.

[b]Entrada[/b]
sensor("cliente_na_tela") informa quando atender. input() fornece um único pedido por atendimento. As regras do carrinho, troco e promoções continuam valendo.

[b]Saída e comportamento esperados[/b]
Uma resposta completa por cliente, enviada com send(). Quando não houver cliente, o script deve esperar antes da próxima verificação.

[b]Regras[/b]
Organize um ciclo: verificar, atender quando necessário e esperar. Leia o pedido [b]uma vez[/b], guarde-o e conclua todos os cálculos [b]antes de enviar[/b]. Use wait() também nas voltas sem cliente. A espera não produz clientes mais rápido.

[b]Exemplo de comportamento[/b]
Sem cliente: verificar → esperar.
Com cliente: verificar → ler pedido → calcular → responder → esperar.
Depois, a próxima volta procura um novo atendimento.

[b]Como conferir[/b]
Observe mais de um cliente e também o intervalo vazio entre eles. Verifique se cada cliente recebe uma única resposta e se PARAR encerra o script. Não deixe dois arquivos competindo por input(): a entrada é compartilhada.

[b]Arquivos[/b]
RODAR TODOS mantém os arquivos ativos juntos. Uma opção é separar reposição e atendimento; cada arquivo pode ser parado individualmente. Cada wait() suspende somente o arquivo que o chamou.""",
		"hint": """Monte primeiro um atendimento correto. Depois envolva esse comportamento em um ciclo com sensor e pausa."""
	},
	{
		"id": "discount",
		"title": "Decisões e desconto",
		"category": "Lógica",
		"requirement": "if",
		"text": """[b]Tomar decisões com if[/b]
[code]if[/code] executa um bloco apenas quando uma condição é verdadeira. Transforme a regra em uma pergunta: o total passou do limite? Existe cliente esperando?

[b]Regra da loja[/b]
Quando o total bruto for maior que R$50, aplique 10% de desconto uma única vez sobre a compra inteira. Primeiro some tudo; só depois teste a condição.

[b]Estrutura mental[/b]
1. Calcule o total bruto.
2. Compare o total com 50.
3. Se for maior, calcule [code]total = total * 0.9[/code].
4. Envie o total final.

[b]Comparar não é guardar[/b]
[code]==[/code] compara dois valores. [code]=[/code] guarda um valor em uma variável. Confundir os dois altera o sentido do programa.""",
		"hint": "Imprima o total antes e depois do if para confirmar se o desconto aconteceu uma única vez."
	},
	{
		"id": "sentinel_client",
		"title": "Pedidos variáveis e repetição",
		"category": "Lógica",
		"requirement": "sentinela",
		"text": """[b]Pedidos sem tamanho fixo[/b]
Alguns clientes enviam uma quantidade variável de preços. O valor [code]-1[/code] é a sentinela: ele avisa que os produtos terminaram e nunca entra na soma.

[b]while: repetir até encontrar o fim[/b]
[code]while[/code] é ideal quando você ainda não sabe quantas voltas serão necessárias. Leia um valor, repita enquanto ele for diferente de [code]-1[/code] e leia novamente dentro do bloco.

[b]O que precisa mudar[/b]
Toda repetição deve avançar. Se a variável testada nunca recebe um novo [code]input()[/code], o programa observa o mesmo valor para sempre.

[b]for: repetir uma coleção conhecida[/b]
Use [code]for item in coleção:[/code] quando os elementos ou o número de voltas já estiverem definidos. O bloco abaixo do cabeçalho precisa estar indentado.

[b]Escolha rápida[/b]
Use [code]while[/code] para “até acontecer algo” e [code]for[/code] para “para cada item”.""",
		"hint": "No while, encontre a linha que atualiza o valor usado na condição. Sem ela, a repetição não avança."
	},
	{
		"id": "delivery_overview",
		"title": "Automatizar entregas",
		"category": "Desafios do mercado",
		"requirement": "delivery",
		"text": """[b]Objetivo[/b]
Concluir três entregas programando o caminho do motoqueiro. A automação pode continuar após a meta.

[b]Entrada e saída[/b]
entrega_atual() informa origem e destino; mapa_entrega() fornece as ruas. Calcule o caminho e envie a lista de coordenadas com enviar_rota(rota).

[b]Regras[/b]
Existe um único caminho livre. Inclua origem e destino, sem diagonais ou posições repetidas. Uma rota recusada pode ser corrigida.

[b]Como conferir[/b]
A chegada rende R$40; outra entrega surge após 15 segundos. Use wait(1) entre verificações. O mercado continua funcionando durante a viagem.""",
		"hint": "Separe a busca pelo caminho da repetição que aguarda novas entregas."
	},
	{
		"id": "delivery_matrix",
		"title": "Matrizes e coordenadas",
		"category": "Aprender a programar",
		"requirement": "delivery",
		"text": """[b]Uma lista de listas[/b]
Uma matriz é uma lista de listas. Acesse [linha][coluna], com índices começando em zero.
[code]matriz = [[1, 2], [3, 4]]
print(matriz[1][0])  # 3[/code]

[b]Mover em uma grade[/b]
Subir/descer altera a linha; ir para os lados altera a coluna. Confira os limites antes de acessar.

[b]No delivery[/b]
Na matriz 9×9 do bairro, 0 é terreno, 1 é rua livre e 2 é bloqueio. Só 1 permite passagem.""",
		"hint": "[0, 1] significa primeira linha, segunda coluna."
	},
	{
		"id": "delivery_search",
		"title": "Busca de caminhos — DFS e BFS",
		"category": "Aprender a programar",
		"requirement": "delivery",
		"text": """[b]Explorar vizinhos[/b]
Examine os quatro vizinhos de cada posição e marque os visitados para evitar repetições.

[b]Duas estratégias[/b]
DFS aprofunda uma direção, usando uma pilha; BFS explora em camadas, usando uma fila. Ambas resolvem o delivery, sem exigir recursão.

[b]Reconstruir a rota[/b]
Guarde de onde veio cada posição para reconstruir o caminho até o destino. Não envie todo o histórico da busca.""",
		"hint": "Os becos fazem parte da busca, mas não precisam aparecer na rota enviada."
	},
	{
		"id": "delivery_api",
		"title": "Consultar entrega — entrega_atual()",
		"category": "Comandos do jogo",
		"requirement": "delivery",
		"text": """[b]Para que serve[/b]
Retorna um dicionário com id, origem e destino. Sem entrega pendente, retorna None.

[b]Como chamar e formato[/b]
[code]entrega = entrega_atual()
if entrega:
    print(entrega["origem"], entrega["destino"])[/code]
Origem e destino são listas [linha, coluna].

[b]Cuidados[/b]
Durante a viagem e o intervalo, retorna None. Use wait() entre consultas.""",
		"hint": "Guarde a entrega antes de consultar o mapa e calcular a rota."
	},
	{
		"id": "delivery_map_api",
		"title": "Consultar bairro — mapa_entrega()",
		"category": "Comandos do jogo",
		"requirement": "delivery",
		"text": """[b]Para que serve[/b]
Retorna uma cópia da matriz: 0 = terreno, 1 = rua livre, 2 = bloqueio. Sem entrega pendente, retorna [].

[b]Como chamar[/b]
[code]mapa = mapa_entrega()
if mapa:
    print(mapa[0][0])[/code]

[b]Cuidados[/b]
Leia também entrega_atual() para o mesmo pedido. Alterar a cópia não muda as ruas reais.""",
		"hint": "Na busca, avance somente para posições dentro dos limites e com valor 1."
	},
	{
		"id": "delivery_route_api",
		"title": "Enviar caminho — enviar_rota()",
		"category": "Comandos do jogo",
		"requirement": "delivery",
		"text": """[b]Para que serve[/b]
Valida a rota e inicia a viagem. Retorna True se aceita ou False com a explicação da recusa.

[b]Como chamar[/b]
[code]rota = [[0, 0], [0, 1], [0, 2]]
print(enviar_rota(rota))[/code]
O exemplo mostra o formato, não uma solução para qualquer mapa.

[b]Cuidados[/b]
Use pares de inteiros, incluindo origem e destino, com passos de uma célula. Bloqueios e repetições são recusados sem mover o motoqueiro. Durante a viagem, aguarde.""",
		"hint": "Confira a primeira e a última coordenada antes de enviar."
	}
]
