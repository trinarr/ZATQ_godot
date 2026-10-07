extends SceneTree
const TIMELINE := preload("res://scripts/ui/episode_timeline.gd")
const SHADER_TEXT := preload("res://scripts/ui/shared/shader_text.gd")
const BLURS := preload("res://scripts/ui/blur_texture_cache.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error(message)
func _initialize() -> void:call_deferred("run")
func settle() -> void:
 for i in 4:await process_frame
func run() -> void:
 TranslationServer.set_locale("ru")
 var quest: Node=root.get_node("Quest")
 quest.save_path="user://runtime_optimization.json";quest.tmp_path="user://runtime_optimization.tmp";quest.backup_path="user://runtime_optimization.bak"
 quest.sound_enabled=false
 var ui: Control=load("res://scenes/Main.tscn").instantiate();root.add_child(ui)
 await settle()
 ui.playing=true;quest.new_game(1);await settle()
 var original_screen: Control=ui.screen
 var original_world: Control=ui.world_layer
 var original_pause: Button=ui.edge_hit
 var original_label: Label=ui.narrative_layer.blocks[0].label
 for id: String in ["screams","transport","lift_button","wake"]:
  quest._enter(id);await settle()
  check(ui.screen==original_screen and ui.world_layer==original_world,"screen/world shell reused: "+id)
  check(ui.edge_hit==original_pause,"pause control reused: "+id)
  check(ui.narrative_layer.blocks[0].label==original_label,"narrative label reused: "+id)
  check(original_label.is_visible_in_tree(),"pooled narrative label visible: "+id)
  check(original_label.text==quest.current().text,"pool replaces narrative content: "+id)
 ui._lock_pause();quest._enter("shop_window")
 check(ui._can_pause(),"persistent screen clears previous death lock")
 quest._enter("transport")
 var hotspot: Button=ui.world_layer.find_child(ui.LOC.text("@loc:ui.main.43"),true,false)
 ui._show_pause();hotspot.pressed.emit()
 check(quest.current_id=="transport" and not quest.flags.TakenKey,"reused shell preserves modal input barrier")
 ui._resume()
 # Stable captions do not run a per-frame polling process. Text-only updates
 # must reach the shadow even when a new string has exactly the same width.
 var text: Label=SHADER_TEXT.new();root.add_child(text)
 text.size=Vector2(600,100);text.text="111";await settle()
 check(not text.is_processing(),"static text has no process callback")
 var updates: int=text.shadow_updates
 await settle()
 check(text.shadow_updates==updates,"idle text does not rebuild shadow")
 text.text="222";await settle()
 check(text.shadow_pass.text=="222","text-only change updates shadow")
 text.shadow_offset=Vector2(2,3);await settle()
 check(text.shadow_pass.position==Vector2(2,3),"offset setter updates shadow")
 text.add_theme_font_size_override("font_size",34);text.size=Vector2(400,120);await settle()
 check(text.shadow_pass.get_theme_font_size("font_size")==34 and text.shadow_pass.size==text.size,"font and geometry update shadow")
 text.free()
 var player:=TIMELINE.new();root.add_child(player);player.configure("ep1_mainstreet_choice");player.playing=false
 player.seek_frame(2,0.1)
 var poses: int=player.pose_updates
 var key: String=""
 for part: String in player.spec.parts:
  if player.spec.parts[part].has("blur"):key=part;break
 var paint: ShaderMaterial=player.sprites[key].get_child(0).material
 var before: float=paint.get_shader_parameter("blur_strength")
 for i in 120:player.seek_frame(2,0.8)
 check(player.pose_updates==poses,"120 same-frame seeks apply no additional poses")
 check(float(paint.get_shader_parameter("blur_strength"))!=before,"blur still interpolates inside one authored frame")
 player.seek_frame(3)
 check(player.pose_updates==poses+1,"next authored frame applies its pose")
 player.play("intro")
 check(player.current_frame==0,"restarting same phase resets first pose")
 player.free();paint=null
 # Cache includes direct flag edits, graph edits and language changes.
 quest.nodes["optimization_probe"]={"episode":1,"text":"base","variants":[{"when":{"probe":true},"text":"variant"}]}
 quest.flags.probe=false
 var resolutions: int=quest.current_resolutions
 check(quest.current("optimization_probe").text=="base","base view resolves")
 for i in 120:quest.current("optimization_probe")
 check(quest.current_resolutions==resolutions+1,"repeated current calls reuse resolved tree")
 quest.flags.probe=true
 check(quest.current("optimization_probe").text=="variant","direct flag edit invalidates view")
 quest.flags.probe=false;quest.nodes.optimization_probe.text="edited"
 check(quest.current("optimization_probe").text=="edited","in-place graph edit invalidates view")
 TranslationServer.set_locale("en");quest.current("optimization_probe")
 check(quest.current_resolutions==resolutions+4,"locale change invalidates view")
 TranslationServer.set_locale("ru");quest.nodes.erase("optimization_probe");quest.flags.erase("probe")
 # No-op saves do not rewrite files; genuine state changes do and survive reload.
 quest._enter("transport")
 var writes: int=quest.save_writes
 check(quest.save_game(),"unchanged snapshot still reports success")
 check(quest.save_writes==writes,"unchanged snapshot skips disk write")
 quest.flags.optimization_saved=17
 check(quest.save_game() and quest.save_writes==writes+1,"changed snapshot writes exactly once")
 quest.flags.optimization_saved=0;quest._load_save()
 check(quest.flags.optimization_saved==17,"atomic save restores changed flags")
 quest.activity={};quest.current_id="e3_opening_8";quest.episode=3;ui.playing=true;ui.paused=false
 writes=quest.save_writes;ui._show_story()
 check(quest.save_writes==writes+1,"QTE initialization persists one complete snapshot")
 var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(quest.save_path))
 check(saved.activity==JSON.parse_string(JSON.stringify(quest.activity)),"single QTE save includes all initialized fields")
 check(ui.texture_prefetch.pending.size()<=4 and ui.texture_prefetch.retained.size()<=12 and ui.texture_prefetch.retained_bytes<=ui.texture_prefetch.MAX_BYTES,"prefetch caches bounded")
 ui.free();await settle()
 # More than the target cache budget is allowed while a material still pins it.
 var source:=Image.create(8,8,false,Image.FORMAT_RGBA8);source.fill(Color.WHITE)
 var sharp:=ImageTexture.create_from_image(source)
 var held: Array[ShaderMaterial]=[]
 var entries: Array=[]
 for i in 6:
  var material:=ShaderMaterial.new();material.shader=preload("res://shaders/flash_color_transform.gdshader")
  entries.append(BLURS.bind(material,sharp,{"sigma":[float(i+1),1.0],"angle":0.0}));held.append(material)
 for i in 120:
  if entries.all(func(entry):return entry.complete):break
  await process_frame
 BLURS.prune()
 check(entries.all(func(entry):return entry.pinned()),"active blur targets cannot be evicted")
 held.clear();await settle();BLURS.prune()
 check(BLURS._entries.size()<=BLURS.MAX_CACHED,"unreferenced blur cache returns to budget")
 for path: String in [quest.save_path,quest.tmp_path,quest.backup_path]:
  if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
 print("Runtime optimization: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
