"""Run with the bundled Python; uses a workspace-local Lua 5.4 (lupa)."""
from pathlib import Path
import os
import shutil
import sys

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / "_tools/python"))
from lupa.lua54 import LuaRuntime

core = root / "_reference/freekill-core"
game = root / "_tools/test-game"
game.mkdir(parents=True, exist_ok=True)
shutil.copytree(core / "lua", game / "lua", dirs_exist_ok=True)
for name in ("standard", "standard_cards", "maneuvering"):
    shutil.copytree(core / name, game / "packages" / name, dirs_exist_ok=True)
# These unmodified upstream skills are cached locally, not bundled with the extension.
for package, name in (("variation_cards", "ice__slash"), ("espionage_cards", "stab__slash"), ("espionage_cards", "sincere_treat")):
    target = game / "packages/variant_fixture" / (name + ".lua")
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(root / "_reference/gamemode/pkg" / package / "skills" / (name + ".lua"), target)
shutil.copytree(root / "diy_sunjiale", game / "packages/diy_sunjiale", dirs_exist_ok=True)
(game / "packages/diy_sunjiale/skills/blind_play.lua").unlink(missing_ok=True)
os.chdir(game)
lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().py_ls = lambda path: lua.table_from(sorted(p.name for p in Path(path).iterdir()))
lua.globals().py_exists = lambda path: Path(path).exists()
lua.globals().py_pwd = lambda: str(game).replace("\\", "/")
for file in (root / "diy_sunjiale").rglob("*.lua"):
    lua.execute("assert(load(...))", file.read_text(encoding="utf-8"))
lua.execute((root / "tests/bootstrap.lua").read_text(encoding="utf-8"))
lua.execute((root / "tests/variant_registration.lua").read_text(encoding="utf-8"))
# Native Exppattern builds its name/type index once from the registered entity cards.
lua.execute('''for id, name in ipairs(Fk.all_card_names) do
  local card = Fk:cloneCard(name, Card.Spade, 7)
  card.id = id; Fk.cards[id] = card
end
Exppattern:Parse(".")''')
lua.execute((root / "tests/skills.lua").read_text(encoding="utf-8"))
lua.execute((root / "tests/wei_skills.lua").read_text(encoding="utf-8"))
lua.execute((root / "tests/variant_cards.lua").read_text(encoding="utf-8"))
print("PASS: Lua 5.4 syntax, official core registration and skill scenario tests")
