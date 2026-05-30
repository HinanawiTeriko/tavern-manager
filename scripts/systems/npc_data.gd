class_name NpcData
extends RefCounted

var id: String = ""
var npc_name: String = ""
var title: String = ""
var description: String = ""
var affection_start: int = 0
var scenes: Array[NpcSceneData] = []
var endings: Dictionary = {}
var preferred_styles: Array = []
var disliked_styles: Array = []
