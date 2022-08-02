import Foundation

final class OfflineFilesRepository: OfflineFilesRepositoryProtocol {
    static var newRepo: OfflineFilesRepository {
        OfflineFilesRepository(store: MEGAStore.shareInstance(), sdk: MEGASdkManager.sharedMEGASdk())
    }
    
    private let store: MEGAStore
    private let sdk: MEGASdk
        
    let offlineURL: URL? = URL(string: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first ?? "")
    
    init(store: MEGAStore, sdk: MEGASdk) {
        self.store = store
        self.sdk = sdk
    }
    
    func offlineFiles() -> [OfflineFileEntity] {
        guard let offlineNodes = store.fetchOfflineNodes(MEGAQuickAccessWidgetMaxDisplayItems as NSNumber, inRootFolder: true) else {
            return []
        }
        
        return offlineNodes.map {
            OfflineFileEntity(with: $0)
        }
    }
    
    func offlineFile(for base64Handle: Base64HandleEntity) -> OfflineFileEntity? {
        if let offlineNode = store.offlineNode(withHandle: base64Handle) {
            return OfflineFileEntity(with: offlineNode)
        } else {
            return nil
        }
    }
    
    func createOfflineFile(name: String, for handle: HandleEntity) {
        guard let node = sdk.node(forHandle: handle) else {
            return
        }
        store.insertOfflineNode(node, api: sdk, path: name)
    }
}
