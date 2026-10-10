local response = spec("diyzjl_gouyun", "viewas")
local blind = {on_use = function(self, room, effect)
  local card = response.view_as(self, effect.from, effect.cards)
  assert(card and card.skill == Fk.skills["#diyzjl_blind_select"])
  assert(card.skill:feasible(effect.from, {}, {card.id}, card))
  assert(response.before_use(self, effect.from, {card = card, from = effect.from, tos = {}}) == "")
end}
local visibility = spec("diyzjl_tangshi", "visibility")
local limit = spec("diyzjl_tangshi", "maxcards")
local moving = spec("diyzjl_tangshi", fk.BeforeCardsMove)
local after = spec("diyzjl_tangshi", fk.AfterCardsMove)
local request = spec("diyzjl_gouyun", fk.HandleAskForPlayCard)
local luck = spec("diyzjl_gouyun", fk.AfterCardTargetDeclared)
local judge = spec("diyzjl_nitian", fk.FinishJudge)
local turn = spec("diyzjl_nitian", fk.BeforeTurnStart)
local wake = spec("diyzjl_yingli", fk.EventPhaseStart)
local tests = 0
local function check(fn) fn(); tests = tests + 1 end

check(function()
  local p, other, room = setup()
  local slash = give(p, "slash", 1)
  give(p, "jink", 2)
  assert(visibility.card_visible(nil, p, slash) == false)
  assert(visibility.card_visible(nil, other, slash) == nil)
  assert(limit.exclude_from(nil, p, slash))
  H.reveal(p, 1)
  assert(visibility.card_visible(nil, p, slash) == true)
  assert(not limit.exclude_from(nil, p, slash))
  assert(room.hp_losses == nil)
end)

check(function()
  local p, _, room = setup()
  local slash = give(p, "slash", 1)
  H.reveal(p, 1)
  assert(room.hp_losses == 1 and p.drawn == 4)
  H.reveal(p, 1)
  assert(room.hp_losses == 1)
end)

check(function()
  local p, _, room = setup()
  give(p, "slash", 1); give(p, "jink", 2)
  blind.on_use({interaction = {data = "ex_nihilo"}}, room, {from = p, cards = {1}})
  assert(#room.uses == 0 and room.thrown[1] == 1)
  assert(p:usedCardTimes("slash", Player.HistoryPhase) == 0)
  assert(room.real_request == nil)
  assert(p:getMark(H.count_mark) == 0)
end)

check(function()
  local p, other, room = setup()
  local slash = give(p, "slash", 1); give(p, "jink", 2)
  room.real_use = {card = slash, from = p, tos = {other}}
  blind.on_use({interaction = {data = "slash"}}, room, {from = p, cards = {1}})
  assert(room.uses[1].card == slash and room.uses[1].extra_data.diyzjl_hidden)
  assert(not room.real_request.extra_data.bypass_times and not room.real_request.extra_data.extraUse)
  assert(p:getMark(H.count_mark) == 1)
end)

check(function()
  local p, other, room = setup()
  local slash = give(p, "slash", 1); give(p, "jink", 2)
  p:setMark(H.awake_mark, 1)
  room.real_use = {card = slash, from = p, tos = {other}}
  blind.on_use({interaction = {data = "diyzjl_basic"}}, room, {from = p, cards = {1}})
  assert(room.uses[1].card.name == "slash")
  assert(not H.matches(p, "diyzjl_equip", slash))
end)

check(function()
  local p, _, room = setup()
  give(p, "slash", 1); give(p, "jink", 2)
  Fk.currentResponsePattern = "jink"
  local self = {interaction = {data = "jink"}}
  assert(response.card_filter(self, p, 1, {}) and response.card_filter(self, p, 2, {}))
  assert(response.view_as(self, p, {1}).name == response.view_as(self, p, {2}).name)
  request.on_refresh(nil, nil, p, p, {pattern = "jink"})
  Fk.currentResponsePattern = nil
  local failed = {card = response.view_as(self, p, {1}), from = p, tos = {}}
  assert(response.before_use(self, p, failed) == "" and room.thrown[1] == 1)
  assert(p:getMark(H.count_mark) == 0)
  request.on_refresh(nil, nil, p, p, {pattern = "jink"})
  local passed = {card = response.view_as(self, p, {2}), from = p, tos = {}}
  assert(response.before_use(self, p, passed) == nil and passed.card.id == 2)
  assert(p:getMark(H.count_mark) == 1)
end)

check(function()
  local p = setup()
  give(p, "slash", 1); give(p, "jink", 2)
  request.on_refresh(nil, nil, p, p, {pattern = "jink"})
  local choices = response.interaction(nil, p).choices
  assert(#choices == 1 and choices[1] == "jink")
  assert(response.view_as({interaction = {data = "slash"}}, p, {1}) == nil)
  assert(response.view_as({interaction = {data = "peach"}}, p, {2}) == nil)
  p:setMark(H.awake_mark, 1)
  choices = response.interaction(nil, p).choices
  assert(#choices == 1 and choices[1] == "diyzjl_basic")
end)

check(function()
  local p = setup()
  give(p, "slash", 1); give(p, "jink", 2)
  for _, pattern in ipairs({"slash", "peach", "nullification"}) do
    request.on_refresh(nil, nil, p, p, {pattern = pattern, isResponse = true})
    local choices = response.interaction(nil, p).choices
    for _, name in ipairs(choices) do assert(Exppattern:Parse(pattern):matchExp(name)) end
    assert(not table.contains(choices, "jink"))
  end
  request.on_refresh(nil, nil, p, p, {pattern = "peach,analeptic"})
  local choices = response.interaction(nil, p).choices
  assert(table.contains(choices, "peach") and table.contains(choices, "analeptic"))
end)

check(function()
  local p, _, room = setup()
  give(p, "jink", 1); give(p, "slash", 2)
  local self = {interaction = {data = "jink"}}
  request.on_refresh(nil, nil, p, p, {pattern = "jink|.|heart", isResponse = true})
  local placeholder = response.view_as(self, p, {1})
  assert(placeholder and placeholder.suit == Card.Heart)
  assert(placeholder.suit == response.view_as(self, p, {2}).suit)
  assert(response.before_use(self, p, {card = placeholder}) == "" and room.thrown[1] == 1)
end)

check(function()
  local p = setup()
  give(p, "slash", 1); give(p, "jink", 2)
  request.on_refresh(nil, nil, p, p, {pattern = "jink"})
  spec("diyzjl_gouyun", fk.StartPlayCard).on_refresh(nil, nil, p, p)
  assert(H.responsePattern(p) == nil)
  assert(table.contains(response.interaction(nil, p).choices, "slash"))
end)

check(function()
  local p, _, room = setup()
  give(p, "slash", 1); give(p, "jink", 2)
  p:setMark(H.awake_mark, 1)
  request.on_refresh(nil, nil, p, p, {pattern = "jink", isResponse = true})
  local self = {interaction = {data = "diyzjl_basic"}}
  local use = {card = response.view_as(self, p, {1}), from = p, tos = {}}
  assert(response.before_use(self, p, use) == "" and room.thrown[1] == 1)
  assert(p:usedCardTimes("slash", Player.HistoryPhase) == 0)
end)

check(function()
  local p, other, room = setup()
  give(p, "slash", 1)
  local data = {{from = p, toArea = Card.DiscardPile, moveInfo = {{cardId = 1, fromArea = Card.PlayerHand}}}}
  moving.on_refresh(nil, nil, nil, p, data)
  room:throwCard({1})
  assert(after.can_trigger(nil, nil, nil, p, data))
  after.on_use(nil, nil, nil, p, data)
  assert(room.hp_losses == 1 and p.drawn == 4)
end)

check(function()
  local p, _, room = setup()
  give(p, "slash", 1)
  local same = give(p, "jink", 2)
  room.selected = 2
  local data = {card = same}
  assert(judge.on_use(nil, nil, p, p, data) == true)
  local different = give(p, "peach", 3, Player.Hand, Card.Heart)
  table.removeOne(p.player_cards[Player.Hand], 3)
  room.processing, room.selected = 3, 1
  data.card = different
  assert(judge.on_use(nil, nil, p, p, data) == nil and room.obtained == different)
end)

check(function()
  local p, other, room = setup()
  local slash = give(p, "slash", 1)
  local use = UseCardData:new{card = slash, from = p, tos = {other}, extra_data = {diyzjl_hidden = true}}
  local e = event()
  room.choice = "diyzjl_repeat"
  assert(luck.on_cost(nil, e, p, p, use))
  luck.on_use(nil, e, p, p, use)
  assert(use.additionalEffect == 1 and p:getMark(H.count_mark) == 0)
  room.choice = "Cancel"
  assert(not luck.on_cost(nil, e, p, p, use) and p:getMark(H.count_mark) == 0)
end)

check(function()
  local p, other, room = setup()
  local equip = give(p, "crossbow", 1)
  room.can_move, room.choice = true, "diyzjl_move"
  local use = UseCardData:new{card = equip, from = p, tos = {p}, extra_data = {diyzjl_hidden = true}}
  local e = event()
  assert(luck.on_cost(nil, e, p, p, use))
  luck.on_use(nil, e, p, p, use)
  assert(room.moved.target_one == p and room.moved.target_two == other and p:getMark(H.count_mark) == 0)
end)

check(function()
  local p, other, room = setup()
  local trick = give(p, "duel", 1)
  local use = UseCardData:new{card = trick, from = p, tos = {other}, extra_data = {diyzjl_hidden = true}}
  local e = event()
  room.choice = "diyzjl_remove"
  assert(luck.on_cost(nil, e, p, p, use))
  luck.on_use(nil, e, p, p, use)
  assert(#use.tos == 0 and p:getMark(H.count_mark) == 0)
end)

check(function()
  local p, _, room = setup()
  p.phase, p.hp = Player.Start, 2
  p:setMark(H.count_mark, 3)
  assert(not wake.can_wake(nil, nil, p, p, {}))
  p:setMark(H.count_mark, 4)
  assert(wake.can_wake(nil, nil, p, p, {}))
  wake.on_use(nil, nil, p, p, {})
  assert(p.maxHp == 3 and p.hp == 3 and p:getMark(H.awake_mark) == 1)
  assert(not wake.can_trigger(nil, nil, p, p, {}))
  local card = give(p, "slash", 1)
  assert(limit.exclude_from(nil, p, card))
  H.reveal(p, 1)
  assert(room.hp_losses == 1 and p.drawn == 3)
end)

check(function()
  local p, _, room = setup()
  give(p, "slash", 1)
  room.choice = "ex_nihilo"
  turn.on_use(nil, nil, p, p, {})
  assert(room.uses[1].card.name == "ex_nihilo" and room.uses[1].tos[1] == p)
  assert(room.uses[1].extra_data.diyzjl_nitian and not room.uses[1].extra_data.diyzjl_hidden)
  assert(p:getMark(H.count_mark) == 0)
  assert(not luck.can_trigger(nil, nil, p, p, room.uses[1]))
end)

check(function()
  local p = setup()
  give(p, "slash", 1)
  local names = H.selfTrickNames(p, 1)
  for _, name in ipairs({"duel", "dismantlement", "snatch", "collateral", "nullification", "savage_assault", "archery_attack", "indulgence"}) do
    assert(not table.contains(names, name), name)
  end
  for _, name in ipairs({"ex_nihilo", "amazing_grace", "god_salvation", "lightning", "iron_chain", "fire_attack"}) do
    assert(table.contains(names, name), name)
  end
  p.sealedSlots = {Player.JudgeSlot}
  assert(not table.contains(H.selfTrickNames(p, 1), "lightning"))
end)

check(function()
  local p, _, room = setup()
  give(p, "slash", 1)
  room.choice = "duel"
  turn.on_use(nil, nil, p, p, {})
  assert(#room.uses == 0)
end)

check(function()
  local p, _, room = setup()
  local equip = give(p, "crossbow", 1, Player.Equip)
  assert(not H.isHidden(p, 1) and #H.hiddenCards(p) == 0)
  assert(not limit.exclude_from(nil, p, equip))
  assert(not table.contains(H.selfTrickNames(p, 1), "fire_attack"))
  local hand = give(p, "slash", 2)
  local moves = {{from = p, to = p, toArea = Card.PlayerEquip,
    moveInfo = {{cardId = 2, fromArea = Card.PlayerHand}}}}
  moving.on_refresh(nil, nil, nil, p, moves)
  table.removeOne(p.player_cards[Player.Hand], 2)
  table.insert(p.player_cards[Player.Equip], 2)
  assert(not H.isHidden(p, 2))
  assert(after.can_trigger(nil, nil, nil, p, moves))
  after.on_use(nil, nil, nil, p, moves)
  assert(room.hp_losses == 1 and p.drawn == 4)
end)

check(function()
  local p, other, room = setup()
  local hand = give(p, "slash", 1)
  local equip = give(p, "crossbow", 2, Player.Equip)
  for _, effect in ipairs(Fk.skill_skels.diyzjl_tangshi.effects) do
    if effect:isInstanceOf(VisibilitySkill) then room.status_skills[VisibilitySkill] = {effect} end
  end
  assert(not p:cardVisible(hand.id) and p:cardVisible(equip.id))
  assert(not other:cardVisible(hand.id) and other:cardVisible(equip.id))
  H.reveal(p, hand.id)
  assert(p:cardVisible(hand.id))
end)

check(function()
  local p, other, room = setup()
  local card = give(p, "duel", 1)
  give(other, "crossbow", 2, Player.Equip)
  room.choice = "diyzjl_discard"
  local use = UseCardData:new{card = card, from = p, tos = {other}, extra_data = {diyzjl_hidden = true}}
  local e = event()
  assert(luck.on_cost(nil, e, p, p, use))
  luck.on_use(nil, e, p, p, use)
  assert(room.thrown[1] == 2 and p:getMark(H.count_mark) == 0)
end)

check(function()
  local p, _, room = setup()
  local card = give(p, "slash", 1)
  give(p, "jink", 2)
  H.reveal(p, 1)
  local moves = {{from = p, toArea = Card.DiscardPile, moveInfo = {{cardId = 1, fromArea = Card.PlayerHand}}}}
  moving.on_refresh(nil, nil, nil, p, moves)
  room:throwCard({1})
  assert(not after.can_trigger(nil, nil, nil, p, moves))
  table.insert(p.player_cards[Player.Hand], 1)
  assert(H.isHidden(p, 1))
end)

check(function()
  local p, _, room = setup()
  give(p, "slash", 1); give(p, "jink", 2)
  local trick = Fk:cloneCard("duel")
  trick.skillName = "diyzjl_nitian"
  trick:addSubcard(1)
  local restriction = spec("diyzjl_tangshi", "prohibit")
  assert(restriction.prohibit_use(nil, p, Fk:getCardById(1)))
  assert(not restriction.prohibit_use(nil, p, trick))
end)

check(function()
  local p, _, room = setup()
  give(p, "jink", 1)
  request.on_refresh(nil, nil, p, p, {pattern = "jink"})
  local self = {interaction = {data = "jink"}}
  local use = {card = response.view_as(self, p, {1}), from = p, tos = {}}
  local reveal = p.showCards
  p.showCards = function()
    request.on_refresh(nil, nil, p, p, {pattern = "peach", afterRequest = true})
    reveal()
  end
  assert(response.before_use(self, p, use) == nil and use.card.name == "jink")
  request.on_refresh(nil, nil, p, p, {pattern = "jink", afterRequest = true})
  assert(p:getMark("diyzjl_response_pattern") == "jink")
end)
check(function()
  local p = setup()
  for id = 1, 5 do give(p, "jink", id) end
  for id = 1, 4 do
    request.on_refresh(nil, nil, p, p, {pattern = "jink", isResponse = true})
    local self = {interaction = {data = "jink"}}
    local use = {card = response.view_as(self, p, {id}), from = p, tos = {}}
    assert(response.before_use(self, p, use) == nil)
  end
  assert(p:getMark(H.count_mark) == 4)
  p.phase = Player.Start
  assert(wake.can_wake(nil, nil, p, p, {}))
end)

check(function()
  local p, _, room = setup()
  give(p, "slash", 1); give(p, "jink", 2)
  blind.on_use({interaction = {data = "slash"}}, room, {from = p, cards = {1}})
  assert(room.thrown[1] == 1 and p:getMark(H.count_mark) == 0)
end)

check(function()
  local p, other, room = setup()
  local slash = give(p, "slash", 1); give(p, "jink", 2)
  room.real_use = {card = slash, from = p, tos = {other}}
  blind.on_use({interaction = {data = "slash"}}, room, {from = p, cards = {1}})
  assert(p:getMark(H.count_mark) == 1)
  local use = UseCardData:new(room.uses[1])
  local e = event()
  room.choice = "Cancel"
  assert(not luck.on_cost(nil, e, p, p, use))
  assert(p:getMark(H.count_mark) == 1)
  room.choice = "diyzjl_repeat"
  assert(luck.on_cost(nil, e, p, p, use))
  luck.on_use(nil, e, p, p, use)
  assert(p:getMark(H.count_mark) == 1)
end)

check(function()
  local p = setup()
  p.phase = Player.Play
  give(p, "slash", 1); give(p, "jink", 2)
  local menu = response.interaction(nil, p)
  assert(table.contains(menu.all_choices, "jink") and not table.contains(menu.choices, "jink"))
  assert(table.contains(menu.all_choices, "peach") and not table.contains(menu.choices, "peach"))
  assert(table.contains(menu.choices, "slash"))
  assert(not table.contains(menu.all_choices, "fire__slash") and not table.contains(menu.all_choices, "thunder__slash"))
  p:addCardUseHistory("slash", 1)
  menu = response.interaction(nil, p)
  assert(table.contains(menu.all_choices, "slash") and not table.contains(menu.choices, "slash"))
  assert(response.view_as({interaction = {data = "slash"}}, p, {1}) == nil)
  assert(response.view_as({interaction = {data = "jink"}}, p, {2}) == nil)
  request.on_refresh(nil, nil, p, p, {pattern = "slash", isResponse = true})
  assert(table.contains(response.interaction(nil, p).choices, "slash"))
end)

check(function()
  local p = setup()
  give(p, "slash", 1); give(p, "jink", 2)
  for _, name in ipairs({"slash", "fire__slash", "thunder__slash"}) do
    assert(H.matches(p, "slash", Fk:cloneCard(name)))
  end
  assert(not H.matches(p, "slash", Fk:cloneCard("jink")))
  local before = table.concat(response.interaction(nil, p).choices, ",")
  Fk.cards[1] = Fk:cloneCard("iron_chain"); Fk.cards[1].id = 1
  assert(table.concat(response.interaction(nil, p).choices, ",") == before)
end)

check(function()
  local p, other = setup()
  give(p, "slash", 1)
  p:setMark(H.awake_mark, 1)
  local menu = response.interaction(nil, p)
  assert(table.concat(menu.all_choices, ",") == "diyzjl_basic,diyzjl_equip,diyzjl_trick,diyzjl_delayed_trick")
  assert(H.matches(p, "diyzjl_trick", Fk:cloneCard("duel")))
  assert(H.matches(p, "diyzjl_delayed_trick", Fk:cloneCard("lightning")))
  assert(not H.matches(p, "diyzjl_trick", Fk:cloneCard("lightning")))
  p.sealedSlots = {Player.JudgeSlot}
  other.sealedSlots = {Player.JudgeSlot}
  menu = response.interaction(nil, p)
  assert(table.contains(menu.all_choices, "diyzjl_delayed_trick") and not table.contains(menu.choices, "diyzjl_delayed_trick"))
  request.on_refresh(nil, nil, p, p, {pattern = "jink"})
  assert(table.concat(response.interaction(nil, p).choices, ",") == "diyzjl_basic")
end)

print("PASS: "..tests.." skill scenarios")
