-- Internal card skill for the target-free declaration step. Never used as a card.
local skill = fk.CreateSkill{name = "#diyzjl_blind_select"}
skill:addEffect("cardskill", {
  card_num = 1, target_num = 0,
  can_use = function() return true end,
  target_filter = function() return false end,
})
return skill
