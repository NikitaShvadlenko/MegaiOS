import MEGADomain

@objc final class SearchNodeUseCaseOCWrapper: NSObject {
    let searchUC = SearchNodeUseCase(searchNodeRepository: SearchNodeRepository.newRepo)
    
    @objc func searchOnInShares(text: String, sortType: MEGASortOrderType) async throws -> [MEGANode]? {
        try await search(type: .inShares, text: text, sortType: sortType)
    }
    
    @objc func searchOnOutShares(text: String, sortType: MEGASortOrderType) async throws -> [MEGANode]? {
        try await search(type: .outShares, text: text, sortType: sortType)
    }
    
    @objc func searchOnPublicLinks(text: String, sortType: MEGASortOrderType) async throws -> [MEGANode]? {
        try await search(type: .publicLinks, text: text, sortType: sortType)
    }
    
    @objc func cancelSearch() {
        searchUC.cancelSearch() 
    }
    
    private func search(type: SearchNodeTypeEntity, text: String, sortType: MEGASortOrderType) async throws -> [MEGANode]? {
        let nodeArray = try await searchUC.search(type: type, text: text, sortType: sortType.toSortOrderEntity())
        return nodeArray.toMEGANodes(in: MEGASdk.shared)
    }
}
