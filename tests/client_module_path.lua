-- Run with the installed FreeKill.exe --testfile <absolute path>.
Testdiyzjl_ui_path = {
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
    lu.assertEquals(data.hp, 4)
    lu.assertEquals(Fk:translate("diyzjl__sunjiale", "zh_CN"), "孙佳乐")
    lu.assertEquals(Fk:translate("#diyzjl__sunjiale", "zh_CN"), "大胃菌王")
    lu.assertEquals(#Fk.generals.diyzjl__sunjiale.other_skills, 4)
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
