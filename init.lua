local extension = Package:new("diy_sunjiale")
extension.extensionName = "diy_sunjiale"
extension:loadSkillSkelsByPath("./packages/diy_sunjiale/skills")

local general = General:new(extension, "diyzjl__sunjiale", "god", 4)
general.prefix = extension.name
general:addSkills{
  "diyzjl_nitian", "diyzjl_tangshi", "diyzjl_gouyun", "diyzjl_yingli",
}

local wei = General:new(extension, "diywei__sunjiale", "wei", 4, 8)
wei.prefix = extension.name
wei:addSkills{"diywei_juanshi", "diywei_baotie"}

Fk:loadTranslationTable((require "packages.diy_sunjiale.translations"))

return { extension }
