extends SceneTree
const TIMELINE := preload("res://scripts/ui/episode_timeline.gd")
const CLOCK := preload("res://scripts/ui/flash_playback_clock.gd")
const TEST_CLOCK := preload("res://tools/flash_test_clock.gd")
var failures := 0
var checks := 0
var player: Node2D
var presented_frames: Array[int] = []
func check(value: bool, message: String) -> void:
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize() -> void:call_deferred("run")
func observe() -> void:
 presented_frames.append(player.current_frame)
func run() -> void:
 var clock:=CLOCK.new();root.add_child(clock);clock.restart()
 check(clock.advance(.35)==0.0,"assembly time is not visible playback time")
 clock._frame_presented()
 check(clock.advance(.35)<.05,"first step excludes time before presentation")
 check(is_equal_approx(clock.advance(1.0/19.0),1.0/19.0),"subsequent steps keep authored timing")
 clock.restart()
 check(clock.advance(.35)==0.0,"a new phase gets its own presentation boundary")
 clock.free()
 var frames: Array=[]
 for i: int in 20:frames.append([["background",[1,0,0,1,0,0],[1,1,1,float(i)/19,0,0,0]]])
 var data: Dictionary=TIMELINE.data
 TIMELINE.data={"fps":19,"art":{"probe":{"parts":{"background":{"type":"panel","rect":[0,0,800,480],"color":[1,1,1,1]}},"intro":frames,"outro":frames}}}
 await process_frame
 player=TIMELINE.new();root.add_child(player);player.configure("probe")
 if DisplayServer.get_name()!="headless":RenderingServer.frame_post_draw.connect(observe)
 # Reproduce synchronous font/texture/layout work after configuring a scene.
 OS.delay_msec(350)
 await process_frame
 await process_frame
 check(player.elapsed<.08,"initial assembly delay does not advance the new scene")
 if DisplayServer.get_name()!="headless":
  check(not presented_frames.is_empty() and presented_frames[0]==0,"first drawn pose is frame zero")
  RenderingServer.frame_post_draw.disconnect(observe)
 player.set_process(false)
 player.play("intro")
 TEST_CLOCK.step(player,1.0/19.0)
 check(player.current_frame==1,"one authored interval advances exactly one frame")
 player.suspended=true;TEST_CLOCK.step(player,1.0)
 check(player.current_frame==1,"pause does not advance playback")
 player.suspended=false;TEST_CLOCK.step(player,1.0/19.0)
 check(player.current_frame==2,"resume preserves timeline speed")
 player.play("outro")
 player._process(.35)
 check(player.current_frame==0,"outro waits for its own first draw")
 TEST_CLOCK.step(player,1.0/19.0)
 check(player.current_frame==1,"outro uses the same authored timing")
 player.free();TIMELINE.data=data
 # Freeing an unpresented clip disconnects the global signal safely.
 clock=CLOCK.new();root.add_child(clock);clock.restart();clock.free()
 await process_frame
 print("PASS: %d Flash playback clock checks; failures %d" % [checks,failures])
 quit(1 if failures else 0)
