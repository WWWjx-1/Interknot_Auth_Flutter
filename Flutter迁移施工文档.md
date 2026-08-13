# InterKnot_Auth Flutter 迁移施工文档

> **文档定位**：面向 AI（DeepSeek V4 Pro）执行的结构化施工手册
> **源项目**：`InterKnot_Auth-1.68`（Python/PyQt5 + 内嵌 Java `login.jar`）
> **迁移目标目录**：`interknot_auth_flutter`（已存在 `flutter create` 生成的空骨架，需在其上实现业务代码）
> **参考架构文档**：`InterKnot_Auth-1.68架构解析.html`（同目录）
> **目标平台**：Windows 桌面为主战场，架构上兼容 Android/iOS（移动端功能子集）
> **版本基线**：源 v1.68，迁移目标 v2.0.0

---

## 0. 执行约定（AI 必读）

### 0.1 项目现状澄清
- `interknot_auth_flutter/` 当前为 **`flutter create` 默认模板**：`lib/main.dart` 仅为计数器示例，`pubspec.yaml` 仅含 `flutter` + `cupertino_icons` + `flutter_lints`，**无任何业务代码**。
- 全平台目录（android/ios/linux/macos/web/windows）已生成，可直接启用。
- 本文档假设执行环境已安装 Flutter 3.22+ / Dart 3.4+（pubspec 声明 `sdk: ^3.11.1`，执行时以本机实际为准，下文依赖版本为参考下限）。

### 0.2 执行原则
1. **严格按里程碑顺序执行**，每个里程碑结束后必须满足验收标准方可进入下一阶段。
2. **每个任务一个 commit**，commit message 格式：`feat(Mx): <任务描述>` / `fix(Mx): ...` / `refactor(Mx): ...`。
3. **不得跳过兼容性处理**（§4），尤其 login.jar/unidbg/ddddocr 不可在 Dart 中重写，必须走外部进程或平台通道。
4. **遵循 Flutter 陷阱清单**（来自技能库）：
   - `setState` 前检查 `mounted`；异步间隙后使用 `context` 前检查 `mounted`。
   - `FutureBuilder` 必须缓存 Future（在 `initState` 中赋值，避免父级 rebuild 重复触发）。
   - 列表项必须给 `Key`（用 ValueKey 绑定业务 id）。
   - 静态 widget 用 `const` 构造；`dispose` 中取消 Timer/StreamSubscription/AnimationController。
   - 平台通道调用必须 `try/catch PlatformException`。
5. **命名规范**：文件 `snake_case.dart`，类 `PascalCase`，私有成员 `_camelCase`，常量 `camelCase` 或 `SCREAMING_SNAKE`。
6. **每个公共类写文档注释**（`///`），便于后续维护。

### 0.3 不可重写的黑盒组件（迁移红线）
| 组件 | 原因 | 处理方式 |
|------|------|----------|
| `login.jar`（含 unidbg + keystone） | JNI 模拟天翼 native .so 加密，Dart 无法复刻 | 桌面端：Process.run 启动 `java -jar login.jar` + 捆绑 JRE；移动端：不支持此路径 |
| `ddddocr/common_old.onnx` | onnx 推理 + PIL 预处理 | 桌面端：`tflite_flutter` 或保留独立 OCR 子进程；移动端：`google_mlkit_text_recognition` 或 tflite |
| `easytier-core.exe` | Rust 二进制组网 | 桌面端：Process.run + 捆绑；移动端：不支持（仅作为隧道客户端连接桌面端） |

---

## 1. 项目初始化配置

### 1.1 环境要求
- Flutter 3.22+（`flutter --version` 确认）
- 启用桌面支持：`flutter config --enable-windows-desktop --enable-macos-desktop --enable-linux-desktop`
- Windows 构建：Visual Studio 2022 + "使用 C++ 的桌面开发" 工作负载
- Java JDK 17（仅用于打包时捆绑 jre，非运行时编译）

### 1.2 依赖引入（pubspec.yaml 完整配置）

执行第一步：用以下内容**替换** `interknot_auth_flutter/pubspec.yaml`（保留原 name/environment，重写 dependencies）：

```yaml
name: interknot_auth_flutter
description: "绳网认证 InterKnot_Auth - Flutter 跨平台校园网认证客户端"
publish_to: 'none'
version: 2.0.0+1

environment:
  sdk: ^3.11.1

dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8

  # === 状态管理 ===
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5

  # === 路由 ===
  go_router: ^14.2.0

  # === 网络 ===
  dio: ^5.7.0

  # === 加密 ===
  pointycastle: ^3.9.1          # RSA(PKCS#1 v1.5) + AES-GCM
  encrypt: ^5.0.3               # 辅助

  # === 本地存储 ===
  flutter_secure_storage: ^9.2.2  # 密码加密存储（替代 Secret.dat 方案）
  shared_preferences: ^2.3.2     # 配置项（替代 config.ini 简单键值）
  path_provider: ^2.1.4          # 目录定位

  # === 桌面/系统集成 ===
  window_manager: ^0.4.2          # 窗口控制/DPI
  tray_manager: ^0.2.3            # 系统托盘
  launch_at_startup: ^0.3.1       # 开机自启
  bitsdojo_window: ^0.1.6         # 窗口定制（可选）
  win32: ^5.5.1                   # Windows API（route/schtasks 备选）

  # === 进程调用 ===
  process_run: ^1.2.0             # 启动 java/easytier 子进程

  # === 网络/连通性 ===
  connectivity_plus: ^6.0.5       # 网卡状态（看门狗）
  url_launcher: ^6.3.0

  # === 数据/序列化 ===
  freezed_annotation: ^2.4.4
  json_annotation: ^4.9.0
  collection: ^1.18.0
  async: ^2.11.0
  intl: ^0.19.0

  # === UI ===
  fl_chart: ^0.69.0              # dashboard 图表（替代 chart.js）
  dynamic_color: ^1.7.0          # 跟随系统主题

  # === 信息/更新 ===
  package_info_plus: ^8.0.0      # 版本号
  http: ^1.2.2                   # 更新检查（轻量，也可用 dio）

  # === 平台分支：移动端 OCR ===
  google_mlkit_text_recognition: ^0.14.0  # 移动端验证码识别（备选）

  # === 桌面端 WebUI（可选保留） ===
  shelf: ^1.4.1
  shelf_router: ^1.1.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  build_runner: ^2.4.11
  riverpod_generator: ^2.4.3
  freezed: ^2.5.2
  json_serializable: ^6.8.0
  custom_lint: ^0.6.4
  riverpod_lint: ^2.3.19

flutter:
  uses-material-design: true
  assets:
    - assets/icons/
    - assets/images/
    # 桌面端捆绑资源（仅 windows 构建）：
    - assets/bin/                  # login.jar, easytier-core.exe, jre/, ddddocr 模型
  fonts:
    - family: InterKnotIcon
      fonts:
        - asset: assets/fonts/InterKnotIcon.ttf
```

> **执行命令**：
> ```bash
> cd interknot_auth_flutter
> flutter pub get
> dart run build_runner build --delete-conflicting-outputs
> ```

### 1.3 目录结构规划（feature-first）

执行：在 `lib/` 下创建如下结构（删除默认 `main.dart` 计数器代码，重写）：

```
interknot_auth_flutter/
├── lib/
│   ├── main.dart                      # 入口：ProviderScope + runApp + 窗口/托盘初始化
│   ├── app.dart                       # MaterialApp.router（主题、路由）
│   ├── core/                         # 跨 feature 基础设施
│   │   ├── crypto/
│   │   │   ├── rsa_crypto.dart        # RSA PKCS#1 v1.5 加密（对应 Login_Thread.encrypt_rsa）
│   │   │   ├── aes_gcm_crypto.dart    # AES-GCM（对应 SecurityManager，迁移过渡用）
│   │   │   └── machine_fingerprint.dart # 机器指纹（桌面：MachineGuid；移动：设备 id）
│   │   ├── network/
│   │   │   ├── dio_client.dart         # dio 单例（超时/代理禁用/UA）
│   │   │   └── connectivity_checker.dart # 6 源公网连通性检测（对应 Watch_dog）
│   │   ├── storage/
│   │   │   ├── secure_storage.dart     # flutter_secure_storage 封装（密码）
│   │   │   ├── config_store.dart      # shared_preferences 封装（配置项，对应 config.ini）
│   │   │   └── file_store.dart         # 文件存储（log/lock/signal/toml/zip）
│   │   ├── platform/
│   │   │   ├── platform_service.dart  # 平台能力抽象接口
│   │   │   ├── desktop_platform_service.dart  # Windows 实现（Process/route/schtasks/lock）
│   │   │   └── mobile_platform_service.dart   # 移动端空实现/降级
│   │   ├── process/
│   │   │   ├── jar_process.dart        # login.jar 子进程管理（对应 Jar_Thread）
│   │   │   ├── easytier_process.dart   # easytier-core 子进程（对应 Easytier）
│   │   │   └── ocr_service.dart        # 验证码 OCR（桌面 tflite/移动 MLKit）
│   │   ├── state/
│   │   │   ├── app_state.dart          # global_state 单例的 Riverpod 等价物
│   │   │   └── providers.dart          # 全局 Provider 汇总
│   │   └── utils/
│   │       ├── logger.dart             # 日志（对应 write_to_log，含分级/轮转）
│   │       ├── ip_utils.dart
│   │       └── version.dart
│   ├── features/                      # 业务功能（按原模块映射）
│   │   ├── auth/                      # 认证（Login_Thread + Jar_Thread）
│   │   │   ├── data/
│   │   │   │   ├── auth_repository.dart    # 认证数据源（HTTP + jar 双路径）
│   │   │   │   ├── auth_dto.dart           # XML/JSON 协议模型
│   │   │   │   └── esurfing_api.dart       # 天翼 Portal 接口常量
│   │   │   ├── domain/
│   │   │   │   └── auth_state.dart         # 登录态枚举/模型
│   │   │   ├── application/
│   │   │   │   ├── auth_controller.dart    # Riverpod notifier（login/logout/retry）
│   │   │   │   └── heartbeat_controller.dart # 心跳保活（对应 jar heartbeat）
│   │   │   └── presentation/
│   │   │       ├── login_page.dart
│   │   │       └── widgets/
│   │   ├── watchdog/                 # 看门狗（Watch_dog）
│   │   │   ├── application/watchdog_controller.dart
│   │   │   └── presentation/watchdog_status_widget.dart
│   │   ├── multilogin/               # 多拨（Setting.mulit_login）
│   │   │   ├── application/multilogin_controller.dart
│   │   │   └── presentation/multilogin_page.dart
│   │   ├── easytier/                 # 组网/隧道（Easytier + WebUI）
│   │   │   ├── application/easytier_controller.dart
│   │   │   ├── presentation/
│   │   │   │   ├── share_page.dart
│   │   │   │   ├── tunnel_page.dart
│   │   │   │   └── dashboard_page.dart   # 替代 WebUI 大屏（fl_chart）
│   │   │   └── data/easytier_cli.dart     # easytier-cli RPC 调用
│   │   ├── settings/                 # 设置（Setting）
│   │   │   ├── presentation/settings_page.dart
│   │   │   └── presentation/params_page.dart  # 登录参数获取
│   │   └── updater/                  # 更新检查（Update_Thread）
│   │       └── application/updater_controller.dart
│   ├── shared/                       # 共享 UI
│   │   ├── widgets/
│   │   │   ├── log_console.dart      # 日志列表（对应 listWidget）
│   │   │   ├── progress_bar.dart
│   │   │   └── version_badge.dart
│   │   ├── theme/
│   │   │   ├── app_theme.dart
│   │   │   └── app_colors.dart
│   │   └── router/
│   │       └── app_router.dart       # go_router 路由表
│   └── l10n/                         # 国际化（中/英，对应 README 双语）
│       ├── app_zh.arb
│       └── app_en.arb
├── assets/
│   ├── icons/yish.ico                 # 从源项目 res/ 复制图标
│   ├── images/                        # 从源项目 res/img 复制
│   ├── fonts/InterKnotIcon.ttf        # 图标字体（按需生成）
│   └── bin/                           # 桌面端捆绑二进制（.gitignore，构建时注入）
│       ├── login.jar
│       ├── jre/                       # 复制源项目 jre/
│       ├── easytier/                  # 复制源项目 easytier/
│       └── ocr/common_old.onnx        # 复制 ddddocr 模型
├── windows/                           # 已存在，配置托盘/自启/管理员清单
└── test/                              # 单元测试
    ├── core/crypto/rsa_test.dart
    └── features/auth/auth_repository_test.dart
```

### 1.4 关键全局配置

- `analysis_options.yaml`：启用 `riverpod_lint` 与 `custom_lint`：
  ```yaml
  include: package:flutter_lints/flutter.yaml
  analyzer:
    plugins:
      - custom_lint
    exclude: ["build/**", "**/*.g.dart", "**/*.freezed.dart"]
  ```

- 资源复制脚本（构建前执行，写到 `scripts/copy_bins.ps1`）：将源项目 `InterKnot_Auth-1.68` 的 `login.jar`、`jre/`、`easytier/`、`ddddocr/common_old.onnx` 复制到 `assets/bin/`。

---

## 2. 原项目核心模块功能分析（迁移映射）

### 2.1 模块映射总表

| 原模块（Python） | 职责 | Flutter 对应 | 迁移策略 |
|---|---|---|---|
| `main.py` MainWindow | GUI 编排、托盘、DPI、文件锁 | `main.dart` + `app.dart` + `tray_manager` | 重写为 Widget 树 |
| `State.py` global_state | 全局单例状态 | `core/state/app_state.dart` + Riverpod Provider | 单例→不可变状态 + Provider |
| `Config_Manager.py` | `[key]=value` INI | `core/storage/config_store.dart`（shared_preferences） | 格式简化为 JSON/SP |
| `SecurityManager.py` | AES-GCM 密码加密 | `core/storage/secure_storage.dart`（flutter_secure_storage） | 直接用平台安全存储替代自实现 AES |
| `DatManager` | 账号-密码表 | secure_storage（key=account） | 同上 |
| `Login_Thread.py` | HTTP 登录（RSA+验证码） | `features/auth/data/auth_repository.dart`（HTTP 路径） | dio + pointycastle RSA + OCR service |
| `Jar_Thread.py` | jar 登录子进程 | `core/process/jar_process.dart` + `auth_controller` | Process.run + stdout 解析（桌面） |
| `Watch_dog.py` | 网络监测重连 | `features/watchdog/` + `connectivity_checker` | connectivity_plus + 多源探测 + 退避 |
| `Easytier.py` | 组网/隧道 | `features/easytier/` + `easytier_process` | Process.run + toml 生成 |
| `WebUI.py` | :50000 HTTP 大屏/下载 | `features/easytier/presentation/dashboard_page.dart` | Flutter 原生 dashboard 替代（移动友好） |
| `Get_Userip_Thread.py` | 189.cn 探测取参 | `features/auth/data/auth_repository.dart` | dio GET + 正则 |
| `Update_Thread.py` | cmxz.top 版本/停用 | `features/updater/` | dio GET check.php |
| `Setting.py` | 设置/多拨/取参 | `features/settings/` | Widget |
| `WorkerSignals.py` | Qt 信号槽 | Riverpod Provider 状态变更 | 信号→状态流 |
| `Cred.c` | Credential Manager（旧） | secure_storage（新） | 弃用旧方案，迁移期兼容读取 |
| `login.jar`（Java） | CCTP 加密认证 | `jar_process.dart`（外部进程） | **不重写**，桌面端捆绑调用 |

### 2.2 身份认证流程分析

原项目**双路径**（详见架构解析 §3）：

- **路径 A：jar 登录**（学生，默认，用户名非 t 开头 & login_mode=0）
  - 流程：取参(189.cn) → `java -jar login.jar -u -p -t -a` → stdout 关键字状态机 → 心跳保活(~480s)
  - jar 内部：unidbg 模拟天翼 native .so JNI 加密，CCTP XML 协议（ticket/authUrl/keepUrl/termUrl）
  - **关键：Flutter 不可重写 unidbg，必须保留 jar 外部进程（桌面端）**

- **路径 B：HTTP 登录**（教师 t 开头 / login_mode=1）
  - 流程：取参 → GET `/qs/index_gz.jsp` 取验证码图 URL → GET 验证码图 → OCR 识别 → RSA(PKCS#1 v1.5) 加密 `{userName,password,rand}` → hex loginKey → POST `/ajax/login` → resultCode=="0"/"13002000" 成功 → signature cookie
  - 下线：POST `/ajax/logout`（Cookie: signature）
  - **此路径 Flutter 可完全原生实现**

- **登录态**：无 OAuth/JWT 令牌刷新；jar 路径=心跳保活，HTTP 路径=看门狗重连。
- **验证码错误重试**：`login_Retry_Thread` 最多 5 次，间隔 3s，遇「认证失败/频繁/密码错误」停止。

### 2.3 数据存储分析

| 文件 | 格式 | Flutter 迁移 |
|---|---|---|
| `config.ini` | `[key]=value` | shared_preferences（key-value）+ JSON 迁移工具 |
| `Secret.dat` | `[user]=AES-GCM密文` | flutter_secure_storage（平台 Keychain/DPAPI） |
| `log.txt` | 纯文本（启动清空） | 文件日志 + 轮转（不再启动清空） |
| `downloads.log` | 纯文本 | 保留文件 + DB（可选 drift） |
| `~/.InterKnot.lock` | 文件锁 | `file_store.dart` 用 `file_lock`/pid 文件 |
| `logout.signal` | 空文件信号 | 内存标志 + 文件（跨进程） |
| `easytier.toml` | TOML | 动态生成（toml 包或字符串模板） |
| `%TEMP%/InterKnot/InterKnot.zip` | zip | `file_store.dart` + `archive` 包 |

**配置项清单**（迁移自 `MainWindow.read_config` config_maps）：
`first_run, username, password(机器码校验值), wlanacip, wlanuserip, esurfingurl, save_pwd, auto_connect, wtg_timeout, mulit_login, login_mode, enable_watch_dog, auto_share, auto_update_userip, et_secret_key, et_enable_ipv6, et_enable_webdl, et_speed_limit, et_en_userconf, et_userconf_path`，以及多拨项 `line_edit_{tab}_{1|2|3}`（1=IP,2=账号,3=密码）。

### 2.4 网络请求分析

- HTTP 登录/登出：`requests`，UA 伪装 Edge，`proxies=None` 禁用代理，`verify=False`（仅校园网 Portal 场景）。
- 取参：GET http://189.cn/ 重定向，正则解析 `esurfingurl/wlanacip/wlanuserip`。
- 看门狗连通性：6 个公网点（msftconnecttest/gstatic/apple/miui/vivo generate_204）。
- 更新检查：GET `https://cmxz.top/programs/sac/check.php`，UA=`CMXZ-SAC_<version>`，对比版本号；`?enable=0` 远程停用→强制下线。
- easytier-cli RPC：`easytier-cli.exe -p 127.0.0.1:15888 -o json node|peer|route`。
- WebUI：原 `http.server` :50000，本机大屏/外网下载分流。

**Flutter 方案**：统一用 `dio`，封装超时/代理禁用/UA/异常映射。WebUI 用 Flutter 原生 dashboard 替代（更利于移动端，避免内嵌 HTTP server 的复杂度；桌面端如需对外下载页可保留 shelf 可选模块）。

### 2.5 UI 交互逻辑分析

- 主窗口：账号下拉 + 密码框 + 登录/下线按钮 + 复选框（记住密码/自动登录/看门狗/自动共享/t模式）+ 日志列表 + 进度条 + 托盘 + 菜单（设置/WebUI）。
- 设置窗口：登录参数（esurfingurl/wlanacip/wlanuserip）+ 自动获取 + 多拨 tab（IP/账号/密码）+ 隧道配置（密钥/IPv6/下载页/限速/自定义 toml）+ 清除配置 + 打开配置目录。
- EasyTier：共享/隧道双 tab + 隧道日志列表 + dashboard。
- 托盘：恢复/退出；最小化到托盘；DPI 自适应；开机自启（schtasks ONLOGON/HIGHEST）。
- 异步模式：所有耗时操作走线程 → 信号更新 UI；Flutter 改为 Riverpod 异步 Provider + `AsyncValue`。

---

## 3. 各模块 Flutter 实现方案

### 3.1 状态管理选型：Riverpod 2.x（codegen）

**选型理由**：类型安全、编译期检查、无 BuildContext 依赖（解决 Flutter 技能强调的"context after async gap"问题）、易测试。对比 Bloc：Riverpod 样板更少、AI 生成更稳；对比 Provider：Riverpod 支持 async/自动 dispose。

**核心模式**：
```dart
@riverpod
class AuthController extends _$AuthController {
  @override
  Future<AuthState> build() async => AuthState.initial();

  Future<void> login(String user, String pwd) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(authRepositoryProvider);
      final result = await repo.login(user: user, password: pwd);
      state = AsyncData(result);
    } catch (e, s) {
      state = AsyncError(e, s);
    }
  }
}
```

**全局状态**（替代 `global_state` 单例）：
```dart
@riverpod
class AppState extends _$AppState {
  @override
  AppStateData build() => AppStateData.initial();

  void setConnected(bool v) => state = state.copyWith(connected: v);
  void setSignature(String s) => state = state.copyWith(signature: s);
  // ... 对应原 state 字段
}
```

**关键陷阱规避**：
- 异步操作中不持有 `BuildContext`；用 `ref` 读写 Provider。
- `ref.listen` 替代 Qt 信号槽连接。
- `AutoDispose` 防止 Provider 泄漏；耗时 Provider 配 `keepAlive` 谨慎使用。

### 3.2 路由设计：go_router

```dart
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRouteIndex(builder: (s, child) => MainShell(child: child), routes: [
      GoRoute(path: '/', builder: (s,_) => const LoginPage()),
      GoRoute(path: '/dashboard', builder: (s,_) => const DashboardPage()),
      GoRoute(path: '/multilogin', builder: (s,_) => const MultiloginPage()),
      GoRoute(path: '/settings', builder: (s,_) => const SettingsPage()),
      GoRoute(path: '/share', builder: (s,_) => const SharePage()),
      GoRoute(path: '/tunnel', builder: (s,_) => const TunnelPage()),
    ]),
  ],
  redirect: (ctx, state) async {
    final auth = ref.read(authControllerProvider);
    // 未登录且访问受保护页 → 重定向 /
    return null;
  },
);
```

### 3.3 认证模块实现（双路径 + 平台分支）

#### 3.3.1 认证仓库接口（抽象双路径）

```dart
abstract interface class AuthRepository {
  Future<void> fetchEsurfingParams();          // Get_Userip_Thread
  Future<LoginResult> login({required String user, required String pwd}); // 分流
  Future<void> logout();
  Future<void> startHeartbeat();
}

class AuthRepositoryImpl implements AuthRepository {
  final Dio dio;
  final RsaCrypto rsa;
  final OcrService ocr;
  final JarProcess? jarProcess;   // 桌面端非 null，移动端 null
  final PlatformService platform;

  @override
  Future<LoginResult> login(...) async {
    // 1. 用户名是 IPv4 → connectEt（隧道）
    if (IpUtils.isIPv4(user)) return _connectEt(user, pwd);

    // 2. 非 t 开头且 loginMode==0 且桌面端 → jar 路径
    if (!user.startsWith('t') && loginMode == 0 && jarProcess != null) {
      return _loginJar(user, pwd);
    }
    // 3. 否则 HTTP 路径
    return _loginHttp(user, pwd);
  }
}
```

#### 3.3.2 HTTP 路径实现（可完全原生）

```dart
Future<LoginResult> _loginHttp(String user, String pwd) async {
  final code = await _fetchAndRecognizeCaptcha(); // OCR
  final payload = jsonEncode({'userName': user, 'password': pwd, 'rand': code});
  final loginKey = rsa.encryptHex(payload);       // RSA PKCS#1 v1.5 → hex
  final res = await dio.post(
    'http://$esurfingUrl/ajax/login',
    data: {'loginKey': loginKey, 'wlanuserip': wlanUserIp, 'wlanacip': wlanAcIp},
    options: Options(contentType: Headers.formUrlEncodedContentType),
  );
  final resultCode = res.data['resultCode'];
  if (resultCode == '0' || resultCode == '13002000') {
    signature = res.headers.map['set-cookie']...;  // 解析 signature
    return LoginResult.success();
  }
  if (res.data['resultInfo'] == '验证码错误') throw CaptchaError();
  throw LoginFailed(res.data['resultInfo']);
}
```

#### 3.3.3 jar 路径实现（桌面端外部进程）

```dart
Future<LoginResult> _loginJar(String user, String pwd) async {
  final jarPath = await platform.resolveAsset('assets/bin/login.jar');
  final java = await platform.resolveJava();  // 捆绑 jre/bin/java.exe
  final proc = await jarProcess.start(
    java, ['-jar', jarPath, '-u', user, '-p', pwd, '-t', userIp, '-a', acIp],
  );
  // stdout 关键字状态机（对应 Jar_Thread.read_output）
  await for (final line in proc.stdout.transform(utf8.decoder).transform(LineSplitter())) {
    if (line.contains('The login has been authorized')) {
      return LoginResult.successAuthorized();
    }
    if (line.contains('Send Keep Packet')) {
      _scheduleHeartbeat(interval: const Duration(seconds: 480));
    }
    if (line.contains('KeepUrl is empty')) {
      jarProcess.terminate(pid: proc.pid);
      throw LoginFailed('账号或密码错误');
    }
  }
}
```

#### 3.3.4 验证码 OCR 服务（平台分支）

```dart
abstract interface class OcrService {
  Future<String> recognize(Uint8List imageBytes);
}

class TfliteOcrService implements OcrService {       // 桌面端（onnx→tflite）
  // 用 tflite_flutter 加载 common_old.tflite，PIL 预处理用 image 包替代
}
class MlKitOcrService implements OcrService {        // 移动端
  // google_mlkit_text_recognition
}
```

> **注意**：ddddocr 的 onnx 需先转换为 tflite（用 `onnx2tf` 或 `ai-edge-litert`），或将原 Python OCR 作为独立子进程在桌面端调用（过渡方案）。迁移期建议先用「保留 Python OCR 子进程」快速通路，M6 再替换 tflite。

### 3.4 数据存储模块

```dart
// 密码：flutter_secure_storage
class SecureAccountStore {
  final _s = FlutterSecureStorage();
  Future<void> save(String user, String pwd) =>
      _s.write(key: 'account:$user', value: pwd);
  Future<String?> read(String user) => _s.read(key: 'account:$user');
  Future<void> delete(String user) => _s.delete(key: 'account:$user');
  Future<List<String>> list() async => (await _s.readAll())
      .keys.where((k) => k.startsWith('account:')).map((k) => k.substring(8)).toList();
}

// 配置：shared_preferences（对应 config.ini）
class ConfigStore {
  final SharedPreferences _sp;
  String? get username => _sp.getString('username');
  set username(String? v) => _sp.setString('username', v ?? '');
  // ... 全部 config_maps 字段
}
```

**迁移兼容**：M0 写一次性迁移工具，读旧 `config.ini`/`Secret.dat`（用 AES-GCM 解密）导入 SP/SecureStorage，见 §4.5。

### 3.5 网络模块（dio）

```dart
class AppDio {
  static Dio create() {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 3),
      receiveTimeout: const Duration(seconds: 5),
      // 校园网场景：禁用系统代理、关闭 TLS 校验（仅 Portal）
      proxy: '',
      validateStatus: (s) => s != null && s < 500,
      headers: {'User-Agent': 'Mozilla/5.0 ... Edg/130.0.0.0'},
    ));
    dio.interceptors.add(LogInterceptor(responseBody: true));
    return dio;
  }
}
```

### 3.6 看门狗模块

```dart
class WatchdogController extends Notifier {
  Timer? _timer;
  @override
  WatchdogState build() => WatchdogState.idle();

  void start() {
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _tick());
    ref.onDispose(() => _timer?.cancel());   // 防泄漏
  }

  Future<void> _tick() async {
    final nlmOk = await platform.isNetworkConnected();      // connectivity_plus
    if (!nlmOk) return;
    final internetOk = await ConnectivityChecker.checkAny();  // 6 源
    if (!internetOk) _reconnectWithBackoff();
  }

  int _cooldown = 15;
  Future<void> _reconnectWithBackoff() async {
    // 冷却退避 15→600s（对应 Watch_dog.try_reconnect）
    await ref.read(authControllerProvider.notifier).login(...);
    _cooldown = (_cooldown + 30).clamp(15, 600);
  }
}
```

### 3.7 EasyTier 模块

```dart
class EasyTierController extends Notifier {
  Future<void> startServer() async {
    final toml = _buildServerToml();   // 对应 Easytier.check_config_exist server 分支
    await _writeToml(toml);
    await easytierProcess.start(['-c', tomlPath]);
    // stdout 关键字：starting easytier / remote: wg:// / peer connection removed ...
  }
  Future<void> startClient(String peerIp, String secret) async {
    final toml = _buildClientToml(peerIp, secret);
    // route add 0.0.0.0 mask 0.0.0.0 10.129.114.10 metric 1
    await platform.addRoute('0.0.0.0', '10.129.114.10');
  }
}
```

### 3.8 WebUI/Dashboard 模块（Flutter 原生替代）

原 WebUI :50000 大屏改为 Flutter `DashboardPage`，用 `fl_chart` 绘制流量/节点图，通过 `easytier_cli.dart` 调 `easytier-cli.exe -p 127.0.0.1:15888 -o json node|peer|route`，1s 缓存。

```dart
final etNodeProvider = StreamProvider.autoDispose((ref) async* {
  while (true) {
    yield await EasyTierCli.queryNode();
    await Future.delayed(const Duration(seconds: 1));
  }
});
```

> 移动端无 easytier-core，dashboard 显示「仅桌面端可用」占位；外网下载页功能在桌面端可选保留 shelf 模块。

### 3.9 系统集成模块（桌面）

| 能力 | 原 Python | Flutter 方案 |
|---|---|---|
| 系统托盘 | QSystemTrayIcon | `tray_manager` |
| 开机自启 | schtasks ONLOGON/HIGHEST | `launch_at_startup` |
| 文件锁防多开 | msvcrt.locking | `file_store.dart` pid 锁 |
| DPI 感知 | SetProcessDpiAwareness | `window_manager` + Flutter 默认 |
| 管理员权限 | --windows-uac-admin | windows/runner/main.cpp 嵌入 manifest requireAdministrator |
| 路由增删 | route add/delete | `process_run` 调 route |
| 版本更新检查 | cmxz.top | `UpdaterController`（dio） |

### 3.10 组件拆分清单

- `MainShell`（ShellRoute 容器：侧栏/托盘入口/日志控制台常驻）
- `AccountDropdown`（账号下拉 + 右键删除，ValueKey 绑定账号）
- `LogConsole`（日志列表，限 1000 行滚动，对应 listWidget）
- `ProgressBar`（看门狗进度）
- `CheckboxRow`（记住密码/自动登录/看门狗/自动共享/t模式）
- `CaptchaImage`（FutureBuilder 缓存 Future）
- `MultiloginTab`（多 IP/账号/密码表单）
- `EasytierLogConsole`、`DashboardChart`（fl_chart）
- `VersionBadge`、`TrayMenu`

### 3.11 平台适配策略

```dart
final platformServiceProvider = Provider<PlatformService>((ref) {
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    return DesktopPlatformService();
  }
  return MobilePlatformService();  // 功能子集
});
```

| 能力 | Windows 桌面 | 移动端 |
|---|---|---|
| jar 登录 | ✅ Process + 捆绑 jre | ❌ 不支持（UI 隐藏入口） |
| HTTP 登录 | ✅ | ✅ |
| 验证码 OCR | tflite/Python 子进程 | MLKit |
| 看门狗重连 | ✅ | ✅（connectivity_plus） |
| EasyTier 共享/隧道 | ✅ Process | ❌（仅展示状态） |
| 网络共享下载页 | ✅（可选 shelf） | ❌ |
| 托盘/自启/锁 | ✅ | ❌ |
| 密码存储 | flutter_secure_storage(DPAPI) | Keychain/Keystore |

---

## 4. 迁移过程中的兼容性处理策略

### 4.1 login.jar 不可移植问题
- **策略**：桌面端保留 `login.jar` + `jre` 作为捆绑资产，`JarProcess` 用 `process_run` 启动，stdout 协议与原 Python 完全一致（关键字不变）。
- 移动端：`AuthRepository` 检测到无 jar 能力时，对非 t 账号提示「请使用 HTTP(t) 模式或在桌面端登录」。
- **风险**：jar 版本与源 v1.68 绑定，升级需同步替换 assets/bin/login.jar。

### 4.2 ddddocr onnx 迁移
- **过渡方案（M2）**：桌面端保留 `ddddocr` Python 子进程（`python -c "import ddddocr..."`），快速通路。
- **最终方案（M6）**：用 `onnx2tf` 将 `common_old.onnx` 转 tflite，`tflite_flutter` 加载；PIL 预处理用 `image` 包重写（灰度/二值化/中值滤波）。
- 移动端：`google_mlkit_text_recognition`（验证码非标准文字，准确率可能下降，需实测；必要时保留服务端 OCR 选项）。

### 4.3 unidbg 加密不可重写
- jar 内 unidbg 模拟天翼 native .so 加密，**Dart 侧绝不重写**。所有 jar 路径加密由 jar 进程内部完成，Flutter 仅做进程托管与 stdout 解析。

### 4.4 Win32 API 替代
| 原 API | Flutter 替代 |
|---|---|
| `winreg` MachineGuid | `win32` 包读注册表，或 `device_info_plus` 获取设备唯一标识 |
| `msvcrt.locking` 文件锁 | `file_store.dart` + `file_lock`/flock |
| `schtasks /Create ONLOGON HIGHEST` | `launch_at_startup`（封装 schtasks/LaunchAgent） |
| `route add/delete 0.0.0.0` | `process_run` 调 `route`（需管理员权限，见 manifest） |
| `user32.MessageBoxW` | Flutter `AlertDialog`/`showDialog` |
| DPI `SetProcessDpiAwareness` | `window_manager` + Flutter 默认 Per-Monitor |

### 4.5 配置文件格式兼容（数据迁移）
- **迁移工具** `lib/core/storage/migration.dart`：
  1. 读旧 `%APPDATA%/SAC/config.ini`（`[key]=value`），按 config_maps 映射到 shared_preferences。
  2. 读旧 `Secret.dat`，用 AES-GCM（pointycastle，密钥=SHA256(MachineGuid去横线+"InterKnot2026")）解密每个账号密码，写入 flutter_secure_storage。
  3. 读旧 Cred.c 凭据（若存在）：用 platform channel 调 Cred.c 编译产物 `read`，导入 secure_storage。
  4. 标记 `migrated=true`，避免重复迁移。
- 兼容旧 Cred 新旧格式（`user@InterKnot` / `InterKnot`），对应 Cred.c fallback 逻辑。

### 4.6 版本号/数据迁移
- Flutter 版本 2.0.0+1（区分原 1.68，表明跨平台重写）。
- 更新检查接口 `cmxz.top` UA 改为 `CMXZ-SAC-Flutter_2.0.0`，服务端需兼容新 UA（或新 endpoint）。
- 原 `?enable=0` 远程停用逻辑保留。

### 4.7 并发与状态安全
- 原多拨 `mulit_status` dict 在并发登录下有竞态；Flutter 用 `Map` + 不可变状态 + Riverpod 自动序列化更新规避。
- jar 多进程列表 `jar_Thread.processes`（QMutex）→ `JarProcess` 内部用 `List<Process>` + `synchronized`/`Mutex`（dart `synchronized` 包）。

---

## 5. 分阶段实施计划（里程碑）

> 工期为参考估值（人日），AI 执行时按实际调整。每个里程碑结束须满足验收标准。

### M0 项目初始化与骨架（工期：1.5 人日）
**任务清单**：
1. 替换 pubspec.yaml，`flutter pub get`，`build_runner` 生成。
2. 创建 §1.3 目录结构，删除默认 main.dart 计数器。
3. 写 `app.dart`（MaterialApp.router + 主题 + dynamic_color）。
4. 写 `app_router.dart` 路由表（空页面占位）。
5. 配置 windows/runner：管理员 manifest、托盘图标、窗口标题「绳网认证 2.0」。
6. 复制 `assets/icons/yish.ico` 等资源；写 `scripts/copy_bins.ps1`。
7. 配置 analysis_options + l10n 骨架。

**验收标准**：
- `flutter run -d windows` 启动空白主壳，窗口标题/图标正确。
- `flutter analyze` 0 error。
- 目录结构与文档一致；提交 7+ commits。

---

### M1 核心层基础设施（工期：3 人日）
**任务清单**：
1. `dio_client.dart`（超时/代理禁用/UA/拦截器）。
2. `rsa_crypto.dart`（pointycastle，PKCS#1 v1.5，hex 输出，含单元测试）。
3. `aes_gcm_crypto.dart`（pointycastle AES-GCM，用于迁移工具解密旧 Secret.dat）。
4. `machine_fingerprint.dart`（桌面 MachineGuid，移动 device_info_plus）。
5. `secure_storage.dart` + `config_store.dart`（全部 config_maps 字段）。
6. `file_store.dart`（log/lock/signal/toml/zip，含日志轮转）。
7. `platform_service.dart` 抽象 + Desktop/Mobile 实现。
8. `logger.dart`（分级 DEBUG/INFO/WARN/ERROR，不再启动清空）。
9. `migration.dart` 数据迁移工具（读旧 config.ini/Secret.dat/Cred）。

**验收标准**：
- RSA 加密结果与原 Python `Login_Thread.encrypt_rsa` 字节级一致（用同公钥同明文测试）。
- AES-GCM 能解密旧 Secret.dat 中的账号密码。
- 迁移工具在含旧数据的环境跑通，数据进入 SP/SecureStorage。
- 单元测试覆盖率 ≥ 70%。

---

### M2 HTTP 认证路径 + OCR（工期：4 人日）
**任务清单**：
1. `auth_repository.dart` 框架 + 平台分支。
2. `esurfing_api.dart` 常量（Portal 路径、UA、6 源连通性 URL）。
3. 取参：GET 189.cn 重定向正则解析。
4. 验证码：GET `/qs/index_gz.jsp` → 正则取图 URL → GET 图。
5. OCR：桌面过渡方案（Python 子进程）+ 接口预留 tflite。
6. RSA 加密 loginKey → POST `/ajax/login` → resultCode/signature。
7. 下线 POST `/ajax/logout`。
8. 验证码错误重试控制器（最多 5 次，间隔 3s，关键字停止）。
9. `login_page.dart` UI（账号下拉/密码/复选框/登录下线/日志）。
10. `AuthController` Riverpod notifier。

**验收标准**：
- t 账号能完成 HTTP 登录/登出，日志与原程序一致。
- 验证码识别成功率与原 ddddocr 相当（过渡方案）。
- 验证码错误自动重试且遇密码错误停止。
- 异步 UI 无 context 失效崩溃（mounted/不持 BuildContext）。

---

### M3 jar 认证路径 + 心跳（工期：3 人日，仅桌面）
**任务清单**：
1. `jar_process.dart`：Process.run 启动 java + login.jar，捆绑 jre 解析。
2. stdout 行解析状态机（authorized/Send Keep Packet/KeepUrl empty/network connected）。
3. `term_all_processes` 等价：进程列表 + Mutex，logout.signal 文件信号。
4. 心跳调度器（480s 兜底）。
5. `AuthRepository._loginJar` 接入。
6. 捆绑资源注入（copy_bins.ps1 把 login.jar/jre 放入 assets/bin）。
7. 移动端 UI 隐藏 jar 入口逻辑。

**验收标准**：
- 学生账号（非 t）桌面端能 jar 登录、心跳保活、下线。
- stdout 关键字状态机覆盖原 Jar_Thread 全部分支。
- 多拨并发登录下进程列表管理无竞态。

---

### M4 看门狗 + 系统集成（工期：3 人日）
**任务清单**：
1. `connectivity_checker.dart` 6 源探测 + 重定向识别。
2. `WatchdogController`（3s 轮询 + NLM/connectivity_plus + 退避 15→600s）。
3. `tray_manager` 托盘（恢复/退出 + 最小化到托盘）。
4. `launch_at_startup` 开机自启（ONLOGON/HIGHEST 等价）。
5. `window_manager` DPI/窗口控制。
6. 文件锁防多开（pid 锁）。
7. `UpdaterController`（cmxz.top 版本/停用，UA=CMXZ-SAC-Flutter_2.0.0）。

**验收标准**：
- 拔网线/断网后看门狗自动重连，退避递增。
- 托盘最小化/恢复正常；开机自启生效。
- 重复启动触发锁提示。
- 模拟服务端 `?enable=0` 能强制下线。

---

### M5 多拨 + 设置（工期：2.5 人日）
**任务清单**：
1. `multilogin_controller.dart`（tab 管理、IP 去重、串行登录 50ms 间隔）。
2. `multilogin_page.dart`（动态 tab、密码框加密、右键删除）。
3. `settings_page.dart`（参数/隧道/清除配置/打开配置目录）。
4. `params_page.dart` 自动获取参数（Get_Userip_Thread 等价）。
5. 多拨密码加密存 secure_storage（对应 line_edit_*_3）。

**验收标准**：
- 多 IP 多拨登录结果汇总正确，重复 IP 拦截。
- 设置页保存/读取配置一致，清除配置可恢复默认。

---

### M6 EasyTier + Dashboard + OCR 终态（工期：4 人日）
**任务清单**：
1. `easytier_process.dart`（server/client toml 生成 + 启动 + stdout 状态机）。
2. 路由增删（route add/delete 0.0.0.0 → 10.129.114.10）。
3. `easytier_cli.dart`（RPC 127.0.0.1:15888 -o json node/peer/route，1s 缓存）。
4. `dashboard_page.dart`（fl_chart 节点/流量图，替代 WebUI 大屏）。
5. `share_page.dart` / `tunnel_page.dart`（共享/隧道双模式 + 隧道日志）。
6. OCR 终态：onnx→tflite 转换 + tflite_flutter 加载 + image 包预处理。
7. （可选）桌面 shelf WebUI 下载页，保留外网下载能力。

**验收标准**：
- 桌面端能启动共享、移动端能连隧道、路由添加/删除正确。
- Dashboard 实时显示节点/流量，1s 刷新。
- tflite OCR 识别率 ≥ 原 ddddocr 90%。

---

### M7 国际化 + 打包发布（工期：2.5 人日）
**任务清单**：
1. l10n arb（中/英），所有 UI 文案提取。
2. Windows 打包：`flutter build windows --release`，嵌入管理员 manifest、托盘图标、捆绑 assets/bin（login.jar/jre/easytier/ocr）。
3. 可选 MSIX：`msix` 包生成安装包。
4. 移动端构建（Android APK / iOS）功能子集验证。
5. 启动崩溃捕获 + 写 startup_crash.log 等价。
6. README 更新（构建说明、平台差异）。

**验收标准**：
- Windows release 包可独立运行，含全部捆绑二进制。
- 中/英切换正常。
- 移动端包能跑通 HTTP 登录 + 看门狗（功能子集）。

---

### M8（可选增强）打磨与动画（工期：2 人日）
**任务清单**：
1. 按 Flutter Animations 技能补全微交互：
   - 登录按钮状态切换用 `AnimatedSwitcher`（loading/success/error）。
   - 日志条目入场用 staggered（`Interval` + `SlideTransition`）。
   - 账号下拉删除用 `AnimatedList` + Hero。
   - Dashboard 图表过渡用 implicit `AnimatedContainer`/`TweenAnimationBuilder`。
2. 性能：`const` 化、列表 `Key`、`AnimatedBuilder` 替代 `setState` 监听。
3. 无障碍：`Semantics` 标注、尊重 `disableAnimations`。

**验收标准**：
- 动画流畅 60fps，AnimationController 全 dispose（无泄漏）。
- 开启「减少动态效果」时降级为瞬时切换。

---

## 6. 风险与回滚

| 风险 | 概率 | 影响 | 缓解 |
|---|---|---|---|
| tflite 转换失败/识别率低 | 中 | 验证码登录受阻 | 保留 Python OCR 子进程作长期 fallback |
| jar 在新 JRE 版本行为变化 | 低 | jar 路径失效 | 捆绑原 v1.68 的 jre，不升级 |
| easytier-cli 输出格式变更 | 低 | dashboard 失败 | 输出解析容错 + 版本探测 |
| flutter_secure_storage 桌面依赖 | 低 | 密码存储失败 | fallback 到 AES-GCM 文件方案（复用 §4.5 解密逻辑） |
| 管理员权限被拒 | 中 | 路由/自启失效 | UI 提示 + 降级运行（仅认证） |
| 迁移数据解密失败（设备变更） | 中 | 历史密码丢失 | 提示重新输入（原项目即此行为，保持一致） |

**回滚策略**：每个里程碑独立分支，M1/M3/M6 为关键节点；若 M3 jar 迁移受阻，可先发布仅 HTTP 路径的移动端版本（M2+M4+M5），桌面 jar 路径延后。

---

## 7. 附录

### 7.1 依赖速查（按里程碑分组）
- M0：flutter_riverpod, go_router, dynamic_color, tray_manager, window_manager
- M1：dio, pointycastle, encrypt, flutter_secure_storage, shared_preferences, path_provider, process_run, win32, device_info_plus, synchronized
- M2：google_mlkit_text_recognition（移动）/ Python OCR 子进程（桌面过渡）
- M4：connectivity_plus, launch_at_startup, package_info_plus, http
- M6：fl_chart, shelf, shelf_router, tflite_flutter, image
- M7：msix, flutter_localizations

### 7.2 关键常量迁移（来自源码）
```dart
class EsurfingConstants {
  static const rsaPublicKey = '''-----BEGIN PUBLIC KEY-----
MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCyhncn4Z4RY8wITqV7n6hAapEM
ZwNBP6fflsGs3Ke5g6Ji4AWvNflIXZLNTGIuykoU1v2Bitylyuc9nSKLTvBdcytB
+4X4CvV4oVDr2aLrXs7LhTNyykcxyhyGhokph0Cb4yR/mybK6OeH2ME1/AZS7AZ4
pe2gw9lcwXQVF8DJwwIDAQAB
-----END PUBLIC KEY-----''';

  static const captchaUrls = [
    ('http://www.msftconnecttest.com/connecttest.txt', 200, 'HEAD'),
    ('http://connectivitycheck.gstatic.com/generate_204', 204, 'GET'),
    ('http://www.google.cn/generate_204', 204, 'GET'),
    ('http://captive.apple.com/hotspot-detect.html', 200, 'HEAD'),
    ('http://connect.rom.miui.com/generate_204', 204, 'GET'),
    ('http://wifi.vivo.com.cn/generate_204', 204, 'GET'),
  ];

  static const updateCheckUrl = 'https://cmxz.top/programs/sac/check.php';
  static const etDefaultSecret = 'Hello_InterKnot';
  static const etVirtualIp = '10.129.114.10';
  static const etPort = 51145;
  static const webuiPort = 50000;
  // 原 jar 内常量（参考，不在 Dart 实现）：AUTH_KEY='Eshore!@#', USER_AGENT='CCTP/android64_vpn/2093'
}
```

### 7.3 迁移检查清单（交付前自检）
- [ ] `flutter analyze` 0 error，`dart test` 全绿
- [ ] Riverpod `custom_lint` 无警告
- [ ] 所有 `setState` 前有 `mounted` 检查（若用 StatefulWidget）
- [ ] 所有 `AnimationController`/`Timer`/`StreamSubscription` 在 `dispose`/`ref.onDispose` 释放
- [ ] 所有列表项有 `Key`
- [ ] 静态 Widget `const` 化
- [ ] 平台通道调用 `try/catch PlatformException`
- [ ] 管理员 manifest 生效；托盘/自启可用
- [ ] 数据迁移工具跑通旧 → 新
- [ ] Windows release 包含 login.jar/jre/easytier/ocr 捆绑资源
- [ ] 中/英 l10n 完整

### 7.4 与架构解析文档的对应
本施工文档各节对应 `InterKnot_Auth-1.68架构解析.html`：
- §2.2 ← 架构解析 §3（认证时序）
- §2.3 ← 架构解析 §4（数据存储）
- §2.4 ← 架构解析 §5（接口协议）
- §3.9 ← 架构解析 §6（安全加固，密码/权限/防多开）
- §4.5 ← 架构解析 §7（v1.68 变更，密码存储迁移）

---

**文档版本**：1.0 · 生成于 2026-08-10 · 执行方：DeepSeek V4 Pro
