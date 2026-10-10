local H = {}
H.open_mark = "diyzjl_open_owner"
H.awake_mark = "diyzjl_awakened"
H.count_mark = "@diyzjl_gouyun"
H.types = {"diyzjl_basic", "diyzjl_equip", "diyzjl_trick", "diyzjl_delayed_trick"}

function H.typeName(card)
  if card.type == Card.TypeBasic then return H.types[1] end
  if card.type == Card.TypeEquip then return H.types[2] end
  if card.type == Card.TypeTrick then
    return card.sub_type == Card.SubtypeDelayedTrick and H.types[4] or H.types[3]
  end
end

function H.isHidden(player, id)
  return player:hasSkill("diyzjl_tangshi") and
    table.contains(player:getCardIds("h"), id) and
    Fk:getCardById(id, true):getMark(H.open_mark) ~= player.id
end

function H.hiddenCards(player)
  return table.filter(player:getCardIds("h"), function(id) return H.isHidden(player, id) end)
end

function H.selfTrickNames(player, id)
  return table.filter(Fk:getAllCardNames("td"), function(name)
    local card = Fk:cloneCard(name)
    card.skillName = "diyzjl_nitian"
    if id then card:addSubcard(id) end
    return player:canUseTo(card, player, {bypass_times = true}) and
      card.skill:feasible(player, {player}, card.subcards, card)
  end)
end

function H.refill(player)
  if player.dead or player.diyzjl_refilling or #H.hiddenCards(player) > 0 then return end
  player.diyzjl_refilling = true
  player.room:loseHp(player, 1, "diyzjl_tangshi")
  if not player.dead then player:drawCards(player.maxHp, "diyzjl_tangshi") end
  player.diyzjl_refilling = nil
end

function H.reveal(player, id)
  local hidden = H.isHidden(player, id)
  player.room:setCardMark(Fk:getCardById(id, true), H.open_mark, player.id)
  player:showCards({id})
  if hidden and #H.hiddenCards(player) == 0 then H.refill(player) end
end

function H.matches(player, declaration, card)
  if player:getMark(H.awake_mark) > 0 then return declaration == H.typeName(card) end
  return declaration == H.declarationName(card)
end

function H.declarationName(card)
  return card.trueName == "slash" and "slash" or card.name
end

function H.responsePattern(player)
  local pattern = Fk.currentResponsePattern or player:getMark("diyzjl_response_pattern")
  if type(pattern) == "string" and pattern ~= "" then return pattern end
end

function H.allowedNames(pattern)
  local names = Fk:getAllCardNames("btde")
  if not pattern then return names end
  local exp = Exppattern:Parse(pattern)
  return table.filter(names, function(name)
    local card = Fk:cloneCard(name)
    return exp:matchExp(card.trueName.."|.|.|.|"..card.name)
  end)
end

-- Probe public prototypes, never the identity of a selected hidden hand card.
function H.canDeclareAtPlay(player, name)
  local card = Fk:cloneCard(name)
  card.skillName = "diyzjl_gouyun"
  if not player:canUse(card) then return false end
  local skill = card.getSkill and card:getSkill(player) or card.skill
  local min = skill:getMinTargetNum(player)
  local function complete(selected)
    if #selected >= min then return skill:feasible(player, selected, {card.id}, card) end
    for _, target in ipairs(Fk:currentRoom().alive_players) do
      if not table.contains(selected, target) and
        skill:targetFilter(player, target, selected, {}, card, {}) then
        local nextTargets = table.simpleClone(selected)
        table.insert(nextTargets, target)
        if complete(nextTargets) then return true end
      end
    end
    return false
  end
  return complete({})
end

function H.allDeclarations(player)
  if player:getMark(H.awake_mark) > 0 then return H.types end
  local choices = {}
  for _, name in ipairs(Fk:getAllCardNames("btde")) do
    table.insertIfNeed(choices, H.declarationName(Fk:cloneCard(name)))
  end
  return choices
end

function H.declarations(player, pattern)
  local choices = {}
  for _, name in ipairs(H.allowedNames(pattern)) do
    if pattern or H.canDeclareAtPlay(player, name) then
      local card = Fk:cloneCard(name)
      table.insertIfNeed(choices, player:getMark(H.awake_mark) > 0 and H.typeName(card) or H.declarationName(card))
    end
  end
  return choices
end

-- A public-request placeholder must never expose the selected hidden card's face.
function H.responsePlaceholder(pattern, id)
  local exp = Exppattern:Parse(pattern)
  for _, name in ipairs(H.allowedNames(pattern)) do
    local card = Fk:cloneCard(name)
    card.skillName = "diyzjl_gouyun"
    card:addSubcard(id)
    card.suit, card.number = Card.NoSuit, 0
    card.color = Card.NoColor
    if exp:match(card) then return card end
    for _, suit in ipairs({Card.Spade, Card.Club, Card.Heart, Card.Diamond}) do
      for number = 1, 13 do
        card.suit, card.number = suit, number
        card.color = (suit == Card.Heart or suit == Card.Diamond) and Card.Red or Card.Black
        if exp:match(card) then return card end
      end
    end
  end
end

function H.fail(player, id, declaration)
  player.room:sendLog{
    type = "#diyzjl_wrong", from = player.id, arg = declaration, arg2 = Fk:getCardById(id).name,
  }
  player.room:throwCard({id}, "diyzjl_tangshi", player, player)
end

function H.boardCards(player, target)
  return table.filter(target:getCardIds("ej"), function(id) return not player:prohibitDiscard(id) end)
end

function H.discardBoard(player)
  local room = player.room
  local targets = table.filter(room.alive_players, function(p) return #H.boardCards(player, p) > 0 end)
  if #targets == 0 then return false end
  local selected = room:askToChoosePlayers(player, {
    targets = targets, min_num = 1, max_num = 1, cancelable = false,
    skill_name = "diyzjl_gouyun", prompt = "#diyzjl_discard",
  })
  local target = selected[1]
  if not target then return false end
  local ids = H.boardCards(player, target)
  local id = room:askToChooseCard(player, {
    target = target, flag = {card_data = {{"$Board", ids}}}, skill_name = "diyzjl_gouyun",
  })
  if not table.contains(ids, id) then return false end
  room:throwCard({id}, "diyzjl_gouyun", target, player)
  return true
end

return H
