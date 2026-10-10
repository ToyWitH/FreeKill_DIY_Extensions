游戏兼容补丁

来源：Qsgs-Fans/FreeKill v0.5.25（GPL-3.0-or-later）。
对应修改：
- EquipItem.qml：当CardModel.known为false时隐藏名称、花色、点数、图标，改为牌背。
- RoomModel.qml：SetCardMark时也刷新装备区与判定区的CardModel，让暗置/明置即时生效。
- LtkLuaUtil.qml：按UsingNewCore选择核心模块目录，兼容v0.5.25自带的ltk目录布局。
- play_card.lua：暗置牌不提供重铸等特殊用法，防止牌背泄露实体牌身份。
- room.lua：服务器同时拦截不可见实体牌的特殊用法请求。

没有新建技能界面，也不改变其他玩家的正常牌面规则。
安装脚本验证源文件哈希并保留备份。
源文件位置与原版/修改版哈希见manifest.json。
完整许可证见LICENSE。

https://github.com/Qsgs-Fans/FreeKill/tree/v0.5.25/LunarLtk
