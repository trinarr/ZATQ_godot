extends Control
const BLOCK := preload("res://scripts/ui/shared/narrative_block.gd")
var blocks: Array = []
var active := 0
func _init() -> void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 hide()
func reset() -> void:
 for block in blocks:block.park(self)
 active=0
func show_block(host: Control, value: String, rect: Rect2, font: Font, font_size: int, options: Dictionary = {}) -> Label:
 if active==blocks.size():blocks.append(BLOCK.new())
 var block=blocks[active];active+=1
 options=options.duplicate()
 options.storage=self
 return block.configure(host,value,rect,font,font_size,options)
func band_for(label: Label) -> ColorRect:
 for block in blocks:
  if block.label==label:return block.band if block.band.get_parent()!=null and block.band.visible else null
 return null
