class_name ActiveExperience
extends RefCounted

# Durante a reconstrução, somente a experiência integrada de estoque é pública.
# O conteúdo legado continua no repositório e pode ser reativado alterando esta
# política, sem apagar dados de saves ou implementações antigas.
const ACTIVE_CHALLENGE_TYPE := "estoque"
const ACTIVE_HELP_TOPIC_IDS := ["terminal", "sensor", "stock"]
const ACTIVE_UPGRADE_IDS: Array[String] = []

const SHOW_LEGACY_TUTORIAL := false
const SHOW_UPGRADE_SHOP := false
const SHOW_DELIVERY := false
const SHOW_COMPLETION_FLOW := false


static func is_help_topic_active(topic_id: String) -> bool:
	return ACTIVE_HELP_TOPIC_IDS.has(topic_id)


static func is_upgrade_active(upgrade_id: String) -> bool:
	return ACTIVE_UPGRADE_IDS.has(upgrade_id)

