@tool
extends RefCounted
# Standard key,ru,en CSV tables; TranslationServer handles locale and fallback.
const PREFIX := "@loc:"
const DIRECTORY := "res://locales/"
static var translations: Array[Translation] = []
static var ready := false
static var tables: Dictionary = {}
const BUILTIN_TABLES := ["ui", "episode1", "episode2", "episode3"]
static func imported_table(path:String)->Dictionary:
 var base:=path.trim_suffix(".csv")
 var locales:Array[String]=["ru","en"]
 for filename:String in DirAccess.get_files_at(DIRECTORY):
  if filename.begins_with(base.get_file()+".") and filename.ends_with(".translation"):
   var locale:=filename.trim_prefix(base.get_file()+".").trim_suffix(".translation")
   if locale not in locales:locales.append(locale)
 var rows:Dictionary={}
 for locale:String in locales:
  var resource_path:=base+"."+locale+".translation"
  if not ResourceLoader.exists(resource_path):continue
  var translation:=ResourceLoader.load(resource_path,"Translation") as Translation
  if translation==null:continue
  for key:String in translation.get_message_list():
   if not rows.has(key):rows[key]={}
   rows[key][locale]=str(translation.get_message(key))
 return {"headers":["key"]+locales,"rows":rows}
static func read_table(path: String) -> Dictionary:
 # Exported builds use Godot's imported translations, not raw CSV discovery.
 if not Engine.is_editor_hint() and path.begins_with(DIRECTORY):
  var imported:=imported_table(path)
  if not imported.rows.is_empty():return imported
 var file:=FileAccess.open(path,FileAccess.READ)
 if file==null:return imported_table(path)
 var headers:=file.get_csv_line()
 if not headers.is_empty():headers[0]=headers[0].trim_prefix("\ufeff")
 if headers.is_empty() or headers[0]!="key":return imported_table(path)
 var rows:Dictionary={}
 while not file.eof_reached():
  var row:=file.get_csv_line()
  if row.size()<2 or row[0].is_empty():continue
  var values:Dictionary={}
  for i:int in range(1,mini(row.size(),headers.size())):values[headers[i]]=row[i]
  rows[row[0]]=values
 return {"headers":Array(headers),"rows":rows}
static func prepare(force:bool=false)->void:
 if ready and not force:return
 for translation:Translation in translations:TranslationServer.remove_translation(translation)
 translations.clear();tables.clear()
 var names:Array[String]=[]
 for name:String in BUILTIN_TABLES:names.append(name)
 for filename:String in DirAccess.get_files_at(DIRECTORY):
  if filename.ends_with(".csv") or filename.ends_with(".translation"):
   var name:=filename.get_slice(".",0)
   if name not in names:names.append(name)
 for filename:String in DirAccess.get_files_at("res://data/story_graphs"):
  if filename.begins_with("episode") and filename.ends_with(".json") and filename.get_basename() not in names:names.append(filename.get_basename())
 for name:String in names:
  var table:=read_table(DIRECTORY+name+".csv")
  tables[name]=table
  for locale:String in table.headers.slice(1):
   var translation:=Translation.new();translation.locale=locale
   for key:String in table.rows:
    var value:String=table.rows[key].get(locale,"")
    if not value.is_empty():translation.add_message(key,value)
   TranslationServer.add_translation(translation);translations.append(translation)
 ready=true
static func text(value:String)->String:
 if not value.begins_with(PREFIX):return value
 prepare()
 var key:=value.trim_prefix(PREFIX)
 var translated:String=TranslationServer.translate(key)
 return source(value) if translated==key else translated
static func source(value:String)->String:
 if not value.begins_with(PREFIX):return value
 var key:=value.trim_prefix(PREFIX)
 var table_name:=key.get_slice(".",0)
 if not tables.has(table_name):tables[table_name]=read_table(DIRECTORY+table_name+".csv")
 return tables[table_name].rows.get(key,{}).get("ru",key)
static func resolve_tree(value:Variant,source_locale:bool=false)->Variant:
 if value is String:return source(value) if source_locale else text(value)
 if value is Dictionary:
  var result:Dictionary={}
  for key:Variant in value:result[key]=resolve_tree(value[key],source_locale)
  return result
 if value is Array:
  var result:Array=[]
  for item:Variant in value:result.append(resolve_tree(item,source_locale))
  return result
 return value
static func extract(value:Variant,prefix:String,table:Dictionary)->Variant:
 if value is Dictionary:
  var result:Dictionary={}
  for key:String in value:
   var item:Variant=value[key]
   if key in ["text","speaker","title","description","text_on_foot"] and item is String and not item.is_empty():
    var id:=prefix+"."+key
    if item.begins_with(PREFIX):item=source(item)
    if not table.rows.has(id):
     table.rows[id]={}
     for locale:String in table.headers.slice(1):table.rows[id][locale]=""
    table.rows[id].ru=item
    result[key]=PREFIX+id
   else:result[key]=extract(item,prefix+"."+key,table)
  return result
 if value is Array:
  var result:Array=[]
  for i:int in value.size():result.append(extract(value[i],prefix+"."+str(i),table))
  return result
 return value
static func write_table(path:String,table:Dictionary)->Error:
 DirAccess.make_dir_recursive_absolute(path.get_base_dir())
 var file:=FileAccess.open(path+".tmp",FileAccess.WRITE)
 if file==null:return FileAccess.get_open_error()
 file.store_csv_line(PackedStringArray(table.headers))
 var keys:Array=table.rows.keys();keys.sort()
 for key:String in keys:
  var row:=PackedStringArray([key])
  for locale:String in table.headers.slice(1):row.append(table.rows[key].get(locale,""))
  file.store_csv_line(row)
 file.flush();var error:=file.get_error();file.close()
 if error!=OK:return error
 return DirAccess.rename_absolute(path+".tmp",path)
static func publish(path:String,document:Dictionary)->Error:
 var table_path:=DIRECTORY+"episode%d.csv" % int(document.episode)
 var old:=FileAccess.get_file_as_string(table_path) if FileAccess.file_exists(table_path) else ""
 var table:=read_table(table_path)
 var graph:Dictionary=extract(document,"episode%d" % int(document.episode),table)
 var error:=write_table(table_path,table)
 if error!=OK:return error
 error=load("res://addons/story_graph/graph.gd").save_graph(path,graph)
 if error!=OK:
  if old.is_empty():DirAccess.remove_absolute(table_path)
  else:
   var rollback:=FileAccess.open(table_path,FileAccess.WRITE)
   if rollback:rollback.store_string(old);rollback.close()
  return error
 prepare(true)
 return OK
