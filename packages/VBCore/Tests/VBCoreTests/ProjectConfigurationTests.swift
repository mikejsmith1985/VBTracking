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
}
