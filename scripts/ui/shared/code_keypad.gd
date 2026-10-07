extends Control
# Autonomous authored keypad; caller supplies saved state and routing.
signal finished(index: int)
signal sound_requested(name: String)
signal indicator_changed(frame: int)
signal state_changed
var state: Dictionary
var definition: Dictionary
var expected_code := ""
var is_suspended: Callable
var done := false
var buttons: Array[Button] = []
func configure(owner: Control, data: Dictionary, saved: Dictionary, code: String, suspended: Callable) -> void:
 state=saved;definition=data;expected_code=code;is_suspended=suspended
 if not state.has("status"):state.status="idle";state.feedback_remaining=0.0
 for key: Dictionary in data.keys:
  var r: Array=key.rect
  var button: Button=owner._hit(key.text,Rect2(r[0],r[1],r[2],r[3]),func():press(key.text))
  if not data.get("labels_in_art",false):owner._button_text(key.text,Rect2(0,0,r[2],r[3]),26,button,owner.BODY_FONT)
  buttons.append(button)
 refresh()
func press(key: String) -> void:
 if done or (is_suspended.is_valid() and is_suspended.call()) or state.status=="accepted":return
 sound_requested.emit("MetalButtonsCLick")
 if key=="*":state.input="*"
 elif key=="#":
  state.input+="#"
  if not expected_code.is_empty() and state.input==expected_code:
   state.status="accepted";sound_requested.emit("OpenedBeep")
  else:
   state.attempts-=1;sound_requested.emit("ClosedBeep");state.input=""
   if int(state.attempts)<=0:done=true;state_changed.emit();finished.emit(1);return
   state.status="error"
  state.feedback_remaining=float(definition.get("feedback_seconds",16.0/19.0))
 elif str(state.input).length()>10:
  state.input="";indicator_changed.emit(1)
 else:state.input+=key
 state_changed.emit();refresh()
func refresh() -> void:
 for button: Button in buttons:button.disabled=done or state.status=="accepted"
 if state.status=="idle":indicator_changed.emit(0)
 else:
  var elapsed: float=float(definition.get("feedback_seconds",16.0/19.0))-float(state.feedback_remaining)
  indicator_changed.emit((17 if state.status=="accepted" else 1)+clampi(int(elapsed*19),0,15))
func _process(delta: float) -> void:
 if done or state.is_empty() or state.status=="idle" or (is_suspended.is_valid() and is_suspended.call()):return
 state.feedback_remaining=maxf(0,float(state.feedback_remaining)-delta)
 refresh()
 if float(state.feedback_remaining)<=0:
  if state.status=="accepted":done=true;state_changed.emit();finished.emit(0)
  else:state.status="idle";refresh();state_changed.emit()
