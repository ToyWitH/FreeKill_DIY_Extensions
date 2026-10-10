local H = require "packages.diy_zhangjiale.helpers"
local skill = fk.CreateSkill{name = "diyzjl_nitian", tags = {Skill.Compulsory}}
skill:addEffect(fk.BeforeTurnStart, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name) and #player:getCardIds("he") > 0 and
      #H.selfTrickNames(player) > 0
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local names = H.selfTrickNames(player)
    if #names == 0 then return end
    local ids = room:askToCards(player, {
      min_num = 1, max_num = 1, include_equip = true, cancelable = false,
      skill_name = skill.name, prompt = "#diyzjl_nitian_card",
    })
    local id = ids[1]
    if not id or not table.contains(player:getCardIds("he"), id) then return end
    names = H.selfTrickNames(player, id)
    if #names == 0 then return end
    local name = room:askToChoice(player, {choices = names, skill_name = skill.name, prompt = "#diyzjl_nitian_name"})
    if not table.contains(H.selfTrickNames(player, id), name) then return end
    local card = Fk:cloneCard(name)
    card.skillName = skill.name
    card:addSubcard(id)
    room:useCard{from = player, tos = {player}, card = card, extraUse = true,
      extra_data = {diyzjl_nitian = true}}
  end,
})
skill:addEffect(fk.FinishJudge, {
  priority = 10,
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(skill.name) and not player.dead and data.card and #H.hiddenCards(player) > 0
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local ids = room:askToCards(player, {
      min_num = 1, max_num = 1, include_equip = true, cancelable = false,
      pattern = tostring(Exppattern{id = H.hiddenCards(player)}),
      skill_name = skill.name, prompt = "#diyzjl_judge",
    })
    local id = ids[1]
    if not id or not H.isHidden(player, id) then return end
    local same = Fk:getCardById(id).color == data.card.color
    H.reveal(player, id)
    if same then
      room:sendLog{type = "#diyzjl_cancel_judge", from = player.id, to = {target.id}}
      return true
    elseif not player.dead and room:getCardArea(data.card) == Card.Processing then
      room:obtainCard(player, data.card, true, fk.ReasonJustMove, player, skill.name)
    end
  end,
})
return skill
