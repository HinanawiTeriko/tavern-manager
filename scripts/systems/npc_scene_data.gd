class_name NpcSceneData
extends RefCounted

var day: int = 0
var dialogue: String = ""
var order: String = ""
var trigger = null  # String (旧格式) 或 Dictionary (新格式: {"type":"auto|affection","threshold":N})
var variables: Array[String] = []
