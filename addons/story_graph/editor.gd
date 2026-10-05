@tool
extends VBoxContainer
const LOC = preload("res://scripts/core/localization.gd")
const MODEL = preload("res://addons/story_graph/graph.gd")
const CANVAS = preload("res://addons/story_graph/canvas.gd")
const GRAPH_SCENE = preload("res://addons/dialogue_nodes/editor/Graph.tscn")
const QTE := preload("res://scripts/core/qte_rules.gd")
const LABELS := {"scene":"Сцена", "choice":"Ответ", "condition":"Условие", "action":"Действие", "dialogue":"Реплика", "code":"Ввод кода", "qte":"QTE"}
const COLORS := {"scene":Color("6d9bea"),"choice":Color("72caba"),"condition":Color("eab761"),"action":Color("bda0ed"),"dialogue":Color("69cbde"),"code":Color("e6a5cc"),"qte":Color("e77973")}
var editor_plugin: EditorPlugin
var document: Dictionary = {}
var path := "res://data/story_graphs/episode1.json"
var dirty := false
var selected := ""
var canvas: GraphEdit
var inspector: VBoxContainer
var add_menu: PopupMenu
var episode := OptionButton.new()
var status := Label.new()
var search := LineEdit.new()
var results := ItemList.new()
var node_ids: Dictionary = {}
var names: Dictionary = {}
var port_map: Dictionary = {}
var history: Array = []
var future: Array = []
var pending_edit := false
var edit_timer := Timer.new()
var preview: Window
var simulator: Node
var preview_box: VBoxContainer
var preview_flags: VBoxContainer
var preview_log: RichTextLabel
var preview_active := ""
var preview_trace: Array = []
func _ready() -> void:
 size_flags_horizontal = Control.SIZE_EXPAND_FILL
 size_flags_vertical = Control.SIZE_EXPAND_FILL
 var bar := HBoxContainer.new()
 add_child(bar)
 episode.add_item("I. Первый эпизод",1)
 episode.add_item("II. Скорее мертв, чем жив",2)
 for filename:String in DirAccess.get_files_at("res://data/story_graphs"):
  if not filename.begins_with("episode") or not filename.ends_with(".json"):continue
  var graph:Dictionary=MODEL.load_graph("res://data/story_graphs/"+filename)
  var number:=int(graph.get("episode",0))
  if number>2:episode.add_item(LOC.source(graph.get("title","Эпизод "+str(number))),number)
 episode.item_selected.connect(_switch_episode)
 episode.clip_text=true
 episode.custom_minimum_size.x=255
 bar.add_child(episode)
 button(bar,"Новый эпизод",_new_episode)
 button(bar,"Открыть…",_open_dialog)
 button(bar,"Параметры",episode_settings)
 button(bar,"Сохранить",save_document)
 button(bar,"Отменить",undo)
 button(bar,"Повторить",redo)
 button(bar,"Проверить",validate_document)
 button(bar,"Разложить",arrange_blocks)
 button(bar,"Тест с блока",start_preview)
 var add := MenuButton.new()
 add.text = "+ Блок"
 bar.add_child(add)
 add_menu = add.get_popup()
 for t: String in LABELS: add_menu.add_item(LABELS[t])
 add_menu.id_pressed.connect(func(i): add_block(LABELS.keys()[i]))
 var split := HSplitContainer.new()
 split.size_flags_vertical = Control.SIZE_EXPAND_FILL
 add_child(split)
 canvas = GRAPH_SCENE.instantiate()
 canvas.set_script(CANVAS)
 canvas.host = self
 canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 split.add_child(canvas)
 var side := VBoxContainer.new()
 side.custom_minimum_size.x = 380
 split.add_child(side)
 search.placeholder_text = "Найти текст или ID блока"
 side.add_child(search)
 search.text_changed.connect(_search)
 results.custom_minimum_size.y = 110
 side.add_child(results)
 results.item_selected.connect(func(i): focus_block(results.get_item_metadata(i)))
 var scroll := ScrollContainer.new()
 scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
 side.add_child(scroll)
 inspector = VBoxContainer.new()
 inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 scroll.add_child(inspector)
 status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 add_child(status)
 edit_timer.one_shot = true
 edit_timer.wait_time = 0.5
 edit_timer.timeout.connect(_finish_edit)
 add_child(edit_timer)
 load_document(path)
func button(parent: Node, text: String, callback: Callable) -> Button:
 var b := Button.new()
 b.text = text
 b.clip_text = true
 b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
 b.tooltip_text = text
 b.custom_minimum_size.x = minf(310,maxf(40,b.get_theme_font("font").get_string_size(text).x+20))
 b.pressed.connect(callback)
 parent.add_child(b)
 return b
func label(parent: Node, text: String) -> Label:
 var l := Label.new()
 l.text = text
 l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 parent.add_child(l)
 return l
func clear(parent: Node) -> void:
 for child in parent.get_children():
  parent.remove_child(child)
  child.queue_free()
func _unhandled_key_input(event: InputEvent) -> void:
 if not is_visible_in_tree(): return
 if event is InputEventKey and event.pressed and event.ctrl_pressed:
  if event.keycode == KEY_S: save_document(); get_viewport().set_input_as_handled()
  elif event.keycode == KEY_Z and not event.shift_pressed: undo(); get_viewport().set_input_as_handled()
  elif event.keycode == KEY_Y or (event.keycode == KEY_Z and event.shift_pressed): redo(); get_viewport().set_input_as_handled()
func checkpoint() -> void:
 _finish_edit()
 history.append(document.duplicate(true))
 if history.size() > 60: history.pop_front()
 future.clear()
func begin_edit() -> void:
 if not pending_edit:
  history.append(document.duplicate(true))
  future.clear()
  pending_edit = true
 edit_timer.start()
 dirty = true
func _finish_edit() -> void:
 if not pending_edit: return
 pending_edit = false
 edit_timer.stop()
 rebuild(false)
func undo() -> void:
 _finish_edit()
 if history.is_empty(): return
 future.append(document.duplicate(true))
 document = history.pop_back()
 dirty = true
 rebuild()
func redo() -> void:
 if future.is_empty(): return
 history.append(document.duplicate(true))
 document = future.pop_back()
 dirty = true
 rebuild()
func load_document(new_path: String) -> void:
 _finish_edit()
 var loaded := MODEL.load_graph(new_path)
 if loaded.is_empty(): status.text = "Не удалось открыть " + new_path; return
 LOC.prepare(true)
 document = LOC.resolve_tree(loaded,true)
 _select_episode(int(document.get("episode",1)))
 path = new_path.trim_suffix(".draft")
 selected = ""
 dirty = false
 history.clear()
 future.clear()
 rebuild()
 status.text = "Открыт " + path + ". Соединяйте выходы справа со входом блока слева."
func _select_episode(number:int)->void:
 for i:int in episode.item_count:
  if episode.get_item_id(i)==number:episode.select(i);return
 episode.add_item(document.get("title","Эпизод "+str(number)),number)
 episode.select(episode.item_count-1)
func _switch_episode(index: int) -> void:
 var p := "res://data/story_graphs/episode%d.json" % episode.get_item_id(index)
 if dirty:
  var confirm := ConfirmationDialog.new()
  confirm.dialog_text = "Сохранить изменения перед сменой эпизода?"
  confirm.get_ok_button().text = "Сохранить и открыть"
  confirm.add_button("Открыть без сохранения",true,"discard")
  add_child(confirm)
  confirm.confirmed.connect(func():
   if save_document(): load_document(p)
   confirm.queue_free())
  confirm.custom_action.connect(func(_a): load_document(p);confirm.queue_free())
  confirm.canceled.connect(func(): _select_episode(int(document.episode));confirm.queue_free())
  confirm.popup_centered()
 else: load_document(p)
func _new_episode() -> void:
 var dialog := ConfirmationDialog.new()
 dialog.title = "Новый эпизод"
 dialog.dialog_text = "Номер эпизода (существующие файлы не перезаписываются)"
 var n := SpinBox.new()
 n.min_value = 3; n.max_value = 99; n.value = 3
 while n.value<99 and FileAccess.file_exists("res://data/story_graphs/episode%d.json" % int(n.value)):n.value+=1
 dialog.add_child(n)
 add_child(dialog)
 dialog.confirmed.connect(func():
  if dirty and not save_document(): return
  var number := int(n.value)
  var new_path := "res://data/story_graphs/episode%d.json" % number
  if FileAccess.file_exists(new_path): status.text = "Файл уже существует: " + new_path;return
  document = {"version":1,"episode":number,"start":"","nodes":{},"edges":[]}
  path = new_path;selected="";history.clear();future.clear();dirty=true
  add_block("scene")
  dialog.queue_free())
 dialog.popup_centered()
func _open_dialog() -> void:
 var dialog := EditorFileDialog.new()
 dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
 dialog.add_filter("*.json,*.draft", "Граф эпизода / черновик")
 dialog.current_dir = "res://data/story_graphs"
 add_child(dialog)
 dialog.file_selected.connect(func(p):
  if dirty and not save_document(): return
  load_document(p);dialog.queue_free())
 dialog.popup_centered_ratio(0.65)
func save_document() -> bool:
 _finish_edit()
 var errors := MODEL.validate(document)
 if not errors.is_empty():
  var draft_error := MODEL.save_graph(path+".draft",document)
  if draft_error!=OK:status.text="Ошибка сохранения черновика: "+error_string(draft_error);return false
  dirty=false
  status.text="Черновик сохранён: "+path+".draft. Игра использует предыдущий завершённый граф.\n"+"\n".join(errors)
  return true
 var err := LOC.publish(path,document)
 if err != OK: status.text = "Ошибка сохранения: " + error_string(err);return false
 if FileAccess.file_exists(path+".draft"):DirAccess.remove_absolute(path+".draft")
 dirty = false
 status.text = "Сохранён " + path + ". Игра читает этот граф при следующем запуске."
 if editor_plugin != null: editor_plugin.get_editor_interface().get_resource_filesystem().scan()
 return true
func save_if_dirty() -> void:
 if dirty: save_document()
func validate_document() -> void:
 var errors := MODEL.validate(document)
 status.text = "Проверка пройдена: %d блоков, %d связей." % [document.nodes.size(),document.edges.size()] if errors.is_empty() else "\n".join(errors)
func port_labels(id: String) -> Dictionary:
 var type: String = document.nodes[id].type
 var result := {}
 if type in MODEL.SCENE_TYPES:
  for p: String in MODEL.ports(document,id,"choice:"):
   var ordinal: int=int(p.get_slice(":",1))
   result[p] = "Ответ " + str(ordinal+1)
   if type=="code" and ordinal<2:result[p]=["Код верен","Попытки исчерпаны"][ordinal]
   elif type=="qte":
    var d:Dictionary=document.nodes[id].data
    if d.get("qte_mode","")=="branch":
     result[p] = d.get("targets",[])[ordinal].get("text","Направление") if ordinal<2 else "Время истекло"
    elif ordinal<2:result[p]=["Нажатия выполнены","Время истекло"][ordinal]
  if type in ["code","qte"] and result.is_empty():
   result["choice:0"] = "Результат 1";result["choice:1"] = "Результат 2"
  for p: String in ["entry","pickup","back"]:
   if not MODEL.target(document,id,p).is_empty(): result[p] = {"entry":"При входе","pickup":"Проверить предмет","back":"Закрыть / назад"}[p]
  for p: String in MODEL.ports(document,id,"variant:"): result[p] = "Вариант " + str(int(p.get_slice(":",1))+1)
 elif type == "choice":
  result["next"] = "Далее"
  result["effects"] = "Последствия"
  result["requires"] = "Доступность"
  for p: String in MODEL.ports(document,id,"route:"): result[p] = "Если " + str(int(p.get_slice(":",1))+1)
  for p: String in ["with_keys","by_car"]:
   if not MODEL.target(document,id,p).is_empty(): result[p] = "Есть ключи" if p == "with_keys" else "На машине"
 elif type == "condition":
  var auxiliary := false
  for edge:Dictionary in document.edges:
   if edge.to==id and (edge.port=="requires" or str(edge.port).begins_with("variant:")):auxiliary=true
  if not auxiliary:result["true"] = "Условие выполнено"
 return result
func summary(id: String) -> String:
 var d: Dictionary = document.nodes[id].data
 match document.nodes[id].type:
  "action": return "Установить: " + str(d.get("set",{})) + "\nИзменить: " + str(d.get("add",{}))
  "condition": return "Если " + str(d.get("when",{})) + ("\nБез ключей" if d.get("unless_keys",false) else "") + ("\n"+str(d.patch) if d.has("patch") else "")
  "code": return "Код: " + str(d.get("code_variable","code")) + "\nПопыток: " + str(d.get("attempts",3))
  "qte": return "Нажатий: %s · Время: %s с" % [d.get("taps",10),d.get("seconds",5)]
  _: return (str(d.get("speaker",""))+"\n"+str(d.get("text", ""))).strip_edges().left(170)
func rebuild(refresh_inspector: bool = true) -> void:
 canvas.clear_connections()
 for child in canvas.get_children():
  if child is GraphElement: canvas.remove_child(child);child.queue_free()
 names.clear();node_ids.clear();port_map.clear()
 var i := 0
 for id: String in document.nodes:
  var data: Dictionary = document.nodes[id]
  var node := GraphNode.new()
  node.name = "N"+str(i);i+=1
  names[id] = str(node.name);node_ids[str(node.name)] = id
  node.title = LABELS.get(data.type,data.type)+" · "+str(data.get("title",id)).left(50)
  node.tooltip_text = id+"\n"+summary(id)
  node.custom_minimum_size.x = 285
  node.size = Vector2(285,0)
  node.position_offset = Vector2(data.position[0],data.position[1])
  var color: Color = COLORS.get(data.type,Color.WHITE)
  var style := StyleBoxFlat.new();style.bg_color = color.darkened(0.64)
  style.border_color = color;style.set_border_width_all(2)
  node.add_theme_stylebox_override("panel",style)
  var selected_style:StyleBoxFlat=style.duplicate()
  selected_style.border_color=Color("ffe6a2")
  selected_style.set_border_width_all(3)
  node.add_theme_stylebox_override("panel_selected",selected_style)
  var header:StyleBoxFlat=StyleBoxFlat.new()
  header.bg_color=color.darkened(0.52)
  header.content_margin_left=8;header.content_margin_right=8
  header.content_margin_top=5;header.content_margin_bottom=5
  node.add_theme_stylebox_override("titlebar",header)
  node.add_theme_stylebox_override("titlebar_selected",header)
  canvas.add_child(node)
  var ps := port_labels(id)
  port_map[str(node.name)] = ps.keys()
  if ps.is_empty():
   label(node,"Вход")
   node.set_slot(0,true,0,color,false,0,color)
  else:
   var row := 0
   for port: String in ps:
    var l := label(node,ps[port]);l.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
    node.set_slot(row,row==0,0,color,true,0,color)
    row+=1
  var text := label(node,summary(id));text.custom_minimum_size.x=265
  text.mouse_filter=Control.MOUSE_FILTER_IGNORE
  var art: String = data.data.get("art","")
  if not art.is_empty() and data.type in MODEL.SCENE_TYPES:
   var texture_path: String = "res://assets/flash_ui/"+art+"."+data.data.get("art_extension","png")
   if ResourceLoader.exists(texture_path):
    var image := TextureRect.new();image.texture=load(texture_path)
    image.custom_minimum_size=Vector2(260,110)
    image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    image.mouse_filter=Control.MOUSE_FILTER_IGNORE
    node.add_child(image)
  node.dragged.connect(func(_old: Vector2, pos: Vector2):
   checkpoint();document.nodes[id].position=[pos.x,pos.y];dirty=true)
  node.selected = id == selected
  node.set_deferred("size",Vector2(285,0))
 for edge: Dictionary in document.edges:
  if not names.has(edge.from) or not names.has(edge.to): continue
  var index: int = port_map[names[edge.from]].find(edge.port)
  if index >= 0: canvas.connect_node(names[edge.from],index,names[edge.to],0)
 _search(search.text)
 if refresh_inspector: _inspect_id(selected)
func inspect(node_name: String) -> void:
 selected=node_ids.get(node_name,"")
 _inspect_id(selected)
func focus_block(id: String) -> void:
 if not names.has(id): return
 selected=id
 for child in canvas.get_children():
  if child is GraphNode: child.selected=str(child.name)==names[id]
 var p: Array=document.nodes[id].position
 canvas.scroll_offset=Vector2(p[0],p[1])*canvas.zoom-canvas.size*0.3
 _inspect_id(id)
func _search(query: String) -> void:
 results.clear()
 var count:=0
 for id: String in document.get("nodes",{}):
  if not query.is_empty() and query.to_lower() not in (id+" "+summary(id)).to_lower(): continue
  if count >= 100: break
  results.add_item(LABELS.get(document.nodes[id].type,"")+" · "+id)
  results.set_item_metadata(count,id);count+=1
func connect_blocks(a: String, port_index: int, b: String) -> void:
 if not node_ids.has(a) or not node_ids.has(b): return
 var port: String=port_map[a][port_index]
 var from_id: String=node_ids[a];var to_id: String=node_ids[b]
 var draft := document.duplicate(true)
 draft.edges=draft.edges.filter(func(e):return not (e.from==from_id and e.port==port))
 draft.edges.append({"from":from_id,"port":port,"to":to_id})
 # Check the new connection's type immediately; incomplete draft nodes remain editable.
 var expected: String="scene"
 if port.begins_with("choice:"):expected="choice"
 elif port in ["entry","effects"]:expected="action"
 elif port in ["requires","pickup"] or port.begins_with("route:") or port.begins_with("variant:"):expected="condition"
 var actual: String=document.nodes[to_id].type
 if (expected=="scene" and actual not in MODEL.SCENE_TYPES) or (expected!="scene" and actual!=expected):
  status.text="Нужен блок: "+LABELS.get(expected,expected);return
 checkpoint();document=draft;dirty=true;rebuild()
func disconnect_block(a: String, port_index: int) -> void:
 var id: String=node_ids.get(a,"")
 if id.is_empty():return
 var port: String=port_map[a][port_index]
 checkpoint()
 document.edges=document.edges.filter(func(e):return not(e.from==id and e.port==port))
 dirty=true;rebuild()
func delete_blocks(list: Array[StringName]) -> void:
 checkpoint()
 var ids: Array=[]
 for n: StringName in list:
  var id: String=node_ids.get(str(n),"")
  if id==document.start:status.text="Начальную сцену нельзя удалить: сначала назначьте другую.";continue
  ids.append(id);document.nodes.erase(id)
 document.edges=document.edges.filter(func(e):return e.from not in ids and e.to not in ids)
 selected="";dirty=true;rebuild()
func unique_id(prefix: String) -> String:
 var n:=1
 while document.nodes.has(prefix+str(n)):n+=1
 return prefix+str(n)
func add_block(type: String, parent: String = "", port: String = "") -> String:
 checkpoint()
 var id:=unique_id("e%d_%s_" % [int(document.episode),type])
 var data: Dictionary={}
 match type:
  "scene":data={"source":"Story Graph","kind":"city_story","text":"Новая сцена","blocks":[{"text":"Новая сцена","rect":[70,20,660,120],"font":"GraffitiC1 Medium","size":24}],"art":"result_background","clean_background":true}
  "choice":data={"text":"Далее"}
  "condition":data={"when":{"BulletsNumber":{"min":1}}}
  "action":data={"set":{},"add":{}}
  "dialogue":data={"source":"Story Graph","speaker":"Персонаж","text":"Реплика","art":"result_background"}
  "code":data={"source":"Story Graph","text":"Введите код","code_variable":"code","attempts":3,"art":"result_background"}
  "qte":data={"source":"Story Graph","text":"Нажимайте быстро","taps":10,"seconds":5.0,"target_mode":"fixed","art":"result_background"}
 var pos:=canvas.scroll_offset/canvas.zoom+Vector2(100,100)
 if not parent.is_empty():
  var old:Array=document.nodes[parent].position;pos=Vector2(old[0]+420,old[1]+70)
 document.nodes[id]={"type":type,"data":data,"title":LABELS[type],"position":[pos.x,pos.y]}
 if document.start.is_empty() and type in MODEL.SCENE_TYPES:document.start=id
 if not parent.is_empty():document.edges.append({"from":parent,"port":port,"to":id})
 selected=id;dirty=true;rebuild();focus_block(id)
 return id
func duplicate_selected() -> void:
 checkpoint()
 var mapping: Dictionary={}
 for child in canvas.get_children():
  if child is GraphNode and child.selected:
   var old: String=node_ids[str(child.name)]
   var id:=unique_id(old+"_copy_")
   var copy: Dictionary=document.nodes[old].duplicate(true)
   copy.position=[copy.position[0]+60,copy.position[1]+60]
   document.nodes[id]=copy;mapping[old]=id
 var extra: Array=[]
 for e: Dictionary in document.edges:
  if mapping.has(e.from):extra.append({"from":mapping[e.from],"port":e.port,"to":mapping.get(e.to,e.to)})
 document.edges.append_array(extra);dirty=true;rebuild()
func text_field(parent: Node, title: String, value: String, callback: Callable, multiline: bool = false) -> void:
 label(parent,title)
 if multiline:
  var field:=TextEdit.new();field.text=value;field.custom_minimum_size=Vector2(310,120);field.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY
  parent.add_child(field);field.text_changed.connect(func():callback.call(field.text))
 else:
  var field:=LineEdit.new();field.text=value;parent.add_child(field)
  field.text_changed.connect(callback)
func _inspect_id(id: String) -> void:
 clear(inspector)
 if not document.nodes.has(id):label(inspector,"Выберите блок. Выходы справа показывают переходы и связанные условия / действия.");return
 var node:Dictionary=document.nodes[id];var d:Dictionary=node.data
 label(inspector,id)
 text_field(inspector,"Название блока",node.get("title",id),func(v):begin_edit();document.nodes[id].title=v)
 if node.type in MODEL.SCENE_TYPES:
  button(inspector,"Назначить начальной сценой",func():checkpoint();document.start=id;dirty=true)
  button(inspector,"Добавить ответ / результат",func():
   var count:=0
   for p:String in MODEL.ports(document,id,"choice:"):count=maxi(count,int(p.get_slice(":",1))+1)
   add_block("choice",id,"choice:"+str(count)))
  if MODEL.target(document,id,"entry").is_empty():button(inspector,"Действие при входе",func():add_block("action",id,"entry"))
  if node.type=="scene":
   var kinds: Array=["city_story","city_decision","city_cutscene","city_pickup","city_death","city_ending"]
   var kinds_ui:=OptionButton.new()
   for kind:String in ["Обычная сцена","Выбор действия","Автоматический переход","Получение предмета","Смерть","Спасение"]:kinds_ui.add_item(kind)
   kinds_ui.select(maxi(0,kinds.find(d.get("kind","city_story"))))
   inspector.add_child(kinds_ui)
   kinds_ui.item_selected.connect(func(i):begin_edit();d.kind=kinds[i])
 if node.type in ["scene","choice","dialogue","code","qte"]:
  text_field(inspector,"Текст",d.get("text",""),func(v):
   begin_edit();d.text=v
   if d.get("blocks",[]).size()==1:d.blocks[0].text=v,true)
 if node.type=="scene" and d.get("blocks",[]).size()>1:
  for index:int in d.blocks.size():
   text_field(inspector,"Текстовый блок "+str(index+1),d.blocks[index].text,func(v):begin_edit();d.blocks[index].text=v,true)
 if node.type=="dialogue":text_field(inspector,"Персонаж",d.get("speaker",""),func(v):begin_edit();d.speaker=v)
 if node.type in MODEL.SCENE_TYPES:
  text_field(inspector,"Фон (имя в assets/flash_ui)",d.get("art",""),func(v):begin_edit();d.art=v)
  text_field(inspector,"Звук (имя в assets/audio)",d.get("sound",""),func(v):begin_edit();d.sound=v)
  button(inspector,"Выбрать фон…",func():_resource_picker(id,"art","*.png,*.webp","res://assets/flash_ui"))
  button(inspector,"Выбрать звук…",func():_resource_picker(id,"sound","*.mp3","res://assets/audio"))
 if node.type=="choice":
  for pair:Array in [["effects","action","Добавить последствия"],["requires","condition","Добавить условие доступности"]]:
   if MODEL.target(document,id,pair[0]).is_empty():button(inspector,pair[2],func():add_block(pair[1],id,pair[0]))
  button(inspector,"Добавить условный переход",func():add_block("condition",id,"route:"+str(MODEL.ports(document,id,"route:").size())))
 if node.type=="condition":_variables_form(d,"when",true)
 if node.type=="action":
  _variables_form(d,"set",false)
  _variables_form(d,"add",false)
 if node.type=="code":
  text_field(inspector,"Переменная с кодом",d.get("code_variable","code"),func(v):begin_edit();d.code_variable=v)
  _number_field(d,"attempts","Количество попыток",1,100)
 if node.type=="qte":
  if d.has("taps_range"):
   label(inspector,"Случайное число нажатий: "+str(d.taps_range))
   button(inspector,"Использовать постоянное число",func():begin_edit();d.erase("taps_range");_inspect_id(id))
  if d.get("qte_mode","")=="branch":label(inspector,"Два направления и третий выход по таймеру")
  if d.has("target_windows"):label(inspector,"Нажатия в окнах: "+str(d.target_windows.size())+". Координаты и время — в свойствах JSON.")
  _number_field(d,"taps","Требуемые нажатия",1,1000)
  _number_field(d,"seconds","Время, секунд",0.1,300)
  var mode:=OptionButton.new();mode.add_item("Неподвижная цель");mode.add_item("Случайная цель")
  mode.select(1 if d.get("target_mode")=="random" else 0);inspector.add_child(mode)
  mode.item_selected.connect(func(i):begin_edit();d.target_mode="random" if i==1 else "fixed")
 label(inspector,"Связи")
 for p:String in port_labels(id):
  var dest:=MODEL.target(document,id,p)
  if not dest.is_empty():button(inspector,p+" → "+dest,func():focus_block(dest))
 var advanced:=TextEdit.new();advanced.text=JSON.stringify(d,"  ",false);advanced.custom_minimum_size=Vector2(310,160)
 label(inspector,"Все свойства (JSON): координаты, маски, варианты")
 inspector.add_child(advanced)
 button(inspector,"Применить свойства",func():
  var parsed:Variant=JSON.parse_string(advanced.text)
  if not parsed is Dictionary:status.text="Неверный JSON";return
  checkpoint();document.nodes[id].data=parsed;dirty=true;rebuild())
func _number_field(d:Dictionary,key:String,title:String,minimum:float,maximum:float)->void:
 label(inspector,title)
 var value:=SpinBox.new();value.min_value=minimum;value.max_value=maximum;value.step=0.1 if key=="seconds" else 1;value.value=float(d.get(key,minimum));inspector.add_child(value)
 value.value_changed.connect(func(v):begin_edit();d[key]=v)
func _variables_form(d:Dictionary,key:String,condition:bool)->void:
 label(inspector,{"when":"Условия (все должны выполняться)","set":"Установить значения","add":"Прибавить / вычесть","variables":"Начальные значения переменных"}[key])
 var dictionary:Dictionary=d.get(key,{})
 for variable:String in dictionary:
  var row:=HBoxContainer.new();inspector.add_child(row)
  var name_field:=LineEdit.new();name_field.text=variable;name_field.custom_minimum_size.x=125;row.add_child(name_field)
  var value:Variant=dictionary[variable]
  var op:=OptionButton.new()
  for text:String in (["=",">=","<=","диапазон"] if condition else ["="]):op.add_item(text)
  if value is Dictionary:op.select(3 if value.has("min") and value.has("max") else (1 if value.has("min") else 2))
  row.add_child(op)
  var field:=LineEdit.new();field.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  field.text=JSON.stringify(value) if not value is String else value
  if value is Dictionary and op.selected in [1,2]:field.text=str(value.get("min",value.get("max")))
  row.add_child(field)
  var apply:=func():
   var parsed:Variant=JSON.parse_string(field.text)
   if parsed==null and field.text!="null":parsed=field.text
   if condition and op.selected in [1,2]:
    if not parsed is float and not parsed is int:status.text="Граница должна быть числом";return
    parsed={"min" if op.selected==1 else "max":parsed}
   if condition and op.selected==3 and not parsed is Dictionary:status.text='Диапазон: {"min":1,"max":5}';return
   if name_field.text.is_empty():return
   begin_edit();dictionary.erase(variable);dictionary[name_field.text]=parsed;d[key]=dictionary
  field.text_submitted.connect(func(_v):apply.call())
  button(row,"✓",apply)
  button(row,"×",func():checkpoint();dictionary.erase(variable);d[key]=dictionary;dirty=true;episode_settings() if key=="variables" else _inspect_id(selected);rebuild(false))
 button(inspector,"+ Переменная",func():checkpoint();dictionary["variable_"+str(dictionary.size()+1)]=true if condition else 0;d[key]=dictionary;dirty=true;episode_settings() if key=="variables" else _inspect_id(selected);rebuild(false))
func _resource_picker(id:String,key:String,filter:String,dir:String)->void:
 var dialog:=EditorFileDialog.new();dialog.file_mode=EditorFileDialog.FILE_MODE_OPEN_FILE;dialog.add_filter(filter);dialog.current_dir=dir;add_child(dialog)
 dialog.file_selected.connect(func(p):
  checkpoint();document.nodes[id].data[key]=p.get_file().get_basename()
  if key=="art":document.nodes[id].data.art_extension=p.get_extension()
  dirty=true;dialog.queue_free();rebuild())
 dialog.popup_centered_ratio(0.6)
func start_preview() -> void:
 _finish_edit()
 var errors:=MODEL.validate(document)
 if not errors.is_empty():status.text="Перед тестом исправьте:\n"+"\n".join(errors);return
 var screens:=MODEL.compile(document)
 var start:=selected if screens.has(selected) else str(document.start)
 if is_instance_valid(preview):preview.queue_free()
 if is_instance_valid(simulator):simulator.free()
 simulator=load("res://scripts/core/quest_state.gd").new()
 simulator.nodes=screens
 simulator.episode_starts[int(document.episode)]=document.start
 simulator.episode_defaults[int(document.episode)]=document.get("variables",{})
 preview_trace.clear()
 simulator.save_path="user://story_editor_preview.json";simulator.tmp_path="user://story_editor_preview.tmp";simulator.backup_path="user://story_editor_preview.bak"
 simulator.flags={"TakenKey":false,"Auto":0,"BulletsNumber":-1,"LinkedFr":false,"code":"1234#"}
 simulator.flags.merge(document.get("variables",{}),true)
 simulator.sound_enabled=false
 preview=Window.new();preview.title="Тест сюжета — отдельное сохранение";preview.size=Vector2i(760,700)
 preview.close_requested.connect(func():preview.queue_free();simulator.free();simulator=null)
 add_child(preview)
 var root_box:=VBoxContainer.new();root_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);preview.add_child(root_box)
 preview_flags=VBoxContainer.new();root_box.add_child(preview_flags)
 for key:String in simulator.flags:
  text_field(preview_flags,key,str(simulator.flags[key]),func(v):
   var parsed:Variant=JSON.parse_string(v)
   simulator.flags[key]=v if parsed==null else parsed)
 button(root_box,"Перезапустить с выбранного блока",func():simulator.current_id=start;simulator.result_recorded=false;simulator._enter(start);_draw_preview())
 preview_box=VBoxContainer.new();preview_box.size_flags_vertical=Control.SIZE_EXPAND_FILL;root_box.add_child(preview_box)
 preview_log=RichTextLabel.new();preview_log.custom_minimum_size.y=100;root_box.add_child(preview_log)
 simulator.changed.connect(_draw_preview)
 simulator.current_id=start;simulator._enter(start)
 preview.popup_centered()
func _draw_preview() -> void:
 clear(preview_box)
 var d:Dictionary=simulator.current()
 preview_active=simulator.current_id
 preview_trace.append(preview_active)
 focus_block(preview_active)
 label(preview_box,preview_active+"\n"+str(d.get("speaker",""))+"\n"+str(d.get("text","")))
 var kind:String=d.get("kind","story")
 if kind=="activity_code":
  var entry:=LineEdit.new();entry.placeholder_text="Введите код";preview_box.add_child(entry)
  var attempts: Array=[int(d.get("attempts",3))]
  button(preview_box,"Проверить код",func():
   if entry.text==str(simulator.flags.get(d.get("code_variable","code"),d.get("code",""))):simulator.choose(0)
   else:
    attempts[0]-=1
    if attempts[0]<=0:simulator.choose(1)
    else:entry.placeholder_text="Осталось попыток: "+str(attempts[0]);entry.clear())
 elif kind=="activity_qte":
  var qstate:Dictionary={"taps":0,"remaining":float(d.get("seconds",5))}
  QTE.initialize(qstate,d)
  var timer:=Timer.new();timer.wait_time=0.02;preview_box.add_child(timer)
  var meter:=label(preview_box,"")
  var target_count:=2 if d.get("qte_mode","")=="branch" else 1
  for i:int in target_count:
   var title:String=d.get("targets",[])[i].get("text","Направление") if target_count==2 else "Нажать"
   button(preview_box,title,func():
    var outcome:=QTE.press(qstate,d,i)
    if outcome>=0:timer.stop();simulator.choose(outcome))
  timer.timeout.connect(func():
   if not is_instance_valid(meter):return
   qstate.remaining=maxf(0,float(qstate.remaining)-0.02)
   meter.text="Время: %.2f · %d/%d" % [qstate.remaining,qstate.taps,qstate.required_taps]
   if d.has("target_windows"):meter.text+=" · окно: "+str(QTE.window_index(qstate,d)+1)
   if qstate.remaining<=0:timer.stop();simulator.choose(QTE.timeout(qstate,d)))
  timer.start()
 else:
  var choices:Array=simulator.available_choices()
  for i:int in choices.size():button(preview_box,choices[i].get("text","Далее"),func():simulator.choose(i))
 preview_log.text=" → ".join(preview_trace.slice(maxi(0,preview_trace.size()-10)))+"\n"+str(simulator.flags)
func arrange_blocks() -> void:
 checkpoint()
 var scenes:=MODEL.compile(document)
 var depth:Dictionary={str(document.start):0}
 var todo:Array=[str(document.start)]
 while not todo.is_empty():
  var id:String=todo.pop_front()
  for c:Dictionary in scenes.get(id,{}).get("choices",[]):
   var destinations:Array=[]
   for key:String in ["next","with_keys","by_car"]:
    if c.has(key):destinations.append(c[key])
   for route:Dictionary in c.get("next_cases",[]):destinations.append(route.next)
   for target:String in destinations:
    if scenes.has(target) and not depth.has(target):depth[target]=int(depth[id])+1;todo.append(target)
 var rows:Dictionary={}
 for id:String in scenes:
  var column:int=int(depth.get(id,0))
  var row:int=int(rows.get(column,0));rows[column]=row+1
  var position:=Vector2(column*1700,row*1300)
  document.nodes[id].position=[position.x,position.y]
  for edge:Dictionary in document.edges:
   if edge.from!=id:continue
   if edge.port.begins_with("choice:"):
    var ordinal:int=int(str(edge.port).get_slice(":",1))
    var p:=position+Vector2(390,ordinal*290)
    document.nodes[edge.to].position=[p.x,p.y]
    var offset:=0
    for sub:Dictionary in document.edges:
     if sub.from==edge.to and document.nodes[sub.to].type in ["condition","action"]:
      var p2:=p+Vector2(420,offset*170);offset+=1
      document.nodes[sub.to].position=[p2.x,p2.y]
   elif edge.port in ["entry","pickup"] or str(edge.port).begins_with("variant:"):
    var p:=position+Vector2(-380,180)
    document.nodes[edge.to].position=[p.x,p.y]
 dirty=true;rebuild();focus_block(str(document.start))
func episode_settings() -> void:
 selected=""
 clear(inspector)
 label(inspector,"Параметры эпизода "+str(document.episode))
 text_field(inspector,"Название",document.get("title","Эпизод "+str(document.episode)),func(v):begin_edit();document.title=v)
 text_field(inspector,"Описание",document.get("description",""),func(v):begin_edit();document.description=v,true)
 label(inspector,"Начальная сцена: "+str(document.start))
 if not document.has("variables"):document.variables={}
 _variables_form(document,"variables",false)

func _exit_tree() -> void:
 if is_instance_valid(simulator): simulator.free()
