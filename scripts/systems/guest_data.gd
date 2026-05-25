class_name GuestData
extends RefCounted

enum GuestType { NORMAL, IMPORTANT }

var guest_name: String = ""
var type: int = GuestType.NORMAL
var order_key: String = ""
var npc_id: String = ""
var patience: float = 60.0
var has_dialogue: bool = false

const BASE_PATIENCE: float = 60.0
