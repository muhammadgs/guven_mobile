import Flutter
import UIKit
import UserNotifications
import flutter_local_notifications
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Lets a notification show as a banner while the app is open, and routes
    // a tap on one back to Flutter. FlutterAppDelegate already implements
    // the delegate and forwards to the notifications plugin.
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate

    // The background notification check. BGTaskScheduler only accepts a
    // launch handler registered before launch finishes, so this cannot wait
    // for Dart. The identifier is listed in Info.plist and is
    // `kNotificationTask` in lib/src/features/notifications/application/
    // notification_background.dart; 15 minutes is a floor iOS treats as a
    // hint.
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: "az.guvenfinans.mobile.notifications",
      earliestBeginInSeconds: NSNumber(value: 15 * 60)
    )

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    // The background check runs in an engine of its own, with no plugins
    // until these hand it the same registrant the app uses.
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
