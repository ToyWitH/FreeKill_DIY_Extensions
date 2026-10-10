-- Metadata follows the upstream packages; skills are copied unmodified by run.py.
local pack = Package:new("variant_fixture", Package.CardPack)
pack:loadSkillSkels({dofile("packages/variant_fixture/ice__slash.lua"),
  dofile("packages/variant_fixture/stab__slash.lua"), dofile("packages/variant_fixture/sincere_treat.lua")})
Fk:loadPackage(pack)
for _, row in ipairs({
  {name = "ice__slash", type = Card.TypeBasic, skill = "ice__slash_skill", damage_type = fk.IceDamage},
  {name = "stab__slash", type = Card.TypeBasic, skill = "stab__slash_skill", damage_type = fk.NormalDamage},
  {name = "sincere_treat", type = Card.TypeTrick, skill = "sincere_treat_skill"},
  {name = "future_fixture__slash", type = Card.TypeBasic, skill = "slash_skill"},
  {name = "future_basic", type = Card.TypeBasic, skill = "jink_skill", is_passive = true},
  {name = "future_trick", type = Card.TypeTrick, skill = "sincere_treat_skill"},
  {name = "fixture_delayed", type = Card.TypeTrick, sub_type = Card.SubtypeDelayedTrick, skill = "lightning_skill"},
  {name = "fixture_equip", type = Card.TypeEquip, sub_type = Card.SubtypeWeapon, attack_range = 1, skill = "crossbow_skill"},
}) do
  local card = fk.CreateCard(row):createCardPrototype()
  card.package = pack
  Fk.all_card_types[card.name] = card
  table.insert(Fk.all_card_names, card.name)
end
