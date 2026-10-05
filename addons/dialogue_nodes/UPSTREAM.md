Dialogue Nodes 1.3.2 by Nagi (nagidev)
Source: user-supplied DialogueNodes-main.zip, commit 742486baa9ad73504b6ee7350adb2f78e55da4ee.
Repository: https://github.com/nagidev/DialogueNodes
Upstream declares the MIT license. The supplied archive contains the addon only.

Local changes: plugin.gd adds an Episodes tab and keeps the original dialogue
editor in a second tab. addons/story_graph/canvas.gd subclasses the original
Graph editor for stable episode IDs and gameplay records. Other upstream code
is unchanged apart from trimming trailing whitespace. Story execution uses the project's Quest state and renderer;
ordinary .tres dialogues still use the original Dialogue Nodes editor/parser.
