-- Run against the cached, unmodified upstream card skills; do not ship the card packs.
local response = spec("diyzjl_gouyun", "viewas")
local request = spec("diyzjl_gouyun", fk.HandleAskForPlayCard)
local combo = spec("diywei_baotie", fk.CardUsing)
local reward = spec("diywei_baotie", fk.CardUseFinished)
local tests = 0
local function check(fn) fn(); tests = tests + 1 end

check(function()
  local p = setup()
  local choices = H.allDeclarations(p)
  local count = 0
  for _, name in ipairs(choices) do if name == "slash" then count = count + 1 end end
  assert(count == 1)
  for _, name in ipairs({"ice__slash", "stab__slash", "future_fixture__slash"}) do
    local card = Fk:cloneCard(name)
    assert(card.trueName == "slash" and card.skill.trueName == "slash_skill")
    assert(H.matches(p, "slash", card) and not table.contains(choices, name))
  end
end)

check(function()
  local p, other, room = setup()
  p.phase = Player.Play
  local card = give(p, "ice__slash", 901)
  give(p, "jink", 902)
  card.extra_data = {variation = {"@canqu", "variation_addtarget"}}
  local originalSkill, originalData = card.skill, card.extra_data
  room.real_use = {card = card, from = p, tos = {other}}
  local use = {card = response.view_as({interaction = {data = "slash"}}, p, {901})}
  assert(response.before_use(nil, p, use) == "")
  local actual = room.uses[1].card
  assert(actual == card and actual.skill == originalSkill and actual.extra_data == originalData)
  assert(actual.name == "ice__slash" and actual.number == 7 and actual.suit == Card.Spade)
  room.damage = function(_, data) room.last_damage = data end
  actual.skill:onEffect(room, {from = p, to = other, card = actual})
  assert(room.last_damage.damageType == fk.IceDamage and room.last_damage.card == actual)
  assert(p:getMark(H.count_mark) == 1)
end)

check(function()
  local p, _, room = setup()
  give(p, "ice__slash", 903); give(p, "stab__slash", 904); give(p, "jink", 905)
  request.on_refresh(nil, nil, p, p, {pattern = "slash|.|.|.|ice__slash", isResponse = true})
  assert(table.concat(response.interaction(nil, p).choices, ",") == "slash")
  local wrong = {card = response.view_as({interaction = {data = "slash"}}, p, {904})}
  assert(response.before_use(nil, p, wrong) == "" and room.thrown[1] == 904)
  assert(p:getMark(H.count_mark) == 0)
  request.on_refresh(nil, nil, p, p, {pattern = "slash|.|.|.|ice__slash", isResponse = true})
  local right = {card = response.view_as({interaction = {data = "slash"}}, p, {903})}
  assert(response.before_use(nil, p, right) == nil and right.card == Fk:getCardById(903))
  assert(right.card.name == "ice__slash" and p:getMark(H.count_mark) == 1)
end)

check(function()
  local p, _, room = setup()
  give(p, "stab__slash", 906); give(p, "jink", 907)
  request.on_refresh(nil, nil, p, p, {pattern = "jink"})
  assert(table.concat(response.interaction(nil, p).choices, ",") == "jink")
  assert(response.view_as({interaction = {data = "slash"}}, p, {906}) == nil)
  local wrong = {card = response.view_as({interaction = {data = "jink"}}, p, {906})}
  assert(response.before_use(nil, p, wrong) == "" and #room.uses == 0)
  assert(p:getMark(H.count_mark) == 0)
end)

check(function()
  local p = setup()
  p.phase = Player.Play
  give(p, "stab__slash", 908)
  p:addCardUseHistory("slash", 1)
  local menu = response.interaction(nil, p)
  assert(table.contains(menu.all_choices, "slash") and not table.contains(menu.choices, "slash"))
  for _, name in ipairs({"ice__slash", "stab__slash"}) do
    local card = Fk:cloneCard(name)
    assert(not card.skill:withinTimesLimit(p, Player.HistoryPhase, card, "slash"))
  end
  request.on_refresh(nil, nil, p, p, {pattern = "slash", isResponse = true})
  assert(table.contains(response.interaction(nil, p).choices, "slash"))
end)

check(function()
  local p, other, room = setup()
  p.phase = Player.Play
  local trick = give(p, "sincere_treat", 909); give(p, "jink", 910)
  give(other, "slash", 911)
  assert(table.contains(H.declarations(p), "sincere_treat"))
  assert(not table.contains(H.selfTrickNames(p, 909), "sincere_treat"))
  assert(not p:canUseTo(trick, p) and p:canUseTo(trick, other))
  p:setMark(H.awake_mark, 1)
  assert(H.matches(p, "diyzjl_trick", trick) and not H.matches(p, "diyzjl_delayed_trick", trick))
  local original = trick.skill
  room.real_use = {card = trick, from = p, tos = {other}}
  local use = {card = response.view_as({interaction = {data = "diyzjl_trick"}}, p, {909})}
  assert(response.before_use(nil, p, use) == "")
  assert(room.uses[1].card == trick and room.uses[1].card.skill == original)
end)

check(function()
  local p, _, room = setup()
  p:setMark(H.awake_mark, 1)
  assert(H.typeName(Fk:cloneCard("fixture_delayed")) == "diyzjl_delayed_trick")
  assert(H.typeName(Fk:cloneCard("fixture_equip")) == "diyzjl_equip")
  assert(H.typeName(Fk:cloneCard("ice__slash")) == "diyzjl_basic")
  assert(H.typeName(Fk:cloneCard("future_basic")) == "diyzjl_basic")
  assert(H.typeName(Fk:cloneCard("future_trick")) == "diyzjl_trick")
  p:setMark(H.awake_mark, 0)
  local menu = response.interaction(nil, p)
  assert(table.contains(menu.all_choices, "future_basic") and not table.contains(menu.choices, "future_basic"))
  assert(table.contains(menu.all_choices, "future_trick"))
  assert(table.contains(H.allowedNames("slash"), "future_fixture__slash"))
  assert(table.concat(H.declarations(p, ".|.|.|.|future_basic"), ",") == "future_basic")
  assert(Fk:translate("diyzjl_trick", "zh_CN") == "普通锦囊牌")
  assert(Fk:translate("diyzjl_delayed_trick", "zh_CN") == "特殊（延时）锦囊牌")
  room.disabled_packs = {"variant_fixture"}
  p:setMark(H.awake_mark, 0)
  for _, name in ipairs({"ice__slash", "stab__slash", "sincere_treat", "fixture_delayed", "fixture_equip", "future_basic", "future_trick", "future_fixture__slash"}) do
    assert(not table.contains(H.allowedNames(), name))
  end
  assert(not table.contains(H.allDeclarations(p), "sincere_treat"))
end)

check(function()
  local p, _, room = setup()
  p.phase = Player.Play
  room.getCardsFromPileByRule = function() return {} end
  for _, effect in ipairs(Fk.skill_skels.diywei_baotie.effects) do
    if effect:isInstanceOf(TargetModSkill) then room.status_skills[TargetModSkill] = {effect} end
  end
  p:addCardUseHistory("slash", 1)
  for i, name in ipairs({"ice__slash", "stab__slash"}) do
    local peach = {card = Fk:cloneCard("peach")}
    combo.on_refresh(nil, nil, p, p, peach)
    local data = {card = Fk:cloneCard(name)}
    combo.on_refresh(nil, nil, p, p, data)
    assert(reward.can_trigger(nil, nil, p, p, data))
    reward.on_use(nil, nil, p, p, data)
    assert(p:getMark("@diywei_baotie-turn") == i)
    assert(data.card.skill:withinTimesLimit(p, Player.HistoryPhase, data.card, "slash"))
    assert(not reward.can_trigger(nil, nil, p, p, data))
    p:addCardUseHistory("slash", 1)
  end
end)
assert(tests == 8)
print("PASS: "..tests.." extension card scenarios with upstream skills (ice slash, stab slash, sincere treat)")
