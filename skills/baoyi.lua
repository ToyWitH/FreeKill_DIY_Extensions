local skill = fk.CreateSkill{name = "diystd_baoyi", tags = {Skill.Wake}}
skill:addEffect(fk.RoundEnd, {
  anim_type = "special",
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(skill.name) and not player.dead and
      player:usedSkillTimes(skill.name, Player.HistoryGame) == 0 and
      #player:getPile("diystd_zhu") >= #player.room.alive_players
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:moveCardTo(player:getPile("diystd_zhu"), Card.DiscardPile, nil,
      fk.ReasonPutIntoDiscardPile, skill.name, nil, true, player)
    if not player.dead then player:gainAnExtraTurn(false, skill.name) end
  end,
})
skill:addEffect(fk.TurnStart, {
  mute = true,
  is_delay_effect = true,
  can_refresh = function(self, event, target, player, data)
    return target == player and data.reason == skill.name
  end,
  on_refresh = function(self, event, target, player, data)
    player.room:setPlayerMark(player, "@diystd_baoyi-turn", 1)
  end,
})
skill:addEffect("prohibit", {
  is_prohibited = function(self, from, to, card)
    return from and card and from:getMark("@diystd_baoyi-turn") > 0 and from ~= to
  end,
})
return skill
