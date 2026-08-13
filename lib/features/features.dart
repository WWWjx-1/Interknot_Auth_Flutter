/// Feature modules - auth, watchdog, multilogin, easytier, settings, updater
library;

export 'auth/data/auth_dto.dart';
export 'auth/data/auth_repository.dart';
export 'auth/data/esurfing_api.dart';
export 'auth/domain/auth_state.dart';
export 'auth/application/auth_controller.dart';
export 'auth/presentation/login_page.dart';

// M4: 看门狗
export 'watchdog/application/watchdog_controller.dart';
export 'watchdog/presentation/watchdog_status_widget.dart';

// M4: 更新器
export 'updater/application/updater_controller.dart';

// M5: 多拨
export 'multilogin/application/multilogin_controller.dart';
export 'multilogin/presentation/multilogin_page.dart';

// M5: 设置
export 'settings/presentation/settings_page.dart';
export 'settings/presentation/params_page.dart';

// M6: EasyTier
export 'easytier/application/easytier_controller.dart';
export 'easytier/data/easytier_cli.dart';
export 'easytier/presentation/dashboard_page.dart';
export 'easytier/presentation/share_page.dart';
export 'easytier/presentation/tunnel_page.dart';
