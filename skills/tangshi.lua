local H = require "packages.diy_zhangjiale.helpers"
local skill = fk.CreateSkill{name = "diyzjl_tangshi", tags = {Skill.Compulsory}}

skill:addEffect("visibility", {
  card_visible = function(self, viewer, card)
    if H.isHidden(viewer, card.id) then return false end
    if table.contains(viewer:getCardIds("h"), card.id) and
      card:getMark(H.open_mark) == viewer.id then return true end
  end,
})
skill:addEffect("maxcards", {
  exclude_from = function(self, player, card) return H.isHidden(player, card.id) end,
})
local function prohibit(player, card)
  return player:hasSkill(skill.name) and
    not table.contains(card.skillNames, "diyzjl_gouyun") and
    not table.contains(card.skillNames, "diyzjl_nitian") and
    table.find(Card:getIdList(card), function(id) return H.isHidden(player, id) end) ~= nil
end
skill:addEffect("prohibit", {prohibit_use = function(self, p, c) return prohibit(p, c) end,
  prohibit_response = function(self, p, c) return prohibit(p, c) end})

skill:addEffect(fk.BeforeCardsMove, {
  can_refresh = function(self, event, target, player, data) return player:hasSkill(skill.name) end,
  on_refresh = function(self, event, target, player, data)
    data.diyzjl_before = data.diyzjl_before or {}
    data.diyzjl_before[player.id] = #H.hiddenCards(player)
    for _, move in ipairs(data) do
      for _, info in ipairs(move.moveInfo) do
        if move.from == player or move.to == player then
          local stayed = move.from == player and move.to == player and
            info.fromArea == Card.PlayerHand and move.toArea == Card.PlayerHand
          if not stayed then player.room:setCardMark(Fk:getCardById(info.cardId, true), H.open_mark, 0) end
        end
      end
    end
  end,
})
skill:addEffect(fk.AfterCardsMove, {
  can_refresh = function(self, event, target, player, data)
    return player:hasSkill(skill.name) and table.find(data, function(move)
      return move.to == player and move.toArea == Card.PlayerHand
    end) ~= nil
  end,
  on_refresh = function(self, event, target, player, data)
    for _, move in ipairs(data) do
      if move.to == player then
        for _, info in ipairs(move.moveInfo) do
          local card = Fk:getCardById(info.cardId, true)
          player.room:setCardMark(card, H.open_mark, card:getMark(H.open_mark))
        end
      end
    end
  end,
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(skill.name) and not player.dead and data.diyzjl_before and
      (data.diyzjl_before[player.id] or 0) > 0 and #H.hiddenCards(player) == 0
  end,
  on_use = function(self, event, target, player, data) H.refill(player) end,
})
return skill
