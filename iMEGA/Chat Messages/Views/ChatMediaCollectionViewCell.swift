import MessageKit

class ChatMediaCollectionViewCell: MessageContentCell {

    open var imageView: UIImageView = {
        let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    // MARK: - Methods

    /// Responsible for setting up the constraints of the cell's subviews.
    open func setupConstraints() {
        imageView.autoPinEdgesToSuperviewEdges()
    }

    open override func setupSubviews() {
        super.setupSubviews()
        messageContainerView.addSubview(imageView)
        setupConstraints()
    }
    
    override func configure(with message: MessageType, at indexPath: IndexPath, and messagesCollectionView: MessagesCollectionView) {
        super.configure(with: message, at: indexPath, and: messagesCollectionView)
        
        guard let chatMessage = message as? ChatMessage else {
            return
        }
        let megaMessage = chatMessage.message

        
    }
}

open class ChatMediaCollectionViewSizeCalculator: MessageSizeCalculator {
    public override init(layout: MessagesCollectionViewFlowLayout? = nil) {
        super.init(layout: layout)
    }
    
    open override func messageContainerSize(for message: MessageType) -> CGSize {
        switch message.kind {
        case .custom:
            let maxWidth = messageContainerMaxWidth(for: message)
            guard let chatMessage = message as? ChatMessage else {
                return .zero
            }
           
            return CGSize(width: min(200, maxWidth), height: 80)
        default:
            fatalError("messageContainerSize received unhandled MessageDataType: \(message.kind)")
        }
    }
}
