extends RefCounted
# The game and graph preview share timing, hit windows and branch semantics.
static func initialize(state: Dictionary, data: Dictionary) -> void:
 if not state.has("required_taps"):
  var range_data: Array = data.get("taps_range",[])
  state.required_taps = int(data.get("taps",10))
  if range_data.size()==2:
   state.required_taps=int(range_data[0])+roundi(randf()*float(int(range_data[1])-int(range_data[0])))
 if not state.has("hit_windows"):state.hit_windows=[]
 if data.has("target_cycles") and not state.has("target_windows"):
  state.target_windows=[]
  for i: int in int(data.target_cycles):
   var area: Array=data.target_areas[randi_range(0,data.target_areas.size()-1)]
   var size: Array=data.get("target_size",[112,112])
   state.target_windows.append({"start":i*float(data.cycle_seconds),"end":(i+1)*float(data.cycle_seconds),"rect":[randf_range(area[0],area[0]+area[2]),randf_range(area[1],area[1]+area[3]),size[0],size[1]]})
 if data.get("qte_mode","")=="ratchet" and not state.has("lock_frame"):
  state.lock_frame=int(data.ratchet_start);state.lock_fraction=0.0;state.lock_running=false
 # JSON numbers reload as floats; Array.has compares Variant types strictly.
 for i:int in state.hit_windows.size():state.hit_windows[i]=int(state.hit_windows[i])
 if not state.has("last_target"):state.last_target=0
static func elapsed(state: Dictionary, data: Dictionary) -> float:
 return maxf(0,float(data.get("seconds",5))-float(state.remaining))
static func window_index(state: Dictionary, data: Dictionary) -> int:
 var time:=elapsed(state,data)
 var windows:Array=windows(state,data)
 for i:int in windows.size():
  if time>=float(windows[i].start) and time<float(windows[i].end):return i
 return -1
static func press(state: Dictionary, data: Dictionary, target: int = 0) -> int:
 if float(state.remaining)<=0:return timeout(state,data)
 if data.has("target_windows") or state.has("target_windows"):
  var window:=window_index(state,data)
  if window<0 or window in state.hit_windows:return -1
  state.hit_windows.append(window)
 if data.get("qte_mode","")=="ratchet":
  state.taps+=1
  if int(state.lock_frame)<=int(data.ratchet_finish):return 0
  state.lock_frame=maxi(0,int(state.lock_frame)-int(data.ratchet_step));state.lock_running=true;state.lock_fraction=0.0
  return -1
 state.taps+=1
 state.last_target=target
 if int(state.taps)>=int(state.required_taps) and not data.get("resolve_at_end",false):return target
 return -1
static func timeout(state: Dictionary, data: Dictionary) -> int:
 if data.get("qte_mode","")=="ratchet":return 1
 if int(state.taps)>=int(state.required_taps):return int(state.last_target)
 return 2 if data.get("qte_mode","")=="branch" else 1

static func windows(state: Dictionary, data: Dictionary) -> Array:
 return state.get("target_windows",data.get("target_windows",[]))
static func advance(state: Dictionary, data: Dictionary, delta: float) -> void:
 if data.get("qte_mode","")!="ratchet" or not state.get("lock_running",false):return
 state.lock_fraction=float(state.lock_fraction)+delta*float(data.get("animation_fps",19))
 var ticks: int=int(state.lock_fraction)
 state.lock_fraction-=ticks
 state.lock_frame=mini(int(data.ratchet_start),int(state.lock_frame)+ticks)
 if int(state.lock_frame)==int(data.ratchet_start):state.lock_running=false
