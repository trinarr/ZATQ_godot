extends RefCounted
# The game and graph preview share timing, hit windows and branch semantics.
static func initialize(state: Dictionary, data: Dictionary) -> void:
 if not state.has("required_taps"):
  var range_data: Array = data.get("taps_range",[])
  state.required_taps = int(data.get("taps",10))
  if range_data.size()==2:
   state.required_taps=int(range_data[0])+roundi(randf()*float(int(range_data[1])-int(range_data[0])))
 if not state.has("hit_windows"):state.hit_windows=[]
 # JSON numbers reload as floats; Array.has compares Variant types strictly.
 for i:int in state.hit_windows.size():state.hit_windows[i]=int(state.hit_windows[i])
 if not state.has("last_target"):state.last_target=0
static func elapsed(state: Dictionary, data: Dictionary) -> float:
 return maxf(0,float(data.get("seconds",5))-float(state.remaining))
static func window_index(state: Dictionary, data: Dictionary) -> int:
 var time:=elapsed(state,data)
 var windows:Array=data.get("target_windows",[])
 for i:int in windows.size():
  if time>=float(windows[i].start) and time<float(windows[i].end):return i
 return -1
static func press(state: Dictionary, data: Dictionary, target: int = 0) -> int:
 if float(state.remaining)<=0:return timeout(state,data)
 if data.has("target_windows"):
  var window:=window_index(state,data)
  if window<0 or window in state.hit_windows:return -1
  state.hit_windows.append(window)
 state.taps+=1
 state.last_target=target
 if int(state.taps)>=int(state.required_taps) and not data.get("resolve_at_end",false):return target
 return -1
static func timeout(state: Dictionary, data: Dictionary) -> int:
 if int(state.taps)>=int(state.required_taps):return int(state.last_target)
 return 2 if data.get("qte_mode","")=="branch" else 1
