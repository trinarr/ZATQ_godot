"""Check every authored locale in a CSV-free PCK, without game autoloads or saves."""
import argparse
import csv
import json
import os
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

CHECK = '''extends SceneTree
const LOC = preload("res://scripts/core/localization.gd")
func _initialize() -> void:
 var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://expected.json"))
 var failures := 0
 var checks := 0
 LOC.prepare(true)
 for table_name: String in expected:
  if FileAccess.file_exists("res://locales/"+table_name+".csv"):
   push_error("Source CSV leaked into test pack: "+table_name)
   failures += 1
  if not LOC.tables.has(table_name) or LOC.tables[table_name].rows.is_empty():
   push_error("Packaged table unavailable: "+table_name)
   failures += 1
 for locale: String in ["ru", "en", "ru_RU", "en_US"]:
  TranslationServer.set_locale(locale)
  for table_name: String in expected:
   for key: String in expected[table_name]:
    var values: Dictionary = expected[table_name][key]
    var wanted: String = values.get(locale.get_slice("_",0), "")
    if wanted.is_empty(): wanted = values.ru
    var actual: String = LOC.text("@loc:"+key)
    checks += 1
    if actual != wanted or LOC.source("@loc:"+key) != values.ru:
     if failures < 12: push_error("Packaged translation mismatch: "+locale+" / "+key)
     failures += 1
 print("CSV-free localization: %d checks, %d tables, %d failures" % [checks, expected.size(), failures])
 quit(1 if failures else 0)
'''

BUILD = '''extends SceneTree
func _initialize() -> void:
 var pack := PCKPacker.new()
 assert(pack.pck_start("res://locales_test.pck") == OK)
 for path: String in ["project.godot", "check.gd", "expected.json", "scripts/core/localization.gd"]:
  assert(pack.add_file("res://"+path, "res://"+path) == OK)
 for filename: String in DirAccess.get_files_at("res://locales"):
  if filename.ends_with(".translation"):
   assert(pack.add_file("res://locales/"+filename, "res://locales/"+filename) == OK)
 for filename: String in DirAccess.get_files_at("res://data/story_graphs"):
  assert(pack.add_file("res://data/story_graphs/"+filename, "res://data/story_graphs/"+filename) == OK)
 assert(pack.flush() == OK)
 quit()
'''


def run(godot, work_dir, ui=False):
    expected = {}
    for source in sorted((ROOT / "locales").glob("*.csv")):
        with source.open(encoding="utf-8-sig", newline="") as stream:
            expected[source.stem] = {
                row["key"]: {k: v for k, v in row.items() if k != "key"}
                for row in csv.DictReader(stream)
            }
    keys = {key for table in expected.values() for key in table}
    loader = (ROOT / "scripts/core/localization.gd").read_text(encoding="utf-8")
    builtin = set(re.findall(r'"([^"]+)"', re.search(
        r"const BUILTIN_TABLES := \[([^\]]+)\]", loader).group(1)))
    if set(expected) != builtin:
        raise RuntimeError(f"Export table list differs from CSV tables: {set(expected) ^ builtin}")
    for table in expected:
        settings = (ROOT / "locales" / (table + ".csv.import")).read_text(encoding="utf-8")
        if not re.search(r"^compress=0$", settings, re.MULTILINE):
            raise RuntimeError(f"CSV-free key enumeration requires compress=0: {table}")
    # Check every reference, including TV scripts and nested JSON UI/graph fields.
    references = set()
    for folder, suffix in [("scripts", "*.gd"), ("scenes", "*.tscn"), ("data", "*.json")]:
        for path in (ROOT / folder).rglob(suffix):
            references.update(re.findall(r"@loc:([A-Za-z0-9_.]+)", path.read_text(encoding="utf-8")))
    missing = references - keys
    if missing:
        raise RuntimeError(f"Unknown localization references: {sorted(missing)}")
    print(f"PASS: {len(references)} referenced keys exist in {len(expected)} tables", flush=True)
    # Separate app, no Quest or other autoloads, no game user:// reads or writes.
    work_dir.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="zatq_locales_", dir=work_dir) as temp:
        sandbox = Path(temp)
        sandbox.resolve().relative_to(work_dir.resolve())
        environment = os.environ.copy()
        for variable in ["APPDATA", "LOCALAPPDATA"]:
            profile = sandbox / variable.lower()
            profile.mkdir()
            environment[variable] = str(profile)
        project = sandbox / "source"
        project.mkdir()
        (project / "scripts/core").mkdir(parents=True)
        shutil.copy2(ROOT / "scripts/core/localization.gd", project / "scripts/core/localization.gd")
        (project / "locales").mkdir()
        shutil.copytree(ROOT / "data/story_graphs", project / "data/story_graphs")
        for source in (ROOT / "locales").iterdir():
            if source.name.endswith((".csv", ".csv.import")):
                shutil.copy2(source, project / "locales" / source.name)
        ui_scripts = ["tools/tv_dorwood_test.gd", "tools/tv_news_test.gd",
                      "tools/tv_vestnik_test.gd", "tests/test_tv_maintenance.gd"]
        if ui:
            copied = set()

            def copy_resource(relative):
                if relative in copied:
                    return
                copied.add(relative)
                source = ROOT / relative
                target = project / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source, target)
                if Path(str(source) + ".import").exists():
                    shutil.copy2(str(source) + ".import", str(target) + ".import")
                if source.suffix in {".gd", ".tscn"}:
                    for dependency in re.findall(r'res://([^"\s]+)', source.read_text(encoding="utf-8")):
                        if (ROOT / dependency).is_file():
                            copy_resource(dependency)

            for script in ui_scripts:
                copy_resource(script)
        # Match runtime fallback; all authored values remain unchanged.
        (project / "project.godot").write_text(
            '[application]\nconfig/name="ZATQ isolated locale regression"\n'
            '[internationalization]\nlocale/fallback="ru"\n', encoding="utf-8")
        (project / "expected.json").write_text(json.dumps(expected, ensure_ascii=False), encoding="utf-8")
        (project / "check.gd").write_text(CHECK, encoding="utf-8")
        (project / "build.gd").write_text(BUILD, encoding="utf-8")

        def engine(*args, headless=True):
            result = subprocess.run([str(godot), *(["--headless"] if headless else []), *args], cwd=sandbox,
                                    capture_output=True, text=True, encoding="utf-8",
                                    errors="replace", timeout=90, env=environment)
            output = result.stdout + result.stderr
            print(output, end="", flush=True)
            if result.returncode or "ERROR:" in output or "SCRIPT ERROR" in output:
                raise RuntimeError(f"Godot check failed (exit {result.returncode})")

        engine("--path", str(project), "--editor", "--import")
        engine("--path", str(project), "--script", "res://build.gd")
        pack = sandbox / "locales_test.pck"
        shutil.move(project / pack.name, pack)
        # Neither project sources nor CSV are accessible via the pack's res://.
        engine("--path", str(sandbox), "--main-pack", str(pack), "--script", "res://check.gd")
        if ui:
            for script in ui_scripts:
                engine("--path", str(project), "--rendering-method", "gl_compatibility",
                       "--script", "res://" + script, headless=False)
            # Capture the reported broadcast at both target sizes and languages.
            (project / "capture.gd").write_text('''extends SceneTree
func _initialize() -> void: capture.call_deferred()
func capture() -> void:
 var view = load("res://scenes/ui/TVDorwood.tscn").instantiate()
 root.add_child(view)
 for extent in [Vector2i(1600,960), Vector2i(2400,1080)]:
  root.size = extent
  for locale in ["ru", "en"]:
   TranslationServer.set_locale(locale)
   await process_frame
   await process_frame
   await RenderingServer.frame_post_draw
   var image = root.get_texture().get_image()
   assert(image.save_png("res://dorwood_%s_%dx%d.png" % [locale,extent.x,extent.y]) == OK)
 view.free()
 quit()
''', encoding="utf-8")
            engine("--path", str(project), "--rendering-method", "gl_compatibility",
                   "--script", "res://capture.gd", headless=False)
            for capture in project.glob("dorwood_*.png"):
                shutil.copy2(capture, work_dir / capture.name)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--work-dir", type=Path, default=ROOT / "build",
                        help="Parent directory for the temporary isolated project (default: build/)")
    parser.add_argument("--ui", action="store_true", help="Also run TV GPU tests and capture Dorwood in RU/EN")
    args = parser.parse_args()
    run(args.godot.resolve(), args.work_dir.resolve(), args.ui)
