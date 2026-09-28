class_name ChallengeData

var type : String = ""

var order : ClientOrder

var values = []

var expected_output = []

var payment : float = 0

var requested_items = []

var cart : Dictionary = {}

var price_snapshot : Dictionary = {}

var requires_stock : bool = false

var applies_discount : bool = false

var is_golden : bool = false

var difficulty : int = 1

# Recompensa em dinheiro ao completar o desafio
var reward : int = 5

var stock_bonus_active : bool = false

var stock_bonus_multiplier : float = 1.0

var env_context = null
