@tool
extends RefCounted
# Canonical graph -> existing runtime screen records. IDs are stable save anchors.
const SCENE_TYPES := ["scene", "dialogue", "code", "qte"]
static func target(graph: Dictionary, id: String, port: String) -> String:
 for edge: Dictionary in graph.get("edges", []):
  if edge.get("from") == id and edge.get("port") == port: return edge.get("to", "")
 return ""
static func ports(graph: Dictionary, id: String, prefix: String) -> Array:
 var result: Array = []
 for edge: Dictionary in graph.get("edges", []):
  if edge.get("from") == id and str(edge.get("port", "")).begins_with(prefix): result.append(edge.port)
 result.sort_custom(func(a, b): return int(a.get_slice(":", 1)) < int(b.get_slice(":", 1)))
 return result
static func payload(graph: Dictionary, id: String) -> Dictionary:
 return graph.get("nodes", {}).get(id, {}).get("data", {}).duplicate(true)
static func compile(graph: Dictionary) -> Dictionary:
 var output: Dictionary = {}
 for id: String in graph.get("nodes", {}):
  var record: Dictionary = graph.nodes[id]
  if record.type not in SCENE_TYPES: continue
  var data: Dictionary = payload(graph, id)
  if record.type != "scene": data.kind = "activity_" + record.type
  data.episode = graph.get("episode", 1)
  # Retain legacy omission of episode=1 for exact migration comparison.
  if record.type == "scene" and int(graph.get("episode",1)) == 1: data.erase("episode")
  data.choices = []
  var entry := target(graph, id, "entry")
  if not entry.is_empty():
   data.set = payload(graph, entry).get("set", {})
   if not payload(graph,entry).get("add",{}).is_empty():data.add = payload(graph,entry).add
  var gate := target(graph, id, "pickup")
  if not gate.is_empty(): data.pickup_if = {"when":payload(graph, gate).get("when", {}), "next":target(graph, gate, "true")}
  var variants := ports(graph, id, "variant:")
  if not variants.is_empty():
   data.variants = []
   for port: String in variants:
    var v := payload(graph, target(graph, id, port))
    var patch: Dictionary = v.get("patch", {}).duplicate(true)
    patch.when = v.get("when", {})
    data.variants.append(patch)
  var back := target(graph, id, "back")
  if not back.is_empty(): data.back = back
  for port: String in ports(graph, id, "choice:"):
   var choice_id := target(graph, id, port)
   var choice := payload(graph, choice_id)
   for route: String in ["next", "with_keys", "by_car"]:
    var t := target(graph, choice_id, route)
    if not t.is_empty(): choice[route] = t
   var action := target(graph, choice_id, "effects")
   if not action.is_empty(): choice.merge(payload(graph, action), true)
   var requires := target(graph, choice_id, "requires")
   if not requires.is_empty():
    var requirement := payload(graph, requires)
    if not requirement.get("when", {}).is_empty(): choice.requires = requirement.when
    if requirement.get("unless_keys", false): choice.unless_keys = true
   var routes := ports(graph, choice_id, "route:")
   if not routes.is_empty():
    choice.next_cases = []
    for r: String in routes:
     var cid := target(graph, choice_id, r)
     choice.next_cases.append({"when":payload(graph, cid).get("when", {}), "next":target(graph, cid, "true")})
   data.choices.append(choice)
  output[id] = data
 return output
static var component_art_names: Dictionary = {}
static var components_loaded: bool = false
static func has_art(name: String) -> bool:
 if not components_loaded:
  for path: String in ["res://data/episode1_components.json","res://data/episode2_components.json","res://data/episode3_components.json","res://data/ui_components.json"]:
   var parts: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
   if parts is Dictionary:
    for key: String in parts: component_art_names[key] = true
  components_loaded = true
 return component_art_names.has(name)
static func validate(graph: Dictionary) -> PackedStringArray:
 var errors := PackedStringArray()
 if graph.get("version") != 1 or not graph.get("nodes") is Dictionary or not graph.get("edges") is Array:
  errors.append("Неверный формат графа")
  return errors
 var ids: Dictionary = graph.nodes
 var occupied := {}
 for edge: Dictionary in graph.edges:
  var a: String = edge.get("from", "")
  var b: String = edge.get("to", "")
  if not ids.has(a) or not ids.has(b):
   errors.append("Оборванная связь: " + a + " → " + b)
   continue
  var port: String = edge.get("port", "")
  var key := a + "|" + port
  if occupied.has(key): errors.append("Два перехода из одного выхода: " + key)
  occupied[key] = true
  var expected := ""
  if port.begins_with("choice:"): expected = "choice"
  elif port in ["entry", "effects"]: expected = "action"
  elif port in ["requires", "pickup"] or port.begins_with("route:") or port.begins_with("variant:"): expected = "condition"
  elif port in ["next", "true", "back", "with_keys", "by_car"]: expected = "screen"
  if expected == "screen" and ids[b].type not in SCENE_TYPES: errors.append("Выход должен вести в сцену: " + key)
  elif expected not in ["", "screen"] and ids[b].type != expected: errors.append("Неверный тип блока: " + key)
  elif expected == "": errors.append("Неизвестный выход: " + key)
 var start: String = graph.get("start", "")
 if not ids.has(start) or ids.get(start, {}).get("type", "") not in SCENE_TYPES: errors.append("Не задана начальная сцена")
 for id: String in ids:
  var node: Dictionary = ids[id]
  if node.get("type", "") not in SCENE_TYPES + ["choice", "action", "condition"]:
   errors.append("Неизвестный тип: " + id)
  if not node.get("data") is Dictionary: errors.append("Неверные данные: " + id)
  if node.get("type") == "choice" and node.data.get("action", "") != "channel" and target(graph,id,"next").is_empty(): errors.append("Нет перехода после ответа: " + id)
  if node.get("type") == "condition" and not node.data.has("patch"):
   var used_for_route := false
   for edge: Dictionary in graph.edges:
    if edge.to == id and (edge.port == "pickup" or str(edge.port).begins_with("route:")): used_for_route = true
   if used_for_route and target(graph,id,"true").is_empty(): errors.append("Нет условного перехода: " + id)
 for id: String in ids:
  var record: Dictionary = ids[id]
  if record.type not in SCENE_TYPES: continue
  var data: Dictionary = record.data
  if record.type in ["code","qte"]:
   var outcomes := ports(graph,id,"choice:")
   var expected_outcomes: int = 3 if record.type=="qte" and data.get("qte_mode","")=="branch" else 2
   if outcomes.size()!=expected_outcomes: errors.append("Активности нужны %d результата: %s" % [expected_outcomes,id])
   for port: String in outcomes:
    if not target(graph,target(graph,id,port),"requires").is_empty():errors.append("Результат активности не должен скрываться: "+id)
  if record.type=="qte" and (float(data.get("seconds",0))<=0 or int(data.get("taps",0))<=0):errors.append("Укажите время и число нажатий: "+id)
  if record.type=="code" and int(data.get("attempts",0))<=0:errors.append("Укажите число попыток: "+id)
  if record.type=="qte":
   var range_data: Array = data.get("taps_range",[])
   if not range_data.is_empty() and (range_data.size()!=2 or int(range_data[0])<1 or int(range_data[1])<int(range_data[0])):errors.append("Неверный диапазон нажатий: "+id)
   var previous_end: float = 0.0
   for window: Dictionary in data.get("target_windows",[]):
    if float(window.get("start",-1))<previous_end or float(window.get("end",0))<=float(window.get("start",0)) or float(window.get("end",0))>float(data.get("seconds",0)) or window.get("rect",[]).size()!=4:errors.append("Неверное окно QTE: "+id)
    previous_end=float(window.get("end",0))
   for frame: String in data.get("animation_frames",[]):
    if not has_art(frame) and not ResourceLoader.exists("res://assets/flash_ui/"+frame+".png"):errors.append("Не найден кадр: "+id+" / "+frame)
  for key: String in ["art","art_on_foot","controls_art","decision_art","background_art"]:
   var art: String = data.get(key,"")
   if art.is_empty():continue
   var extension: String = data.get("art_extension","png") if key in ["art","art_on_foot"] else ("png" if key=="background_art" else "png")
   if not has_art(art) and not ResourceLoader.exists("res://assets/flash_ui/"+art+"."+extension):errors.append("Не найдено изображение: "+id+" / "+art)
  var sound: String = data.get("sound","")
  if not sound.is_empty() and not ResourceLoader.exists("res://assets/audio/"+sound+".mp3"):errors.append("Не найден звук: "+id+" / "+sound)
 # Prevent recursive pickup redirects, which would recurse inside Quest._enter().
 for id: String in ids:
  var seen := {}
  var cursor := id
  while not cursor.is_empty():
   if seen.has(cursor):
    errors.append("Цикл автоматического получения предмета: " + id)
    break
   seen[cursor] = true
   var gate := target(graph,cursor,"pickup")
   cursor = target(graph,gate,"true") if not gate.is_empty() else ""
 return errors
static func load_graph(path: String) -> Dictionary:
 var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
 return value if value is Dictionary else {}
static func save_graph(path: String, graph: Dictionary) -> Error:
 var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
 if file == null: return FileAccess.get_open_error()
 file.store_string(JSON.stringify(graph, "\t", false, true) + "\n")
 file.flush()
 file.close()
 if FileAccess.file_exists(path):
  var error := DirAccess.copy_absolute(path, path + ".bak")
  if error != OK: return error
 return DirAccess.rename_absolute(path + ".tmp", path)
