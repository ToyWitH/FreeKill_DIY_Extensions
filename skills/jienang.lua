local skill = fk.CreateSkill{name = "diystd_jienang"}
skill:addEffect("active", {
  anim_type = "drawcard",
  prompt = "#diystd_jienang",
  card_num = 0,
  target_num = 0,
  card_filter = Util.FalseFunc,
  can_use = function(self, player)
    return player.phase == Player.Play and not player.dead and not player:isKongcheng() and
      player:usedSkillTimes(skill.name, Player.HistoryPhase) == 0 and player:canUse(Fk:cloneCard("amazing_grace"))
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local cards = player:getCardIds("h")
    if #cards == 0 or player.dead then return end
    player:addToPile("diystd_zhu", cards, true, skill.name)
    if player.dead then return end
    local card = Fk:cloneCard("amazing_grace")
    card.skillName = skill.name
    room:useCard{from = player, tos = {}, card = card, extraUse = true}
  end,
})
return skill
