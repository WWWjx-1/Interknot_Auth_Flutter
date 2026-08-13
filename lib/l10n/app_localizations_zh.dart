// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '绳网认证';

  @override
  String get appTitleVersion => '绳网认证 2.0';

  @override
  String get appVersion => 'v2.0.0';

  @override
  String get ok => '确定';

  @override
  String get cancel => '取消';

  @override
  String get confirm => '确认';

  @override
  String get exit => '退出';

  @override
  String get delete => '删除';

  @override
  String get save => '保存';

  @override
  String get clear => '清除';

  @override
  String get add => '添加';

  @override
  String get stop => '停止';

  @override
  String get logout => '登出';

  @override
  String get alreadyRunningTitle => '程序已在运行';

  @override
  String get alreadyRunningContent => '绳网认证已在运行中，请检查系统托盘。';

  @override
  String get confirmExitTitle => '确认退出';

  @override
  String get confirmExitContent => '确定要退出绳网认证吗？\n退出后网络认证将断开。';

  @override
  String get appExitLog => '绳网认证 2.0 退出';

  @override
  String get appStartLog => '绳网认证 2.0 启动完成';

  @override
  String get systemInitComplete => 'M4 系统集成初始化完成';

  @override
  String get autoStartConfigured => '开机自启已配置';

  @override
  String get migrationChecking => '数据迁移检查中...';

  @override
  String get alreadyRunningDetected => '检测到已有实例在运行';

  @override
  String get watchdogAutoStart => '看门狗已配置为启用，自动启动';

  @override
  String get account => '账号';

  @override
  String get password => '密码';

  @override
  String get login => '登录';

  @override
  String get logoff => '下线';

  @override
  String get processing => '处理中...';

  @override
  String get rememberPassword => '记住密码';

  @override
  String get autoLogin => '自动登录';

  @override
  String get watchdog => '看门狗';

  @override
  String get autoShare => '自动共享';

  @override
  String get tMode => 't模式';

  @override
  String get pleaseEnterAccount => '请输入账号';

  @override
  String get pleaseEnterPassword => '请输入密码';

  @override
  String get deleteAccount => '删除账号';

  @override
  String get deleteAccountTitle => '删除账号';

  @override
  String get accountDeleted => '已删除账号';

  @override
  String get logTitle => '日志';

  @override
  String get noLogs => '暂无日志';

  @override
  String get clearLogs => '清除日志';

  @override
  String get ready => '就绪';

  @override
  String get multilogin => '多拨';

  @override
  String get settings => '设置';

  @override
  String get multiloginTitle => '多拨管理';

  @override
  String get addTab => '添加 tab';

  @override
  String get addMultilogin => '添加多拨';

  @override
  String get loginAll => '全部登录';

  @override
  String get loggingIn => '登录中...';

  @override
  String get logoutAll => '全部登出';

  @override
  String get successCount => '成功';

  @override
  String get failCount => '失败';

  @override
  String successFailFormat(Object success, Object fail) {
    return '成功: $success | 失败: $fail';
  }

  @override
  String get noMultiloginConfig => '暂无多拨配置';

  @override
  String get addMultiloginHint => '点击下方按钮添加多拨 tab';

  @override
  String get loginResults => '登录结果汇总';

  @override
  String successRate(Object success, Object fail) {
    return '成功 $success / 失败 $fail';
  }

  @override
  String get addMultiloginDialog => '添加多拨';

  @override
  String get ipAddress => 'IP 地址';

  @override
  String get ipAddressHint => '如 10.10.10.xxx';

  @override
  String get pleaseFillIpOrAccount => '请至少填写 IP 或账号';

  @override
  String get tabUpdated => 'Tab 已更新';

  @override
  String get confirmDelete => '确认删除';

  @override
  String get confirmDeleteTab => '确定要删除这个多拨 tab 吗？';

  @override
  String get confirmLogout => '确认登出';

  @override
  String get confirmLogoutAll => '确定要登出所有多拨 tab 吗？';

  @override
  String get settingsTitle => '设置';

  @override
  String get saveSettings => '保存设置';

  @override
  String get loginParams => '登录参数';

  @override
  String get portalAddress => 'Portal 地址 (esurfingurl)';

  @override
  String get portalAddressHint => '如 10.10.10.10:8080';

  @override
  String get acIp => 'AC IP (wlanacip)';

  @override
  String get acIpHint => 'AC 控制器 IP';

  @override
  String get userIp => '用户 IP (wlanuserip)';

  @override
  String get userIpHint => '用户分配 IP';

  @override
  String get autoFetchParams => '自动获取参数 (189.cn)';

  @override
  String get manualFetchParams => '手动获取参数';

  @override
  String get tunnelConfig => '隧道配置 (EasyTier)';

  @override
  String get sharedKey => '共享密钥';

  @override
  String get sharedKeyHint => '默认: Hello_InterKnot';

  @override
  String get speedLimit => '限速';

  @override
  String get speedLimitHint => '如 10MB/s（留空不限制）';

  @override
  String get enableIpv6 => '启用 IPv6';

  @override
  String get enableIpv6Subtitle => '隧道支持 IPv6 地址';

  @override
  String get enableWebDownload => '启用网页下载';

  @override
  String get enableWebDownloadSubtitle => '外网可通过网页下载共享文件';

  @override
  String get useCustomConfig => '使用自定义配置';

  @override
  String get useCustomConfigSubtitle => '使用自定义 toml 配置文件';

  @override
  String get customConfigPath => '自定义配置路径';

  @override
  String get customConfigPathHint => 'toml 文件绝对路径';

  @override
  String get configManagement => '配置管理';

  @override
  String get clearAllConfig => '清除所有配置';

  @override
  String get openConfigDir => '打开配置目录';

  @override
  String get confirmClear => '确认清除';

  @override
  String get confirmClearContent =>
      '确定要清除所有配置吗？\n\n这将重置所有设置、登录参数和隧道配置。\n密码数据不会被清除。';

  @override
  String get settingsSaved => '设置已保存';

  @override
  String get saveFailed => '保存失败';

  @override
  String get paramsFetchSuccess => '参数获取成功';

  @override
  String get paramsFetchFailed => '获取参数失败';

  @override
  String get configCleared => '配置已清除';

  @override
  String get configDir => '配置目录';

  @override
  String get cannotOpenConfigDir => '无法打开配置目录';

  @override
  String get fetchParamsTitle => '获取登录参数';

  @override
  String get saveToConfig => '保存到配置';

  @override
  String get paramsInfo => '参数获取说明';

  @override
  String get paramsInfoContent =>
      '通过访问 189.cn 获取校园网 Portal 参数。\n参数获取成功后可手动编辑并保存到设置。';

  @override
  String get fetchParamsButton => '获取参数 (189.cn)';

  @override
  String get fetchingParams => '正在获取...';

  @override
  String get connecting189 => '正在连接 189.cn...';

  @override
  String get fetchSuccess => '参数获取成功！';

  @override
  String get fetchFailed => '获取失败';

  @override
  String get fetchException => '获取异常';

  @override
  String get portalParams => 'Portal 参数';

  @override
  String get currentDeviceIp => '当前设备 IP';

  @override
  String get actions => '操作';

  @override
  String get clearFields => '清空';

  @override
  String get debugInfo => '调试信息';

  @override
  String get fetchUrl => '获取 URL';

  @override
  String get paramsSavedToConfig => '参数已保存到设置';

  @override
  String get clearedRetry => '已清空，点击获取按钮重新获取';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get dashboardDesktopOnly => 'Dashboard 仅桌面端可用';

  @override
  String get dashboardDesktopHint => '请在桌面端查看 EasyTier 节点状态和流量图表';

  @override
  String get easytierDashboard => 'EasyTier Dashboard';

  @override
  String get easytierNotRunning => 'EasyTier 未运行';

  @override
  String get startShare => '启动共享';

  @override
  String get running => '运行中';

  @override
  String get shareMode => '共享模式';

  @override
  String get tunnelMode => '隧道模式';

  @override
  String get noNodeData => '暂无节点数据';

  @override
  String get networkNodes => '网络节点';

  @override
  String get online => '在线';

  @override
  String get offline => '离线';

  @override
  String get peers => '对等';

  @override
  String get traffic => '流量';

  @override
  String get networkTraffic => '网络流量';

  @override
  String get download => '下载';

  @override
  String get upload => '上传';

  @override
  String get noTrafficData => '暂无流量数据';

  @override
  String get peerNodes => '对等节点';

  @override
  String get noPeerConnected => '暂无对等节点连接';

  @override
  String get endpoint => '端点';

  @override
  String get routeTable => '路由表';

  @override
  String get routeDestination => '目标';

  @override
  String get routeGateway => '网关';

  @override
  String get routeInterface => '接口';

  @override
  String get routeMetric => '跃点';

  @override
  String get routeStatus => '状态';

  @override
  String get routeActive => '活跃';

  @override
  String get routeInactive => '非活跃';

  @override
  String get share => '共享';

  @override
  String get easytierDesktopOnly => 'EasyTier 仅桌面端可用';

  @override
  String get easytierShare => 'EasyTier 共享';

  @override
  String get shareRunning => '共享服务运行中';

  @override
  String get shareNotRunning => '共享服务未启动';

  @override
  String get shareConfig => '共享配置';

  @override
  String get networkKey => '网络密钥';

  @override
  String get networkKeyHint => '输入共享密钥';

  @override
  String get networkKeyHelper => '客户端需要使用相同密钥连接';

  @override
  String get networkName => '网络名称';

  @override
  String get defaultPort => '默认端口';

  @override
  String get virtualIp => '虚拟 IP';

  @override
  String get rpcPort => 'RPC 端口';

  @override
  String get stopShare => '停止共享';

  @override
  String get runningLogs => '运行日志';

  @override
  String get tunnel => '隧道';

  @override
  String get easytierTunnel => 'EasyTier 隧道';

  @override
  String get tunnelConnected => '隧道已连接';

  @override
  String get tunnelNotConnected => '隧道未连接';

  @override
  String get connectionConfig => '连接配置';

  @override
  String get peerIpAddress => '对端 IP 地址';

  @override
  String get peerIpHint => '输入服务器 IP 地址';

  @override
  String get peerIpHelper => 'EasyTier 服务端的 IP 地址';

  @override
  String get networkKeyMustMatch => '需要与服务端配置的密钥一致';

  @override
  String get disconnectTunnel => '断开隧道';

  @override
  String get connectTunnel => '连接隧道';

  @override
  String get pleaseEnterPeerIp => '请输入对端 IP 地址';

  @override
  String get tunnelInfo => '隧道信息';

  @override
  String get tunnelLogs => '隧道日志';

  @override
  String get watchdogNotEnabled => '看门狗: 未启用';

  @override
  String get watchdogChecking => '检测中...';

  @override
  String get watchdogRunning => '看门狗: 运行中';

  @override
  String get watchdogDisconnected => '看门狗: 已断开';

  @override
  String get watchdogUnknown => '看门狗: 未知';

  @override
  String get watchdogEnable => '点击启用看门狗';

  @override
  String get watchdogDisable => '点击停用看门狗';

  @override
  String get checkingUpdate => '正在检查更新...';

  @override
  String get appDisabled => '应用已被远程停用，请检查更新';

  @override
  String get alreadyLatest => '已是最新版本';

  @override
  String newVersionFound(Object version) {
    return '发现新版本 $version';
  }

  @override
  String get networkError => '网络异常';

  @override
  String get checkFailed => '检查失败';

  @override
  String get copyAllLogs => '复制全部日志';

  @override
  String get logsCopied => '日志已复制到剪贴板';

  @override
  String migrationComplete(Object config, Object accounts, Object cred) {
    return '迁移完成：配置 $config 项，Secret.dat 账号 $accounts 个，Cred 账号 $cred 个';
  }

  @override
  String get migrationFailed => '迁移失败';

  @override
  String get migrationSkipped => '已迁移，跳过';

  @override
  String get systemSettings => '系统设置';

  @override
  String get launchAtStartupTitle => '开机自启';

  @override
  String get launchAtStartupSubtitle => '登录 Windows 时自动启动绳网认证';

  @override
  String get launchAtStartupNotSupported => '当前平台不支持开机自启（仅桌面端）';

  @override
  String get launchAtStartupEnabled => '开机自启已启用';

  @override
  String get launchAtStartupDisabled => '开机自启已关闭';

  @override
  String get launchAtStartupFailed => '设置开机自启失败';

  @override
  String get minimizeToTrayTitle => '关闭时最小化至托盘';

  @override
  String get minimizeToTraySubtitle => '关闭窗口时隐藏到系统托盘；关闭后改为直接退出';

  @override
  String get minimizeToTrayNotSupported => '当前平台不支持系统托盘';

  @override
  String get minimizeToTrayEnabled => '已设置为：关闭时最小化至托盘';

  @override
  String get minimizeToTrayDisabled => '已设置为：关闭时直接退出';

  @override
  String get minimizeToTrayFailed => '设置失败';

  @override
  String get trayShowWindow => '显示主窗口';

  @override
  String get trayExit => '退出';

  @override
  String get trayQuickExit => '直接退出';
}
