import AppKit
import FastCalcUI

@main
struct FastCalcAppMain {
    static func main() {
        let application = NSApplication.shared
        let delegate = FastCalcAppController()
        application.delegate = delegate
        application.run()
    }
}
