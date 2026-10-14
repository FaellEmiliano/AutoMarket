class_name ActiveExperience
extends RefCounted

# Durante a reconstrução, somente a experiência integrada de estoque é pública.
# O conteúdo legado continua no repositório e pode ser reativado alterando esta
# política, sem apagar dados de saves ou implementações antigas.
const ACTIVE_CHALLENGE_TYPE := "estoque"
const ACTIVE_HELP_TOPIC_IDS := [
	"python_blocks", "python_lists", "python_dicts", "python_if", "python_loops",
	"input", "product_table", "send", "print", "sensor", "wait",
	"stock_query", "budget", "stock_buy", "promotions_api",
	"terminal", "change_client", "promotions", "stock", "automation",
]
const ACTIVE_UPGRADE_IDS: Array[String] = ["gameplay_change", "gameplay_promotions"]

const SHOW_LEGACY_TUTORIAL := false
const SHOW_UPGRADE_SHOP := true
const SHOW_DELIVERY := false
const SHOW_COMPLETION_FLOW := false


static func is_help_topic_active(topic_id: String) -> bool:
	return ACTIVE_HELP_TOPIC_IDS.has(topic_id)


static func is_upgrade_active(upgrade_id: String) -> bool:
	return ACTIVE_UPGRADE_IDS.has(upgrade_id)
