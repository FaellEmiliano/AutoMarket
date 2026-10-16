extends Node

const DeliveryConfigData = preload("res://data/DeliveryConfig.gd")

const UPGRADES = {
	"premium_1": {
		"nome": "Caixa mais esperto I",
		"categoria": "economia",
		"descricao": "+20% adicional e cumulativo na recompensa de cada atendimento",
		"preco": 40,
		"dinheiro_minimo": 0,
		"efeito": {"tipo": "reward_multiplier", "valor": 0.2}
	},
	"lang_if": {
		"retired": true,
		"nome": "Aprender if()",
		"categoria": "linguagem",
		"descricao": "Libera decisões no código. Compras acima de R$50 recebem 10% de desconto",
		"preco": 100,
		"dinheiro_minimo": 120,
		"help_topic": "discount",
		"efeito": {"tipo": "unlock_feature", "feature": "if"}
	},
	"lang_while": {
		"retired": true,
		"nome": "Aprender while()",
		"categoria": "linguagem",
		"descricao": "Clientes podem mandar vários preços; -1 avisa que a lista acabou",
		"preco": 110,
		"dinheiro_minimo": 220,
		"requer": ["lang_if"],
		"help_topic": "sentinel_client",
		"efeito": {"tipo": "unlock_feature", "feature": "cart"}
	},
	"marketing_1": {
		"nome": "Boca a boca I",
		"categoria": "fluxo",
		"descricao": "Clientes aparecem a cada 4s a 6s",
		"preco": 50,
		"dinheiro_minimo": 0,
		"efeito": {"tipo": "spawn_delay", "min": 4.0, "max": 6.0}
	},
	"premium_2": {
		"nome": "Caixa mais esperto II",
		"categoria": "economia",
		"descricao": "+25% adicional e cumulativo na recompensa de cada atendimento",
		"preco": 80,
		"dinheiro_minimo": 240,
		"requer": ["premium_1"],
		"efeito": {"tipo": "reward_multiplier", "valor": 0.25}
	},
	"lang_sensor": {
		"retired": true,
		"nome": "Aprender sensor()",
		"categoria": "linguagem",
		"descricao": "Permite o código olhar se tem cliente esperando",
		"preco": 180,
		"dinheiro_minimo": 360,
		"requer": ["lang_while"],
		"help_topic": "sensor",
		"efeito": {"tipo": "unlock_feature", "feature": "sensor"}
	},
	"marketing_2": {
		"nome": "Boca a boca II",
		"categoria": "fluxo",
		"descricao": "Clientes aparecem a cada 2.5s a 4.5s",
		"preco": 100,
		"dinheiro_minimo": 520,
		"requer": ["marketing_1"],
		"efeito": {"tipo": "spawn_delay", "min": 2.5, "max": 4.5}
	},
	"gameplay_change": {
		"nome": "Troco automático",
		"categoria": "gameplay",
		"descricao": "O pedido passa a incluir o pagamento. Responda com o total e o troco, nessa ordem.",
		"preco": 120,
		"saldo_minimo_compra": 250,
		"requer": [],
		"help_topic": "change_client",
		"efeito": {"tipo": "unlock_feature", "feature": "change"}
	},
	"gameplay_promotions": {
		"nome": "Sistema de promoções",
		"categoria": "gameplay",
		"descricao": "Ofertas leve X, pague Y passam a valer por produto. Calcule o total promocional antes do troco.",
		"preco": 160,
		"saldo_minimo_compra": 300,
		"requer": ["gameplay_change"],
		"help_topic": "promotions",
		"notification": "Sistema de promoções instalado. Use promocoes() para consultar as ofertas antes de calcular o total.",
		"efeito": {"tipo": "unlock_feature", "feature": "discount"}
	},
	"gameplay_stock": {
		"retired": true,
		"nome": "Abrir estoque",
		"categoria": "gameplay",
		"descricao": "Clientes pedem produtos com quantidade. Também libera estoque e wait()",
		"preco": 240,
		"dinheiro_minimo": 860,
		"requer": ["gameplay_change"],
		"help_topic": "stock",
		"efeito": {"tipo": "unlock_feature", "feature": "stock"}
	},
	"premium_3": {
		"nome": "Caixa mais esperto III",
		"categoria": "economia",
		"descricao": "+30% adicional e cumulativo na recompensa de cada atendimento",
		"preco": 150,
		"dinheiro_minimo": 1150,
		"requer": ["premium_2"],
		"efeito": {"tipo": "reward_multiplier", "valor": 0.3}
	},
	"marketing_3": {
		"nome": "Boca a boca III",
		"categoria": "fluxo",
		"descricao": "Clientes aparecem a cada 1s a 3s",
		"preco": 200,
		"dinheiro_minimo": 1500,
		"requer": ["marketing_2"],
		"efeito": {"tipo": "spawn_delay", "min": 1.0, "max": 3.0}
	},
	"delivery_online": {
		"nome": "Delivery Online",
		"categoria": "gameplay",
		"descricao": "Programe rotas pelo bairro e ganhe moedas a cada chegada. Complete três entregas.",
		"tooltip": "Use matrizes e uma busca DFS ou BFS para encontrar o único caminho livre. Não exige recursão.",
		"preco": DeliveryConfigData.DELIVERY_UNLOCK_COST,
		"currency": "money",
		"requer": ["gameplay_promotions"],
		"help_topic": "delivery_overview",
		"efeito": {"tipo": "unlock_delivery"}
	},
	"zerar": {
		"nome": "Zerar",
		"categoria": "final",
		"descricao": "Conclui sua jornada na loja. Custa 5 diamantes conquistados no Delivery Online",
		"tooltip": "Requer 5 diamantes. Você recebe diamantes ao aprovar relatórios do Delivery Online.",
		"preco": DeliveryConfigData.FINAL_UPGRADE_COST,
		"currency": "diamonds",
		"requer": ["delivery_online"],
		"efeito": {"tipo": "complete_game"}
	}
}
