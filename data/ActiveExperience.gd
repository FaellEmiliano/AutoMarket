class_name ActiveExperience
extends RefCounted

# Experiência integrada: estoque e checkout, depois troco, promoções e navegação.
# Conteúdo legado permanece preservado para compatibilidade de saves.
const ACTIVE_CHALLENGE_TYPE := "estoque"
const ACTIVE_HELP_TOPIC_IDS := [
	"python_blocks", "python_lists", "python_dicts", "python_if", "python_loops",
	"input", "product_table", "send", "print", "sensor", "wait",
	"stock_query", "budget", "stock_buy", "promotions_api",
	"delivery_overview", "delivery_matrix", "delivery_search", "delivery_api", "delivery_map_api", "delivery_route_api",
	"terminal", "change_client", "promotions", "stock", "automation",
]
const ACTIVE_UPGRADE_IDS: Array[String] = ["gameplay_change", "gameplay_promotions", "delivery_online"]

const SHOW_LEGACY_TUTORIAL := false
const SHOW_UPGRADE_SHOP := true
const SHOW_DELIVERY := true
const SHOW_COMPLETION_FLOW := false


static func is_help_topic_active(topic_id: String) -> bool:
	return ACTIVE_HELP_TOPIC_IDS.has(topic_id)


static func is_upgrade_active(upgrade_id: String) -> bool:
	return ACTIVE_UPGRADE_IDS.has(upgrade_id)
