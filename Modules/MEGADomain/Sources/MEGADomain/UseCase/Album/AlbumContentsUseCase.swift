import Combine

public protocol AlbumContentsUseCaseProtocol {
    var updatePublisher: AnyPublisher<Void, Never> { get }
    func nodes(forAlbum album: AlbumEntity) async throws -> [NodeEntity]
}

public final class AlbumContentsUseCase: AlbumContentsUseCaseProtocol {
    private var albumContentsRepo: AlbumContentsUpdateNotifierRepositoryProtocol
    private let mediaUseCase: MediaUseCaseProtocol
    private let fileSearchRepo: FilesSearchRepositoryProtocol
    private let userAlbumRepo: UserAlbumRepositoryProtocol
    
    public let updatePublisher: AnyPublisher<Void, Never>
    private let updateSubject = PassthroughSubject<Void, Never>()
    
    public init(albumContentsRepo: AlbumContentsUpdateNotifierRepositoryProtocol, mediaUseCase: MediaUseCaseProtocol, fileSearchRepo: FilesSearchRepositoryProtocol, userAlbumRepo: UserAlbumRepositoryProtocol) {
        self.albumContentsRepo = albumContentsRepo
        self.mediaUseCase = mediaUseCase
        self.fileSearchRepo = fileSearchRepo
        self.userAlbumRepo = userAlbumRepo
        
        updatePublisher = AnyPublisher(updateSubject)
        
        self.albumContentsRepo.onAlbumReload = { [weak self] in
            self?.updateSubject.send()
        }
    }
    
    // MARK: Protocols
    
    public func nodes(forAlbum album: AlbumEntity) async throws -> [NodeEntity] {
        if album.systemAlbum {
            return try await filter(forAlbum: album)
        } else {
            return await userAlbumContent(by: album.id)
        }
    }
    
    // MARK: Private
    
    private func filter(forAlbum album: AlbumEntity) async throws -> [NodeEntity] {
        async let photos = try await fileSearchRepo.allPhotos()
        var nodes = [NodeEntity]()
        
        if album.type == .favourite {
            async let videos = try fileSearchRepo.allVideos()
            nodes = try await [photos, videos]
                .flatMap { $0 }
                .filter { $0.hasThumbnail && $0.isFavourite }
        } else if album.type == .raw {
            nodes = try await photos.filter { $0.hasThumbnail && mediaUseCase.isRawImage($0.name) }
        } else if album.type == .gif {
            nodes = try await photos.filter { $0.hasThumbnail && mediaUseCase.isGifImage($0.name) }
        }
        
        return nodes
    }
    
    private func userAlbumContent(by id: HandleEntity) async -> [NodeEntity] {
        await withTaskGroup(of: NodeEntity?.self) { group in
            let nodeIds = await userAlbumRepo.albumContent(by: id).map { $0.nodeId }
            nodeIds.forEach { handle in
                group.addTask { [weak self] in
                    await self?.fileSearchRepo.node(by: handle)
                }
            }
            
            return await group.reduce(into: [NodeEntity](), {
                if let node = $1 { $0.append(node) }
            })
        }
    }
}
