local skill = fk.CreateSkill{name = "diystd_chishi"}
skill:addEffect(fk.AfterCardsMove, {
  anim_type = "support",
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(skill.name) and not player.dead and not player:isKongcheng() and
      table.find(data, function(move)
        return move.to == player and move.toArea == Card.PlayerHand and #move.moveInfo > 0
      end) ~= nil
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {skill_name = skill.name, prompt = "#diystd_chishi"})
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local hand = player:getCardIds("h")
    if #hand == 0 then return end
    player:showCards(hand)
    if player.dead then return end
    local color = Fk:getCardById(hand[1]).color
    if not table.every(hand, function(id) return Fk:getCardById(id).color == color end) then return end
    local pile = player:getPile("diystd_zhu")
    local target, cost
    if color == Card.Black then
      local targets = table.filter(room.alive_players, function(p)
        local distance = p:distanceTo(player)
        return not p:isAllNude() and distance >= 0 and distance <= #pile
      end)
      if #targets == 0 then return end
      local chosen = room:askToChoosePlayers(player, {targets = targets, min_num = 1, max_num = 1,
        cancelable = true, skill_name = skill.name, prompt = "#diystd_chishi_black"})
      target = chosen[1]
      if not target or target.dead or target:isAllNude() then return end
      cost = target:distanceTo(player)
      if cost < 0 or cost > #pile then return end
    elseif color == Card.Red then
      local peach = Fk:cloneCard("peach")
      if not player:isWounded() or not player:canUseTo(peach, player) then return end
      cost = player:getLostHp()
      if cost > #pile then return end
    else
      return
    end
    local cards = cost == 0 and {} or room:askToCards(player, {min_num = cost, max_num = cost,
      expand_pile = "diystd_zhu", pattern = tostring(Exppattern{id = pile}), cancelable = true,
      skill_name = skill.name, prompt = "#diystd_chishi_pay:::" .. cost})
    if #cards ~= cost or not table.every(cards, function(id)
      return table.contains(player:getPile("diystd_zhu"), id)
    end) then return end
    if #cards > 0 then
      room:moveCardTo(cards, Card.DiscardPile, nil, fk.ReasonPutIntoDiscardPile, skill.name, nil, true, player)
    end
    if player.dead then return end
    if color == Card.Black then
      if target.dead or target:isAllNude() then return end
      local id = room:askToChooseCard(player, {target = target, flag = "hej", skill_name = skill.name})
      if table.contains(target:getCardIds("hej"), id) then room:throwCard({id}, skill.name, target, player) end
    else
      local peach = Fk:cloneCard("peach")
      peach.skillName = skill.name
      if player:canUseTo(peach, player) then room:useCard{from = player, tos = {player}, card = peach, extraUse = true} end
    end
  end,
})
return skill
