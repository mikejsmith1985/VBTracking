// The parts of the build that Apple checks and no compiler does.
//
// A missing Info.plist key is not a compile error, not a test failure, and not visible on any
// screen. It surfaces as an ITMS warning in an email, hours after the build was uploaded --
// which is the slowest feedback loop in the whole project.
//
// So the ones that have bitten are checked here, where they cost a fifth of a second.
import Foundation
import Testing

@testable import VBCore

@Suite("What the build declares about itself")
struct ProjectConfigurationTests {
    private static var projectFile: String {
        get throws {
            let path = ShippedSources.repository.appendingPathComponent("ios/project.yml")
            return try String(contentsOf: path, encoding: .utf8)
        }
    }

    @Test("An app that declares a document type says how it opens one")
    func declaresHowItOpensADocument() throws {
        let project = try Self.projectFile
        guard project.contains("CFBundleDocumentTypes") else { return }

        // ITMS-90737: declaring a document type without this is a warning on every single
        // upload. It arrived by email, after the build had already gone to TestFlight.
        #expect(
            project.contains("LSSupportsOpeningDocumentsInPlace")
                || project.contains("UISupportsDocumentBrowser"),
            "a document type needs LSSupportsOpeningDocumentsInPlace or UISupportsDocumentBrowser"
        )
    }

    @Test("A file type the app owns is exported, so another app can recognise it")
    func exportsTheTypeItOwns() throws {
        let project = try Self.projectFile
        guard project.contains("CFBundleDocumentTypes") else { return }
        #expect(project.contains("UTExportedTypeDeclarations"))
    }

    @Test("Every radio the app uses has the string iOS shows before switching it on")
    func explainsEveryRadio() throws {
        let project = try Self.projectFile

        // A local-network connection without this string does not prompt and does not fail
        // loudly -- it simply never finds anybody, which is the hardest kind of broken.
        if project.contains("NSBonjourServices") {
            #expect(project.contains("NSLocalNetworkUsageDescription"))
        }
        if project.contains("NSLocalNetworkUsageDescription") {
            #expect(project.contains("NSBonjourServices"), "a usage string with no service finds nobody")
        }
    }

    @Test("Export compliance is answered at build time, on both apps")
    func answersExportCompliance() throws {
        let project = try Self.projectFile
        // Twice: once per app. Unanswered, every build lands in TestFlight marked "Missing
        // Compliance" and reaches nobody until somebody answers it again by hand.
        let answers = project.components(separatedBy: "INFOPLIST_KEY_ITSAppUsesNonExemptEncryption").count - 1
        #expect(answers >= 2, "the phone and the watch each need it")
    }

    @Test("Every bundle the build signs has a signing step that asks for its profile")
    func fetchesAProfileForEveryBundle() throws {
        let project = try Self.projectFile
        let pipeline = try String(
            contentsOf: ShippedSources.repository.appendingPathComponent("codemagic.yaml"),
            encoding: .utf8
        )

        // A target added without a call of its own is not a compile error and not a test
        // failure: the archive gets most of the way through and then refuses that one
        // target for want of a provisioning profile. That is a whole cloud build to find
        // out, which is why it is found here instead.
        for identifier in Self.bundleIdentifiers(in: project) {
            #expect(
                pipeline.contains("\"\(identifier)\""),
                "codemagic.yaml never asks for a profile for \(identifier)"
            )
        }
    }

    @Test("Nothing claims an App Group it never opens")
    func claimsNoUnusedAppGroup() throws {
        let project = try Self.projectFile
        guard project.contains("VBTrackerGlance:") else { return }

        // The lock screen extension is handed its state by the app through ActivityKit and
        // never opens the log itself. Claiming the group anyway asked Apple for a capability
        // this identifier had never been granted, and the archive refused outright.
        let glance = project.components(separatedBy: "VBTrackerGlance:")[1]
        let untilTheNextTarget = glance.components(separatedBy: "\n  VBTrackerWatch:")[0]
        #expect(
            !untilTheNextTarget.contains("application-groups"),
            "the lock screen extension reads nothing from the group it would be claiming"
        )
    }

    /// Every bundle identifier the project declares, in the order they appear.
    private static func bundleIdentifiers(in project: String) -> [String] {
        project.components(separatedBy: .newlines).compactMap { line in
            let key = "PRODUCT_BUNDLE_IDENTIFIER:"
            guard let range = line.range(of: key) else { return nil }
            let value = line[range.upperBound...].trimmingCharacters(in: .whitespaces)
            return value.isEmpty ? nil : value
        }
    }
}
