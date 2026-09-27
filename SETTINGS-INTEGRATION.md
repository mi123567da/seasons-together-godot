# 设置面板集成

设置面板以单独的 `CanvasLayer` 覆盖层提供，内部整屏 `Control` 初始隐藏，不依赖主场景脚本。

在主场景 `_ready()` 完成输入动作配置后实例化并加入场景树：

```gdscript
const SETTINGS_PANEL := preload("res://ui/settings_panel.tscn")
var settings_panel: Control

func _ready() -> void:
    # Keep the main scene's existing setup first, including InputMap actions.
    var settings_layer := SETTINGS_PANEL.instantiate()
    add_child(settings_layer)
    settings_panel = settings_layer.get_node("SettingsPanel")
    settings_panel.settings_closed.connect(_on_settings_closed)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F2:
        settings_panel.open_settings()
        get_viewport().set_input_as_handled()

func _on_settings_closed() -> void:
    pass # Optional: restore a paused game here.
```

`settings_closed` 是关闭信号；`open_settings()` 和 `close_settings()` 是面板入口。面板以 `PROCESS_MODE_ALWAYS` 运行，适合在暂停时打开。窗口启动加载时，`SettingsStore` 会创建并管理 `Music` 与 `SFX` 音频总线。背景音乐播放器的 `AudioStreamPlayer.bus` 设为 `Music`，攻击音效播放器的总线设为 `SFX`，各自滑杆才会分别控制对应声音。音频播放器没有这些路由时会继续走 `Master` 总线。

当前切片只有攻击、闪避、互动三个已存在的游戏动作可重绑；移动动作沿用原场景的 `ui_up/down/left/right` 输入，以免改动 Godot 内置 UI 导航按键。手柄按键沿用主场景定义，面板会显示连接状态与操作提示。当前 2D 切片没有可切换的动态画质管线，因此此面板不提供不会影响画面的“画质”档位。

检查面板可运行：

```powershell
& 'E:\Godot\Godot_v4.7.2-stable_win64.exe' --headless --path 'E:\GAME\四季同行\godot-vertical-slice' --scene 'res://tests/settings_panel_smoke.tscn' --quit-after 10
```
