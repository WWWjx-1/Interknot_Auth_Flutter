// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'InterKnot Auth';

  @override
  String get appTitleVersion => 'InterKnot Auth 2.0';

  @override
  String get appVersion => 'v2.0.0';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get exit => 'Exit';

  @override
  String get delete => 'Delete';

  @override
  String get save => 'Save';

  @override
  String get clear => 'Clear';

  @override
  String get add => 'Add';

  @override
  String get stop => 'Stop';

  @override
  String get logout => 'Logout';

  @override
  String get alreadyRunningTitle => 'Already Running';

  @override
  String get alreadyRunningContent =>
      'InterKnot Auth is already running. Please check the system tray.';

  @override
  String get confirmExitTitle => 'Confirm Exit';

  @override
  String get confirmExitContent =>
      'Are you sure you want to exit InterKnot Auth?\nNetwork authentication will be disconnected.';

  @override
  String get appExitLog => 'InterKnot Auth 2.0 exited';

  @override
  String get appStartLog => 'InterKnot Auth 2.0 started';

  @override
  String get systemInitComplete => 'M4 system integration initialized';

  @override
  String get autoStartConfigured => 'Auto-start configured';

  @override
  String get migrationChecking => 'Checking data migration...';

  @override
  String get alreadyRunningDetected => 'Another instance detected';

  @override
  String get watchdogAutoStart =>
      'Watchdog configured as enabled, auto-starting';

  @override
  String get account => 'Account';

  @override
  String get password => 'Password';

  @override
  String get login => 'Login';

  @override
  String get logoff => 'Logoff';

  @override
  String get processing => 'Processing...';

  @override
  String get rememberPassword => 'Remember Password';

  @override
  String get autoLogin => 'Auto Login';

  @override
  String get watchdog => 'Watchdog';

  @override
  String get autoShare => 'Auto Share';

  @override
  String get tMode => 'T-Mode';

  @override
  String get pleaseEnterAccount => 'Please enter account';

  @override
  String get pleaseEnterPassword => 'Please enter password';

  @override
  String get deleteAccount => 'Delete Account';

  @override
  String get deleteAccountTitle => 'Delete Account';

  @override
  String get accountDeleted => 'Account deleted';

  @override
  String get logTitle => 'Log';

  @override
  String get noLogs => 'No logs';

  @override
  String get clearLogs => 'Clear logs';

  @override
  String get ready => 'Ready';

  @override
  String get multilogin => 'Multi-Login';

  @override
  String get settings => 'Settings';

  @override
  String get multiloginTitle => 'Multi-Login Management';

  @override
  String get addTab => 'Add tab';

  @override
  String get addMultilogin => 'Add Multi-Login';

  @override
  String get loginAll => 'Login All';

  @override
  String get loggingIn => 'Logging in...';

  @override
  String get logoutAll => 'Logout All';

  @override
  String get successCount => 'Success';

  @override
  String get failCount => 'Fail';

  @override
  String successFailFormat(Object success, Object fail) {
    return 'Success: $success | Fail: $fail';
  }

  @override
  String get noMultiloginConfig => 'No multi-login configuration';

  @override
  String get addMultiloginHint =>
      'Click the button below to add a multi-login tab';

  @override
  String get loginResults => 'Login Results';

  @override
  String successRate(Object success, Object fail) {
    return 'Success $success / Fail $fail';
  }

  @override
  String get addMultiloginDialog => 'Add Multi-Login';

  @override
  String get ipAddress => 'IP Address';

  @override
  String get ipAddressHint => 'e.g. 10.10.10.xxx';

  @override
  String get pleaseFillIpOrAccount => 'Please fill in at least IP or Account';

  @override
  String get tabUpdated => 'Tab updated';

  @override
  String get confirmDelete => 'Confirm Delete';

  @override
  String get confirmDeleteTab =>
      'Are you sure you want to delete this multi-login tab?';

  @override
  String get confirmLogout => 'Confirm Logout';

  @override
  String get confirmLogoutAll =>
      'Are you sure you want to logout all multi-login tabs?';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get saveSettings => 'Save settings';

  @override
  String get loginParams => 'Login Parameters';

  @override
  String get portalAddress => 'Portal Address (esurfingurl)';

  @override
  String get portalAddressHint => 'e.g. 10.10.10.10:8080';

  @override
  String get acIp => 'AC IP (wlanacip)';

  @override
  String get acIpHint => 'AC controller IP';

  @override
  String get userIp => 'User IP (wlanuserip)';

  @override
  String get userIpHint => 'Assigned user IP';

  @override
  String get autoFetchParams => 'Auto Fetch Params (189.cn)';

  @override
  String get manualFetchParams => 'Manual Fetch Params';

  @override
  String get tunnelConfig => 'Tunnel Config (EasyTier)';

  @override
  String get sharedKey => 'Shared Key';

  @override
  String get sharedKeyHint => 'Default: Hello_InterKnot';

  @override
  String get speedLimit => 'Speed Limit';

  @override
  String get speedLimitHint => 'e.g. 10MB/s (blank for unlimited)';

  @override
  String get enableIpv6 => 'Enable IPv6';

  @override
  String get enableIpv6Subtitle => 'Tunnel supports IPv6 addresses';

  @override
  String get enableWebDownload => 'Enable Web Download';

  @override
  String get enableWebDownloadSubtitle =>
      'External network can download shared files via web';

  @override
  String get useCustomConfig => 'Use Custom Config';

  @override
  String get useCustomConfigSubtitle => 'Use custom toml config file';

  @override
  String get customConfigPath => 'Custom Config Path';

  @override
  String get customConfigPathHint => 'Absolute path to toml file';

  @override
  String get configManagement => 'Config Management';

  @override
  String get clearAllConfig => 'Clear All Config';

  @override
  String get openConfigDir => 'Open Config Directory';

  @override
  String get confirmClear => 'Confirm Clear';

  @override
  String get confirmClearContent =>
      'Are you sure you want to clear all config?\n\nThis will reset all settings, login parameters and tunnel config.\nPassword data will not be cleared.';

  @override
  String get settingsSaved => 'Settings saved';

  @override
  String get saveFailed => 'Save failed';

  @override
  String get paramsFetchSuccess => 'Params fetched successfully';

  @override
  String get paramsFetchFailed => 'Failed to fetch params';

  @override
  String get configCleared => 'Config cleared';

  @override
  String get configDir => 'Config directory';

  @override
  String get cannotOpenConfigDir => 'Cannot open config directory';

  @override
  String get fetchParamsTitle => 'Fetch Login Params';

  @override
  String get saveToConfig => 'Save to Config';

  @override
  String get paramsInfo => 'Parameter Info';

  @override
  String get paramsInfoContent =>
      'Fetch campus network Portal parameters via 189.cn.\nAfter successful fetch, you can manually edit and save to settings.';

  @override
  String get fetchParamsButton => 'Fetch Params (189.cn)';

  @override
  String get fetchingParams => 'Fetching...';

  @override
  String get connecting189 => 'Connecting to 189.cn...';

  @override
  String get fetchSuccess => 'Parameters fetched successfully!';

  @override
  String get fetchFailed => 'Fetch failed';

  @override
  String get fetchException => 'Fetch exception';

  @override
  String get portalParams => 'Portal Parameters';

  @override
  String get currentDeviceIp => 'Current Device IP';

  @override
  String get actions => 'Actions';

  @override
  String get clearFields => 'Clear';

  @override
  String get debugInfo => 'Debug Info';

  @override
  String get fetchUrl => 'Fetch URL';

  @override
  String get paramsSavedToConfig => 'Params saved to config';

  @override
  String get clearedRetry => 'Cleared, click fetch button to retry';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get dashboardDesktopOnly => 'Dashboard is desktop-only';

  @override
  String get dashboardDesktopHint =>
      'Please view EasyTier node status and traffic charts on desktop';

  @override
  String get easytierDashboard => 'EasyTier Dashboard';

  @override
  String get easytierNotRunning => 'EasyTier Not Running';

  @override
  String get startShare => 'Start Share';

  @override
  String get running => 'Running';

  @override
  String get shareMode => 'Share Mode';

  @override
  String get tunnelMode => 'Tunnel Mode';

  @override
  String get noNodeData => 'No node data';

  @override
  String get networkNodes => 'Network Nodes';

  @override
  String get online => 'Online';

  @override
  String get offline => 'Offline';

  @override
  String get peers => 'Peers';

  @override
  String get traffic => 'Traffic';

  @override
  String get networkTraffic => 'Network Traffic';

  @override
  String get download => 'Download';

  @override
  String get upload => 'Upload';

  @override
  String get noTrafficData => 'No traffic data';

  @override
  String get peerNodes => 'Peer Nodes';

  @override
  String get noPeerConnected => 'No peer connections';

  @override
  String get endpoint => 'Endpoint';

  @override
  String get routeTable => 'Route Table';

  @override
  String get routeDestination => 'Destination';

  @override
  String get routeGateway => 'Gateway';

  @override
  String get routeInterface => 'Interface';

  @override
  String get routeMetric => 'Metric';

  @override
  String get routeStatus => 'Status';

  @override
  String get routeActive => 'Active';

  @override
  String get routeInactive => 'Inactive';

  @override
  String get share => 'Share';

  @override
  String get easytierDesktopOnly => 'EasyTier is desktop-only';

  @override
  String get easytierShare => 'EasyTier Share';

  @override
  String get shareRunning => 'Share service running';

  @override
  String get shareNotRunning => 'Share service not started';

  @override
  String get shareConfig => 'Share Config';

  @override
  String get networkKey => 'Network Key';

  @override
  String get networkKeyHint => 'Enter shared key';

  @override
  String get networkKeyHelper => 'Client must use the same key to connect';

  @override
  String get networkName => 'Network Name';

  @override
  String get defaultPort => 'Default Port';

  @override
  String get virtualIp => 'Virtual IP';

  @override
  String get rpcPort => 'RPC Port';

  @override
  String get stopShare => 'Stop Share';

  @override
  String get runningLogs => 'Running Logs';

  @override
  String get tunnel => 'Tunnel';

  @override
  String get easytierTunnel => 'EasyTier Tunnel';

  @override
  String get tunnelConnected => 'Tunnel Connected';

  @override
  String get tunnelNotConnected => 'Tunnel Not Connected';

  @override
  String get connectionConfig => 'Connection Config';

  @override
  String get peerIpAddress => 'Peer IP Address';

  @override
  String get peerIpHint => 'Enter server IP address';

  @override
  String get peerIpHelper => 'IP address of the EasyTier server';

  @override
  String get networkKeyMustMatch => 'Must match the server\'s configured key';

  @override
  String get disconnectTunnel => 'Disconnect Tunnel';

  @override
  String get connectTunnel => 'Connect Tunnel';

  @override
  String get pleaseEnterPeerIp => 'Please enter peer IP address';

  @override
  String get tunnelInfo => 'Tunnel Info';

  @override
  String get tunnelLogs => 'Tunnel Logs';

  @override
  String get watchdogNotEnabled => 'Watchdog: Disabled';

  @override
  String get watchdogChecking => 'Checking...';

  @override
  String get watchdogRunning => 'Watchdog: Running';

  @override
  String get watchdogDisconnected => 'Watchdog: Disconnected';

  @override
  String get watchdogUnknown => 'Watchdog: Unknown';

  @override
  String get watchdogEnable => 'Click to enable watchdog';

  @override
  String get watchdogDisable => 'Click to disable watchdog';

  @override
  String get checkingUpdate => 'Checking for updates...';

  @override
  String get appDisabled =>
      'App has been remotely disabled, please check for updates';

  @override
  String get alreadyLatest => 'Already up to date';

  @override
  String newVersionFound(Object version) {
    return 'New version $version found';
  }

  @override
  String get networkError => 'Network error';

  @override
  String get checkFailed => 'Check failed';

  @override
  String get copyAllLogs => 'Copy all logs';

  @override
  String get logsCopied => 'Logs copied to clipboard';

  @override
  String migrationComplete(Object config, Object accounts, Object cred) {
    return 'Migration complete: $config config items, $accounts Secret.dat accounts, $cred Cred accounts';
  }

  @override
  String get migrationFailed => 'Migration failed';

  @override
  String get migrationSkipped => 'Already migrated, skipping';

  @override
  String get systemSettings => 'System';

  @override
  String get launchAtStartupTitle => 'Launch at startup';

  @override
  String get launchAtStartupSubtitle =>
      'Start InterKnot Auth automatically when you sign in';

  @override
  String get launchAtStartupNotSupported =>
      'Not supported on this platform (desktop only)';

  @override
  String get launchAtStartupEnabled => 'Launch at startup enabled';

  @override
  String get launchAtStartupDisabled => 'Launch at startup disabled';

  @override
  String get launchAtStartupFailed => 'Failed to set launch at startup';

  @override
  String get minimizeToTrayTitle => 'Minimize to tray on close';

  @override
  String get minimizeToTraySubtitle =>
      'Hide to system tray when closing; turn off to quit directly';

  @override
  String get minimizeToTrayNotSupported =>
      'System tray not supported on this platform';

  @override
  String get minimizeToTrayEnabled => 'Minimize to tray on close: enabled';

  @override
  String get minimizeToTrayDisabled => 'Quit directly on close: enabled';

  @override
  String get minimizeToTrayFailed => 'Failed to update';

  @override
  String get trayShowWindow => 'Show main window';

  @override
  String get trayExit => 'Exit';

  @override
  String get trayQuickExit => 'Quit now';
}
