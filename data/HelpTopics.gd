extends RefCounted
class_name HelpTopics

const TOPICS = [
	{
		"id": "terminal",
		"title": "Começar a atender",
		"category": "Atendimento",
		"requirement": "start",
		"text": """[b]Seu fluxo de trabalho[/b]
Escreva no editor, aperte [b]RODAR[/b] e acompanhe o retorno logo abaixo. Comece com poucas linhas e teste cedo. Se algo falhar, confira primeiro indentação, dois-pontos, parênteses e nomes.

[b]Ler o pedido com input()[/b]
[code]input()[/code] devolve a próxima informação da fila do cliente. No atendimento inicial, cada chamada lê o preço de um item. Some os valores na mesma ordem em que chegaram.

[b]Responder com send()[/b]
[code]send(total)[/code] entrega a resposta final ao cliente. Quando um atendimento pedir mais de um resultado, mantenha a ordem indicada na tela.

[b]Investigar com print()[/b]
[code]print(valor)[/code] mostra valores intermediários no retorno sem responder o cliente. Use para localizar onde uma conta saiu do esperado; depois ainda é necessário chamar [code]send()[/code].

[b]Organizar scripts[/b]
Você pode concentrar tudo em um arquivo ou separar responsabilidades. [b]RODAR TODOS[/b] inicia os arquivos juntos; cada aba também pode ser iniciada ou parada separadamente.

[b]Primeiro atendimento[/b]
Leia os dois preços, some e envie um único total. Respostas parciais não concluem a venda.""",
		"hint": "Mostre com print() cada valor recebido e o total antes de chamar send()."
	},
	{
		"id": "change_client",
		"title": "Pagamento e troco",
		"category": "Atendimento",
		"requirement": "troco",
		"text": """[b]O que muda[/b]
Depois dos itens, o cliente informa quanto entregou para pagar. Esse valor não entra no total da compra: ele serve para calcular o troco.

[b]Separar produtos do pagamento[/b]
Nos pedidos variáveis, leia preços até encontrar [code]-1[/code]. Não some esse marcador. O próximo [code]input()[/code] contém o pagamento.

[b]Calcular e responder[/b]
Use [code]troco = pagamento - total[/code] e envie exatamente dois valores nesta ordem:
[code]send(total, troco)[/code]

[b]Erros comuns[/b]
Somar o [code]-1[/code], tratar o pagamento como produto ou inverter total e troco faz a resposta ser recusada. Use [code]print()[/code] para conferir cada etapa antes de enviar.""",
		"hint": "Depois do -1, guarde o próximo valor como pagamento e confira pagamento - total."
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
		"id": "sensor",
		"title": "Automação contínua",
		"category": "Lógica",
		"requirement": "sensor",
		"text": """[b]Observar a loja[/b]
[code]sensor("cliente_na_tela")[/code] informa se existe um cliente esperando. O nome do sensor é texto e precisa estar entre aspas.

[b]Decidir quando agir[/b]
Combine o sensor com [code]if[/code] dentro de uma repetição. Assim o script atende somente quando há trabalho, sem exigir que você aperte [b]RODAR[/b] para cada cliente.

[b]Esperar sem travar[/b]
[code]wait(segundos)[/code] suspende apenas o script que fez a chamada. O jogo, os clientes e outros scripts continuam normalmente. Dentro de um laço contínuo, [code]wait(0.1)[/code] ou [code]wait(1)[/code] evita verificar a mesma coisa milhares de vezes.

[b]Ritmo da automação[/b]
Uma espera curta responde rápido; uma espera longa economiza verificações, mas pode demorar a notar o próximo cliente. Coloque a pausa depois de verificar ou atender.""",
		"hint": "Monte o ciclo: verificar o sensor, atender se necessário e esperar antes da próxima volta."
	},
	{
		"id": "stock",
		"title": "Estoque e reposição",
		"category": "Loja",
		"requirement": "estoque",
		"text": """[b]Atender pelo estoque[/b]
O cliente entrega em [code]input()[/code] um dicionário no formato [code]{código: quantidade}[/code]. Consulte [code]tabela_produtos()[codigo]["preco"][/code], multiplique pelo número de unidades e some o carrinho.

[b]Consultar produtos e quantidades[/b]
[code]tabela_produtos()[/code] contém nome, preço, custo, capacidade e lote. [code]get_stock()[/code] devolve a quantidade atual de cada código e [code]get_budget()[/code] informa o dinheiro disponível.

[b]Comprar pelo código[/b]
[code]buy_stock({101: 5, 103: 10})[/code] recebe códigos e quantidades. O resultado possui [code]resultado["ok"][/code]; em caso de falha, [code]resultado["erro"][/code] explica o motivo.

[b]Compra segura[/b]
Produto, lote, capacidade e orçamento são validados antes de qualquer alteração. A compra é atômica: se uma parte for inválida, nada entra no estoque e nenhum dinheiro é descontado.

[b]Bônus de prateleira cheia[/b]
Com todos os produtos no limite, a recompensa de cada atendimento vale 1,5x. O total enviado ao cliente não muda. Depois de uma venda, encha novamente o estoque para reativar o bônus.

[b]Pela interface[/b]
Você também pode abrir [b]Estoque[/b], escolher as quantidades e confirmar. Cada item mostra quantidade atual e capacidade, como [code]4/10[/code].""",
		"hint": "Antes de comprar, compare quantidade atual, lote, capacidade e orçamento; depois confira resultado[\"ok\"]."
	},
	{
		"id": "delivery_overview",
		"title": "Delivery Online completo",
		"category": "Delivery",
		"requirement": "delivery",
		"text": """[b]O objetivo[/b]
Cada relatório traz três quantidades nesta ordem: entregas normais, expressas e VIP. Ele permanece aberto até seu script declarar os três lucros corretos.

[b]Ler e declarar[/b]
[code]entregas = get_deliveries()[/code] devolve um array: [code][0][/code] normal, [code][1][/code] expressa e [code][2][/code] VIP.
[code]declare_profit(lucros)[/code] recebe outro array com três resultados na mesma ordem.

[b]Regra do lucro[/b]
Para [code]n[/code] entregas e valor-base [code]b[/code]:
[code]L(0) = 0[/code]
[code]L(n) = 2 * L(n - 1) + b[/code]
Normal usa [code]b = 2[/code], expressa usa [code]b = 4[/code] e VIP usa [code]b = 7[/code].

A fórmula [code]L(n) = b * (2^n - 1)[/code] serve apenas para conferir o resultado; a solução aprovada precisa usar a relação recursiva.

[b]Recursão segura[/b]
Crie uma função que chama a si mesma com [code]n - 1[/code]. Use [code]if[/code] para o caso-base [code]n == 0[/code]. Cada chamada precisa se aproximar desse caso; caso contrário, o limite de segurança interrompe o programa.

[b]Processar as categorias[/b]
Use [code]for[/code] ou [code]while[/code] para calcular as três posições. A função recursiva precisa participar de verdade desse cálculo — não basta deixá-la escrita sem uso.

[b]Continuar operando[/b]
Depois de uma declaração aprovada, use [code]wait(segundos)[/code] antes da próxima leitura. Diminuir a espera não cria relatórios ou recompensas mais rápido.

[b]Recompensas[/b]
O lucro aprovado entra no caixa e você recebe 1 diamante enquanto não tiver atingido o limite de 5. Junte 5 diamantes para comprar o upgrade final [b]Zerar[/b]. Uma resposta rejeitada não fecha o relatório: revise e tente novamente.""",
		"hint": "Teste primeiro L(0), depois L(1). Quando a função estiver correta, percorra as três bases [2, 4, 7] e monte o array final."
	}
]
