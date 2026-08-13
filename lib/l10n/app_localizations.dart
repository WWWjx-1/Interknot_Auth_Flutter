import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// 应用标题
  ///
  /// In zh, this message translates to:
  /// **'绳网认证'**
  String get appTitle;

  /// 带版本号的应用标题
  ///
  /// In zh, this message translates to:
  /// **'绳网认证 2.0'**
  String get appTitleVersion;

  /// 版本号字符串
  ///
  /// In zh, this message translates to:
  /// **'v2.0.0'**
  String get appVersion;

  /// 确定按钮
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get ok;

  /// 取消按钮
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// 确认按钮
  ///
  /// In zh, this message translates to:
  /// **'确认'**
  String get confirm;

  /// 退出按钮
  ///
  /// In zh, this message translates to:
  /// **'退出'**
  String get exit;

  /// 删除按钮
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get delete;

  /// 保存按钮
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get save;

  /// 清除按钮
  ///
  /// In zh, this message translates to:
  /// **'清除'**
  String get clear;

  /// 添加按钮
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get add;

  /// 停止按钮
  ///
  /// In zh, this message translates to:
  /// **'停止'**
  String get stop;

  /// 登出按钮
  ///
  /// In zh, this message translates to:
  /// **'登出'**
  String get logout;

  /// 多开检测对话框标题
  ///
  /// In zh, this message translates to:
  /// **'程序已在运行'**
  String get alreadyRunningTitle;

  /// 多开检测对话框内容
  ///
  /// In zh, this message translates to:
  /// **'绳网认证已在运行中，请检查系统托盘。'**
  String get alreadyRunningContent;

  /// 退出确认对话框标题
  ///
  /// In zh, this message translates to:
  /// **'确认退出'**
  String get confirmExitTitle;

  /// 退出确认对话框内容
  ///
  /// In zh, this message translates to:
  /// **'确定要退出绳网认证吗？\n退出后网络认证将断开。'**
  String get confirmExitContent;

  /// 退出日志消息
  ///
  /// In zh, this message translates to:
  /// **'绳网认证 2.0 退出'**
  String get appExitLog;

  /// 启动日志消息
  ///
  /// In zh, this message translates to:
  /// **'绳网认证 2.0 启动完成'**
  String get appStartLog;

  /// 系统集成初始化完成日志
  ///
  /// In zh, this message translates to:
  /// **'M4 系统集成初始化完成'**
  String get systemInitComplete;

  /// 开机自启配置完成日志
  ///
  /// In zh, this message translates to:
  /// **'开机自启已配置'**
  String get autoStartConfigured;

  /// 数据迁移检查日志
  ///
  /// In zh, this message translates to:
  /// **'数据迁移检查中...'**
  String get migrationChecking;

  /// 多开检测日志
  ///
  /// In zh, this message translates to:
  /// **'检测到已有实例在运行'**
  String get alreadyRunningDetected;

  /// 看门狗自动启动日志
  ///
  /// In zh, this message translates to:
  /// **'看门狗已配置为启用，自动启动'**
  String get watchdogAutoStart;

  /// 账号输入框标签
  ///
  /// In zh, this message translates to:
  /// **'账号'**
  String get account;

  /// 密码输入框标签
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get password;

  /// 登录按钮
  ///
  /// In zh, this message translates to:
  /// **'登录'**
  String get login;

  /// 下线按钮
  ///
  /// In zh, this message translates to:
  /// **'下线'**
  String get logoff;

  /// 处理中状态文本
  ///
  /// In zh, this message translates to:
  /// **'处理中...'**
  String get processing;

  /// 记住密码复选框
  ///
  /// In zh, this message translates to:
  /// **'记住密码'**
  String get rememberPassword;

  /// 自动登录复选框
  ///
  /// In zh, this message translates to:
  /// **'自动登录'**
  String get autoLogin;

  /// 看门狗复选框
  ///
  /// In zh, this message translates to:
  /// **'看门狗'**
  String get watchdog;

  /// 自动共享复选框
  ///
  /// In zh, this message translates to:
  /// **'自动共享'**
  String get autoShare;

  /// t模式复选框
  ///
  /// In zh, this message translates to:
  /// **'t模式'**
  String get tMode;

  /// 账号为空提示
  ///
  /// In zh, this message translates to:
  /// **'请输入账号'**
  String get pleaseEnterAccount;

  /// 密码为空提示
  ///
  /// In zh, this message translates to:
  /// **'请输入密码'**
  String get pleaseEnterPassword;

  /// 删除账号对话框标题
  ///
  /// In zh, this message translates to:
  /// **'删除账号'**
  String get deleteAccount;

  /// 删除账号对话框标题
  ///
  /// In zh, this message translates to:
  /// **'删除账号'**
  String get deleteAccountTitle;

  /// 账号删除成功提示
  ///
  /// In zh, this message translates to:
  /// **'已删除账号'**
  String get accountDeleted;

  /// 日志区域标题
  ///
  /// In zh, this message translates to:
  /// **'日志'**
  String get logTitle;

  /// 无日志占位文本
  ///
  /// In zh, this message translates to:
  /// **'暂无日志'**
  String get noLogs;

  /// 清除日志按钮提示
  ///
  /// In zh, this message translates to:
  /// **'清除日志'**
  String get clearLogs;

  /// 状态栏就绪文本
  ///
  /// In zh, this message translates to:
  /// **'就绪'**
  String get ready;

  /// 多拨入口按钮提示
  ///
  /// In zh, this message translates to:
  /// **'多拨'**
  String get multilogin;

  /// 设置入口按钮提示
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settings;

  /// 多拨页面标题
  ///
  /// In zh, this message translates to:
  /// **'多拨管理'**
  String get multiloginTitle;

  /// 添加 tab 按钮提示
  ///
  /// In zh, this message translates to:
  /// **'添加 tab'**
  String get addTab;

  /// 添加多拨按钮
  ///
  /// In zh, this message translates to:
  /// **'添加多拨'**
  String get addMultilogin;

  /// 全部登录按钮
  ///
  /// In zh, this message translates to:
  /// **'全部登录'**
  String get loginAll;

  /// 登录中状态文本
  ///
  /// In zh, this message translates to:
  /// **'登录中...'**
  String get loggingIn;

  /// 全部登出按钮
  ///
  /// In zh, this message translates to:
  /// **'全部登出'**
  String get logoutAll;

  /// 成功计数标签
  ///
  /// In zh, this message translates to:
  /// **'成功'**
  String get successCount;

  /// 失败计数标签
  ///
  /// In zh, this message translates to:
  /// **'失败'**
  String get failCount;

  /// 成功/失败计数格式
  ///
  /// In zh, this message translates to:
  /// **'成功: {success} | 失败: {fail}'**
  String successFailFormat(Object success, Object fail);

  /// 多拨空状态文本
  ///
  /// In zh, this message translates to:
  /// **'暂无多拨配置'**
  String get noMultiloginConfig;

  /// 多拨空状态提示
  ///
  /// In zh, this message translates to:
  /// **'点击下方按钮添加多拨 tab'**
  String get addMultiloginHint;

  /// 登录结果汇总标题
  ///
  /// In zh, this message translates to:
  /// **'登录结果汇总'**
  String get loginResults;

  /// 成功/失败统计
  ///
  /// In zh, this message translates to:
  /// **'成功 {success} / 失败 {fail}'**
  String successRate(Object success, Object fail);

  /// 添加多拨对话框标题
  ///
  /// In zh, this message translates to:
  /// **'添加多拨'**
  String get addMultiloginDialog;

  /// IP 地址输入框标签
  ///
  /// In zh, this message translates to:
  /// **'IP 地址'**
  String get ipAddress;

  /// IP 地址输入提示
  ///
  /// In zh, this message translates to:
  /// **'如 10.10.10.xxx'**
  String get ipAddressHint;

  /// IP/账号验证提示
  ///
  /// In zh, this message translates to:
  /// **'请至少填写 IP 或账号'**
  String get pleaseFillIpOrAccount;

  /// Tab 更新成功提示
  ///
  /// In zh, this message translates to:
  /// **'Tab 已更新'**
  String get tabUpdated;

  /// 确认删除对话框标题
  ///
  /// In zh, this message translates to:
  /// **'确认删除'**
  String get confirmDelete;

  /// 确认删除 tab 内容
  ///
  /// In zh, this message translates to:
  /// **'确定要删除这个多拨 tab 吗？'**
  String get confirmDeleteTab;

  /// 确认登出对话框标题
  ///
  /// In zh, this message translates to:
  /// **'确认登出'**
  String get confirmLogout;

  /// 确认登出所有内容
  ///
  /// In zh, this message translates to:
  /// **'确定要登出所有多拨 tab 吗？'**
  String get confirmLogoutAll;

  /// 设置页面标题
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settingsTitle;

  /// 保存设置按钮提示
  ///
  /// In zh, this message translates to:
  /// **'保存设置'**
  String get saveSettings;

  /// 登录参数区块标题
  ///
  /// In zh, this message translates to:
  /// **'登录参数'**
  String get loginParams;

  /// Portal 地址输入框标签
  ///
  /// In zh, this message translates to:
  /// **'Portal 地址 (esurfingurl)'**
  String get portalAddress;

  /// Portal 地址提示
  ///
  /// In zh, this message translates to:
  /// **'如 10.10.10.10:8080'**
  String get portalAddressHint;

  /// AC IP 输入框标签
  ///
  /// In zh, this message translates to:
  /// **'AC IP (wlanacip)'**
  String get acIp;

  /// AC IP 提示
  ///
  /// In zh, this message translates to:
  /// **'AC 控制器 IP'**
  String get acIpHint;

  /// 用户 IP 输入框标签
  ///
  /// In zh, this message translates to:
  /// **'用户 IP (wlanuserip)'**
  String get userIp;

  /// 用户 IP 提示
  ///
  /// In zh, this message translates to:
  /// **'用户分配 IP'**
  String get userIpHint;

  /// 自动获取参数按钮
  ///
  /// In zh, this message translates to:
  /// **'自动获取参数 (189.cn)'**
  String get autoFetchParams;

  /// 手动获取参数按钮
  ///
  /// In zh, this message translates to:
  /// **'手动获取参数'**
  String get manualFetchParams;

  /// 隧道配置区块标题
  ///
  /// In zh, this message translates to:
  /// **'隧道配置 (EasyTier)'**
  String get tunnelConfig;

  /// 共享密钥输入框标签
  ///
  /// In zh, this message translates to:
  /// **'共享密钥'**
  String get sharedKey;

  /// 共享密钥提示
  ///
  /// In zh, this message translates to:
  /// **'默认: Hello_InterKnot'**
  String get sharedKeyHint;

  /// 限速输入框标签
  ///
  /// In zh, this message translates to:
  /// **'限速'**
  String get speedLimit;

  /// 限速提示
  ///
  /// In zh, this message translates to:
  /// **'如 10MB/s（留空不限制）'**
  String get speedLimitHint;

  /// 启用 IPv6 开关
  ///
  /// In zh, this message translates to:
  /// **'启用 IPv6'**
  String get enableIpv6;

  /// 启用 IPv6 副标题
  ///
  /// In zh, this message translates to:
  /// **'隧道支持 IPv6 地址'**
  String get enableIpv6Subtitle;

  /// 启用网页下载开关
  ///
  /// In zh, this message translates to:
  /// **'启用网页下载'**
  String get enableWebDownload;

  /// 启用网页下载副标题
  ///
  /// In zh, this message translates to:
  /// **'外网可通过网页下载共享文件'**
  String get enableWebDownloadSubtitle;

  /// 使用自定义配置开关
  ///
  /// In zh, this message translates to:
  /// **'使用自定义配置'**
  String get useCustomConfig;

  /// 使用自定义配置副标题
  ///
  /// In zh, this message translates to:
  /// **'使用自定义 toml 配置文件'**
  String get useCustomConfigSubtitle;

  /// 自定义配置路径输入框标签
  ///
  /// In zh, this message translates to:
  /// **'自定义配置路径'**
  String get customConfigPath;

  /// 自定义配置路径提示
  ///
  /// In zh, this message translates to:
  /// **'toml 文件绝对路径'**
  String get customConfigPathHint;

  /// 配置管理区块标题
  ///
  /// In zh, this message translates to:
  /// **'配置管理'**
  String get configManagement;

  /// 清除所有配置按钮
  ///
  /// In zh, this message translates to:
  /// **'清除所有配置'**
  String get clearAllConfig;

  /// 打开配置目录按钮
  ///
  /// In zh, this message translates to:
  /// **'打开配置目录'**
  String get openConfigDir;

  /// 确认清除对话框标题
  ///
  /// In zh, this message translates to:
  /// **'确认清除'**
  String get confirmClear;

  /// 确认清除对话框内容
  ///
  /// In zh, this message translates to:
  /// **'确定要清除所有配置吗？\n\n这将重置所有设置、登录参数和隧道配置。\n密码数据不会被清除。'**
  String get confirmClearContent;

  /// 设置保存成功提示
  ///
  /// In zh, this message translates to:
  /// **'设置已保存'**
  String get settingsSaved;

  /// 保存失败提示
  ///
  /// In zh, this message translates to:
  /// **'保存失败'**
  String get saveFailed;

  /// 参数获取成功提示
  ///
  /// In zh, this message translates to:
  /// **'参数获取成功'**
  String get paramsFetchSuccess;

  /// 参数获取失败提示
  ///
  /// In zh, this message translates to:
  /// **'获取参数失败'**
  String get paramsFetchFailed;

  /// 配置清除成功提示
  ///
  /// In zh, this message translates to:
  /// **'配置已清除'**
  String get configCleared;

  /// 配置目录提示
  ///
  /// In zh, this message translates to:
  /// **'配置目录'**
  String get configDir;

  /// 无法打开配置目录提示
  ///
  /// In zh, this message translates to:
  /// **'无法打开配置目录'**
  String get cannotOpenConfigDir;

  /// 获取参数页面标题
  ///
  /// In zh, this message translates to:
  /// **'获取登录参数'**
  String get fetchParamsTitle;

  /// 保存到配置按钮
  ///
  /// In zh, this message translates to:
  /// **'保存到配置'**
  String get saveToConfig;

  /// 参数获取说明标题
  ///
  /// In zh, this message translates to:
  /// **'参数获取说明'**
  String get paramsInfo;

  /// 参数获取说明内容
  ///
  /// In zh, this message translates to:
  /// **'通过访问 189.cn 获取校园网 Portal 参数。\n参数获取成功后可手动编辑并保存到设置。'**
  String get paramsInfoContent;

  /// 获取参数按钮文本
  ///
  /// In zh, this message translates to:
  /// **'获取参数 (189.cn)'**
  String get fetchParamsButton;

  /// 获取中状态文本
  ///
  /// In zh, this message translates to:
  /// **'正在获取...'**
  String get fetchingParams;

  /// 连接 189.cn 状态
  ///
  /// In zh, this message translates to:
  /// **'正在连接 189.cn...'**
  String get connecting189;

  /// 参数获取成功状态
  ///
  /// In zh, this message translates to:
  /// **'参数获取成功！'**
  String get fetchSuccess;

  /// 获取失败状态
  ///
  /// In zh, this message translates to:
  /// **'获取失败'**
  String get fetchFailed;

  /// 获取异常状态
  ///
  /// In zh, this message translates to:
  /// **'获取异常'**
  String get fetchException;

  /// Portal 参数区块标题
  ///
  /// In zh, this message translates to:
  /// **'Portal 参数'**
  String get portalParams;

  /// 当前设备 IP 提示
  ///
  /// In zh, this message translates to:
  /// **'当前设备 IP'**
  String get currentDeviceIp;

  /// 操作区块标题
  ///
  /// In zh, this message translates to:
  /// **'操作'**
  String get actions;

  /// 清空字段按钮
  ///
  /// In zh, this message translates to:
  /// **'清空'**
  String get clearFields;

  /// 调试信息区块标题
  ///
  /// In zh, this message translates to:
  /// **'调试信息'**
  String get debugInfo;

  /// 获取 URL 标签
  ///
  /// In zh, this message translates to:
  /// **'获取 URL'**
  String get fetchUrl;

  /// 参数已保存提示
  ///
  /// In zh, this message translates to:
  /// **'参数已保存到设置'**
  String get paramsSavedToConfig;

  /// 清空后提示
  ///
  /// In zh, this message translates to:
  /// **'已清空，点击获取按钮重新获取'**
  String get clearedRetry;

  /// Dashboard 页面标题
  ///
  /// In zh, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// 移动端 Dashboard 占位
  ///
  /// In zh, this message translates to:
  /// **'Dashboard 仅桌面端可用'**
  String get dashboardDesktopOnly;

  /// 移动端 Dashboard 提示
  ///
  /// In zh, this message translates to:
  /// **'请在桌面端查看 EasyTier 节点状态和流量图表'**
  String get dashboardDesktopHint;

  /// EasyTier Dashboard 标题
  ///
  /// In zh, this message translates to:
  /// **'EasyTier Dashboard'**
  String get easytierDashboard;

  /// EasyTier 未运行状态
  ///
  /// In zh, this message translates to:
  /// **'EasyTier 未运行'**
  String get easytierNotRunning;

  /// 启动共享按钮
  ///
  /// In zh, this message translates to:
  /// **'启动共享'**
  String get startShare;

  /// 运行中状态
  ///
  /// In zh, this message translates to:
  /// **'运行中'**
  String get running;

  /// 共享模式标签
  ///
  /// In zh, this message translates to:
  /// **'共享模式'**
  String get shareMode;

  /// 隧道模式标签
  ///
  /// In zh, this message translates to:
  /// **'隧道模式'**
  String get tunnelMode;

  /// 无节点数据占位
  ///
  /// In zh, this message translates to:
  /// **'暂无节点数据'**
  String get noNodeData;

  /// 网络节点标题
  ///
  /// In zh, this message translates to:
  /// **'网络节点'**
  String get networkNodes;

  /// 在线状态
  ///
  /// In zh, this message translates to:
  /// **'在线'**
  String get online;

  /// 离线状态
  ///
  /// In zh, this message translates to:
  /// **'离线'**
  String get offline;

  /// 对等标签
  ///
  /// In zh, this message translates to:
  /// **'对等'**
  String get peers;

  /// 流量标签
  ///
  /// In zh, this message translates to:
  /// **'流量'**
  String get traffic;

  /// 网络流量标题
  ///
  /// In zh, this message translates to:
  /// **'网络流量'**
  String get networkTraffic;

  /// 下载标签
  ///
  /// In zh, this message translates to:
  /// **'下载'**
  String get download;

  /// 上传标签
  ///
  /// In zh, this message translates to:
  /// **'上传'**
  String get upload;

  /// 无流量数据占位
  ///
  /// In zh, this message translates to:
  /// **'暂无流量数据'**
  String get noTrafficData;

  /// 对等节点标题
  ///
  /// In zh, this message translates to:
  /// **'对等节点'**
  String get peerNodes;

  /// 无对等节点占位
  ///
  /// In zh, this message translates to:
  /// **'暂无对等节点连接'**
  String get noPeerConnected;

  /// 端点标签
  ///
  /// In zh, this message translates to:
  /// **'端点'**
  String get endpoint;

  /// 路由表标题
  ///
  /// In zh, this message translates to:
  /// **'路由表'**
  String get routeTable;

  /// 路由目标列
  ///
  /// In zh, this message translates to:
  /// **'目标'**
  String get routeDestination;

  /// 路由网关列
  ///
  /// In zh, this message translates to:
  /// **'网关'**
  String get routeGateway;

  /// 路由接口列
  ///
  /// In zh, this message translates to:
  /// **'接口'**
  String get routeInterface;

  /// 路由跃点列
  ///
  /// In zh, this message translates to:
  /// **'跃点'**
  String get routeMetric;

  /// 路由状态列
  ///
  /// In zh, this message translates to:
  /// **'状态'**
  String get routeStatus;

  /// 路由活跃状态
  ///
  /// In zh, this message translates to:
  /// **'活跃'**
  String get routeActive;

  /// 路由非活跃状态
  ///
  /// In zh, this message translates to:
  /// **'非活跃'**
  String get routeInactive;

  /// 共享页面标题
  ///
  /// In zh, this message translates to:
  /// **'共享'**
  String get share;

  /// 移动端 EasyTier 占位
  ///
  /// In zh, this message translates to:
  /// **'EasyTier 仅桌面端可用'**
  String get easytierDesktopOnly;

  /// EasyTier 共享标题
  ///
  /// In zh, this message translates to:
  /// **'EasyTier 共享'**
  String get easytierShare;

  /// 共享运行中状态
  ///
  /// In zh, this message translates to:
  /// **'共享服务运行中'**
  String get shareRunning;

  /// 共享未启动状态
  ///
  /// In zh, this message translates to:
  /// **'共享服务未启动'**
  String get shareNotRunning;

  /// 共享配置标题
  ///
  /// In zh, this message translates to:
  /// **'共享配置'**
  String get shareConfig;

  /// 网络密钥输入框标签
  ///
  /// In zh, this message translates to:
  /// **'网络密钥'**
  String get networkKey;

  /// 网络密钥提示
  ///
  /// In zh, this message translates to:
  /// **'输入共享密钥'**
  String get networkKeyHint;

  /// 网络密钥帮助文本
  ///
  /// In zh, this message translates to:
  /// **'客户端需要使用相同密钥连接'**
  String get networkKeyHelper;

  /// 网络名称标签
  ///
  /// In zh, this message translates to:
  /// **'网络名称'**
  String get networkName;

  /// 默认端口标签
  ///
  /// In zh, this message translates to:
  /// **'默认端口'**
  String get defaultPort;

  /// 虚拟 IP 标签
  ///
  /// In zh, this message translates to:
  /// **'虚拟 IP'**
  String get virtualIp;

  /// RPC 端口标签
  ///
  /// In zh, this message translates to:
  /// **'RPC 端口'**
  String get rpcPort;

  /// 停止共享按钮
  ///
  /// In zh, this message translates to:
  /// **'停止共享'**
  String get stopShare;

  /// 运行日志标题
  ///
  /// In zh, this message translates to:
  /// **'运行日志'**
  String get runningLogs;

  /// 隧道页面标题
  ///
  /// In zh, this message translates to:
  /// **'隧道'**
  String get tunnel;

  /// EasyTier 隧道标题
  ///
  /// In zh, this message translates to:
  /// **'EasyTier 隧道'**
  String get easytierTunnel;

  /// 隧道已连接状态
  ///
  /// In zh, this message translates to:
  /// **'隧道已连接'**
  String get tunnelConnected;

  /// 隧道未连接状态
  ///
  /// In zh, this message translates to:
  /// **'隧道未连接'**
  String get tunnelNotConnected;

  /// 连接配置标题
  ///
  /// In zh, this message translates to:
  /// **'连接配置'**
  String get connectionConfig;

  /// 对端 IP 输入框标签
  ///
  /// In zh, this message translates to:
  /// **'对端 IP 地址'**
  String get peerIpAddress;

  /// 对端 IP 提示
  ///
  /// In zh, this message translates to:
  /// **'输入服务器 IP 地址'**
  String get peerIpHint;

  /// 对端 IP 帮助文本
  ///
  /// In zh, this message translates to:
  /// **'EasyTier 服务端的 IP 地址'**
  String get peerIpHelper;

  /// 密钥一致性提示
  ///
  /// In zh, this message translates to:
  /// **'需要与服务端配置的密钥一致'**
  String get networkKeyMustMatch;

  /// 断开隧道按钮
  ///
  /// In zh, this message translates to:
  /// **'断开隧道'**
  String get disconnectTunnel;

  /// 连接隧道按钮
  ///
  /// In zh, this message translates to:
  /// **'连接隧道'**
  String get connectTunnel;

  /// 对端 IP 为空提示
  ///
  /// In zh, this message translates to:
  /// **'请输入对端 IP 地址'**
  String get pleaseEnterPeerIp;

  /// 隧道信息标题
  ///
  /// In zh, this message translates to:
  /// **'隧道信息'**
  String get tunnelInfo;

  /// 隧道日志标题
  ///
  /// In zh, this message translates to:
  /// **'隧道日志'**
  String get tunnelLogs;

  /// 看门狗未启用状态
  ///
  /// In zh, this message translates to:
  /// **'看门狗: 未启用'**
  String get watchdogNotEnabled;

  /// 看门狗检测中状态
  ///
  /// In zh, this message translates to:
  /// **'检测中...'**
  String get watchdogChecking;

  /// 看门狗运行中状态
  ///
  /// In zh, this message translates to:
  /// **'看门狗: 运行中'**
  String get watchdogRunning;

  /// 看门狗已断开状态
  ///
  /// In zh, this message translates to:
  /// **'看门狗: 已断开'**
  String get watchdogDisconnected;

  /// 看门狗未知状态
  ///
  /// In zh, this message translates to:
  /// **'看门狗: 未知'**
  String get watchdogUnknown;

  /// 启用看门狗提示
  ///
  /// In zh, this message translates to:
  /// **'点击启用看门狗'**
  String get watchdogEnable;

  /// 停用看门狗提示
  ///
  /// In zh, this message translates to:
  /// **'点击停用看门狗'**
  String get watchdogDisable;

  /// 检查更新状态
  ///
  /// In zh, this message translates to:
  /// **'正在检查更新...'**
  String get checkingUpdate;

  /// 远程停用提示
  ///
  /// In zh, this message translates to:
  /// **'应用已被远程停用，请检查更新'**
  String get appDisabled;

  /// 已是最新版本状态
  ///
  /// In zh, this message translates to:
  /// **'已是最新版本'**
  String get alreadyLatest;

  /// 发现新版本状态
  ///
  /// In zh, this message translates to:
  /// **'发现新版本 {version}'**
  String newVersionFound(Object version);

  /// 网络异常提示
  ///
  /// In zh, this message translates to:
  /// **'网络异常'**
  String get networkError;

  /// 检查失败提示
  ///
  /// In zh, this message translates to:
  /// **'检查失败'**
  String get checkFailed;

  /// 复制日志按钮提示
  ///
  /// In zh, this message translates to:
  /// **'复制全部日志'**
  String get copyAllLogs;

  /// 日志复制成功提示
  ///
  /// In zh, this message translates to:
  /// **'日志已复制到剪贴板'**
  String get logsCopied;

  /// 迁移完成摘要
  ///
  /// In zh, this message translates to:
  /// **'迁移完成：配置 {config} 项，Secret.dat 账号 {accounts} 个，Cred 账号 {cred} 个'**
  String migrationComplete(Object config, Object accounts, Object cred);

  /// 迁移失败提示
  ///
  /// In zh, this message translates to:
  /// **'迁移失败'**
  String get migrationFailed;

  /// 迁移跳过提示
  ///
  /// In zh, this message translates to:
  /// **'已迁移，跳过'**
  String get migrationSkipped;

  /// 系统设置区块标题
  ///
  /// In zh, this message translates to:
  /// **'系统设置'**
  String get systemSettings;

  /// No description provided for @launchAtStartupTitle.
  ///
  /// In zh, this message translates to:
  /// **'开机自启'**
  String get launchAtStartupTitle;

  /// No description provided for @launchAtStartupSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'登录 Windows 时自动启动绳网认证'**
  String get launchAtStartupSubtitle;

  /// No description provided for @launchAtStartupNotSupported.
  ///
  /// In zh, this message translates to:
  /// **'当前平台不支持开机自启（仅桌面端）'**
  String get launchAtStartupNotSupported;

  /// No description provided for @launchAtStartupEnabled.
  ///
  /// In zh, this message translates to:
  /// **'开机自启已启用'**
  String get launchAtStartupEnabled;

  /// No description provided for @launchAtStartupDisabled.
  ///
  /// In zh, this message translates to:
  /// **'开机自启已关闭'**
  String get launchAtStartupDisabled;

  /// No description provided for @launchAtStartupFailed.
  ///
  /// In zh, this message translates to:
  /// **'设置开机自启失败'**
  String get launchAtStartupFailed;

  /// No description provided for @minimizeToTrayTitle.
  ///
  /// In zh, this message translates to:
  /// **'关闭时最小化至托盘'**
  String get minimizeToTrayTitle;

  /// No description provided for @minimizeToTraySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'关闭窗口时隐藏到系统托盘；关闭后改为直接退出'**
  String get minimizeToTraySubtitle;

  /// No description provided for @minimizeToTrayNotSupported.
  ///
  /// In zh, this message translates to:
  /// **'当前平台不支持系统托盘'**
  String get minimizeToTrayNotSupported;

  /// No description provided for @minimizeToTrayEnabled.
  ///
  /// In zh, this message translates to:
  /// **'已设置为：关闭时最小化至托盘'**
  String get minimizeToTrayEnabled;

  /// No description provided for @minimizeToTrayDisabled.
  ///
  /// In zh, this message translates to:
  /// **'已设置为：关闭时直接退出'**
  String get minimizeToTrayDisabled;

  /// No description provided for @minimizeToTrayFailed.
  ///
  /// In zh, this message translates to:
  /// **'设置失败'**
  String get minimizeToTrayFailed;

  /// No description provided for @trayShowWindow.
  ///
  /// In zh, this message translates to:
  /// **'显示主窗口'**
  String get trayShowWindow;

  /// No description provided for @trayExit.
  ///
  /// In zh, this message translates to:
  /// **'退出'**
  String get trayExit;

  /// No description provided for @trayQuickExit.
  ///
  /// In zh, this message translates to:
  /// **'直接退出'**
  String get trayQuickExit;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
