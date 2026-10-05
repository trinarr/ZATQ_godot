extends SceneTree
var checks:=0
var failures:=0
func check(v:bool,m:String)->void:
 checks+=1
 if not v:failures+=1;push_error(m)
func _initialize()->void:call_deferred("run")
func settle()->void:
 await process_frame
 await process_frame
func controller(scene:Control)->Control:
 for child in scene.screen.get_children():
  if child.get_script()==load("res://scripts/ui/story_activity.gd"):return child
 return null
func run()->void:
 var quest:Node=root.get_node("Quest")
 quest.save_path="user://activity_test.json";quest.tmp_path="user://activity_test.tmp";quest.backup_path="user://activity_test.bak";quest.sound_enabled=false
 var scene:Control=load("res://scenes/Main.tscn").instantiate();root.add_child(scene)
 await settle()
 var ending:Dictionary={"episode":2,"source":"test","kind":"city_story","art":"result_background","text":"Конец","choices":[]}
 for id:String in ["e2_test_correct","e2_test_failed"]:quest.nodes[id]=ending.duplicate(true)
 quest.nodes.e2_test_code={"episode":2,"source":"test","kind":"activity_code","text":"Код","code_variable":"secret","attempts":3,"choices":[{"text":"Верно","next":"e2_test_correct"},{"text":"Ошибки","next":"e2_test_failed"}]}
 quest.nodes.e2_test_qte={"episode":2,"source":"test","kind":"activity_qte","text":"QTE","seconds":5,"taps":3,"target_mode":"random","choices":[{"text":"Нажал","next":"e2_test_correct"},{"text":"Время","next":"e2_test_failed"}]}
 quest.nodes.e2_test_dialogue={"episode":2,"source":"test","kind":"activity_dialogue","speaker":"Дэвид","text":"Реплика","choices":[{"text":"Да","next":"e2_test_correct"},{"text":"Нет","requires":{"LinkedFr":true},"next":"e2_test_failed"}]}
 scene.playing=true;quest.has_progress=true;quest.flags={"TakenKey":false,"Auto":0,"BulletsNumber":-1,"LinkedFr":false,"secret":"*123#"}
 quest._enter("e2_test_code");await settle()
 var c:Control=controller(scene)
 check(c!=null,"code renders")
 c.input.text="wrong";c.check_code()
 check(quest.activity.attempts==2,"failed attempt counted")
 scene._show_pause();quest.save_game();quest._load_save();scene._resume();await settle()
 c=controller(scene)
 check(quest.activity.attempts==2 and quest.flags.secret=="*123#","code attempts and custom variables survive save")
 c.input.text="*123#";c.check_code();await settle()
 check(quest.current_id=="e2_test_correct" and quest.activity.is_empty(),"code success routes and clears state")
 quest._enter("e2_test_code");await settle()
 c=controller(scene)
 for i:int in 3:c.input.text="wrong";c.check_code()
 await settle();check(quest.current_id=="e2_test_failed","attempt limit routes")
 quest._enter("e2_test_qte");await settle();c=controller(scene)
 check(c!=null and is_instance_valid(c.tap),"QTE renders target")
 c.press_target();var remaining:float=quest.activity.remaining
 check(quest.activity.taps==1,"QTE count")
 scene._show_pause();c._process(2)
 check(quest.activity.remaining==remaining,"pause freezes QTE")
 quest.save_game();quest._load_save();scene._resume();await settle();c=controller(scene)
 check(quest.activity.taps==1 and quest.activity.remaining<=remaining,"QTE resumes saved count and time")
 c.press_target();c.press_target();await settle()
 check(quest.current_id=="e2_test_correct","QTE count routes")
 quest._enter("e2_test_qte");await settle();c=controller(scene);c._process(6);await settle()
 check(quest.current_id=="e2_test_failed","QTE timeout routes")
 quest._enter("e2_test_dialogue");await settle()
 check(quest.available_choices().size()==1,"dialogue filters conditional answers")
 quest.choose(0);await settle();check(quest.current_id=="e2_test_correct","dialogue choice routes")
 var model:Script=load("res://addons/story_graph/graph.gd")
 var demo:Dictionary=model.load_graph("res://data/story_graphs/examples/activity_demo.json")
 quest.nodes.merge(model.compile(demo),true)
 quest.episode_starts[3]=demo.start;quest.episode_defaults[3]=demo.variables
 quest.new_game(3);await settle()
 check(quest.episode==3 and quest.flags.secret=="*123#","new episode defaults and start")
 quest.choose(0);await settle();c=controller(scene);c.input.text="*123#";c.check_code();await settle()
 c=controller(scene)
 for i:int in 5:c.press_target()
 await settle()
 check(quest.current_id=="e3_win" and quest.stats_for(3).wins==1,"new graph runs and records independent results")
 check(quest.ending_count(3)==1,"authored ending total")
 quest.save_game();quest._load_save()
 check(quest.episode==3 and quest.stats_for(3).endings==[3001],"new episode save and ending IDs")
 scene.queue_free();await settle()
 print("PASS: ",checks," activity checks; failures ",failures)
 quit(1 if failures else 0)
