local H = require "packages.diy_zhangjiale.helpers"
local skill = fk.CreateSkill{name = "diyzjl_yingli", tags = {Skill.Wake}}
skill:addEffect(fk.EventPhaseStart, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name) and player.phase == Player.Start and
      player:getMark(H.awake_mark) == 0
  end,
  can_wake = function(self, event, target, player, data) return player:getMark(H.count_mark) >= player.maxHp end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:setPlayerMark(player, H.awake_mark, 1)
    room:changeMaxHp(player, -1)
    if not player.dead then room:recover{who = player, num = 1, recoverBy = player, skillName = skill.name} end
    room:sendLog{type = "#diyzjl_awaken", from = player.id}
  end,
})
return skill
