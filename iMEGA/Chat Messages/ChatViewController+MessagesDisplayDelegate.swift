import MessageKit

extension ChatViewController: MessagesDisplayDelegate {
    func backgroundColor(for message: MessageType,
                         at indexPath: IndexPath,
                         in messagesCollectionView: MessagesCollectionView) -> UIColor {
        
        guard let chatMessage = message as? ChatMessage else {
            return isFromCurrentSender(message: message) ? UIColor(fromHexString: "#009476") : UIColor(fromHexString: "#EEEEEE")
        }
        
        if chatMessage.message.isManagementMessage {
            return .clear
        }
        
        switch chatMessage.message.type {
        case .contact, .attachment:
            return .clear
        case .normal:
            if (chatMessage.message.content as NSString).mnz_isPureEmojiString() {
                return .clear
            }
            
            return isFromCurrentSender(message: message) ? UIColor(fromHexString: "#009476") : UIColor(fromHexString: "#EEEEEE")
            
        default:
            return isFromCurrentSender(message: message) ? UIColor(fromHexString: "#009476") : UIColor(fromHexString: "#EEEEEE")
            
        }
        
    }

    func textColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        return isFromCurrentSender(message: message) ? .white : .black
    }

    func messageStyle(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageStyle {
        return .custom { [weak self] containerView in
            guard let `self` = self else {
                return
            }
            
            containerView.layer.cornerRadius = 13.0
            containerView.layer.borderColor = self.isFromCurrentSender(message: message) ?  #colorLiteral(red: 0, green: 0.5803921569, blue: 0.462745098, alpha: 1).cgColor :  #colorLiteral(red: 0.8941176471, green: 0.9215686275, blue: 0.9176470588, alpha: 1).cgColor
            containerView.layer.borderWidth = 1
            
            guard let chatMessage = message as? ChatMessage else {
                return
            }
            if chatMessage.message.status == .sending || chatMessage.message.status == .sendingManual {
                containerView.alpha = 0.7
            } else {
                containerView.alpha = 1
            }
            
            if chatMessage.message.isManagementMessage {
                containerView.layer.borderColor = #colorLiteral(red: 0.8941176471, green: 0.9215686275, blue: 0.9176470588, alpha: 0).cgColor
                return
            }
            
            if chatMessage.message.type == .normal && (chatMessage.message.content as NSString).mnz_isPureEmojiString() {
                containerView.layer.borderColor = #colorLiteral(red: 0.8941176471, green: 0.9215686275, blue: 0.9176470588, alpha: 0).cgColor
            }
        }
    }

    func configureAccessoryView(_ accessoryView: UIView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        // Cells are reused, so only add a button here once. For real use you would need to
        // ensure any subviews are removed if not needed
        accessoryView.subviews.forEach { $0.removeFromSuperview() }
        accessoryView.backgroundColor = .clear
        
        guard shouldShowAccessoryView(for: message) else {
            return
        }

        let button = UIButton()
        button.setImage(#imageLiteral(resourceName: "forwardChat"), for: .normal)
        accessoryView.addSubview(button)
        button.frame = accessoryView.bounds
        button.isUserInteractionEnabled = false // respond to accessoryView tap through `MessageCellDelegate`
        accessoryView.layer.cornerRadius = accessoryView.frame.height / 2
    }
    
    func configureAvatarView(_ avatarView: AvatarView,
                             for message: MessageType,
                             at indexPath: IndexPath,
                             in messagesCollectionView: MessagesCollectionView) {
        if !isFromCurrentSender(message: message) {
            let chatInitials = initials(for: message)
            let avatar = Avatar(image: avatarImage(for: message), initials: chatInitials)
            avatarView.set(avatar: avatar)
            avatarView.isHidden = isFromCurrentSender(message: message)
        }
    }
    
    func enabledDetectors(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> [DetectorType] {
        return [.url, .address, .phoneNumber, .date, .transitInformation, .mention, .hashtag]
    }
    
    // MARK: - Private methods
    
    private func shouldShowAccessoryView(for message: MessageType) -> Bool {
        guard let chatMessage = message as? ChatMessage else { return false }
        
        return chatMessage.message.shouldShowForwardAccessory()
    }
}
