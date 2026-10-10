local extension = Package:new("diy_zhangjiale")
extension.extensionName = "diy_zhangjiale"
extension:loadSkillSkelsByPath("./packages/diy_zhangjiale/skills")

local general = General:new(extension, "diyzjl__zhangjiale", "god", 4)
general:addSkills{
  "diyzjl_nitian", "diyzjl_tangshi", "diyzjl_gouyun", "diyzjl_yingli",
}

Fk:loadTranslationTable((require "packages.diy_zhangjiale.translations"))

return { extension }
