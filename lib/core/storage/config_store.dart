/// 配置项存储
///
/// 使用 shared_preferences 替代原 `config.ini`（`[key]=value` 格式）。
///
/// 包含原 `MainWindow.read_config` 中 config_maps 的全部字段，
/// 以及多拨配置项 `line_edit_{tab}_{1|2|3}`（1=IP, 2=账号, 3=密码）。
///
/// 数据迁移由 `migration.dart` 完成，从旧 config.ini 导入。
library;

import 'package:shared_preferences/shared_preferences.dart';

/// 配置项存储服务
class ConfigStore {
  final SharedPreferences _sp;

  ConfigStore(this._sp);

  // ──────────────────────────── 通用配置 ────────────────────────────

  /// 是否首次运行
  bool get firstRun => _sp.getBool('first_run') ?? true;
  set firstRun(bool v) => _sp.setBool('first_run', v);

  /// 上次登录用户名
  String? get username => _sp.getString('username');
  set username(String? v) => _sp.setString('username', v ?? '');

  /// 密码（机器码校验值，迁移时使用）
  String? get passwordHash => _sp.getString('password');
  set passwordHash(String? v) => _sp.setString('password', v ?? '');

  /// 天翼 Portal 地址
  String? get esurfingUrl => _sp.getString('esurfingurl');
  set esurfingUrl(String? v) => _sp.setString('esurfingurl', v ?? '');

  /// wlanacip
  String? get wlanAcIp => _sp.getString('wlanacip');
  set wlanAcIp(String? v) => _sp.setString('wlanacip', v ?? '');

  /// wlanuserip
  String? get wlanUserIp => _sp.getString('wlanuserip');
  set wlanUserIp(String? v) => _sp.setString('wlanuserip', v ?? '');

  // ──────────────────────────── 开关配置 ────────────────────────────

  /// 记住密码
  bool get savePassword => _sp.getBool('save_pwd') ?? false;
  set savePassword(bool v) => _sp.setBool('save_pwd', v);

  /// 自动连接
  bool get autoConnect => _sp.getBool('auto_connect') ?? false;
  set autoConnect(bool v) => _sp.setBool('auto_connect', v);

  /// 开机自启（用户手动开关）
  ///
  /// 与 `autoConnect`(自动登录) 不同：此开关控制是否注册系统开机自启。
  /// 默认 false，需用户在设置页主动开启。
  bool get launchAtStartup => _sp.getBool('launch_at_startup') ?? false;
  set launchAtStartup(bool v) => _sp.setBool('launch_at_startup', v);

  /// 关闭窗口时最小化至托盘（true）或直接退出（false）
  ///
  /// 默认 true，保持原「关闭即最小化」行为。
  /// 切换后对当前会话即时生效（onWindowClose 读取此配置分流）。
  bool get minimizeToTray => _sp.getBool('minimize_to_tray') ?? true;
  set minimizeToTray(bool v) => _sp.setBool('minimize_to_tray', v);

  /// 看门狗超时（秒）
  int get watchdogTimeout => _sp.getInt('wtg_timeout') ?? 3;
  set watchdogTimeout(int v) => _sp.setInt('wtg_timeout', v);

  /// 多拨模式
  bool get multiLogin => _sp.getBool('mulit_login') ?? false;
  set multiLogin(bool v) => _sp.setBool('mulit_login', v);

  /// 登录模式：0=jar，1=HTTP(t模式)
  int get loginMode => _sp.getInt('login_mode') ?? 0;
  set loginMode(int v) => _sp.setInt('login_mode', v);

  /// 启用看门狗
  bool get enableWatchdog => _sp.getBool('enable_watch_dog') ?? false;
  set enableWatchdog(bool v) => _sp.setBool('enable_watch_dog', v);

  /// 自动共享（EasyTier）
  bool get autoShare => _sp.getBool('auto_share') ?? false;
  set autoShare(bool v) => _sp.setBool('auto_share', v);

  /// 自动更新用户 IP
  bool get autoUpdateUserIp => _sp.getBool('auto_update_userip') ?? false;
  set autoUpdateUserIp(bool v) => _sp.setBool('auto_update_userip', v);

  // ──────────────────────────── EasyTier 配置 ────────────────────────────

  /// EasyTier 密钥
  String? get etSecretKey => _sp.getString('et_secret_key');
  set etSecretKey(String? v) => _sp.setString('et_secret_key', v ?? '');

  /// EasyTier 启用 IPv6
  bool get etEnableIpv6 => _sp.getBool('et_enable_ipv6') ?? false;
  set etEnableIpv6(bool v) => _sp.setBool('et_enable_ipv6', v);

  /// EasyTier 启用网页下载
  bool get etEnableWebDl => _sp.getBool('et_enable_webdl') ?? false;
  set etEnableWebDl(bool v) => _sp.setBool('et_enable_webdl', v);

  /// EasyTier 限速
  String? get etSpeedLimit => _sp.getString('et_speed_limit');
  set etSpeedLimit(String? v) => _sp.setString('et_speed_limit', v ?? '');

  /// EasyTier 启用自定义配置
  bool get etEnableUserConf => _sp.getBool('et_en_userconf') ?? false;
  set etEnableUserConf(bool v) => _sp.setBool('et_en_userconf', v);

  /// EasyTier 自定义配置路径
  String? get etUserConfPath => _sp.getString('et_userconf_path');
  set etUserConfPath(String? v) => _sp.setString('et_userconf_path', v ?? '');

  // ──────────────────────────── 多拨配置 ────────────────────────────

  /// 多拨 tab 的 IP 地址
  String? getMultiloginIp(int tab) => _sp.getString('line_edit_${tab}_1');
  Future<void> setMultiloginIp(int tab, String? v) =>
      _sp.setString('line_edit_${tab}_1', v ?? '');

  /// 多拨 tab 的账号
  String? getMultiloginAccount(int tab) => _sp.getString('line_edit_${tab}_2');
  Future<void> setMultiloginAccount(int tab, String? v) =>
      _sp.setString('line_edit_${tab}_2', v ?? '');

  /// 多拨 tab 的密码（引用名，实际密码在 SecureAccountStore）
  String? getMultiloginPassword(int tab) =>
      _sp.getString('line_edit_${tab}_3');
  Future<void> setMultiloginPassword(int tab, String? v) =>
      _sp.setString('line_edit_${tab}_3', v ?? '');

  /// 多拨 tab 数量
  int get multiloginTabCount => _sp.getInt('multilogin_tab_count') ?? 0;
  set multiloginTabCount(int v) => _sp.setInt('multilogin_tab_count', v);

  // ──────────────────────────── 迁移标记 ────────────────────────────

  /// 是否已完成数据迁移
  bool get migrated => _sp.getBool('migrated') ?? false;
  set migrated(bool v) => _sp.setBool('migrated', v);

  // ──────────────────────────── 工具方法 ────────────────────────────

  /// 清除所有配置（恢复默认）
  Future<void> clearAll() async {
    await _sp.clear();
  }

  /// 获取所有配置键列表（调试用）
  Set<String> get keys => _sp.getKeys();

  /// 获取配置值（泛型，调试用）
  // ignore: avoid_positional_boolean_parameters
  dynamic getRaw(String key) => _sp.get(key);

  /// 原始设置值（迁移工具使用）
  Future<void> setRaw(String key, dynamic value) async {
    if (value is bool) {
      await _sp.setBool(key, value);
    } else if (value is int) {
      await _sp.setInt(key, value);
    } else if (value is double) {
      await _sp.setDouble(key, value);
    } else if (value is String) {
      await _sp.setString(key, value);
    } else if (value is List<String>) {
      await _sp.setStringList(key, value);
    }
  }
}
