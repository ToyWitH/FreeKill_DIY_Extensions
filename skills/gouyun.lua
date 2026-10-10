local H = require "packages.diy_sunjiale.helpers"
local skill = fk.CreateSkill{name = "diyzjl_gouyun"}
skill:addEffect("viewas", {
  pattern = ".", prompt = function(self, player)
    return H.responsePattern(player) and "#diyzjl_response" or "#diyzjl_play"
  end,
  interaction = function(self, player)
    return UI.ComboBox{choices = H.declarations(player, H.responsePattern(player)), all_choices = H.allDeclarations(player)}
  end,
  card_filter = function(self, player, id, selected)
    return #selected == 0 and H.isHidden(player, id) and table.contains(player:getCardIds("h"), id)
  end,
  view_as = function(self, player, cards)
    if #cards ~= 1 or not self.interaction.data then return end
    local pattern = H.responsePattern(player)
    if not table.contains(H.declarations(player, pattern), self.interaction.data) then return end
    local card
    if pattern then
      card = H.responsePlaceholder(pattern, cards[1])
    else
      card = Fk:cloneCard("slash")
      card.skillName = skill.name
      card:addSubcard(cards[1])
      card.suit, card.number, card.color = Card.NoSuit, 0, Card.NoColor
      card.skill = Fk.skills["#diyzjl_blind_select"]
    end
    if not card then return end
    card.diyzjl_declaration, card.diyzjl_pattern = self.interaction.data, pattern
    return card
  end,
  enabled_at_play = function(self, player)
    return player:hasSkill("diyzjl_tangshi") and #H.declarations(player) > 0 and
      table.find(player:getCardIds("h"), function(id) return H.isHidden(player, id) end) ~= nil
  end,
  enabled_at_response = function(self, player)
    return #H.declarations(player, H.responsePattern(player)) > 0 and
      table.find(player:getCardIds("h"), function(id) return H.isHidden(player, id) end) ~= nil
  end,
  before_use = function(self, player, use)
    local ids = Card:getIdList(use.card)
    local id, declaration, pattern = ids[1], use.card.diyzjl_declaration, use.card.diyzjl_pattern
    if #ids ~= 1 or not table.contains(player:getCardIds("h"), id) or not H.isHidden(player, id) or
      not table.contains(H.declarations(player, pattern), declaration) then return "" end
    local room, real = player.room, Fk:getCardById(id)
    local matches = H.matches(player, declaration, real)
    local responding = player:getMark("diyzjl_response_only") > 0
    room:setPlayerMark(player, "diyzjl_response_pattern", 0)
    room:setPlayerMark(player, "diyzjl_response_only", 0)
    room:sendLog{type = "#diyzjl_declare", from = player.id, arg = declaration}
    H.reveal(player, id)
    if player.dead or not table.contains(player:getCardIds("h"), id) then return "" end
    if not matches then H.fail(player, id, declaration); return "" end
    if pattern then
      local legal = Exppattern:Parse(pattern):match(real) and
        (responding and not player:prohibitResponse(real) or not responding and not player:prohibitUse(real))
      if not legal then
        room:sendLog{type = "#diyzjl_illegal", from = player.id}
        room:throwCard({id}, skill.name, player, player)
        return ""
      end
      use.card = real
      use.extra_data = use.extra_data or {}
      use.extra_data.diyzjl_hidden = true
      room:addPlayerMark(player, H.count_mark, 1)
      return
    end
    local realUse = room:askToUseRealCard(player, {
      pattern = {id}, skill_name = skill.name, cancelable = false, skip = true,
      prompt = "#diyzjl_use_revealed", extra_data = {bypass_times = false, extraUse = false},
    })
    if realUse then
      realUse.extra_data = realUse.extra_data or {}
      realUse.extra_data.diyzjl_hidden = true
      room:addPlayerMark(player, H.count_mark, 1)
      room:useCard(realUse)
    else
      room:sendLog{type = "#diyzjl_illegal", from = player.id}
      room:throwCard({id}, skill.name, player, player)
    end
    return "" -- The placeholder itself must never enter the card-use pipeline.
  end,
})

skill:addEffect(fk.HandleAskForPlayCard, {
  can_refresh = function(self, event, target, player, data)
    return (target == player or target == nil) and player:hasSkill(skill.name) and type(data.pattern) == "string"
  end,
  on_refresh = function(self, event, target, player, data)
    player.room:setPlayerMark(player, "diyzjl_response_pattern", data.pattern)
    player.room:setPlayerMark(player, "diyzjl_response_only", data.isResponse and 1 or 0)
  end,
})
skill:addEffect(fk.StartPlayCard, {
  can_refresh = function(self, event, target, player) return target == player and player:hasSkill(skill.name) end,
  on_refresh = function(self, event, target, player)
    player.room:setPlayerMark(player, "diyzjl_response_pattern", 0)
    player.room:setPlayerMark(player, "diyzjl_response_only", 0)
  end,
})
skill:addEffect(fk.AfterCardTargetDeclared, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name) and not player.dead and
      data.extra_data and data.extra_data.diyzjl_hidden and not data.extra_data.diyzjl_nitian and
      not table.contains(data.card.skillNames, "diyzjl_nitian")
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local choices = {}
    local extra = data:getExtraTargets({bypass_distances = true})
    if data.card.type == Card.TypeBasic then
      table.insert(choices, "diyzjl_repeat")
    elseif data.card.type == Card.TypeTrick then
      if #extra > 0 then table.insert(choices, "diyzjl_add") end
      if #data.tos > 0 then table.insert(choices, "diyzjl_remove") end
    elseif data.card.type == Card.TypeEquip then
      if #room:canMoveCardInBoard() > 0 then table.insert(choices, "diyzjl_move") end
    end
    if data.card.type ~= Card.TypeEquip and
      table.find(room.alive_players, function(p) return #H.boardCards(player, p) > 0 end) then
      table.insert(choices, "diyzjl_discard")
    end
    if #choices == 0 then return false end
    table.insert(choices, "Cancel")
    local choice = room:askToChoice(player, {choices = choices, skill_name = skill.name, prompt = "#diyzjl_gouyun"})
    if choice == "Cancel" or not table.contains(choices, choice) then return false end
    event:setCostData(self, {choice = choice, extra = extra})
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local cost = event:getCostData(self)
    if cost.choice == "diyzjl_repeat" then
      data.additionalEffect = (data.additionalEffect or 0) + 1
    elseif cost.choice == "diyzjl_discard" then
      H.discardBoard(player)
    elseif cost.choice == "diyzjl_move" then
      local pair = room:askToChooseToMoveCardInBoard(player, {
        skill_name = skill.name, cancelable = false, prompt = "#diyzjl_move",
      })
      if #pair == 2 then
        room:askToMoveCardInBoard(player, {target_one = pair[1], target_two = pair[2],
          move_from = pair[1], skill_name = skill.name})
      end
    else
      local choices = cost.choice == "diyzjl_add" and cost.extra or data:getAllTargets()
      local selected = room:askToChoosePlayers(player, {
        targets = choices, min_num = 1, max_num = 1, cancelable = false,
        skill_name = skill.name, prompt = "#"..cost.choice,
      })
      if selected[1] then
        if cost.choice == "diyzjl_add" then data:addTarget(selected[1]) else data:removeTarget(selected[1]) end
      end
    end
  end,
})
return skill
