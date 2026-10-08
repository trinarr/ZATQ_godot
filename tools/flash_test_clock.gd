extends RefCounted
# Manual timeline tests have no render between calls. Acknowledge presentation
# before applying their synthetic delta; real process/render tests do not use this.
static func step(player: Node, seconds: float) -> void:
 if player.playback_clock.waiting_for_presentation:
  player.playback_clock._frame_presented()
  player.playback_clock.advance(0.0)
 player._process(seconds)
