local skill = fk.CreateSkill{name = "diystd_taotie", tags = {Skill.Compulsory}}
skill:addEffect(fk.BeforeCardUseEffect, {
  anim_type = "drawcard",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name) and not player.dead and
      data.card.trueName == "amazing_grace" and #data.tos > 0
  end,
  on_use = function(self, event, target, player, data)
    data.extra_data = data.extra_data or {}
    local count = player:usedSkillTimes("diystd_jienang", Player.HistoryGame)
    local base = data.card.skill
    -- 沿用原牌每次结算的开幕和收尾，避免重复结算重取上一批牌。
    data.card.skill = setmetatable({diystd_taotie_base = base, onAction = function(_, room, use, finished)
      if not finished then
        local original = use.extra_data.orig_cards
        local cards = table.simpleClone(original or room:getNCards(#use.tos))
        if count > 0 then
          local added = 0
          for _, id in ipairs(room:getNCards(#cards + count)) do
            if not table.contains(cards, id) then
              table.insert(cards, id)
              added = added + 1
              if added == count then break end
            end
          end
        end
        use.extra_data.orig_cards = cards
        base:onAction(room, use, false)
        use.extra_data.orig_cards = original
      else
        local remaining = use.extra_data.diystd_taotie_left or {}
        for _, id in ipairs(use.extra_data.AGFilled or {}) do
          if room:getCardArea(id) == Card.Processing then table.insertIfNeed(remaining, id) end
        end
        use.extra_data.diystd_taotie_left = remaining
        base:onAction(room, use, true)
      end
    end}, {__index = base})
  end,
})
skill:addEffect(fk.CardUseFinished, {
  anim_type = "drawcard",
  can_refresh = function(self, event, target, player, data)
    return target == player and data.card.skill.diystd_taotie_base ~= nil
  end,
  on_refresh = function(self, event, target, player, data)
    data.card.skill = data.card.skill.diystd_taotie_base
  end,
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name) and not player.dead and
      data.extra_data and data.extra_data.diystd_taotie_left and #data.extra_data.diystd_taotie_left > 0
  end,
  on_use = function(self, event, target, player, data)
    local ids = table.filter(data.extra_data.diystd_taotie_left, function(id)
      return player.room:getCardArea(id) == Card.DiscardPile
    end)
    data.extra_data.diystd_taotie_left = nil
    if #ids > 0 then player.room:obtainCard(player, ids, true, fk.ReasonPrey, player, skill.name) end
  end,
})
return skill
