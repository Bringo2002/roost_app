import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // TODO: Replace with your iOS Maps API key from Google Cloud Console.
    // Not wired to a gitignored config file (unlike Android) since this
    // project isn't currently building for iOS -- if that changes, move
    // this into an untracked .xcconfig and read it via Info.plist instead
    // of hardcoding it here.
    GMSServices.provideAPIKey("YOUR_IOS_MAPS_API_KEY")
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
