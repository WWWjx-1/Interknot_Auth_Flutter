# 绳网认证 InterKnot_Auth v2.0

> **Flutter 跨平台校园网认证客户端**
>
> 从 Python/PyQt5 v1.68 迁移至 Flutter，支持 Windows 桌面端 + Android/iOS 移动端（功能子集）。

---

## 功能概览

| 功能 | Windows 桌面 | Android/iOS 移动 |
|------|:-----------:|:---------------:|
| jar 认证（CCTP 加密） | ✅ | ❌ |
| HTTP 认证（RSA+验证码） | ✅ | ✅ |
| 多拨登录 | ✅ | ✅ |
| 看门狗自动重连 | ✅ | ✅ |
| EasyTier 组网/隧道 | ✅ | ❌（仅状态展示） |
| Dashboard 流量图表 | ✅ | ❌ |
| 系统托盘 / 开机自启 | ✅ | ❌ |
| 验证码 OCR | tflite/Python | MLKit |
| 中/英国际化 | ✅ | ✅ |

---

## 环境要求

- **Flutter** 3.22+ / **Dart** 3.4+
- **Windows 构建**：Visual Studio 2022 + "使用 C++ 的桌面开发" 工作负载
- **Java JDK** 17（仅用于打包捆绑 JRE，非编译时依赖）
- **移动端**：Android SDK / Xcode（按需）

---

## 快速开始

### 1. 克隆 & 依赖

```bash
cd interknot_auth_flutter
flutter pub get
```

### 2. 捆绑资源（桌面端必需）

将源项目 `InterKnot_Auth-1.68` 放在父目录，然后执行：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/copy_bins.ps1
```

脚本会将 `login.jar`、`jre/`、`easytier/`、`ddddocr/common_old.onnx` 复制到 `assets/bin/`。

### 3. 运行（调试）

```bash
# Windows 桌面
flutter run -d windows

# Android
flutter run -d android

# 代码生成（修改 freezed/riverpod 注解后）
dart run build_runner build --delete-conflicting-outputs
```

### 4. 构建（发布）

```bash
# Windows 发布包（含管理员 manifest、捆绑资源）
flutter build windows --release

# Android APK
flutter build apk --release

# 可选：MSIX 安装包
flutter pub run msix:create
```

---

## 项目结构

```
lib/
├── main.dart                          # 入口：崩溃捕获 + ProviderScope + 窗口
├── app.dart                           # MaterialApp.router（主题/路由/l10n）
├── l10n/
│   ├── app_zh.arb                     # 中文本地化
│   └── app_en.arb                     # 英文本地化
├── core/                              # 跨 feature 基础设施
│   ├── crypto/                        # RSA/AES-GCM/机器指纹
│   ├── network/                       # dio + 连通性检测
│   ├── platform/                      # 平台抽象（桌面/移动）
│   ├── process/                       # jar/easytier/OCR 子进程
│   ├── state/                         # 全局状态 Provider
│   ├── storage/                       # 安全存储/配置/文件/迁移
│   └── utils/                         # 日志/IP/版本工具
├── features/                          # 业务功能模块
│   ├── auth/                          # 认证（HTTP + jar 双路径）
│   ├── watchdog/                      # 看门狗（断网重连）
│   ├── multilogin/                    # 多拨
│   ├── easytier/                      # 组网/隧道/Dashboard
│   ├── settings/                      # 设置/参数获取
│   └── updater/                       # 版本更新/远程停用
└── shared/                            # 共享 UI
    ├── router/                        # go_router 路由表
    ├── theme/                         # Material 3 主题
    └── widgets/                       # LogConsole 等共享组件
```

---

## 平台差异

### Windows 桌面端（完整功能）
- **jar 登录**：`Process.run` 启动捆绑的 `java -jar login.jar`（含 unidbg 加密）
- **EasyTier**：捆绑 `easytier-core.exe`，支持共享/隧道/路由
- **系统集成**：托盘、开机自启、文件锁防多开、管理员权限（route 操作）
- **OCR**：捆绑 ddddocr 模型，通过 tflite_flutter 加载（或 Python 子进程过渡）

### Android/iOS 移动端（功能子集）
- 仅支持 **HTTP 路径登录**（t 模式）
- 验证码 OCR：`google_mlkit_text_recognition`
- EasyTier 页面显示"仅桌面端可用"占位
- 无托盘/自启/文件锁等桌面特性

---

## 架构关键点

- **状态管理**：Riverpod 2.x（类型安全、编译期检查、无 BuildContext 依赖）
- **路由**：go_router（声明式路由表）
- **主题**：Material 3 + dynamic_color（跟随系统）
- **国际化**：flutter_localizations（中/英 ARB）
- **网络**：dio（超时/代理禁用/UA 伪装）
- **密码存储**：flutter_secure_storage（Windows DPAPI / macOS Keychain / Android Keystore）
- **配置存储**：shared_preferences

---

## 不可重写的黑盒组件

| 组件 | 原因 | 处理方式 |
|------|------|----------|
| `login.jar`（unidbg+keystone） | JNI 模拟天翼 native .so 加密 | 桌面端 Process.run + 捆绑 JRE |
| `ddddocr/common_old.onnx` | ONNX 推理 + PIL 预处理 | tflite 转换 / Python 子进程 |
| `easytier-core.exe` | Rust 二进制组网 | 桌面端 Process.run + 捆绑 |

---

## 常见问题

**Q: `flutter pub get` 报版本冲突？**
确保 Flutter SDK ≥ 3.22，Dart ≥ 3.4。`pubspec.yaml` 中依赖版本为参考下限，可按需升级。

**Q: Windows 构建报找不到 login.jar？**
执行 `scripts/copy_bins.ps1` 捆绑资源，或将 `login.jar`、`jre/` 手动放入 `assets/bin/`。

**Q: 移动端无法登录？**
移动端仅支持 HTTP 路径（t 模式）。请使用 t 开头的教师账号，或在设置中启用 t 模式。

**Q: 管理员权限被拒？**
route 操作和开机自启需要管理员权限。build 包已嵌入 `requireAdministrator` manifest。若被 UAC 拦截，可右键"以管理员身份运行"。

---

## 版本历史

| 版本 | 日期 | 说明 |
|------|------|------|
| v2.0.0 | 2026-08 | Flutter 跨平台重写，M0-M7 里程碑完成 |

---

## 许可证

内部项目，仅供校园网认证使用。
