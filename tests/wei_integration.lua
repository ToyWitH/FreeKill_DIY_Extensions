-- Run with FreeKill 0.5.25: --testfile test/lua/wei_integration.lua
__package.path = __package.path .. ';./test/lua/lib/?.lua'
require 'fake_backend'
fk.qInfo = Util.DummyFunc
local function setup()
  FkTest.initRoom()
  local room, me = FkTest.room, FkTest.room.players[1]
  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, 'diywei_juanshi|diywei_baotie')
    room:setPlayerProperty(me, 'maxHp', 8)
    room:setPlayerProperty(me, 'hp', 4)
    room:setPlayerProperty(room.players[2], 'maxHp', 20)
    room:setPlayerProperty(room.players[2], 'hp', 20)
    me.phase = Player.Play
  end)
end
local function use(room, me, name)
  room:useCard{from = me, tos = name == 'peach' and {me} or {room.players[2]}, card = Fk:cloneCard(name)}
end
local function juanshi(room, me)
  local skill = Fk.skills.diywei_juanshi
  room:useSkill(me, skill, function() skill:onUse(room, {from = me, cards = {}, tos = {}}) end)
end
Testwei_engine_integration = {
  setUp = setup,
  tearDown = FkTest.clearRoom,
  testInsufficientDrawPileDoesNotTakeDiscard = function()
    local room, me = FkTest.room, FkTest.room.players[1]
    FkTest.runInRoom(function()
      local keep, remove = nil, {}
      for _, id in ipairs(room.draw_pile) do
        if not keep and Fk:getCardById(id).color == Card.Black then keep = id
        else table.insert(remove, id) end
      end
      lu.assertNotNil(keep)
      room:moveCardTo(remove, Card.DiscardPile, nil, fk.ReasonPutIntoDiscardPile)
      juanshi(room, me)
      lu.assertEquals(me.hp, 3)
      lu.assertEquals(#me:getCardIds('h'), 0)
      use(room, me, 'peach')
      use(room, me, 'slash')
      lu.assertEquals(me:getMark('@diywei_baotie-turn'), 1)
      lu.assertEquals(me:getCardIds('h'), {keep})
    end)
  end,
  testHpCostAndHeartBasic = function()
    local room, me = FkTest.room, FkTest.room.players[1]
    FkTest.runInRoom(function() juanshi(room, me) end)
    lu.assertEquals(me.hp, 3)
    lu.assertEquals(#me:getCardIds('h'), 1)
    local card = Fk:getCardById(me:getCardIds('h')[1])
    lu.assertEquals(card.suit, Card.Heart)
    lu.assertEquals(card.type, Card.TypeBasic)
    FkTest.runInRoom(function() juanshi(room, me) end)
    lu.assertEquals(me.hp, 2)
    lu.assertEquals(#me:getCardIds('h'), 2)
  end,
  testComboRewardStacksAndTurnCleanup = function()
    local room, me = FkTest.room, FkTest.room.players[1]
    FkTest.runInRoom(function()
      juanshi(room, me)
      use(room, me, 'peach')
      use(room, me, 'fire__slash')
    end)
    lu.assertEquals(me.hp, 4)
    lu.assertEquals(me:getMark('@diywei_baotie-turn'), 1)
    lu.assertEquals(#me:getCardIds('h'), 5)
    for i = 2, 5 do lu.assertEquals(Fk:getCardById(me:getCardIds('h')[i]).color, Card.Black) end
    FkTest.runInRoom(function()
      juanshi(room, me)
      use(room, me, 'peach')
      use(room, me, 'thunder__slash')
    end)
    lu.assertEquals(me:getMark('@diywei_baotie-turn'), 2)
    lu.assertEquals(#me:getCardIds('h'), 10)
    FkTest.setNextReplies(me, {''})
    FkTest.runInRoom(function() GameEvent.Turn:create(TurnData:new(me, 'game_rule', {Player.Play})):exec() end)
    lu.assertEquals(me:getMark('@diywei_baotie-turn'), 0)
    lu.assertEquals(me:getMark('diywei_baotie_ready-phase'), 0)
  end,
  testOtherCardInterruptsAndActiveSkillDoesNot = function()
    local room, me = FkTest.room, FkTest.room.players[1]
    FkTest.runInRoom(function()
      use(room, me, 'slash')
      juanshi(room, me)
      use(room, me, 'peach')
      use(room, me, 'duel')
      use(room, me, 'slash')
    end)
    lu.assertEquals(me:getMark('@diywei_baotie-turn'), 0)
    FkTest.runInRoom(function()
      juanshi(room, me)
      use(room, me, 'peach')
      juanshi(room, me)
      use(room, me, 'slash')
    end)
    lu.assertEquals(me.hp, 3)
    lu.assertEquals(me:getMark('@diywei_baotie-turn'), 1)
    lu.assertEquals(#me:getCardIds('h'), 6)
  end,
}
return {name = 'wei_engine_integration'}


