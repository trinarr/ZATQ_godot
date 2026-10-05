@tool
extends "res://addons/dialogue_nodes/editor/graph.gd"
# Story mode of Dialogue Nodes. Its stock numeric dialogue serializer stays intact
# for regular .tres dialogues; stable screen IDs use the episode graph serializer.
var host: Control
func _ready() -> void:
 right_disconnects = true
 zoom_min = 0.15
 zoom_max = 2.0
func _input(_event: InputEvent) -> void: pass
func _on_connection_request(a: String, ap: int, b: String, _bp: int) -> void: host.connect_blocks(str(a),ap,str(b))
func _on_disconnection_request(a: String, ap: int, _b: String, _bp: int) -> void: host.disconnect_block(str(a),ap)
func _on_delete_nodes_request(names: Array[StringName]) -> void: host.delete_blocks(names)
func _on_duplicate_nodes_request() -> void: host.duplicate_selected()
func _on_node_selected(node: Node) -> void: host.inspect(str(node.name))
func _on_node_deselected(_node: Node) -> void: pass
func _on_connection_to_empty(_a: String, _port: int, _position: Vector2) -> void: pass
func _on_graph_elements_linked_to_frame_request(_elements: Array, _frame: StringName) -> void: pass
func show_add_menu(position: Vector2) -> void:
 host.add_menu.position = Vector2i(position)
 host.add_menu.popup()
func _on_add_menu_pressed(_id: int) -> void: pass
