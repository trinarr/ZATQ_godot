extends Node
# Only nearby scene assets; never preload whole episodes into GPU memory.
const MAX_CACHED := 12
const MAX_PENDING := 4
const MAX_BYTES := 16 * 1024 * 1024
var retained_bytes := 0
var retained: Dictionary = {}
var pending: Array[String] = []
func _init() -> void:set_process(false)
func request(paths: Array[String]) -> void:
 # Dummy rendering has no GPU uploads and cannot initialize textures on workers.
 if DisplayServer.get_name()=="headless":return
 for path: String in paths:
  if retained.has(path) or path in pending or pending.size()>=MAX_PENDING:continue
  if not ResourceLoader.exists(path):continue
  if ResourceLoader.load_threaded_request(path)==OK:pending.append(path)
 set_process(not pending.is_empty())
func _process(_delta: float) -> void:
 # Collect one completed resource per frame, without waiting for worker threads.
 for path: String in pending:
  var status: int=ResourceLoader.load_threaded_get_status(path)
  if status==ResourceLoader.THREAD_LOAD_LOADED:
   var resource: Resource=ResourceLoader.load_threaded_get(path)
   pending.erase(path)
   var bytes: int=resource.get_width()*resource.get_height()*4 if resource is Texture2D else 0
   if bytes<=MAX_BYTES:
    retained[path]=resource;retained_bytes+=bytes
   while retained.size()>MAX_CACHED or retained_bytes>MAX_BYTES:
    var oldest: String=retained.keys()[0]
    var stale: Resource=retained[oldest]
    if stale is Texture2D:retained_bytes-=stale.get_width()*stale.get_height()*4
    retained.erase(oldest)
   break
  elif status==ResourceLoader.THREAD_LOAD_FAILED or status==ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
   pending.erase(path);break
 set_process(not pending.is_empty())

func _exit_tree() -> void:
 # Release the loader task handles too, including unfinished requests at exit.
 for path: String in pending:
  if ResourceLoader.load_threaded_get_status(path)!=ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
   ResourceLoader.load_threaded_get(path)
 pending.clear();retained.clear();retained_bytes=0
