local wei = Fk.generals.diywei__sunjiale
assert(wei and wei.hp == 4 and wei.maxHp == 8 and wei.kingdom == "wei" and #wei.other_skills == 2)
assert(Fk:translate(wei.name, "zh_CN") == "威孙佳乐")
assert(Fk:translate("#"..wei.name, "zh_CN") == "风卷残云")
local juanshi = spec("diywei_juanshi", "active")
local combo = spec("diywei_baotie", fk.CardUsing)
local reward = spec("diywei_baotie", fk.CardUseFinished)
local residue = spec("diywei_baotie", "targetmod")
local tests = 0
local function check(fn) fn(); tests = tests + 1 end
local function prepare()
  local p, other, room = setup()
  p.hp, p.maxHp, p.phase = 4, 8, Player.Play
  room.draw_pile, room.discard_pile = {}, {}
  function room:getCardsFromPileByRule(pattern, count, source)
    assert(source == "drawPile")
    self.last_requested = count
    local result = {}
    for _, id in ipairs(self.draw_pile) do
      local card = Fk:getCardById(id)
      local matches = pattern == ".|.|heart|.|.|basic" and card.type == Card.TypeBasic and card.suit == Card.Heart or
        pattern == ".|.|spade,club" and card.color == Card.Black
      if matches and #result < count then table.insert(result, id) end
    end
    return result
  end
  function room:obtainCard(player, ids)
    self.obtained = self.obtained or {}
    for _, id in ipairs(ids) do
      assert(table.contains(self.draw_pile, id))
      table.removeOne(self.draw_pile, id)
      table.insert(player.player_cards[Player.Hand], id)
      table.insert(self.obtained, id)
    end
  end
  local function pile(name, suit, id)
    local card = Fk:cloneCard(name, suit, 7); card.id = id; Fk.cards[id] = card
    table.insert(room.draw_pile, id)
  end
  pile("slash", Card.Heart, 401); pile("peach", Card.Diamond, 402)
  pile("ex_nihilo", Card.Heart, 403); pile("jink", Card.Heart, 404)
  pile("slash", Card.Spade, 405); pile("dismantlement", Card.Club, 406)
  pile("crossbow", Card.Club, 407); pile("peach", Card.Heart, 408)
  return p, other, room
end
local function using(p, name)
  local data = {card = Fk:cloneCard(name), from = p}
  if combo.can_refresh(nil, nil, p, p, data) then combo.on_refresh(nil, nil, p, p, data) end
  return data
end
check(function()
  local p, _, room = prepare()
  assert(juanshi.can_use(nil, p))
  juanshi.on_use(nil, room, {from = p}); juanshi.on_use(nil, room, {from = p})
  assert(p.hp == 2 and #room.obtained == 2)
  for _, id in ipairs(room.obtained) do assert(Fk.cards[id].suit == Card.Heart and Fk.cards[id].type == Card.TypeBasic) end
  p.phase = Player.Finish; assert(not juanshi.can_use(nil, p))
end)
check(function()
  local p, _, room = prepare()
  room.draw_pile = {402, 403}; juanshi.on_use(nil, room, {from = p})
  assert(p.hp == 3 and room.obtained == nil)
  p.hp = 1
  room.loseHp = function(_, player) player.hp = 0; player.dead = true end
  juanshi.on_use(nil, room, {from = p}); assert(room.obtained == nil)
end)
check(function()
  local p, _, room = prepare()
  using(p, "peach"); local data = using(p, "fire__slash")
  assert(reward.can_trigger(nil, nil, p, p, data) and reward.on_cost())
  p.hp = 2; reward.on_use(nil, nil, p, p, data)
  assert(room.last_requested == 2 and #room.obtained == 2)
  for _, id in ipairs(room.obtained) do assert(Fk.cards[id].color == Card.Black) end
  assert(residue.residue_func(nil, p, {trueName = "slash_skill"}, Player.HistoryPhase) == 1)
  assert(not reward.can_trigger(nil, nil, p, p, data))
  assert(residue.residue_func(nil, p, {trueName = "slash_skill"}, Player.HistoryTurn) == nil)
  assert(residue.residue_func(nil, p, {trueName = "peach_skill"}, Player.HistoryPhase) == nil)
end)
check(function()
  local p, _, room = prepare()
  for _, first in ipairs({"slash", "ex_nihilo"}) do
    using(p, first); assert(not reward.can_trigger(nil, nil, p, p, using(p, "slash")))
  end
  using(p, "peach"); using(p, "ex_nihilo")
  assert(not reward.can_trigger(nil, nil, p, p, using(p, "slash")))
  using(p, "peach")
  p:setMark("diywei_baotie_ready-phase", 0)
  assert(not reward.can_trigger(nil, nil, p, p, using(p, "slash")))
end)
check(function()
  local p, other, room = prepare()
  using(p, "peach")
  assert(not combo.can_refresh(nil, nil, other, p, {card = Fk:cloneCard("slash")}))
  p.phase = Player.NotActive
  assert(not combo.can_refresh(nil, nil, p, p, {card = Fk:cloneCard("slash")}))
  p.phase = Player.Play
  for i = 1, 2 do
    using(p, "peach"); local data = using(p, "slash")
    reward.on_use(nil, nil, p, p, data)
    assert(residue.residue_func(nil, p, {trueName = "slash_skill"}, Player.HistoryPhase) == i)
  end
  assert(#room.obtained == 3)
  p:setMark("@diywei_baotie-turn", 0)
  assert(residue.residue_func(nil, p, {trueName = "slash_skill"}, Player.HistoryPhase) == 0)
end)
print("PASS: "..tests.." Wei Sunjiale skill scenarios and 4/8 general registration")
