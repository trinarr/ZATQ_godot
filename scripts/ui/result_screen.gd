extends RefCounted
const POPUP := preload("res://scenes/shared/ResultPopup.tscn")
# Main owns routing; the standalone popup only draws the original result panel.
static func draw(ui: Control, node: Dictionary) -> void:
	var episode: int = int(node.get("episode",1))
	var panel := POPUP.instantiate()
	ui.overlay = panel
	ui._attach_panel(panel)
	panel.restart_requested.connect(ui._start)
	panel.menu_requested.connect(ui._show_menu)
	panel.next_episode_requested.connect(func(): ui._start_episode(episode+1))
	panel.configure(node,Quest.stats_for(episode),Quest.ending_count(episode),Quest.episode_starts.has(episode+1))
