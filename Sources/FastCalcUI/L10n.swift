import Foundation

enum L10n {
    // Prefer main bundle localizations in packaged .app builds.
    // Keep SwiftPM resource bundle fallbacks for `swift run` and other non-bundled executions.
    private static let localizedBundle: Bundle = {
        if bundleContainsLocalizableStrings(.main) {
            return .main
        }

        if let nestedBundleURL = Bundle.main.url(forResource: "fastcalc_fastcalc", withExtension: "bundle"),
           let nestedBundle = Bundle(url: nestedBundleURL),
           bundleContainsLocalizableStrings(nestedBundle)
        {
            return nestedBundle
        }

        let siblingBundleURL = URL(fileURLWithPath: Bundle.main.bundlePath)
            .deletingLastPathComponent()
            .appendingPathComponent("fastcalc_fastcalc.bundle")
        if let siblingBundle = Bundle(url: siblingBundleURL),
           bundleContainsLocalizableStrings(siblingBundle)
        {
            return siblingBundle
        }

        return .main
    }()

    // Keep this probe lightweight and explicit for supported locales.
    private static func bundleContainsLocalizableStrings(_ bundle: Bundle) -> Bool {
        bundle.url(forResource: "Localizable", withExtension: "strings", subdirectory: nil, localization: "en") != nil
            || bundle.url(forResource: "Localizable", withExtension: "strings", subdirectory: nil, localization: "it") != nil
    }

    private static func text(_ key: String, _ fallback: String, _ comment: String) -> String {
        NSLocalizedString(
            key,
            tableName: nil,
            bundle: localizedBundle,
            value: fallback,
            comment: comment
        )
    }

    private static func format(_ key: String, _ fallback: String, _ comment: String, _ args: CVarArg...) -> String {
        let localized = text(key, fallback, comment)
        return String(format: localized, locale: .current, arguments: args)
    }

    enum App {
        static var displayName: String { text("app.displayName", "FastCalc", "App display name") }
    }

    enum Menu {
        static var statusIconTitle: String { text("menu.status.iconTitle", "fc", "Status bar icon short label") }
        static var about: String { text("menu.app.about", "About FastCalc...", "App and status menu: About item") }
        static var settings: String { text("menu.app.settings", "Settings...", "App and status menu: Settings item") }
        static var fileSection: String { text("menu.section.file", "File", "Main menu section title") }
        static var editSection: String { text("menu.section.edit", "Edit", "Main menu section title") }
        static var viewSection: String { text("menu.section.view", "View", "Main menu section title") }
        static var print: String { text("menu.item.print", "Print...", "Menu item") }
        static var exportPdf: String { text("menu.item.exportPdf", "Export PDF...", "Menu item") }
        static var undo: String { text("menu.item.undo", "Undo", "Menu item") }
        static var redo: String { text("menu.item.redo", "Redo", "Menu item") }
        static var cut: String { text("menu.item.cut", "Cut", "Menu item") }
        static var copy: String { text("menu.item.copy", "Copy", "Menu item") }
        static var paste: String { text("menu.item.paste", "Paste", "Menu item") }
        static var copyText: String { text("menu.item.copyText", "Copy as text", "Menu item") }
        static var copyImage: String { text("menu.item.copyImage", "Copy as image", "Menu item") }
        static var moveToScreen: String { text("menu.item.moveToScreen", "Move to screen", "Menu item title") }
        static var quit: String { text("menu.item.quit", "Quit", "Status menu item") }

        static func toggleWithHotKey(_ hotKey: String) -> String {
            format(
                "menu.item.toggleWithHotKey",
                "Show/Hide (%1$@)",
                "Menu item with configured hotkey",
                hotKey
            )
        }

        static func quitWithAppName(_ appName: String) -> String {
            format(
                "menu.app.quitWithAppName",
                "Quit %1$@",
                "App menu: quit with app name",
                appName
            )
        }

        static func screen(_ index: Int) -> String {
            format(
                "menu.item.screen",
                "Screen %1$d",
                "Menu item for selecting screen index (1-based)",
                index
            )
        }
    }

    enum Settings {
        static var windowTitle: String { text("settings.window.title", "Settings", "Settings window title") }

        static var tabGeneral: String { text("settings.tab.general", "General", "Settings tab title") }
        static var tabFunctions: String { text("settings.tab.functions", "User functions", "Settings tab title") }

        static var buttonDefault: String { text("settings.button.default", "Default", "Settings button title") }
        static var buttonOk: String { text("settings.button.ok", "OK", "Settings button title") }
        static var buttonRegister: String { text("settings.button.register", "Record", "Button to start hotkey capture") }
        static var buttonCancel: String { text("settings.button.cancel", "Cancel", "Button to cancel current capture") }

        static var allSpaces: String { text("settings.checkbox.allSpaces", "Visible on all Spaces", "Checkbox title") }
        static var showTitleBar: String { text("settings.checkbox.showTitlebar", "Show title bar", "Checkbox title") }
        static var alwaysOnTop: String { text("settings.checkbox.alwaysOnTop", "Always on top", "Checkbox title") }
        static var menuBarIcon: String { text("settings.checkbox.menuBarIcon", "Menu bar icon", "Checkbox title") }
        static var dockIcon: String { text("settings.checkbox.dockIcon", "Dock icon", "Checkbox title") }
        static var resultOnly: String { text("settings.checkbox.resultOnly", "Result only", "Checkbox title") }

        static var decimalsLabel: String { text("settings.label.decimals", "Decimals", "Form label") }
        static var roundingLabel: String { text("settings.label.rounding", "Rounding", "Form label") }
        static var viewLabel: String { text("settings.label.view", "View", "Form label") }
        static var startupModeLabel: String { text("settings.label.startupMode", "Startup mode", "Inline label") }
        static var defaultScreenLabel: String { text("settings.label.defaultScreen", "Default screen", "Inline label") }
        static var hotKeyLabel: String { text("settings.label.hotKey", "Global hotkey", "Form label") }
        static var exampleLabel: String { text("settings.label.example", "Example", "Inline label") }
        static var functionNameLabel: String { text("settings.label.functionName", "Name", "Functions form label") }
        static var functionNoteLabel: String { text("settings.label.functionNote", "Note", "Functions form label") }
        static var functionExpressionLabel: String { text("settings.label.functionExpression", "Expression", "Functions form label") }
        static var activeOpacityLabel: String { text("settings.label.activeOpacity", "Active opacity", "Inline label") }
        static var inactiveOpacityLabel: String { text("settings.label.inactiveOpacity", "Inactive opacity", "Inline label") }

        static var decimalsFloatingOption: String { text("settings.popup.decimals.floating", "FL", "Decimals popup floating option") }
        static var roundingDown: String { text("settings.popup.rounding.down", "Down", "Rounding popup option") }
        static var roundingNearest: String { text("settings.popup.rounding.nearest", "Nearest", "Rounding popup option") }
        static var roundingUp: String { text("settings.popup.rounding.up", "Up", "Rounding popup option") }
        static var startupDefault: String { text("settings.popup.startup.default", "Default", "Startup popup option") }
        static var startupHidden: String { text("settings.popup.startup.hidden", "Hidden", "Startup popup option") }
        static var startupVisible: String { text("settings.popup.startup.visible", "Visible", "Startup popup option") }

        static var functionNamePlaceholder: String { text("settings.placeholder.functionName", "Function name", "Function field placeholder") }
        static var functionNotePlaceholder: String { text("settings.placeholder.functionNote", "Short note (max 12)", "Function field placeholder") }
        static var functionExpressionPlaceholder: String { text("settings.placeholder.functionExpression", "Expression with x, e.g. (x*1.22)+5", "Function field placeholder") }

        static var functionHint: String {
            text(
                "settings.hint.function",
                "Use x (or {x}) as current operand. Disable Result only to replay only keyboard-typeable expressions into the roll.",
                "Functions tab hint"
            )
        }

        static var hotKeyHintAvoidReserved: String {
            text(
                "settings.hint.hotKeyAvoidReserved",
                "Avoid combinations already used by the system (for example Cmd+Space, Cmd+Tab).",
                "Hotkey guidance"
            )
        }

        static var hotKeyHintPressNew: String {
            text(
                "settings.hint.hotKeyPressNew",
                "Press the new combination. Esc to cancel.",
                "Hotkey capture guidance"
            )
        }

        static var hotKeyHintRegistrationCancelled: String {
            text("settings.hint.hotKeyRegistrationCancelled", "Registration cancelled.", "Hotkey capture cancelled message")
        }

        static var hotKeyHintRestoredDefault: String {
            text("settings.hint.hotKeyRestoredDefault", "Hotkey restored to F16.", "Hotkey reset message")
        }

        static var iconVisibilityWarning: String {
            text(
                "settings.warning.iconVisibility",
                "If both icons are disabled, the only way to show the app again is the global hotkey.",
                "Warning shown when both menu bar and dock icons are disabled"
            )
        }

        static var screenSingleHint: String {
            text("settings.hint.screenSingle", "Option enabled only when multiple screens are connected.", "Hint for single-screen setups")
        }

        static var screenMultipleHint: String {
            text("settings.hint.screenMultiple", "Used for opening and window repositioning.", "Hint for multi-screen setups")
        }

        static var functionDefaultName: String { text("settings.function.defaultName", "New function", "Default name for a new user function") }
        static var functionDefaultExpression: String { text("settings.function.defaultExpression", "x", "Default expression for a new user function") }

        static var addActionAccessibility: String { text("settings.a11y.add", "Add", "Accessibility label for add button") }
        static var removeActionAccessibility: String { text("settings.a11y.remove", "Remove", "Accessibility label for remove button") }

        static func screen(_ index: Int) -> String {
            format(
                "settings.screen.item",
                "Screen %1$d",
                "Settings popup screen item (1-based)",
                index
            )
        }

        static func hotKeyUpdated(_ displayName: String) -> String {
            format(
                "settings.hint.hotKeyUpdated",
                "Hotkey updated: %1$@.",
                "Hotkey updated confirmation",
                displayName
            )
        }
    }

    enum MultiFunction {
        static var powersAndRootTitle: String { text("multifunction.p.title", "Powers and root", "P-trigger popover title") }
        static var squareTitle: String { text("multifunction.p.square.title", "x²", "Square action title") }
        static var squareDetail: String { text("multifunction.p.square.detail", "Power of 2", "Square action detail") }
        static var cubeTitle: String { text("multifunction.p.cube.title", "x³", "Cube action title") }
        static var cubeDetail: String { text("multifunction.p.cube.detail", "Power of 3", "Cube action detail") }
        static var powerNTitle: String { text("multifunction.p.powerN.title", "xⁿ", "Power-n action title") }
        static var powerNDetail: String { text("multifunction.p.powerN.detail", "^n integers only", "Power-n action detail") }
        static var squareRootTitle: String { text("multifunction.p.squareRoot.title", "√", "Square root action title") }
        static var squareRootDetail: String { text("multifunction.p.squareRoot.detail", "Square root", "Square root action detail") }
        static var userFunctionsTitle: String { text("multifunction.f.title", "User functions", "F-trigger popover title") }
    }

    enum Help {
        static var title: String { text("help.title", "Quick help", "Keyboard help popover title") }
        static var sectionInput: String { text("help.section.input", "INPUT", "Help section title") }
        static var sectionMultiFunction: String { text("help.section.multifunction", "MULTI-FUNCTION", "Help section title") }
        static var sectionCalc: String { text("help.section.calc", "CALCULATION & MEMORY", "Help section title") }
        static var sectionEdit: String { text("help.section.edit", "EDIT", "Help section title") }

        static var lineNumeric: String { text("help.line.numeric", "- 0-9 , . : numeric input", "Help line") }
        static var lineOperators: String { text("help.line.operators", "- + - * / D % : operators and percentages", "Help line") }
        static var lineP: String { text("help.line.p", "- P : powers and square root popover", "Help line") }
        static var lineF: String { text("help.line.f", "- F : user functions popover", "Help line") }
        static var lineH: String { text("help.line.h", "- H : show/hide this help", "Help line") }
        static var linePopoverSelect: String { text("help.line.popover.select", "- 1..9 / arrows / Enter / Esc : popover selection", "Help line") }
        static var lineResult: String { text("help.line.result", "- Enter or = or T : result", "Help line") }
        static var lineFifo: String { text("help.line.fifo", "- M / R : FIFO totalizer", "Help line") }
        static var lineBackspace: String { text("help.line.backspace", "- Backspace : delete one character", "Help line") }
        static var lineDelete: String { text("help.line.delete", "- Delete x2 : full reset", "Help line") }
        static var lineOptionDelete: String { text("help.line.optionDelete", "- Option + Delete x2 : reset + position", "Help line") }
        static var lineUndo: String { text("help.line.undo", "- Cmd+Z : undo full clear", "Help line") }
        static var empty: String { text("help.empty", "No commands available.", "Shown when help content is empty") }
    }

    enum About {
        static var windowTitle: String { text("about.window.title", "About", "About window title") }

        static var description: String {
            text("about.label.description", "Fast calculator with paper tape", "About window subtitle")
        }

        static var debugShortVersion: String {
            text("about.version.debugShort", "Debug session", "Fallback short version for debug runs")
        }

        static var debugBuildVersion: String {
            text("about.version.debugBuild", "swift run", "Fallback build version for debug runs")
        }

        static func versionLine(_ shortVersion: String, _ buildVersion: String) -> String {
            format(
                "about.version.line",
                "Ver. %1$@ (build %2$@)",
                "About window version line",
                shortVersion,
                buildVersion
            )
        }
    }

    enum Errors {
        static var pdfExportTitle: String { text("errors.pdfExport.title", "Unable to export PDF", "PDF export failure alert title") }
        static var pdfExportBody: String { text("errors.pdfExport.body", "An error occurred while exporting the tape.", "PDF export failure alert body") }

        static var hotKeyModifierOnly: String { text("errors.hotKey.modifierOnly", "Modifier-only keys are not allowed.", "Hotkey validation error") }
        static var hotKeyModifierRequired: String { text("errors.hotKey.modifierRequired", "For non-function keys, use at least one modifier (Cmd/Opt/Ctrl/Shift).", "Hotkey validation error") }
        static var hotKeyBlocked: String { text("errors.hotKey.blocked", "Reserved or too invasive combination: choose another hotkey.", "Hotkey validation error") }
        static var hotKeyLikelyReserved: String { text("errors.hotKey.likelyReserved", "Combination likely reserved by the system: verify it works on your Mac.", "Hotkey validation warning") }
    }

    enum Roll {
        static var exportPdfPanelTitle: String { text("roll.exportPdf.panelTitle", "Export PDF", "Save panel title") }

        static func statusGrandTotal(_ total: String) -> String {
            format(
                "roll.status.grandTotal",
                "GT: %1$@",
                "Status row grand total label",
                total
            )
        }

        static func statusQueuedGrandTotal(_ queueCount: Int, _ total: String) -> String {
            format(
                "roll.status.queuedGrandTotal",
                "%1$d GT: %2$@",
                "Status row with queued totalizer count and current total",
                queueCount,
                total
            )
        }

        static func exportPdfDefaultFileName(_ date: String) -> String {
            format(
                "roll.exportPdf.defaultFileName",
                "%1$@ FastCalc.pdf",
                "Default PDF file name: date + app name",
                date
            )
        }

        static func printHeaderVersion(_ version: String) -> String {
            format(
                "roll.print.header.version",
                "FastCalc ver. %1$@",
                "Printed header with app version",
                version
            )
        }

        static func printFooterPage(_ page: Int, _ totalPages: Int) -> String {
            format(
                "roll.print.footer.pageOf",
                "Page %1$d of %2$d",
                "Printed footer page indicator",
                page,
                totalPages
            )
        }
    }
}
