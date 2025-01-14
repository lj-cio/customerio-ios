import Foundation

internal protocol SdkCredentialsStore: AutoMockable {
    var sharedInstanceSiteId: String? { get set }
    func load(siteId: String) -> SdkCredentials?
    func create(siteId: String, apiKey: String, region: Region) -> SdkCredentials
    func save(siteId: String, credentials: SdkCredentials)
}

// sourcery: InjectRegister = "SdkCredentialsStore"
internal class CIOSdkCredentialsStore: SdkCredentialsStore {
    private var keyValueStorage: KeyValueStorage

    internal init(keyValueStorage: KeyValueStorage) {
        self.keyValueStorage = keyValueStorage
    }

    var sharedInstanceSiteId: String? {
        get {
            keyValueStorage.string(siteId: keyValueStorage.sharedSiteId, forKey: .sharedInstanceSiteId)
        }
        set {
            keyValueStorage.setString(siteId: keyValueStorage.sharedSiteId, value: newValue,
                                      forKey: .sharedInstanceSiteId)
        }
    }

    func load(siteId: String) -> SdkCredentials? {
        // try to load the required params
        // else, return nil as we don't have enough information to perform any action in the SDK.
        guard let apiKey = keyValueStorage.string(siteId: siteId, forKey: .apiKey),
              let regionCode = keyValueStorage.string(siteId: siteId, forKey: .regionCode),
              let region = Region(rawValue: regionCode)
        else {
            return nil
        }

        return SdkCredentials(siteId: siteId,
                              apiKey: apiKey,
                              region: region)
    }

    func create(siteId: String, apiKey: String, region: Region) -> SdkCredentials {
        SdkCredentials(siteId: siteId, apiKey: apiKey, region: region)
    }

    func save(siteId: String, credentials: SdkCredentials) {
        keyValueStorage.setString(siteId: siteId, value: credentials.apiKey, forKey: .apiKey)
        keyValueStorage.setString(siteId: siteId, value: credentials.region.rawValue, forKey: .regionCode)

        appendSiteId(siteId)
    }

    /**
     Save all of the site ids given to the SDK. We are storing this because we may need to iterate all of the
     site ids in the future so let's capture them now so we have them.
     */
    internal func appendSiteId(_ siteId: String) {
        let existingSiteIds = keyValueStorage.string(siteId: keyValueStorage.sharedSiteId, forKey: .allSiteIds) ?? ""

        // Must convert String.Substring to String which is why we map()
        var allSiteIds = Set(existingSiteIds.split(separator: ",").map { String($0) })

        allSiteIds.insert(siteId)

        let newSiteIds = allSiteIds.joined(separator: ",")

        keyValueStorage.setString(siteId: keyValueStorage.sharedSiteId, value: newSiteIds, forKey: .allSiteIds)
    }
}
