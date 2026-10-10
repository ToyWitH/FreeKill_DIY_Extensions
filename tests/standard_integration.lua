-- Run with FreeKill 0.5.25: --testfile test/lua/standard_integration.lua
__package.path = __package.path .. ';./test/lua/lib/?.lua'
require 'fake_backend'
fk.qInfo = Util.DummyFunc
local function setup()
  FkTest.initRoom()
  local room, me = FkTest.room, FkTest.room.players[1]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, 'diystd_jienang|diystd_chishi|diystd_taotie|diystd_baoyi')
    room:setPlayerProperty(me, 'maxHp', 4)
    room:setPlayerProperty(me, 'hp', 3)
    me.phase = Player.Play
    room.askToSkillInvoke = function() return false end
  end)
end
local function take(room, n, color)
  local ids = {}
  for _, id in ipairs(room.draw_pile) do
    if not color or Fk:getCardById(id).color == color then
      table.insert(ids, id)
      if #ids == n then break end
    end
  end
  lu.assertEquals(#ids, n)
  return ids
end
local function pile(room, me, n)
  local ids = take(room, n)
  me:addToPile('diystd_zhu', ids, true, 'diystd_jienang')
  return ids
end
local function invokeOnce(room)
  local used = false
  room.askToSkillInvoke = function(_, _, params)
    if params.skill_name ~= 'diystd_chishi' or used then return false end
    used = true
    return true
  end
end
local function jienang(room, me)
  local skill = Fk.skills.diystd_jienang
  room:useSkill(me, skill, function() skill:onUse(room, {from = me, cards = {}, tos = {}}) end)
end
Teststd_engine_integration = {
  setUp = setup,
  tearDown = FkTest.clearRoom,
  testAllHandCostAndCurrentActivationCounts = function()
    local room, me = FkTest.room, FkTest.room.players[1]
    FkTest.runInRoom(function()
      lu.assertFalse(Fk.skills.diystd_jienang:canUse(me))
      local hand = take(room, 3)
      room:obtainCard(me, hand, true, fk.ReasonPrey)
      lu.assertTrue(Fk.skills.diystd_jienang:canUse(me))
      jienang(room, me)
      lu.assertEquals(me:getPile('diystd_zhu'), hand)
      lu.assertEquals(#me:getCardIds('h'), 2)
      for i = 2, #room.players do lu.assertEquals(#room.players[i]:getCardIds('h'), 1) end
      lu.assertEquals(me:usedSkillTimes('diystd_jienang', Player.HistoryGame), 1)
      lu.assertFalse(Fk.skills.diystd_jienang:canUse(me))
      room:clearHistory(Player.HistoryPhase)
      lu.assertTrue(Fk.skills.diystd_jienang:canUse(me))
      me.phase = Player.NotActive
      lu.assertFalse(Fk.skills.diystd_jienang:canUse(me))
    end)
  end,
  testRepeatedGraceAndPhysicalCardSkillRestoration = function()
    local room, me = FkTest.room, FkTest.room.players[1]
    FkTest.runInRoom(function()
      me:addSkillUseHistory('diystd_jienang', 1)
      local id = table.find(room.draw_pile, function(cid) return Fk:getCardById(cid).name == 'amazing_grace' end)
      lu.assertNotNil(id)
      room:obtainCard(me, id, true, fk.ReasonPrey)
      local card = Fk:getCardById(id)
      local original = card.skill
      room:useCard{from = me, tos = {}, card = card, additionalEffect = 1}
      lu.assertEquals(#me:getCardIds('h'), 4)
      for i = 2, #room.players do lu.assertEquals(#room.players[i]:getCardIds('h'), 2) end
      lu.assertEquals(card.skill, original)
      lu.assertNil(card.skill.diystd_taotie_base)
      lu.assertEquals(room:getCardArea(id), Card.DiscardPile)
      local seen = {}
      for _, p in ipairs(room.players) do
        for _, cid in ipairs(p:getCardIds('h')) do lu.assertNil(seen[cid]); seen[cid] = true end
      end
    end)
  end,
  testPickedThenDiscardedCardIsNotLeftover = function()
    local room, me = FkTest.room, FkTest.room.players[1]
    FkTest.runInRoom(function()
      me:addSkillUseHistory('diystd_jienang', 1)
      local black = take(room, #room.players + 1, Card.Black)
      local rest = table.filter(room.draw_pile, function(id) return not table.contains(black, id) end)
      room.draw_pile = table.connect(black, rest)
      local picked
      room.askToAG = function(_, who, params)
        if who == me and not picked then picked = params.id_list[1] end
        return params.id_list[1]
      end
      invokeOnce(room)
      room.askToChoosePlayers = function() return {me} end
      room.askToChooseCard = function() return picked end
      room:useCard{from = me, tos = {}, card = Fk:cloneCard('amazing_grace')}
      lu.assertNotNil(picked)
      lu.assertEquals(room:getCardArea(picked), Card.DiscardPile)
      lu.assertEquals(#me:getCardIds('h'), 1)
      lu.assertFalse(table.contains(me:getCardIds('h'), picked))
    end)
  end,
  testBlackPaysDistanceFromTarget = function()
    local room, me, other = FkTest.room, FkTest.room.players[1], FkTest.room.players[2]
    FkTest.runInRoom(function()
      local zhu = pile(room, me, 3)
      local enemyCard = take(room, 1)[1]
      room:obtainCard(other, enemyCard, true, fk.ReasonPrey)
      other.distanceTo = function() return 2 end
      me.distanceTo = function() return 7 end
      invokeOnce(room)
      room.askToChoosePlayers = function() return {other} end
      room.askToCards = function(_, _, params)
        lu.assertEquals(params.min_num, 2)
        return {zhu[1], zhu[2]}
      end
      room.askToChooseCard = function() return enemyCard end
      room:obtainCard(me, take(room, 1, Card.Black), true, fk.ReasonPrey)
      lu.assertEquals(me:getPile('diystd_zhu'), {zhu[3]})
      lu.assertEquals(room:getCardArea(enemyCard), Card.DiscardPile)
      lu.assertEquals(#me:getCardIds('h'), 1)
    end)
  end,
  testBlackMayChooseSelfAtZeroDistance = function()
    local room, me = FkTest.room, FkTest.room.players[1]
    FkTest.runInRoom(function()
      local card = take(room, 1, Card.Black)[1]
      invokeOnce(room)
      room.askToChoosePlayers = function() return {me} end
      room.askToCards = function() error('Zero distance must not request pile cards') end
      room.askToChooseCard = function() return card end
      room:obtainCard(me, card, true, fk.ReasonPrey)
      lu.assertEquals(#me:getPile('diystd_zhu'), 0)
      lu.assertEquals(#me:getCardIds('h'), 0)
      lu.assertEquals(room:getCardArea(card), Card.DiscardPile)
    end)
  end,
  testRedPaysLostHpAndUsesOnePeach = function()
    local room, me = FkTest.room, FkTest.room.players[1]
    FkTest.runInRoom(function()
      local zhu = pile(room, me, 2)
      room:setPlayerProperty(me, 'hp', 2)
      invokeOnce(room)
      room.askToCards = function(_, _, params)
        lu.assertEquals(params.min_num, 2)
        return zhu
      end
      room:obtainCard(me, take(room, 1, Card.Red), true, fk.ReasonPrey)
      lu.assertEquals(me.hp, 3)
      lu.assertEquals(#me:getPile('diystd_zhu'), 0)
      lu.assertEquals(#me:getCardIds('h'), 1)
    end)
  end,
  testMixedHandAndInsufficientPileHaveNoReward = function()
    local room, me = FkTest.room, FkTest.room.players[1]
    FkTest.runInRoom(function()
      room.askToCards = function() error('No payable monochrome effect') end
      invokeOnce(room)
      room:obtainCard(me, {take(room, 1, Card.Red)[1], take(room, 1, Card.Black)[1]}, true, fk.ReasonPrey)
      lu.assertEquals(me.hp, 3)
      lu.assertEquals(#me:getCardIds('h'), 2)
      room:throwCard(me:getCardIds('h'), 'test', me)
      invokeOnce(room)
      room:obtainCard(me, take(room, 1, Card.Red), true, fk.ReasonPrey)
      lu.assertEquals(me.hp, 3)
      lu.assertEquals(#me:getCardIds('h'), 1)
    end)
  end,
  testCancelPilePaymentKeepsCardsAndHp = function()
    local room, me = FkTest.room, FkTest.room.players[1]
    FkTest.runInRoom(function()
      local zhu = pile(room, me, 2)
      room:setPlayerProperty(me, 'hp', 2)
      invokeOnce(room)
      room.askToCards = function() return {} end
      room:obtainCard(me, take(room, 1, Card.Red), true, fk.ReasonPrey)
      lu.assertEquals(me.hp, 2)
      lu.assertEquals(me:getPile('diystd_zhu'), zhu)
    end)
  end,
  testRoundEndAwakensOnceAndRestrictsOnlyExtraTurn = function()
    local room, me = FkTest.room, FkTest.room.players[1]
    FkTest.runInRoom(function()
      local sawExtra = false
      local trigger = room.logic.trigger
      room.logic.trigger = function(logic, name, target, data, ...)
        if name == fk.BeforePlayCard and target == me and me:getMark('@diystd_baoyi-turn') > 0 then
          sawExtra = true
          lu.assertTrue(me:isProhibited(room.players[2], Fk:cloneCard('slash')))
          lu.assertFalse(me:isProhibited(me, Fk:cloneCard('peach')))
          local card = Fk:cloneCard('amazing_grace')
          lu.assertEquals(table.map(card:getAvailableTargets(me), function(p) return p.id end), {me.id})
          room:useCard{from = me, tos = {}, card = card}
          for i = 2, #room.players do lu.assertEquals(#room.players[i]:getCardIds('h'), 0) end
          data.phase_end = true
        end
        return trigger(logic, name, target, data, ...)
      end
      pile(room, me, #room.alive_players - 1)
      room.logic:trigger(fk.RoundEnd, nil, {})
      lu.assertEquals(me:usedSkillTimes('diystd_baoyi', Player.HistoryGame), 0)
      pile(room, me, 1)
      FkTest.setNextReplies(me, {''})
      room.logic:trigger(fk.RoundEnd, nil, {})
      lu.assertTrue(sawExtra)
      lu.assertEquals(#me:getPile('diystd_zhu'), 0)
      lu.assertEquals(me:usedSkillTimes('diystd_baoyi', Player.HistoryGame), 1)
      lu.assertEquals(me:getMark('@diystd_baoyi-turn'), 0)
      lu.assertFalse(me:isProhibited(room.players[2], Fk:cloneCard('slash')))
      lu.assertEquals(me.maxHp, 4)
      lu.assertEquals(me.hp, 3)
      pile(room, me, #room.alive_players)
      room.logic:trigger(fk.RoundEnd, nil, {})
      lu.assertEquals(#me:getPile('diystd_zhu'), #room.alive_players)
      lu.assertEquals(me:usedSkillTimes('diystd_baoyi', Player.HistoryGame), 1)
    end)
  end,
}
return {name = 'std_engine_integration'}

