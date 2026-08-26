import 'profile_params.dart';
import 'sdk_auth_state.dart';
import 'sdk_authentication.dart';
import 'sdk_configuration.dart';
import 'sdk_critical_error.dart';
import 'sdk_theme.dart';
import 'starting_route.dart';
import 'zing_sdk_initializer_platform_interface.dart';

export 'profile_params.dart';
export 'sdk_auth_state.dart';
export 'sdk_authentication.dart';
export 'sdk_configuration.dart';
export 'sdk_critical_error.dart';
export 'sdk_theme.dart';
export 'starting_route.dart';
export 'zing_program_view.dart';

/// Public API for initializing and interacting with the native Zing SDK.
class ZingSdk {
  ZingSdk._();

  static final ZingSdk instance = ZingSdk._();

  /// Initializes the native SDK with optional [configuration] and [theme].
  Future<void> init({
    SdkConfiguration? configuration,
    SdkTheme? theme,
  }) {
    return ZingSdkInitializerPlatform.instance.init(
      configuration: configuration,
      theme: theme,
    );
  }

  /// Registers the entry point that re-initializes the SDK in a headless
  /// background isolate (used for Health Connect background sync when the app
  /// is launched in the background without an Activity).
  ///
  /// [setup] MUST be a top-level or static function annotated with
  /// `@pragma('vm:entry-point')`. It should call [init] (the same way you do on
  /// app startup). Call this once during normal app startup, e.g. in `main()`.
  Future<void> registerBackgroundSetup(Future<void> Function() setup) {
    return ZingSdkInitializerPlatform.instance.registerBackgroundSetup(setup);
  }

  /// Authenticates and starts a session using [authentication].
  Future<void> login(SdkAuthentication authentication) {
    return ZingSdkInitializerPlatform.instance.login(authentication);
  }

  /// Logs out from the native SDK.
  Future<void> logout() {
    return ZingSdkInitializerPlatform.instance.logout();
  }

  /// Opens one of the predefined SDK screens.
  Future<void> openScreen(StartingRoute route) {
    return ZingSdkInitializerPlatform.instance.openScreen(route);
  }

  /// Set profile paramethers to the native SDK.
  Future<void> setProfileParams(ProfileParams params) {
    return ZingSdkInitializerPlatform.instance.setProfileParams(params);
  }

  /// Stream of authentication state changes from the native SDK.
  Stream<SdkAuthState> get authState {
    return ZingSdkInitializerPlatform.instance.authStateStream;
  }

  /// Registers [callback] to receive critical SDK errors.
  set criticalErrorCallback(CriticalErrorCallback? callback) {
    ZingSdkInitializerPlatform.instance.setCriticalErrorCallback(callback);
  }
}
