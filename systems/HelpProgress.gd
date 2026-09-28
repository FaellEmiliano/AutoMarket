extends RefCounted
class_name HelpProgress

const ActiveExperienceData = preload("res://data/ActiveExperience.gd")

static func is_topic_active(topic: Dictionary) -> bool:
	return ActiveExperienceData.is_help_topic_active(str(topic.get("id", "")))

static func is_requirement_met(requirement: Variant) -> bool:
	if requirement == null:
		return true

	if requirement is Array:
		for item in requirement:
			if not is_requirement_met(item):
				return false
		return true

	var requirement_id := str(requirement)
	match requirement_id:
		"", "start":
			return true
		"troco":
			return FeatureManager.has_feature(FeatureManager.FEATURE_CHANGE)
		"sentinela", "loops":
			return FeatureManager.has_feature(FeatureManager.FEATURE_CART)
		"desconto":
			return FeatureManager.has_feature(FeatureManager.FEATURE_DISCOUNT)
		"estoque":
			return FeatureManager.has_feature(FeatureManager.FEATURE_STOCK)
		"if":
			return FeatureManager.has_feature(FeatureManager.FEATURE_IF)
		"sensor":
			return FeatureManager.has_feature(FeatureManager.FEATURE_SENSOR)
		"delivery":
			return FeatureManager.has_feature(FeatureManager.FEATURE_DELIVERY)
		"if_sensor":
			return (
				FeatureManager.has_feature(FeatureManager.FEATURE_IF)
				and FeatureManager.has_feature(FeatureManager.FEATURE_SENSOR)
			)
		_:
			return (
				FeatureManager.has_feature(requirement_id)
				or UpgradeManager.has_upgrade(requirement_id)
			)

static func get_visible_topics(topics: Array) -> Array:
	var visible_topics: Array = []
	for topic in topics:
		if topic is Dictionary and is_topic_active(topic) and is_requirement_met(topic.get("requirement", "")):
			visible_topics.append(topic)
	return visible_topics

static func get_active_topics(topics: Array) -> Array:
	var active_topics: Array = []
	for topic in topics:
		if topic is Dictionary and is_topic_active(topic):
			active_topics.append(topic)
	return active_topics
