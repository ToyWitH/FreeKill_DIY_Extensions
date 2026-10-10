local skill = fk.CreateSkill{name = "diywei_baotie", tags = {Skill.Combo}}
local ready = "diywei_baotie_ready-phase"
local bonus = "@diywei_baotie-turn"

skill:addEffect(fk.CardUsing, {
  can_refresh = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name) and player.phase == Player.Play
  end,
  on_refresh = function(self, event, target, player, data)
    data.extra_data = data.extra_data or {}
    data.extra_data.diywei_baotie = data.card.trueName == "slash" and player:getMark(ready) == 1
    player.room:setPlayerMark(player, ready, data.card.trueName == "peach" and 1 or 0)
  end,
})
skill:addEffect(fk.CardUseFinished, {
  anim_type = "drawcard",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name) and not player.dead and
      player.phase == Player.Play and data.extra_data and data.extra_data.diywei_baotie == true
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    local room = player.room
    data.extra_data.diywei_baotie = nil
    room:addPlayerMark(player, bonus, 1)
    if player.hp > 0 then
      local ids = room:getCardsFromPileByRule(".|.|spade,club", player.hp, "drawPile")
      if #ids > 0 then room:obtainCard(player, ids, false, fk.ReasonPrey, player, skill.name) end
    end
  end,
})
skill:addEffect("targetmod", {
  residue_func = function(self, player, card_skill, scope, card)
    if player:hasSkill(skill.name) and card_skill.trueName == "slash_skill" and scope == Player.HistoryPhase then
      return player:getMark(bonus)
    end
  end,
})
return skill
