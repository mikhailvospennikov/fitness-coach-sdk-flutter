import Flutter
import UIKit
import DesignSystem
import ZingCoachSDK

public class ZingSdkInitializerPlugin: NSObject, FlutterPlugin {
    private var sdk: ZingSDK?
    private var authStateChannel: FlutterEventChannel?
    private var criticalErrorChannel: FlutterMethodChannel?

    private enum Channel {
        static let initializer = "zing_sdk_initializer"
        static let authState = "zing_sdk_initializer/auth_state"
        static let criticalErrorHandler = "zing_sdk_initializer/critical_error_handler"
    }

    private enum Method {
        static let initialize = "init"
        static let login = "login"
        static let logout = "logout"
        static let openScreen = "openScreen"
        static let setProfileParams = "setProfileParams"
    }

    private enum Route: String {
        case customWorkout = "custom_workout"
        case aiAssistant = "ai_assistant"
        case workoutPlanDetails = "workout_plan_details"
        case fullSchedule = "full_schedule"
        case home = "home"
        case profileSettings = "profile_settings"
        case bodyScan = "body_scan"
        case flexibilityTest = "flexibility_test"
        case fitnessTest = "fitness_test"
    }

    enum PluginError: Error {
        case notInitialized
        case alreadyInitialized
        case nativeInitFailed
        case loginFailed
        case missingRoute
        case unknownRoute(String)
        case noRootViewController
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        dispatchPrecondition(condition: .onQueue(.main))

        let initializerChannel = FlutterMethodChannel(
            name: Channel.initializer,
            binaryMessenger: registrar.messenger()
        )
        let authStateChannel = FlutterEventChannel(
            name: Channel.authState,
            binaryMessenger: registrar.messenger()
        )

        let instance = ZingSdkInitializerPlugin()
        instance.authStateChannel = authStateChannel
        instance.criticalErrorChannel = FlutterMethodChannel(
            name: Channel.criticalErrorHandler,
            binaryMessenger: registrar.messenger()
        )

        registrar.register(
            ZingProgramViewFactory(plugin: instance),
            withId: ZingProgramViewFactory.viewType
        )

        registrar.addMethodCallDelegate(instance, channel: initializerChannel)
    }

    @MainActor
    func makeProgramViewController() throws -> UIViewController {
        guard let sdk else { throw PluginError.notInitialized }
        return try sdk.makeScreen(.program)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case Method.initialize:
            handleInitialize(method: call, result)
        case Method.login:
            handleLogin(method: call, result)
        case Method.logout:
            handleLogout(result)
        case Method.openScreen:
            handleOpenScreen(method: call, result)
        case Method.setProfileParams:
            handleSetProfileParams(method: call, result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func handleInitialize(method: FlutterMethodCall, _ completion: @escaping FlutterResult) {
        guard sdk == nil else {
            completion(PluginError.alreadyInitialized.toFlutter())
            return
        }

        let args = method.arguments as? [String: Any] ?? [:]

        let configuration: ZingSDK.Configuration
        if let configDict = args["configuration"] as? [String: Any] {
            guard
                let coachesRaw = configDict["coachesAvailability"] as? String,
                let coaches = CoachesAvailability(rawValue: coachesRaw),
                let genderRaw = configDict["genderAvailability"] as? String,
                let gender = GenderAvailability(rawValue: genderRaw),
                let backgroundDeliveryEnabled = configDict["healthBackgroundSync"] as? Bool
            else {
                completion(PluginError.nativeInitFailed.toFlutter())
                return
            }
            configuration = ZingSDK.Configuration(
                coachesAvailability: coaches,
                genderAvailability: gender,
                ahBackgroundDeliveryEnabled: backgroundDeliveryEnabled
            )
        } else {
            configuration = ZingSDK.Configuration()
        }

        let theme = (args["theme"] as? [String: Any]).map { FlutterTheme(arguments: $0).build() }
        let parameters = ZingSDK.InitializationParameters(
            theme: theme,
            configuration: configuration
        )

        Task { @MainActor in
            do {
                let sdkInstance = try await ZingSDK.initialize(with: parameters)
                self.sdk = sdkInstance
                self.authStateChannel?.setStreamHandler(AuthStateStreamHandler(sdk: sdkInstance))
                sdkInstance.criticalErrorHandler = self.criticalErrorChannel
                    .map(CriticalErrorHandler.init(channel:))
                completion(nil)
            } catch {
                completion(PluginError.nativeInitFailed.toFlutter())
            }
        }
    }

    private func handleLogin(method: FlutterMethodCall, _ completion: @escaping FlutterResult) {
        guard let sdk else {
            completion(PluginError.notInitialized.toFlutter())
            return
        }

        guard
            let args = method.arguments as? [String: Any],
            let type = args["type"] as? String
        else {
            completion(PluginError.loginFailed.toFlutter())
            return
        }

        let authentication: ZingSDK.AuthenticationType
        switch type {
        case "apiKey":
            guard let key = args["apiKey"] as? String else {
                completion(PluginError.loginFailed.toFlutter())
                return
            }
            authentication = .apiKey(key: key, partnerUserID: args["partnerUserId"] as? String)
        case "externalToken":
            guard let token = args["jwtToken"] as? String else {
                completion(PluginError.loginFailed.toFlutter())
                return
            }
            authentication = .jwtToken(token: token)
        default:
            completion(PluginError.loginFailed.toFlutter())
            return
        }

        Task { @MainActor in
            do {
                try await sdk.login(with: authentication)
                completion(nil)
            } catch {
                completion(error.toFlutter())
            }
        }
    }

    private func handleLogout(_ completion: @escaping FlutterResult) {
        guard let sdk else {
            completion(PluginError.notInitialized.toFlutter())
            return
        }
        Task { @MainActor in
            do {
                try await sdk.logout()
                completion(nil)
            } catch {
                completion(error.toFlutter())
            }
        }
    }

    private func handleOpenScreen(method: FlutterMethodCall, _ completion: @escaping FlutterResult) {
        guard let sdk else {
            completion(PluginError.notInitialized.toFlutter())
            return
        }
        guard
            let args = method.arguments as? [String: Any],
            let rawRoute = args["route"] as? String
        else {
            completion(PluginError.missingRoute.toFlutter())
            return
        }
        guard let route = ZingSdkInitializerPlugin.Route(rawValue: rawRoute) else {
            completion(PluginError.unknownRoute(rawRoute).toFlutter())
            return
        }
        Task { @MainActor in
            do {
                let viewController = try makeViewController(for: route, sdk: sdk)
                presentViewController(viewController, completion: completion)
            } catch {
                completion(error.toFlutter())
            }
        }
    }

    private func handleSetProfileParams(method: FlutterMethodCall, _ completion: @escaping FlutterResult) {
        guard let sdk else {
            completion(PluginError.notInitialized.toFlutter())
            return
        }
        let args = method.arguments as? [String: Any] ?? [:]
        let parameters = ProfileParameters(
            name: args["name"] as? String,
            gender: (args["gender"] as? String).flatMap(ProfileParameters.UserGender.init(rawValue:)),
            height: args["height"] as? Double,
            weight: args["weight"] as? Double,
            age: args["age"] as? Int,
            measurementSystem: (args["measurementSystem"] as? String).flatMap(ProfileParameters.Unit.init(rawValue:))
        )
        do {
            try sdk.setProfileParams(parameters)
            completion(nil)
        } catch {
            completion(error.toFlutter())
        }
    }

    @MainActor
    private func makeViewController(
        for route: Route,
        sdk: ZingSDK
    ) throws(ZingSDK.ScreenPresentationError) -> UIViewController {
        switch route {
        case .customWorkout:
            try sdk.makeScreen(.customWorkout)
        case .aiAssistant:
            try sdk.makeScreen(.assistantChat)
        case .workoutPlanDetails:
            try sdk.makeScreen(.fullSchedule)
        case .fullSchedule:
            try sdk.makeScreen(.fullSchedule)
        case .home:
            try sdk.makeScreen(.program)
        case .profileSettings:
            try sdk.makeScreen(.profileSettings)
        case .bodyScan:
            try sdk.makeScreen(.bodyScan(useFrontCamera: true))
        case .flexibilityTest:
            try sdk.makeScreen(.flexibilityTest(useFrontCamera: true))
        case .fitnessTest:
            try sdk.makeScreen(.fitnessTest(useFrontCamera: true))
        }
    }

    @MainActor
    private func presentViewController(_ viewController: UIViewController, completion: @escaping FlutterResult) {
        guard
            let scene = UIApplication.shared.currentScene,
            let rootViewController = scene.keyWindow?.rootViewController
        else {
            completion(PluginError.noRootViewController.toFlutter())
            return
        }

        let presenter = rootViewController.topPresentedViewController.topInNavigationController
        viewController.modalPresentationStyle = .fullScreen
        presenter.present(viewController, animated: true)
        completion(nil)
    }

    private static func coachesAvailability(from raw: String) -> CoachesAvailability? {
        switch raw {
        case "allCoaches": .allCoaches
        case "userGenderBased": .userGenderBased
        default: nil
        }
    }

    private static func genderAvailability(from raw: String) -> GenderAvailability? {
        switch raw {
        case "all": .all
        case "binary": .binary
        default: nil
        }
    }
}
