# 单人永久档案 API

`scripts/profile_progression.gd` 是独立的 `RefCounted` 服务，不依赖主场景或网络。默认保存到 `user://profile.json`。实例化时加载档案；不存在时内存中建立默认档，损坏或未知版本会返回失败并禁止保存，避免默认档覆盖用户文件。写入先写同目录临时文件，再用 Godot `DirAccess.rename_absolute()` 替换目标。

```gdscript
const ProfileProgression = preload("res://scripts/profile_progression.gd")
var profile := ProfileProgression.new() # 或 ProfileProgression.new("user://slot-1.json")

var growth: Dictionary = profile.get_character_growth("shade")
var upgrade: Dictionary = profile.upgrade_star("shade")
var gear: Dictionary = profile.buy_permanent_gear("weapon", "spring")
var training: Dictionary = profile.upgrade_recovery_training()

# 在整段四房间流程结束时调用一次。run_id 必须在该次流程内保持稳定。
var settlement := profile.settle_room_run(ProfileProgression.new_run_id(), {
    "victory": true,
    "kills": 36,
    "boss_kills": 4,
    "earned_gold": 125.0, # 本次流程已拾取、扣除局内消费后的金币
})
```

变更类方法返回字典；成功含 `ok: true` 和更新后的 `profile`，失败含 `ok: false`、稳定 `code` 与中文 `error`。星级升级、购买永久装备、切换已解锁装备季节、恢复训练及结算都会先写盘，写盘失败时内存档案也不变。重复提交已结算的 `run_id` 返回 `duplicate: true`，不会再次发放奖励。结算 ID 保存在档案中，不能在一轮之后复用。

## 当前成长规则

- 角色 ID 为 `shade`、`bloom`、`gale`、`blade`。每名角色星级 0–5；逐星铭文价格为 30、65、110、170、250。
- 旧版每星提供 +20 最大生命和 +0.08 攻击强度。`get_character_growth()` 返回这些原始成长量，当前 Godot 场景可按自己的调优基数决定何时应用。
- 永久装备槽为 `head`、`chest`、`legs`、`boots`、`charm`、`weapon`，分别以旧版基础售价的 10 倍购买：500、850、700、450、650、1050 旅费。首次购买选季节，之后可免费切换到春夏秋冬任一季。
- 恢复训练花费 250、600、1000 旅费，最高 3 级；每级旧版恢复量 +0.35。服务只存档成长值，不替主场景自动套用战斗属性。
- 每次流程按旧规则获得 `floor(kills / 30) + boss_kills * 15 + (victory ? 40 : 0)` 铭文。放弃时铭文总额减半向下取整，旅费仅结算已拾取的 `earned_gold` 的 50%；正常胜利或失败则按 100% 入账。局内金币、购买所得总额不是永久旅费。

## 旧存档导入契约

目前不自动迁移旧存档。旧版服务器 `source/server.js` 的 `data/profiles.json` 顶层是令牌哈希映射：`{ "<token-hash>": { ...profile... } }`；旧桌面端 `localStorage` 只存音乐、键位等偏好，不是永久成长档案。服务端数据选择依赖旧存档令牌，直接猜测某条档案会有身份错误风险。

未来如需导入，应由用户明确选择其有权导入的单个内层档案对象，并将字段映射到新档案：

```json
{
  "coins": 123.0,
  "runes": 40,
  "stars": { "shade": 1, "bloom": 0, "gale": 0, "blade": 0 },
  "permanentGear": { "weapon": "spring" },
  "recoveryTraining": 2
}
```

新档案还需要由导入器补上 `version: 1`、`mode: "single_player"` 与空 `settledRuns`。`name`、账号等级/经验、解锁关卡、旧局内金币、宠物、装备仓库及账号令牌不属于当前垂直切片的成长字段，不应自行并入。导入前保留原始档案备份；此 API 当前没有暴露导入/覆盖入口。

## 独立验证

在项目目录运行：

```powershell
& 'E:\Godot\Godot_v4.7.2-stable_win64.exe' --headless --path . --script res://tests/profile_progression_smoke.gd
```

测试使用带随机后缀的 `user://` 临时档案名，覆盖默认档、角色成长、永久购买/升级、正常与放弃结算、重复结算、JSON 读写及损坏档保护，并在结束时删除仅由本测试创建的文件。
