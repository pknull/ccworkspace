extends DraggableItem
class_name FurnitureBase

## Base class for all furniture in the office.
## Extends DraggableItem to add trait-based agent interaction.

signal slot_reserved(furniture: FurnitureBase, slot_index: int, agent_id: String)
signal slot_released(furniture: FurnitureBase, slot_index: int, agent_id: String)

# Furniture identity
@export var furniture_type: String = ""  # e.g., "desk", "shredder"
@export var furniture_id: String = ""    # Unique instance ID

# Trait system - defines what agents can do with this furniture
# Examples: "terminal", "delivery", "social", "overflow", "viewable", "cat_rest"
var traits: Array[String] = []

# Slot system - where agents can stand/sit
var capacity: int = 1
var slots: Array = []  # [{offset: Vector2, occupied_by: String}, ...]

# Optional properties
var wall_mounted: bool = false
var delivery_sound: String = ""

func _init() -> void:
	# Subclasses should override to set traits, capacity, slots
	pass

func _ready() -> void:
	super._ready()

	# Override z-index behavior for wall-mounted furniture
	if wall_mounted:
		use_dynamic_z_index = false
		z_index = OfficeConstants.Z_WALL_DECORATION  # Wall-mounted items

	# Build visuals if not already built
	if get_child_count() == 0:
		_build_visuals()

	# Initialize slots if not set by subclass
	if slots.is_empty() and capacity > 0:
		_init_default_slots()

func _init_default_slots() -> void:
	# Default: single slot directly in front
	slots = []
	for i in range(capacity):
		slots.append({
			"offset": Vector2(0, 40),  # Default offset in front
			"occupied_by": ""
		})

## Override in subclasses to create visual representation
func _build_visuals() -> void:
	pass

# --- Trait System ---

func has_trait(trait_name: String) -> bool:
	return trait_name in traits

func get_traits() -> Array[String]:
	return traits

# --- Slot System ---

func get_available_slot() -> int:
	## Returns index of first available slot, or -1 if full
	for i in range(slots.size()):
		if slots[i].occupied_by == "":
			return i
	return -1

func is_slot_available(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= slots.size():
		return false
	return slots[slot_index].occupied_by == ""

func get_slot_position(slot_index: int) -> Vector2:
	## Returns world position for a slot
	if slot_index < 0 or slot_index >= slots.size():
		return position
	return position + slots[slot_index].offset

func get_slot_offset(slot_index: int) -> Vector2:
	## Returns offset for a slot (relative to furniture position)
	if slot_index < 0 or slot_index >= slots.size():
		return Vector2.ZERO
	return slots[slot_index].offset

func get_occupant(slot_index: int) -> String:
	## Returns agent_id occupying slot, or empty string
	if slot_index < 0 or slot_index >= slots.size():
		return ""
	return slots[slot_index].occupied_by

func find_slot_by_agent(agent_id: String) -> int:
	## Returns slot index occupied by agent, or -1 if not found
	for i in range(slots.size()):
		if slots[i].occupied_by == agent_id:
			return i
	return -1

func get_occupied_count() -> int:
	var count := 0
	for slot in slots:
		if slot.occupied_by != "":
			count += 1
	return count

func is_full() -> bool:
	return get_occupied_count() >= capacity

func is_empty() -> bool:
	return get_occupied_count() == 0

# --- Reservation ---

func reserve(agent_id: String, slot_index: int = -1) -> int:
	## Reserve a slot for an agent. Returns slot index or -1 on failure.
	## If slot_index is -1, finds first available slot.
	if slot_index == -1:
		slot_index = get_available_slot()

	if slot_index == -1:
		return -1  # No available slots

	if not is_slot_available(slot_index):
		return -1  # Slot already taken

	slots[slot_index].occupied_by = agent_id
	slot_reserved.emit(self, slot_index, agent_id)
	on_reserved(agent_id, slot_index)
	return slot_index

func release(agent_id: String) -> bool:
	## Release slot held by agent. Returns true if released.
	var slot_index := find_slot_by_agent(agent_id)
	if slot_index == -1:
		return false

	slots[slot_index].occupied_by = ""
	slot_released.emit(self, slot_index, agent_id)
	on_released(agent_id, slot_index)
	return true

func release_slot(slot_index: int) -> bool:
	## Release a specific slot. Returns true if released.
	if slot_index < 0 or slot_index >= slots.size():
		return false

	var agent_id: String = slots[slot_index].occupied_by
	if agent_id == "":
		return false

	slots[slot_index].occupied_by = ""
	slot_released.emit(self, slot_index, agent_id)
	on_released(agent_id, slot_index)
	return true

func release_all() -> void:
	## Release all slots (used when removing furniture)
	for i in range(slots.size()):
		if slots[i].occupied_by != "":
			var agent_id: String = slots[i].occupied_by
			slots[i].occupied_by = ""
			slot_released.emit(self, i, agent_id)
			on_released(agent_id, i)

# --- Hooks (override in subclasses) ---

func on_reserved(_agent_id: String, _slot_index: int) -> void:
	## Called when an agent reserves a slot
	pass

func on_agent_arrived(agent: Node, slot_index: int) -> void:
	## Called when an agent arrives at the furniture
	# Play delivery sound if applicable
	if delivery_sound != "" and has_trait("delivery"):
		_play_delivery_sound()

func on_agent_left(_agent: Node, _slot_index: int) -> void:
	## Called when an agent leaves the furniture
	pass

func on_released(_agent_id: String, _slot_index: int) -> void:
	## Called when a slot is released
	pass

func _play_delivery_sound() -> void:
	# Will be implemented when AudioManager integration is added
	if delivery_sound == "shredder":
		if has_node("/root/Main/AudioManager"):
			get_node("/root/Main/AudioManager").play_shredder()
	elif delivery_sound == "filing":
		if has_node("/root/Main/AudioManager"):
			get_node("/root/Main/AudioManager").play_filing()

# --- Serialization ---

func to_dict() -> Dictionary:
	## Serialize furniture state for persistence
	return {
		"type": furniture_type,
		"id": furniture_id,
		"position": [position.x, position.y],
	}

static func generate_id(type: String) -> String:
	## Generate unique furniture ID
	return "%s_%d" % [type, Time.get_ticks_msec()]
