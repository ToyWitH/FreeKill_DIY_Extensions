# 神孙佳乐 · 大胃菌王

新月杀（FreeKill）DIY武将扩展，目标版本 **v0.5.25 / Windows 64位**。

神势力，男性，4点体力。武将显示名称为“孙佳乐”，内部标识已统一为sunjiale。

## 安装

推荐从本仓库的 **Releases** 下载“神孙佳乐-测试版.zip”。关闭游戏，完整解压后，在解压目录运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\安装扩展.ps1 -GamePath "C:\你的游戏目录\FreeKill-release"
```

`GamePath` 指向含 `FreeKill.exe` 的目录。安装器会核对版本并备份兼容文件；检测到同名扩展时会停止，避免覆盖已有修改。已安装的用户请先备份原扩展再更新。

也可以将本仓库克隆到游戏的 `packages/diy_sunjiale` 目录。仅克隆扩展不会自动应用兼容补丁，仍需核对并安装 `client-patches` 中的5个文件；推荐使用发行版安装器。

本仓库与扩展安装包不包含完整游戏客户端。官方游戏：[Qsgs-Fans/FreeKill](https://github.com/Qsgs-Fans/FreeKill)。

## 技能与操作

保留四个技能：逆天、唐氏、狗运、影黎。完整描述见 [武将设计.md](武将设计.md)。

- 仅自己的手牌对自己暗置，装备区保持明置。
- 使用或响应暗置手牌时点击“狗运”，声明后选择牌背；不能合法使用的声明保留显示，但不可选。
- 普通杀、火杀、雷杀统一声明“杀”，实际牌的属性不变。
- 觉醒后声明基本牌、装备牌、一般锦囊牌或特殊锦囊牌；特殊锦囊为延时锦囊，一般锦囊为其余锦囊。
- 逆天的用牌不发动狗运、不计觉醒次数；狗运成功使用或打出牌时计数，增效不另计数。
- 暗置牌不提供重铸入口，防止暴露牌面。

## 联机

服务器与所有客户端都需要相同版本的扩展及兼容补丁。服务器须应用 `client-patches/ltk/server/room.lua` 中的暗置牌特殊用法拦截。

连接同一服务器并加入同一房间后，是否可选该武将仍取决于房间的武将设置。客户端装好扩展，不代表任意公共服务器都支持这个武将。

## 检查范围

已通过32项技能场景、Lua 5.4语法与核心注册检查，以及4项实际客户端检查。客户端检查使用真实的 `ClientPlayer`，覆盖声明筛选、暗置牌重铸拦截及展示后按钮刷新。

客户端检查文件为 `tests/client_module_path.lua`；复制到已安装游戏的 `test/lua/` 后，可使用 `FreeKill.exe --testfile test/lua/client_module_path.lua` 运行。

完整GUI对局及多人联机尚未验证。延时锦囊暂不支持狗运新增目标。

## 许可证与来源

源码按 [GPL-3.0](LICENSE) 提供。兼容补丁基于新月杀v0.5.25，来源与校验值见 [client-patches/README.txt](client-patches/README.txt) 和 `manifest.json`。

立绘根据用户提供的人脸参照重绘。
