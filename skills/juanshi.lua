local skill = fk.CreateSkill{name = "diywei_juanshi"}
skill:addEffect("active", {
  anim_type = "drawcard",
  prompt = "#diywei_juanshi",
  card_num = 0,
  target_num = 0,
  card_filter = Util.FalseFunc,
  can_use = function(self, player)
    return player.phase == Player.Play and player.hp > 0 and not player.dead
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    room:loseHp(player, 1, skill.name)
    if player.dead then return end
    local ids = room:getCardsFromPileByRule(".|.|heart|.|.|basic", 1, "drawPile")
    if #ids > 0 then room:obtainCard(player, ids, false, fk.ReasonPrey, player, skill.name) end
  end,
})
return skill
