-- Run with the installed FreeKill.exe --testfile <absolute path>.
Testdiyzjl_ui_path = {
  testGeneralAvatarResources = function()
    local util = require "ltk.client.util"
    for _, name in ipairs({"diyzjl__sunjiale", "diywei__sunjiale", "diystd__sunjiale"}) do
      local data = util:getGeneralData(name)
      lu.assertEquals(data.extension, "diy_sunjiale")
      lu.assertTrue(FileIO.exists("./packages/" .. data.extension .. "/image/generals/avatar/" .. name .. ".jpg"))
    end
  end,
  testStandardGeneralData = function()
    local util = require "ltk.client.util"
    local data = util:getGeneralData("diystd__sunjiale")
    lu.assertEquals(data.hp, 3)
    lu.assertEquals(data.maxHp, 4)
    lu.assertEquals(data.kingdom, "wei")
    lu.assertEquals(data.package, "diy_sunjiale")
    lu.assertEquals(data.prefix, data.package)
    lu.assertEquals(Fk:translate(data.prefix, "zh_CN"), "DIY武将")
    lu.assertEquals(Fk:translate("diystd__sunjiale", "zh_CN"), "孙佳乐")
    lu.assertEquals(Fk:translate("#diystd__sunjiale", "zh_CN"), "月华驱霾")
    lu.assertEquals(#Fk.generals.diystd__sunjiale.other_skills, 4)
    lu.assertTrue(Fk.skills.diystd_jienang:isInstanceOf(ActiveSkill))
    lu.assertTrue(table.contains(Fk.skill_skels.diystd_taotie.tags, Skill.Compulsory))
    lu.assertTrue(table.contains(Fk.skill_skels.diystd_baoyi.tags, Skill.Wake))
    for _, name in ipairs(Fk.generals.diystd__sunjiale.other_skills) do
      lu.assertNotNil(Fk.skills[name])
      lu.assertNotEquals(Fk:translate(":" .. name, "zh_CN"), ":" .. name)
    end
  end,
  testWeiGeneralAndExtraSlash = function()
    local util = require "ltk.client.util"
    local data = util:getGeneralData("diywei__sunjiale")
    lu.assertEquals(data.hp, 4)
    lu.assertEquals(data.maxHp, 8)
    lu.assertEquals(data.kingdom, "wei")
    lu.assertEquals(data.prefix, data.package)
    lu.assertEquals(Fk:translate(data.prefix, "zh_CN"), "DIY武将")
    lu.assertEquals(Fk:translate("diywei__sunjiale", "zh_CN"), "威·孙佳乐")
    lu.assertEquals(#Fk.generals.diywei__sunjiale.other_skills, 2)
    local ClientPlayer = require "ltk.client.clientplayer"
    local p = ClientPlayer:new({getId = function() return 997 end})
    p.id, p.hp, p.maxHp, p.phase = 997, 4, 8, Player.Play
    p.hasSkill = function(_, name) return name == "diywei_juanshi" or name == "diywei_baotie" end
    lu.assertNil(p.room)
    lu.assertTrue(Fk.skills.diywei_juanshi:canUse(p))
    p.phase = Player.NotActive
    lu.assertFalse(Fk.skills.diywei_juanshi:canUse(p))
    p.phase = Player.Play
    local savedRoom, savedClient = RoomInstance, ClientInstance
    RoomInstance = nil
    ClientInstance = {status_skills = {}}
    for _, effect in ipairs(Fk.skill_skels.diywei_baotie.effects) do
      if effect:isInstanceOf(TargetModSkill) then ClientInstance.status_skills[TargetModSkill] = {effect} end
    end
    local slash = Fk:cloneCard("slash")
    p:addCardUseHistory("slash", 1)
    lu.assertFalse(slash.skill:withinTimesLimit(p, Player.HistoryPhase, slash, "slash") or false)
    p:setMark("@diywei_baotie-turn", 1)
    lu.assertTrue(slash.skill:withinTimesLimit(p, Player.HistoryPhase, slash, "slash"))
    p:addCardUseHistory("slash", 1)
    lu.assertFalse(slash.skill:withinTimesLimit(p, Player.HistoryPhase, slash, "slash") or false)
    RoomInstance, ClientInstance = savedRoom, savedClient
  end,
  testWeiPilePatterns = function()
    local savedRoom = RoomInstance
    RoomInstance = {card_marks = {}, filtered_cards = {}}
    local room = {draw_pile = {}, discard_pile = {}, random = function(_, lo) return lo end}
    local names = {{"slash", Card.Heart}, {"peach", Card.Diamond}, {"ex_nihilo", Card.Heart},
      {"jink", Card.Spade}, {"crossbow", Card.Club}}
    for i, row in ipairs(names) do
      local card = Fk:cloneCard(row[1], row[2], 7)
      card.id = 15000 + i; Fk.cards[card.id] = card; table.insert(room.draw_pile, card.id)
    end
    lu.assertEquals(Room.getCardsFromPileByRule(room, ".|.|heart|.|.|basic", 1, "drawPile"), {15001})
    lu.assertEquals(Room.getCardsFromPileByRule(room, ".|.|spade,club", 4, "drawPile"), {15004, 15005})
    room.draw_pile = {}; room.discard_pile = {15001}
    lu.assertEquals(Room.getCardsFromPileByRule(room, ".|.|heart|.|.|basic", 1, "drawPile"), {})
    for i = 1, #names do Fk.cards[15000 + i] = nil end
    RoomInstance = savedRoom
  end,
  testSelfTricksAndVisibleEquipment = function()
    local H = require "packages.diy_sunjiale.helpers"
    local p = Player:new()
    p.id, p.hp, p.maxHp = 999, 4, 4
    p.hasSkill = function() return true end
    p.player_cards[Player.Hand], p.player_cards[Player.Equip] = {1}, {2}
    local savedRoom = RoomInstance
    RoomInstance = {status_skills = {}, alive_players = {p}, disabled_packs = {},
      filtered_cards = {}, card_marks = {},
      getPlayerById = function() return p end}
    p.room = RoomInstance
    local names = H.selfTrickNames(p, 1)
    for _, name in ipairs({"duel", "snatch", "dismantlement", "collateral", "nullification", "savage_assault", "archery_attack"}) do
      lu.assertFalse(table.contains(names, name), name)
    end
    lu.assertTrue(table.contains(names, "ex_nihilo"))
    lu.assertTrue(table.contains(names, "lightning"))
    lu.assertTrue(H.isHidden(p, 1))
    lu.assertFalse(H.isHidden(p, 2))
    RoomInstance = savedRoom
  end,
  testInstalledGeneralData = function()
    local util = require (UsingNewCore and "packages.freekill-core.ltk.client.util" or "ltk.client.util")
    local data = util:getGeneralData("diyzjl__sunjiale")
    lu.assertEquals(data.package, "diy_sunjiale")
    lu.assertEquals(data.kingdom, "god")
    lu.assertEquals(data.prefix, data.package)
    lu.assertEquals(Fk:translate(data.prefix, "zh_CN"), "DIY武将")
    lu.assertEquals(data.hp, 4)
    lu.assertEquals(Fk:translate("diyzjl__sunjiale", "zh_CN"), "神·孙佳乐")
    lu.assertEquals(Fk:translate("#diyzjl__sunjiale", "zh_CN"), "大胃菌王")
    lu.assertEquals(#Fk.generals.diyzjl__sunjiale.other_skills, 4)
    lu.assertEquals(Fk:translate("diyzjl_trick", "zh_CN"), "普通锦囊牌")
    lu.assertEquals(Fk:translate("diyzjl_delayed_trick", "zh_CN"), "特殊（延时）锦囊牌")
    lu.assertTrue(Fk.skills.diyzjl_gouyun:isInstanceOf(ViewAsSkill))
    lu.assertFalse(Fk.skills.diyzjl_tangshi:isInstanceOf(ViewAsSkill))
    lu.assertNotNil(Fk.skills.diyzjl_nitian)
    lu.assertNotNil(Fk.skills.diyzjl_tangshi)
    lu.assertNotNil(Fk.skills.diyzjl_gouyun)
    lu.assertNotNil(Fk.skills.diyzjl_yingli)
  end,
  testRequestFilteredDeclarations = function()
    local H = require "packages.diy_sunjiale.helpers"
    local skill = Fk.skills.diyzjl_gouyun
    local ClientPlayer = require "ltk.client.clientplayer"
    local p = ClientPlayer:new({getId = function() return 999 end})
    local other = ClientPlayer:new({getId = function() return 998 end})
    p.id, p.hp, p.maxHp, p.phase = 999, 4, 4, Player.Play
    other.id, other.hp, other.maxHp = 998, 4, 4
    p.next, other.next = other, p
    p.hasSkill = function(_, name) return name == "diyzjl_tangshi" or name == "diyzjl_gouyun" end
    p.player_cards[Player.Hand] = {1, 2}
    local savedRoom, savedClient = RoomInstance, ClientInstance
    RoomInstance = nil
    ClientInstance = {status_skills = {}, players = {p, other}, alive_players = {p, other},
      disabled_packs = {}, filtered_cards = {}, card_marks = {},
      getPlayerById = function(_, id) return id == p.id and p or other end}
    lu.assertNil(p.room)
    lu.assertTrue(table.contains(H.allowedNames("slash"), "fire__slash"))
    lu.assertTrue(table.contains(H.allowedNames("slash"), "thunder__slash"))
    lu.assertEquals(H.allowedNames("slash|.|.|.|fire__slash"), {"fire__slash"})
    Fk.currentResponsePattern = "jink"
    lu.assertEquals(skill:interaction(p).choices, {"jink"})
    skill.interaction.data = "slash"
    lu.assertNil(skill:viewAs(p, {1}))
    skill.interaction.data = "jink"
    lu.assertEquals(skill:viewAs(p, {1}).name, "jink")
    lu.assertEquals(skill:viewAs(p, {2}).name, "jink")
    p:setMark(H.awake_mark, 1)
    lu.assertEquals(skill:interaction(p).choices, {"diyzjl_basic"})
    lu.assertEquals(#skill:interaction(p).all_choices, 4)
    Fk.currentResponsePattern = nil
    p:setMark(H.awake_mark, 0)
    local ReqPlayCard = require "ltk.core.request_type.play_card"
    local handler = {player = p}
    lu.assertTrue(ReqPlayCard.skillButtonValidity(handler, skill.name))
    ClientInstance.card_marks[1] = {[H.open_mark] = p.id}
    lu.assertTrue(ReqPlayCard.skillButtonValidity(handler, skill.name))
    ClientInstance.card_marks[2] = {[H.open_mark] = p.id}
    lu.assertFalse(ReqPlayCard.skillButtonValidity(handler, skill.name))
    ClientInstance.card_marks = {}
    skill.interaction.data = "slash"
    local card = skill:viewAs(p, {1})
    lu.assertNotNil(card)
    lu.assertEquals(card.skill, Fk.skills["#diyzjl_blind_select"])
    lu.assertTrue(card.skill:feasible(p, {}, {card.id}, card))
    local menu = skill:interaction(p)
    lu.assertTrue(table.contains(menu.all_choices, "jink"))
    lu.assertFalse(table.contains(menu.choices, "jink"))
    lu.assertFalse(table.contains(menu.all_choices, "fire__slash"))
    p:addCardUseHistory("slash", 1)
    menu = skill:interaction(p)
    lu.assertTrue(table.contains(menu.all_choices, "slash"))
    lu.assertFalse(table.contains(menu.choices, "slash"))
    RoomInstance, ClientInstance = savedRoom, savedClient
  end,
  testHiddenRecastIsBlocked = function()
    local ReqPlayCard = require "ltk.core.request_type.play_card"
    local hidden = Fk:cloneCard("iron_chain")
    hidden.id = 12000
    Fk.cards[hidden.id] = hidden
    local savedRoom = RoomInstance
    RoomInstance = {filtered_cards = {}, card_marks = {}, status_skills = {}}
    local fake = {canUse = function() return false end, cardVisible = function() return false end,
      getCardIds = function() return {hidden.id} end}
    local handler = {player = fake, scene = {
      update = function(_, kind, id, data)
        if kind == "SpecialSkills" then handler_last_specials = data.skills end
      end,
      unselectOtherCards = function() end,
    }}
    lu.assertFalse(ReqPlayCard.cardValidity(handler, hidden))
    ReqPlayCard.selectCard(handler, hidden.id, {selected = true})
    lu.assertEquals(handler_last_specials, {})
    local recast = hidden.special_skills[1]
    lu.assertEquals(Room.handleUseCardReply({}, fake, {card = hidden.id, special_skill = recast}), "")
    local special = Fk.skills[recast]
    local savedCanUse = special.canUse
    special.canUse = function() return true end
    fake.cardVisible = function() return true end
    lu.assertTrue(ReqPlayCard.cardValidity(handler, hidden))
    special.canUse = savedCanUse
    Fk.cards[hidden.id] = nil
    RoomInstance = savedRoom
  end,
}
return {name = "diyzjl_ui_path"}
