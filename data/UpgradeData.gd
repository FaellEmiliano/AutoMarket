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
		"nome": "Cliente com troco",
		"categoria": "gameplay",
		"descricao": "Clientes entregam um valor acima do total e esperam o troco correto",
		"preco": 180,
		"dinheiro_minimo": 680,
		"requer": [],
		"help_topic": "change_client",
		"efeito": {"tipo": "unlock_feature", "feature": "change"}
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
		"descricao": "Abre uma plataforma de entregas. Calcule e declare os lucros para ganhar dinheiro e diamantes",
		"tooltip": "O Delivery gera relatórios com entregas normais, expressas e VIP. A solução usa função recursiva, if, array e for ou while para calcular as três categorias.",
		"preco": DeliveryConfigData.DELIVERY_UNLOCK_COST,
		"currency": "money",
		"requer": ["premium_3", "marketing_3"],
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
