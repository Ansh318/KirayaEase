import Flutter
import GoogleSignIn
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Explicit iOS Google Sign-In config (do not rely only on plist discovery).
    GIDSignIn.sharedInstance.configuration = GIDConfiguration(
      clientID: "902326938544-ij4aohamli3mumfogtpk9pst0j7jgjhm.apps.googleusercontent.com"
    )

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    NSLog("GoogleSignIn callback URL: \(url.absoluteString)")
    if GIDSignIn.sharedInstance.handle(url) {
      NSLog("GoogleSignIn handled callback successfully")
      return true
    }
    NSLog("GoogleSignIn did not handle callback, forwarding to Flutter")
    return super.application(app, open: url, options: options)
  }
}
