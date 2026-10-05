extends SceneTree
const MODEL := preload("res://addons/story_graph/graph.gd")
const QTE := preload("res://scripts/core/qte_rules.gd")
var checks:=0
var failures:=0
func check(value:bool,message:String)->void:
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize()->void:call_deferred("run")
func settle()->void:
 await process_frame
 await process_frame
func controller(scene:Control)->Control:
 for child in scene.screen.get_children():
  if child.get_script()==load("res://scripts/ui/story_activity.gd"):return child
 return null
func run()->void:
 var graph:=MODEL.load_graph("res://data/story_graphs/episode3.json")
 check(MODEL.validate(graph).is_empty(),"third graph validates: "+str(MODEL.validate(graph)))
 var nodes:=MODEL.compile(graph)
 var quest:Node=root.get_node("Quest")
 quest.save_path="user://episode3_test.json";quest.tmp_path="user://episode3_test.tmp";quest.backup_path="user://episode3_test.bak";quest.sound_enabled=false
 check(quest.episode_starts.get(3)=="e3_opening_1","third episode registered")
 check(quest.ending_count(3)==3,"three original endings, two squad routes share one ending")
 quest.new_game(3)
 check(not quest.flags.TakenKnife and quest.flags.BulletsNumber==-1,"episode defaults")
 var results:Array=[]
 var dialogue_count:=0
 var qte_count:=0
 for id:String in nodes:
  var n:Dictionary=nodes[id]
  check(n.episode==3,"episode ownership "+id)
  if n.has("result_id"):results.append(int(n.result_id));check(n.choices.is_empty(),"terminal result "+id)
  if n.kind=="activity_dialogue":
   dialogue_count+=1;check(n.speaker=="Джон Доннатон" and n.choices.size()==3,"John dialogue exact three replies "+id)
  if n.kind=="activity_qte":
   qte_count+=1;check(n.seconds>0 and n.taps>0,"timed QTE "+id)
  for c:Dictionary in n.choices:
   check(nodes.has(c.next),"transition "+id+" → "+str(c.next))
   for route:Dictionary in c.get("next_cases",[]):check(nodes.has(route.next),"conditional destination "+id)
 check(results.size()==26,"all 26 original episode III result variants")
 check(dialogue_count==14,"all fourteen sparse dialogue states")
 check(qte_count==6,"all six original QTE scenes")
 # Exhaustively traverse original branching states including item consequences.
 var seen:Dictionary={};var pending:Array=[[graph.start,quest.flags.duplicate(true)]];var reachable:Dictionary={}
 while not pending.is_empty():
  var item:Array=pending.pop_back();var id:String=item[0];quest.current_id=id;quest.flags=item[1]
  var node:Dictionary=quest.current()
  for key:String in node.get("set",{}):quest.flags[key]=node.set[key]
  var signature:=id+"|"+JSON.stringify(quest.flags)
  if seen.has(signature):continue
  seen[signature]=true;reachable[id]=true
  for c:Dictionary in quest.available_choices():
   var next:String=c.next
   for route:Dictionary in c.get("next_cases",[]):
    if quest.matches(route.when):next=route.next;break
   var flags:Dictionary=quest.flags.duplicate(true)
   for key:String in c.get("set",{}):flags[key]=c.set[key]
   for key:String in c.get("add",{}):flags[key]=flags.get(key,0)+c.add[key]
   pending.append([next,flags])
 for n:int in range(51,77):check(reachable.has("e3_result_"+str(n)),"result reachable "+str(n))
 # Inventory routes and four aliases of the shared squad ending.
 quest.new_game(3);quest._enter("e3_pickup_glock16");check(quest.flags.BulletsNumber==16,"Glock full magazine")
 quest.save_game();quest.flags.BulletsNumber=-1;quest._load_save();check(quest.flags.BulletsNumber==16,"16 rounds survive save")
 quest._enter("e3_pickup_knife");check(quest.flags.TakenKnife,"knife acquired")
 quest._enter("e3_john_3_choice_25");quest.choose(0);check(quest.current_id=="e3_john_8","knife makes ambush fatal")
 quest.flags.TakenKnife=false;quest._enter("e3_john_3_choice_25");quest.choose(0);check(quest.current_id=="e3_john_4","unarmed ambush succeeds")
 quest._enter("e3_john_3_choice_25");quest.choose(1);check(quest.current_id=="e3_john_5_v2","leave John alone -> companion tunnel")
 quest.choose(0);check(quest.current_id=="e3_john_9","companion avoids mine QTE")
 quest.flags.BulletsNumber=16;quest._enter("e3_north_5");quest.choose(0);check(quest.current_id=="e3_result_63","armed bitten death")
 quest.flags.BulletsNumber=0;quest._enter("e3_north_5");quest.choose(0);check(quest.current_id=="e3_result_76","empty pistol bitten death")
 quest.extra_stats={};quest.result_recorded=false;quest._enter("e3_result_67");quest.result_recorded=false;quest._enter("e3_result_73")
 check(quest.stats_for(3).wins==2 and quest.stats_for(3).endings==[67],"squad routes count once in unlocked endings")
 # Shared QTE rules: spam guards, missed windows, two button race.
 var data:Dictionary=nodes.e3_john_23
 var state:Dictionary={"taps":0,"remaining":data.seconds};QTE.initialize(state,data)
 check(QTE.press(state,data)==-1 and state.taps==0,"shots outside windows ignored")
 for i:int in data.target_windows.size():
  state.remaining=data.seconds-float(data.target_windows[i].start)-0.01
  QTE.press(state,data);QTE.press(state,data)
  check(state.taps==i+1,"one accepted shot per window")
 state.remaining=0
 check(QTE.timeout(state,data)==0,"four shots successful at end")
 state.taps=3;check(QTE.timeout(state,data)==1,"missed shot fails at end")
 data=nodes.e3_opening_11;state={"taps":0,"remaining":2.5};QTE.initialize(state,data);state.required_taps=2
 QTE.press(state,data,0);check(QTE.press(state,data,1)==1,"both buttons decrement shared counter; last selects route")
 state.taps=0;state.remaining=0;check(QTE.timeout(state,data)==2,"timed branch has separate death outcome")
 # Real UI and pause/resume, using original artwork and current display scale.
 var scene:Control=load("res://scenes/Main.tscn").instantiate();root.add_child(scene);await settle();scene.playing=true
 quest.new_game(3);quest._enter("e3_dialogue_0");await settle()
 check(controller(scene)!=null and quest.available_choices().size()==3,"native dialogue renders")
 quest.choose(2);await settle();check(quest.current_id=="e3_result_54","dialogue attack original outcome")
 quest.new_game(3);quest._enter("e3_opening_11");await settle();var c:Control=controller(scene)
 check(c.taps.size()==2,"two original direction hotspots")
 quest.activity.required_taps=2;c.press_target(1);var time:float=quest.activity.remaining
 scene._show_pause();c._process(2)
 check(quest.activity.remaining==time,"pause freezes timed branch")
 quest.save_game();quest._load_save();scene._resume();await settle();c=controller(scene)
 check(quest.activity.taps==1 and quest.activity.required_taps==2 and quest.activity.last_target==1,"count, random requirement and chosen direction survive save")
 c.press_target(1);await settle();check(quest.current_id=="e3_opening_15","kitchen branch resumes")
 quest._enter("e3_john_23");await settle();c=controller(scene)
 quest.activity.remaining=quest.current().seconds-0.12;c.press_target()
 scene._show_pause();quest.save_game();quest._load_save();scene._resume();await settle();c=controller(scene)
 check(quest.activity.hit_windows.size()==1,"hit windows survive save")
 quest.activity.remaining=quest.current().seconds-0.12
 c.press_target();check(quest.activity.taps==1,"same window cannot count again after resume")
 var editor:Control=load("res://addons/story_graph/editor.gd").new();root.add_child(editor);await settle()
 editor.load_document("res://data/story_graphs/episode3.json")
 check(editor.document.episode==3 and editor.episode.get_selected_id()==3,"third graph selectable in editor")
 editor.queue_free();scene.queue_free();await settle()
 print("PASS: ",checks," Episode III checks; failures ",failures)
 quit(1 if failures else 0)
