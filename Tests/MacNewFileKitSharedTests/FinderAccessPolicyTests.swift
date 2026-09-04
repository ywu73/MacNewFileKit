import Foundation
import Testing
@testable import MacNewFileKitShared

@Suite("FinderAccessPolicy")
struct FinderAccessPolicyTests {
    @Test("global Finder access is opt-in")
    func globalFinderAccessIsOptIn() {
        #expect(
            LocalFinderConfiguration(infoDictionary: [:]).accessMode
                == .authorizedDirectories
        )
        #expect(
            LocalFinderConfiguration(
                infoDictionary: ["MacNewFileKitLocalGlobalAccess": true]
            ).accessMode == .allLocalVolumes
        )
    }

    @Test("global Finder access monitors root and mounted volumes")
    func globalFinderAccessMonitorsRootAndMountedVolumes() {
        let authorized = Set([URL(fileURLWithPath: "/Users/test/Authorized")])
        let external = URL(fileURLWithPath: "/Volumes/External")
        let policy = FinderAccessPolicy(mode: .allLocalVolumes)

        #expect(
            policy.monitoringURLs(
                authorizedDirectoryURLs: authorized,
                mountedVolumeURLs: [external]
            ) == Set([URL(fileURLWithPath: "/"), external])
        )
        #expect(policy.permitsTarget(isWithinAuthorizedDirectory: false))
    }

    @Test("distribution Finder access remains authorization scoped")
    func distributionFinderAccessRemainsAuthorizationScoped() {
        let authorized = Set([URL(fileURLWithPath: "/Users/test/Authorized")])
        let policy = FinderAccessPolicy(mode: .authorizedDirectories)

        #expect(
            policy.monitoringURLs(
                authorizedDirectoryURLs: authorized,
                mountedVolumeURLs: [URL(fileURLWithPath: "/Volumes/External")]
            ) == authorized
        )
        #expect(!policy.permitsTarget(isWithinAuthorizedDirectory: false))
        #expect(policy.permitsTarget(isWithinAuthorizedDirectory: true))
    }
}
