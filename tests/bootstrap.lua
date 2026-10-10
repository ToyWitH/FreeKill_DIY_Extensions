package.path = "./?.lua;./?/init.lua;./lua/lib/?.lua;./lua/?.lua;./lua/?/init.lua"
fk = {qCritical = error, qWarning = print, qInfo = print, NormalDamage = 1,
  QmlBackend_ls = py_ls, QmlBackend_exists = py_exists, QmlBackend_pwd = py_pwd,
  GetMicroSecond = function() return 0 end}
FileIO = {ls = py_ls, exists = py_exists, pwd = py_pwd}
class = require "middleclass"
json = require "json"
Util = require "core.util"
Pcall = function(fn, ...) return fn(...) end
Config = {language = "zh_CN"}
Engine = require "core.engine"
Package = require "core.package"
General = require "core.general"
CardSkeleton = require "core.card_skeleton"
Card = require "core.card"
Exppattern = require "core.exppattern"
SkillSkeleton = require "core.skill_skeleton"
Skill = require "core.skill"
UsableSkill = require "core.skill_type.usable_skill"
StatusSkill = require "core.skill_type.status_skill"
Player = require "core.player"
GameMode = require "core.game_mode"
AbstractRoom = require "core.room.abstract_room"
RequestHandler = require "core.request_handler"
UI = require "ui-util"
dofile "lua/fk_ex.lua"
Engine.loadPackages = function() end
Engine.loadRequestHandlers = function() end
Fk = Engine:new()
Fk:loadPackage(require "packages.standard_cards")
Fk:loadPackage(require "packages.maneuvering")
local packs = require "packages.diy_sunjiale"
for _, pack in ipairs(packs) do Fk:loadPackage(pack) end
for _, name in ipairs(Fk.package_names) do
  local pack = Fk.packages[name]
  for _, skel in ipairs(pack.card_skels) do
    local card = skel:createCardPrototype()
    card.package = pack
    Fk.all_card_types[card.name] = card
    table.insert(Fk.all_card_names, card.name)
  end
end
local general = Fk.generals.diyzjl__sunjiale
assert(general and general.hp == 4 and general.maxHp == 4 and general.kingdom == "god")
assert(Fk:translate("diyzjl__sunjiale", "zh_CN") == "神·孙佳乐")
assert(Fk:translate("#diyzjl__sunjiale", "zh_CN") == "大胃菌王")
assert(#general.other_skills == 4)
for _, name in ipairs(general.other_skills) do assert(Fk.skills[name], name) end

H = require "packages.diy_sunjiale.helpers"
function spec(name, key)
  for _, row in ipairs(Fk.skill_skels[name].effect_spec_list) do
    if row[1] == key then return row[3] end
  end
  error("No effect: "..name)
end

function setup()
  local p = Player:new()
  p.id, p.hp, p.maxHp = 1, 4, 4
  p.hasSkill = function(self, name) return name:match("^diyzjl_") ~= nil or name:match("^diywei_") ~= nil end
  p.showCards = function() end
  p.drawCards = function(self, n) self.drawn = (self.drawn or 0) + n end
  local other = Player:new()
  other.id, other.hp, other.maxHp = 2, 4, 4
  other.hasSkill = function() return false end
  local room = {players = {p, other}, alive_players = {p, other}, disabled_packs = {},
    status_skills = {}, logs = {}, thrown = {}, uses = {}, card_marks = {}, filtered_cards = {}}
  RoomInstance, Self = room, p
  p.room, other.room = room, room
  p.next, other.next = other, p
  function room:getPlayerById(id)
    return table.find(self.players, function(player) return player.id == id end)
  end
  function room:getCardArea(card)
    local id = type(card) == "number" and card or card.id
    for _, player in ipairs(self.players) do
      for area, ids in pairs(player.player_cards) do if table.contains(ids, id) then return area end end
    end
    return self.processing == id and Card.Processing or Card.DiscardPile
  end
  function room:getCardOwner(id)
    for _, player in ipairs(self.players) do if table.contains(player:getCardIds("hej"), id) then return player end end
  end
  function room:setCardMark(card, name, value) card:setMark(name, value) end
  function room:setPlayerMark(player, name, value) player:setMark(name, value) end
  function room:addPlayerMark(player, name, value) self:setPlayerMark(player, name, player:getMark(name) + value) end
  function room:loseHp(player, n) player.hp = player.hp - n; self.hp_losses = (self.hp_losses or 0) + 1 end
  function room:sendLog(log) table.insert(self.logs, log) end
  function room:throwCard(ids)
    for _, id in ipairs(ids) do
      table.insert(self.thrown, id)
      for _, player in ipairs(self.players) do
        for _, list in pairs(player.player_cards) do table.removeOne(list, id) end
      end
    end
  end
  function room:useCard(use) table.insert(self.uses, use) end
  function room:askToChoice(player, params) return self.choice or params.choices[1] end
  function room:askToCards(player, params) return {self.selected or player:getCardIds("h")[1]} end
  function room:askToChoosePlayers(player, params) return {params.targets[1]} end
  function room:askToChooseCard(player, params) return params.flag.card_data[1][2][1] end
  function room:askToUseRealCard(player, params)
    self.real_request = params
    return self.real_use
  end
  function room:canMoveCardInBoard() return self.can_move and {p, other} or {} end
  function room:askToChooseToMoveCardInBoard() return {p, other} end
  function room:askToMoveCardInBoard(player, params) self.moved = params; return {card = 8, from = p, to = other} end
  function room:obtainCard(player, card) self.obtained = card; table.insert(player.player_cards[Player.Hand], card.id) end
  function room:changeMaxHp(player, n) player.maxHp = player.maxHp + n; player.hp = math.min(player.hp, player.maxHp) end
  function room:recover(data) data.who.hp = math.min(data.who.maxHp, data.who.hp + data.num) end
  return p, other, room
end

function give(player, name, id, area, suit)
  local card = Fk:cloneCard(name, suit or Card.Spade, 7)
  card.id = id
  Fk.cards[id] = card
  table.insert(player.player_cards[area or Player.Hand], id)
  return card
end

function event()
  return {setCostData = function(self, skill, data) self.cost = data end,
    getCostData = function(self) return self.cost end}
end
