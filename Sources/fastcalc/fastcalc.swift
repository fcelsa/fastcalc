import AppKit
import FastCalcUI

@main
struct FastCalcAppMain {
    static func main() {
        // Let Foundation resolve localization using system preferences,
        // including any per-app language override configured by the user.
        _ = LocalizationBootstrap.readSystemLocalizationConfiguration()

        let application = NSApplication.shared
        let delegate = FastCalcAppController()
        application.delegate = delegate
        application.run()
    }
}
