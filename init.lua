local extension = Package:new("diy_sunjiale")
extension.extensionName = "diy_sunjiale"
extension:loadSkillSkelsByPath("./packages/diy_sunjiale/skills")

local general = General:new(extension, "diyzjl__sunjiale", "god", 4)
general:addSkills{
  "diyzjl_nitian", "diyzjl_tangshi", "diyzjl_gouyun", "diyzjl_yingli",
}

Fk:loadTranslationTable((require "packages.diy_sunjiale.translations"))

return { extension }
