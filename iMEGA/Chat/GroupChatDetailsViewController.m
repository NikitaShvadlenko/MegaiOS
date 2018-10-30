#import "GroupChatDetailsViewController.h"

#import "UIImage+GKContact.h"
#import "SVProgressHUD.h"

#import "MEGAReachabilityManager.h"
#import "UIAlertAction+MNZCategory.h"
#import "UIImageView+MNZCategory.h"

#import "ChatRoomsViewController.h"
#import "ContactsViewController.h"
#import "CustomModalAlertViewController.h"
#import "GroupChatDetailsViewTableViewCell.h"

#import "MEGAInviteContactRequestDelegate.h"
#import "MEGANavigationController.h"
#import "MEGASdkManager.h"
#import "MEGAGlobalDelegate.h"
#import "MEGAArchiveChatRequestDelegate.h"
#import "MEGAChatGenericRequestDelegate.h"

@interface GroupChatDetailsViewController () <MEGAChatRequestDelegate, MEGAChatRoomDelegate, MEGAGlobalDelegate>

@property (weak, nonatomic) IBOutlet UIImageView *avatarImageView;
@property (weak, nonatomic) IBOutlet UILabel *nameLabel;
@property (weak, nonatomic) IBOutlet UILabel *emailLabel;

@property (weak, nonatomic) IBOutlet UITableView *tableView;

@property (weak, nonatomic) IBOutlet UIBarButtonItem *backBarButtonItem;

@property (weak, nonatomic) IBOutlet UIView *participantsHeaderView;
@property (weak, nonatomic) IBOutlet UILabel *participantsHeaderViewLabel;

@property (strong, nonatomic) NSMutableArray *participantsMutableArray;

@property (nonatomic, assign) BOOL openChatRoom;

@end

@implementation GroupChatDetailsViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.backBarButtonItem.image = self.backBarButtonItem.image.imageFlippedForRightToLeftLayoutDirection;
    self.navigationItem.leftBarButtonItem = self.backBarButtonItem;
    self.navigationItem.title = AMLocalizedString(@"info", @"A button label. The button allows the user to get more info of the current context");
    
    self.nameLabel.text = self.chatRoom.title;
    
    CGSize avatarSize = self.avatarImageView.frame.size;
    UIImage *avatarImage = [UIImage imageForName:self.chatRoom.title.uppercaseString size:avatarSize backgroundColor:[UIColor mnz_gray999999] textColor:[UIColor whiteColor] font:[UIFont mnz_SFUIRegularWithSize:(avatarSize.width/2.0f)]];
    self.avatarImageView.image = avatarImage;
    self.emailLabel.text = AMLocalizedString(@"groupChat", @"Label title for a group chat");
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if ([[self.navigationController.viewControllers objectAtIndex:self.navigationController.viewControllers.count-2] class] != [ChatRoomsViewController class]) {
        [[MEGASdkManager sharedMEGAChatSdk] addChatRoomDelegate:self.chatRoom.chatId delegate:self];
        self.openChatRoom = NO;
    } else {
        [[MEGASdkManager sharedMEGAChatSdk] openChatRoom:self.chatRoom.chatId delegate:self];
        self.openChatRoom = YES;
    }
    [[MEGASdkManager sharedMEGASdk] addMEGAGlobalDelegate:self];
    
    [self setParticipants];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (self.openChatRoom) {
        [[MEGASdkManager sharedMEGAChatSdk] closeChatRoom:self.chatRoom.chatId delegate:self];
    } else {
        [[MEGASdkManager sharedMEGAChatSdk] removeChatRoomDelegate:self.chatRoom.chatId delegate:self];
    }
    [[MEGASdkManager sharedMEGASdk] removeMEGAGlobalDelegate:self];
}

- (BOOL)hidesBottomBarWhenPushed {
    return YES;
}

#pragma mark - Private

- (void)setParticipants {
    self.participantsMutableArray = [[NSMutableArray alloc] init];
    for (NSUInteger i = 0; i < self.chatRoom.peerCount; i++) {
        uint64_t peerHandle = [self.chatRoom peerHandleAtIndex:i];
        if ([self.chatRoom peerPrivilegeByHandle:peerHandle] > MEGAChatRoomPrivilegeRm) {
            [self.participantsMutableArray addObject:[NSNumber numberWithUnsignedLongLong:peerHandle]];
        }
    }
    
    uint64_t myHandle = [[MEGASdkManager sharedMEGAChatSdk] myUserHandle];
    [self.participantsMutableArray addObject:[NSNumber numberWithUnsignedLongLong:myHandle]];
}

- (void)alertTextFieldDidChange:(UITextField *)sender {
    UIAlertController *alertController = (UIAlertController *)self.presentedViewController;
    if (alertController) {
        UITextField *textField = alertController.textFields.firstObject;
        UIAlertAction *rightButtonAction = alertController.actions.lastObject;
        BOOL enableRightButton = NO;
        if ((textField.text.length > 0) && ![textField.text isEqualToString:self.chatRoom.title] && ![[textField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] isEqualToString:@""] && ([textField.text lengthOfBytesUsingEncoding:NSUTF8StringEncoding] < 31)) {
            enableRightButton = YES;
        }
        rightButtonAction.enabled = enableRightButton;
    }
}

- (void)showClearChatHistoryAlert {
    UIAlertController *clearChatHistoryAlertController = [UIAlertController alertControllerWithTitle:AMLocalizedString(@"clearChatHistory", @"A button title to delete the history of a chat.") message:AMLocalizedString(@"clearTheFullMessageHistory", @"A confirmation message for a user to confirm that they want to clear the history of a chat.") preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:AMLocalizedString(@"cancel", @"Button title to cancel something") style:UIAlertActionStyleCancel handler:nil];
    
    UIAlertAction *continueAction = [UIAlertAction actionWithTitle:AMLocalizedString(@"continue", @"'Next' button in a dialog") style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        [[MEGASdkManager sharedMEGAChatSdk] clearChatHistory:self.chatRoom.chatId delegate:self];
    }];
    
    [clearChatHistoryAlertController addAction:cancelAction];
    [clearChatHistoryAlertController addAction:continueAction];
    
    [self presentViewController:clearChatHistoryAlertController animated:YES completion:nil];
}

- (void)showArchiveChatAlertAtIndexPath:(NSIndexPath *)indexPath {
    NSString *title = self.chatRoom.isArchived ? AMLocalizedString(@"unarchiveChatMessage", @"Confirmation message for user to confirm it will unarchive an archived chat.") : AMLocalizedString(@"archiveChatMessage", @"Confirmation message on archive chat dialog for user to confirm.");
    UIAlertController *archiveAlertController = [UIAlertController alertControllerWithTitle:title message:nil preferredStyle:UIAlertControllerStyleAlert];
    [archiveAlertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"cancel", @"Button title to cancel something") style:UIAlertActionStyleCancel handler:nil]];
    
    [archiveAlertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"ok", @"Button title to accept something") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        MEGAArchiveChatRequestDelegate *archiveChatRequesDelegate = [[MEGAArchiveChatRequestDelegate alloc] initWithCompletion:^(MEGAChatRoom *chatRoom) {
            self.chatRoom = chatRoom;
            [self.tableView reloadData];
        }];
        [[MEGASdkManager sharedMEGAChatSdk] archiveChat:self.chatRoom.chatId archive:!self.chatRoom.isArchived delegate:archiveChatRequesDelegate];
    }]];
    
    [self presentViewController:archiveAlertController animated:YES completion:nil];
}

- (void)showLeaveChatAlertAtIndexPath:(NSIndexPath *)indexPath {
    UIAlertController *leaveAlertController = [UIAlertController alertControllerWithTitle:AMLocalizedString(@"youWillNoLongerHaveAccessToThisConversation", @"Alert text that explains what means confirming the action 'Leave'") message:nil preferredStyle:UIAlertControllerStyleAlert];
    [leaveAlertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"cancel", @"Button title to cancel something") style:UIAlertActionStyleCancel handler:nil]];
    
    [leaveAlertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"leave", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [[MEGASdkManager sharedMEGAChatSdk] leaveChat:self.chatRoom.chatId];
    }]];
    
    [self presentViewController:leaveAlertController animated:YES completion:nil];
}

- (UIAlertAction *)sendParticipantContactRequestAlertActionForHandle:(uint64_t)userHandle {
    UIAlertAction *sendParticipantContactRequest = [UIAlertAction actionWithTitle:AMLocalizedString(@"addContact", @"Alert title shown when you select to add a contact inserting his/her email") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        if ([MEGAReachabilityManager isReachableHUDIfNot]) {
            MEGAInviteContactRequestDelegate *inviteContactRequestDelegate = [[MEGAInviteContactRequestDelegate alloc] initWithNumberOfRequests:1];
            [[MEGASdkManager sharedMEGASdk] inviteContactWithEmail:[self.chatRoom peerEmailByHandle:userHandle] message:@"" action:MEGAInviteActionAdd delegate:inviteContactRequestDelegate];
        }
    }];
    [sendParticipantContactRequest mnz_setTitleTextColor:[UIColor mnz_black333333]];
    return sendParticipantContactRequest;
}

- (void)addParticipant {
    MEGANavigationController *navigationController = [[UIStoryboard storyboardWithName:@"Contacts" bundle:nil] instantiateViewControllerWithIdentifier:@"ContactsNavigationControllerID"];
    ContactsViewController *contactsVC = navigationController.viewControllers.firstObject;
    contactsVC.contactsMode = ContactsModeChatAddParticipant;
    NSMutableDictionary *participantsMutableDictionary = [[NSMutableDictionary alloc] init];
    NSUInteger peerCount = self.chatRoom.peerCount;
    for (NSUInteger i = 0; i < peerCount; i++) {
        uint64_t peerHandle = [self.chatRoom peerHandleAtIndex:i];
        if ([self.chatRoom peerPrivilegeByHandle:peerHandle] > MEGAChatRoomPrivilegeRm) {
            [participantsMutableDictionary setObject:[NSNumber numberWithUnsignedLongLong:peerHandle] forKey:[NSNumber numberWithUnsignedLongLong:peerHandle]];
        }
    }
    contactsVC.participantsMutableDictionary = participantsMutableDictionary.copy;
    
    contactsVC.userSelected = ^void(NSArray *users) {
        for (NSInteger i = 0; i < users.count; i++) {
            MEGAUser *user = [users objectAtIndex:i];
            [[MEGASdkManager sharedMEGAChatSdk] inviteToChat:self.chatRoom.chatId user:user.handle privilege:MEGAChatRoomPrivilegeStandard delegate:self];
        }
    };
    
    [self presentViewController:navigationController animated:YES completion:nil];
}

#pragma mark - IBActions

- (IBAction)backAction:(UIBarButtonItem *)sender {
    [self.navigationController popViewControllerAnimated:YES];
}

- (IBAction)notificationsSwitchValueChanged:(UISwitch *)sender {
    //TODO: Enable/disable notifications
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 8;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger numberOfRows = 0;
    switch (section) {
        case 0:
            numberOfRows = (self.chatRoom.ownPrivilege >= MEGAChatRoomPrivilegeModerator) ? 1 : 0;
            break;
            
        case 1:
            numberOfRows = (self.chatRoom.ownPrivilege >= MEGAChatRoomPrivilegeModerator && self.chatRoom.isPublicChat) ? 1 : 0;
            break;
            
        case 2:
            numberOfRows = (self.chatRoom.ownPrivilege >= MEGAChatRoomPrivilegeModerator) ? 1 : 0;
            break;
            
        case 3:
            numberOfRows = 1;
            break;
            
        case 4:
            numberOfRows = (self.chatRoom.ownPrivilege >= MEGAChatRoomPrivilegeRo) ? 1 : 0;
            break;
            
        case 5:
            numberOfRows = (self.chatRoom.ownPrivilege >= MEGAChatRoomPrivilegeModerator && self.chatRoom.isPublicChat) ? 1 : 0;
            break;
            
        case 6:
            numberOfRows = self.chatRoom.isPublicChat ? 1 : 0;
            break;
            
        case 7:
            numberOfRows = self.participantsMutableArray.count;
            
            if (self.chatRoom.ownPrivilege == MEGAChatRoomPrivilegeModerator) {
                numberOfRows += 1;
            }
            break;
            
        default:
            break;
    }
    
    return numberOfRows;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    GroupChatDetailsViewTableViewCell *cell;
    
    if (indexPath.section != 7 && indexPath.section != 6) {
        cell = [self.tableView dequeueReusableCellWithIdentifier:@"GroupChatDetailsLeaveGroupTypeID" forIndexPath:indexPath];
    }
    
    switch (indexPath.section) {
        case 0:
            cell.leftImageView.image = [UIImage imageNamed:@"renameGroup"];
            cell.nameLabel.text = AMLocalizedString(@"renameGroup", @"The title of a menu button which allows users to rename a group chat.");
            break;
            
        case 1:
            cell.leftImageView.image = [UIImage imageNamed:@"Link_grey"];
            cell.nameLabel.text = AMLocalizedString(@"Get Chat Link", @"");
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            break;
            
        case 2:
            cell.leftImageView.image = [UIImage imageNamed:@"clearChatHistory"];
            cell.nameLabel.text = AMLocalizedString(@"clearChatHistory", @"A button title to delete the history of a chat.");
            break;
            
        case 3:
            cell.leftImageView.image = self.chatRoom.isArchived ? [UIImage imageNamed:@"unArchiveChat"] : [UIImage imageNamed:@"archiveChat_gray"];
            cell.nameLabel.text = self.chatRoom.isArchived ? AMLocalizedString(@"unarchiveChat", @"The title of the dialog to unarchive an archived chat.") : AMLocalizedString(@"archiveChat", @"Title of button to archive chats.");
            cell.nameLabel.textColor = self.chatRoom.isArchived ? UIColor.mnz_redMain : UIColor.mnz_black333333;
            break;
            
        case 4:
            cell.leftImageView.image = [UIImage imageNamed:@"leaveGroup"];
            cell.nameLabel.text = AMLocalizedString(@"leaveGroup", @"Button title that allows the user to leave a group chat.");
            cell.nameLabel.textColor = UIColor.mnz_redMain;            
            break;
                        
        case 5:
            cell.nameLabel.text = AMLocalizedString(@"Enable Encrypted Key Rotation", @"Title show in a cell where the users can enable the 'Encrypted Key Rotation'");
            break;
            
        case 6:
            cell = [self.tableView dequeueReusableCellWithIdentifier:@"GroupChatDetailsObserversTypeID" forIndexPath:indexPath];
            cell.leftImageView.image = [UIImage imageNamed:@"chatObservers"];
            cell.emailLabel.text = @"Observers";
            cell.rightLabel.text = [NSString stringWithFormat:@"%tu", self.chatRoom.previewersCount];
            break;
            
        case 7: {
            if ((indexPath.row == 0) && (self.chatRoom.ownPrivilege == MEGAChatRoomPrivilegeModerator)) {
                cell = [self.tableView dequeueReusableCellWithIdentifier:@"GroupChatDetailsParticipantEmailTypeID" forIndexPath:indexPath];
                cell.leftImageView.image = [UIImage imageNamed:@"inviteToChat"];
                cell.emailLabel.text = AMLocalizedString(@"addParticipant", @"Button label. Allows to add contacts in current chat conversation.");
                cell.onlineStatusView.backgroundColor = nil;
                cell.rightImageView.image = nil;
                
                return cell;
            }
            
            NSInteger index = (self.chatRoom.ownPrivilege == MEGAChatRoomPrivilegeModerator) ? (indexPath.row - 1) : indexPath.row;
            
            uint64_t handle = [[self.participantsMutableArray objectAtIndex:index] unsignedLongLongValue];
            NSString *peerFullname;
            NSString *peerEmail;
            MEGAChatRoomPrivilege privilege;
            if (handle == [[MEGASdkManager sharedMEGAChatSdk] myUserHandle]) {
                NSString *myFullname = [[MEGASdkManager sharedMEGAChatSdk] myFullname];
                peerFullname = [NSString stringWithFormat:@"%@ (%@)", myFullname, AMLocalizedString(@"me", @"The title for my message in a chat. The message was sent from yourself.")];
                peerEmail = [[MEGASdkManager sharedMEGAChatSdk] myEmail];
                privilege = self.chatRoom.ownPrivilege;
            } else {
                peerFullname = [self.chatRoom peerFullnameByHandle:handle];
                peerEmail = [self.chatRoom peerEmailByHandle:handle];
                privilege = [self.chatRoom peerPrivilegeAtIndex:index];
            }
            BOOL isNameEmpty = [[peerFullname stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] isEqualToString:@""];
            if (isNameEmpty) {
                cell = [self.tableView dequeueReusableCellWithIdentifier:@"GroupChatDetailsParticipantEmailTypeID" forIndexPath:indexPath];
            } else {
                cell = [self.tableView dequeueReusableCellWithIdentifier:@"GroupChatDetailsParticipantTypeID" forIndexPath:indexPath];
                cell.nameLabel.text = peerFullname;
            }
            
            [cell.leftImageView mnz_setImageForUserHandle:handle];
            cell.onlineStatusView.backgroundColor = [UIColor mnz_colorForStatusChange:[[MEGASdkManager sharedMEGAChatSdk] userOnlineStatus:handle]];
            
            cell.emailLabel.text = peerEmail;
            
            UIImage *permissionsImage = nil;
            switch (privilege) {
                case MEGAChatRoomPrivilegeUnknown:
                    break;
                    
                case MEGAChatRoomPrivilegeRm:
                    permissionsImage = nil;
                    break;
                    
                case MEGAChatRoomPrivilegeRo:
                    permissionsImage = [UIImage imageNamed:@"readPermissions"];
                    break;
                    
                case MEGAChatRoomPrivilegeStandard:
                    permissionsImage = [UIImage imageNamed:@"readWritePermissions"];
                    break;
                    
                case MEGAChatRoomPrivilegeModerator:
                    permissionsImage = [UIImage imageNamed:@"permissions"];
                    break;
            }
            cell.rightImageView.image = permissionsImage;
            break;
        }
            
        default:
            break;
    }
    
    return cell;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (section == 7) {
        self.participantsHeaderViewLabel.text = [AMLocalizedString(@"participants", @"Label to describe the section where you can see the participants of a group chat") uppercaseString];
        return self.participantsHeaderView;
    }
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (section == 7) return 24.0f;
    
    if (section == 6 && !self.chatRoom.isPublicChat) return 0.0f;
    
    if (self.chatRoom.ownPrivilege == MEGAChatRoomPrivilegeRm) {
        if (section == 3) {
            return 20.0f;
        } else {
            return 0.0f;
        }
    } else if (self.chatRoom.ownPrivilege >= MEGAChatRoomPrivilegeModerator) {
        if (section == 0) {
            return 20.0f;
        } else if (section == 1 && !self.chatRoom.isPublicChat) {
            return 0.0f;
        } else {
            return 10.0f;
        }
    } else {
        if (section == 3) {
            return 20.0f;
        } else if (section == 6) {
            return 10.0f;
        } else {
            return 0.0f;
        }
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    if (section == 7) return 20.0f;
    
    if (section == 6 && !self.chatRoom.isPublicChat) return 0.0f;
    
    if (self.chatRoom.ownPrivilege == MEGAChatRoomPrivilegeRm) {
        if (section == 3) {
            return 18.0f;
        } else {
            return 0.0f;
        }
    } else if (self.chatRoom.ownPrivilege >= MEGAChatRoomPrivilegeModerator) {
        if (section == 5) {
            if (self.chatRoom.isPublicChat) {
                return 70.0f;
            } else {
                return 0.0f;
            }
        } else if (section == 0 && !self.chatRoom.isPublicChat) {
            return 0.0f;
        } else {
            return 10.0f;
        }
    } else {
        if (section == 3) {
            return 10.0f;
        } else if (section == 6) {
            return 20.0f;
        } else {
            return 0.0f;
        }
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 5 && self.chatRoom.isPublicChat) {
        return AMLocalizedString(@"Key rotation is slightly more secure, but does not allow you to create a link to the chat and new participants will not see past messages.", @"Footer text to explain what means 'Encrypted Key Rotation'");
    }
    return nil;
}


#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat heightForRow;
    switch (indexPath.section) {
        case 0:
            heightForRow = (self.chatRoom.ownPrivilege >= MEGAChatRoomPrivilegeModerator) ? 44.0f : 0.0f;
            break;
            
        case 1:
            heightForRow = (self.chatRoom.ownPrivilege >= MEGAChatRoomPrivilegeModerator) ? 44.0f : 0.0f;
            break;
            
        case 2:
            heightForRow = (self.chatRoom.ownPrivilege >= MEGAChatRoomPrivilegeModerator) ? 44.0f : 0.0f;
            break;
            
        case 3:
            heightForRow = 44.0f;
            break;
            
        case 4:
            heightForRow = (self.chatRoom.ownPrivilege >= MEGAChatRoomPrivilegeRo) ? 44.0f : 0.0f;
            break;
            
        case 5:
            heightForRow = (self.chatRoom.ownPrivilege >= MEGAChatRoomPrivilegeModerator && self.chatRoom.isPublicChat) ? 44.0f : 0.0f;
            break;
            
        case 6:
            heightForRow = (self.chatRoom.isPublicChat) ? 60.0f : 0.0f;
            break;
            
        case 7:
            heightForRow = 60.0f;
            break;
            
        default:
            heightForRow = 0.0f;
            break;
    }
    
    return heightForRow;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.section) {
        case 0:
            if ([MEGAReachabilityManager isReachableHUDIfNot]) {
                UIAlertController *renameGroupAlertController = [UIAlertController alertControllerWithTitle:AMLocalizedString(@"renameGroup", @"The title of a menu button which allows users to rename a group chat.") message:AMLocalizedString(@"renameNodeMessage", @"Hint text to suggest that the user have to write the new name for the file or folder") preferredStyle:UIAlertControllerStyleAlert];
                
                [renameGroupAlertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
                    textField.text = self.chatRoom.title;
                    [textField addTarget:self action:@selector(alertTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
                }];
                
                UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:AMLocalizedString(@"cancel", @"Button title to cancel something") style:UIAlertActionStyleCancel handler:nil];
                
                UIAlertAction *renameAction = [UIAlertAction actionWithTitle:AMLocalizedString(@"rename", @"Title for the action that allows you to rename a file or folder") style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                    UITextField *textField = [[renameGroupAlertController textFields] firstObject];
                    NSString *newGroupName = textField.text;
                    [[MEGASdkManager sharedMEGAChatSdk] setChatTitle:self.chatRoom.chatId title:newGroupName delegate:self];
                }];
                
                [renameGroupAlertController addAction:cancelAction];
                [renameGroupAlertController addAction:renameAction];
                
                renameAction.enabled = NO;
                
                [self presentViewController:renameGroupAlertController animated:YES completion:nil];
            }
            break;
            
        case 1: {
            __block NSString *link;
            MEGAChatGenericRequestDelegate *delegate = [[MEGAChatGenericRequestDelegate alloc] initWithCompletion:^(MEGAChatRequest * _Nonnull request, MEGAChatError * _Nonnull error) {
                if (error.type == MEGAChatErrorTypeOk) {
                    link = request.text;
                } else {
                    MEGAChatGenericRequestDelegate *delegate = [[MEGAChatGenericRequestDelegate alloc] initWithCompletion:^(MEGAChatRequest * _Nonnull request, MEGAChatError * _Nonnull error) {
                        if (error.type == MEGAChatErrorTypeOk) {
                            link = request.text;
                        }
                    }];
                    [[MEGASdkManager sharedMEGAChatSdk] createChatLink:self.chatRoom.chatId delegate:delegate];
                }
            }];
            [[MEGASdkManager sharedMEGAChatSdk] queryChatLink:self.chatRoom.chatId delegate:delegate];

            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
            [alertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"copyLink", @"Title for a button to copy the link to the clipboard") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                if (link) {
                    [UIPasteboard generalPasteboard].string = link;
                    [SVProgressHUD showSuccessWithStatus:AMLocalizedString(@"copiedToTheClipboard", @"Text of the button after the links were copied to the clipboard")];
                } else {
                    [SVProgressHUD showErrorWithStatus:@"Error: link doesn't exist"];
                }
            }]];
            
            [alertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"Delete Chat Link", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                UIAlertController *deleteAlertController = [UIAlertController alertControllerWithTitle:AMLocalizedString(@"Delete Chat Link", nil) message:@"Lorem ipsum dolor sit amet, consectetur adipiscing elit." preferredStyle:UIAlertControllerStyleAlert];
                [deleteAlertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"continue", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    MEGAChatGenericRequestDelegate *delegate = [[MEGAChatGenericRequestDelegate alloc] initWithCompletion:^(MEGAChatRequest * _Nonnull request, MEGAChatError * _Nonnull error) {
                        if (!error.type) {
                            [SVProgressHUD showSuccessWithStatus:AMLocalizedString(@"linkRemoved", @"Message shown when the link to a file or folder has been removed")];
                        }
                    }];
                    [[MEGASdkManager sharedMEGAChatSdk] removeChatLink:self.chatRoom.chatId delegate:delegate];
                }]];
                [deleteAlertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
                [self presentViewController:deleteAlertController animated:YES completion:nil];
            }]];
            [alertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
            
            [self presentViewController:alertController animated:YES completion:nil];
            break;
        }
            
        case 2:
            [self showClearChatHistoryAlert];
            break;
            
        case 3:
            [self showArchiveChatAlertAtIndexPath:indexPath];
            break;
            
        case 4:
            [self showLeaveChatAlertAtIndexPath:indexPath];
            break;
            
        case 5: {
            CustomModalAlertViewController *customModalAlertVC = [[CustomModalAlertViewController alloc] init];
            customModalAlertVC.modalPresentationStyle = UIModalPresentationOverCurrentContext;
            // TODO: add the image as soon as design team share it.
            // customModalAlertVC.image = [UIImage imageNamed:];
            customModalAlertVC.viewTitle = AMLocalizedString(@"Enable Encrypted Key Rotation", @"Title show in a cell where the users can enable the 'Encrypted Key Rotation'");
            customModalAlertVC.detail = @"Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna.";
            customModalAlertVC.action = AMLocalizedString(@"enable", nil);
            customModalAlertVC.dismiss = AMLocalizedString(@"cancel", nil);
            __weak typeof(CustomModalAlertViewController) *weakCustom = customModalAlertVC;
            customModalAlertVC.completion = ^{
                MEGAChatGenericRequestDelegate *delegate = [[MEGAChatGenericRequestDelegate alloc] initWithCompletion:^(MEGAChatRequest * _Nonnull request, MEGAChatError * _Nonnull error) {
                    if (error.type == MEGAChatErrorTypeOk) {                        
                        [weakCustom dismissViewControllerAnimated:YES completion:^{
                            [self.tableView reloadData];
                        }];
                    }
                }];
                [[MEGASdkManager sharedMEGAChatSdk] setPublicChatToPrivate:self.chatRoom.chatId delegate:delegate];
            };
            
            [self presentViewController:customModalAlertVC animated:YES completion:nil];
            break;
        }
            
        case 7:
            if ((indexPath.row == 0) && (self.chatRoom.ownPrivilege == MEGAChatRoomPrivilegeModerator)) {
                [self addParticipant];
                [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
                return;
            }
            
            NSInteger index = (self.chatRoom.ownPrivilege == MEGAChatRoomPrivilegeModerator) ? (indexPath.row - 1) : indexPath.row;
            
            if (index != (self.participantsMutableArray.count - 1)) {
                uint64_t userHandle = [[self.participantsMutableArray objectAtIndex:index] unsignedLongLongValue];
                
                UIAlertController *permissionsAlertController = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
                UIAlertAction *cancelAlertAction = [UIAlertAction actionWithTitle:AMLocalizedString(@"cancel", @"Button title to cancel something") style:UIAlertActionStyleCancel handler:nil];
                [cancelAlertAction mnz_setTitleTextColor:UIColor.mnz_redMain];
                [permissionsAlertController addAction:cancelAlertAction];
                
                if (self.chatRoom.ownPrivilege == MEGAChatRoomPrivilegeModerator) {
                    
                    UIAlertAction *moderatorAlertAction = [UIAlertAction actionWithTitle:AMLocalizedString(@"moderator", @"The Moderator permission level in chat. With moderator permissions a participant can manage the chat.") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                        [[MEGASdkManager sharedMEGAChatSdk] updateChatPermissions:self.chatRoom.chatId userHandle:userHandle privilege:MEGAChatRoomPrivilegeModerator delegate:self];
                    }];
                    [moderatorAlertAction mnz_setTitleTextColor:[UIColor mnz_black333333]];
                    [permissionsAlertController addAction:moderatorAlertAction];
                    
                    UIAlertAction *standartAlertAction = [UIAlertAction actionWithTitle:AMLocalizedString(@"standard", @"The Standard permission level in chat. With the standard permissions a participant can read and type messages in a chat.") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                        [[MEGASdkManager sharedMEGAChatSdk] updateChatPermissions:self.chatRoom.chatId userHandle:userHandle privilege:MEGAChatRoomPrivilegeStandard delegate:self];
                    }];
                    [standartAlertAction mnz_setTitleTextColor:[UIColor mnz_black333333]];
                    [permissionsAlertController addAction:standartAlertAction];
                    
                    UIAlertAction *readOnlyAlertAction = [UIAlertAction actionWithTitle:AMLocalizedString(@"readOnly", @"Permissions given to the user you share your folder with") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                        [[MEGASdkManager sharedMEGAChatSdk] updateChatPermissions:self.chatRoom.chatId userHandle:userHandle privilege:MEGAChatRoomPrivilegeRo delegate:self];
                    }];
                    [readOnlyAlertAction mnz_setTitleTextColor:[UIColor mnz_black333333]];
                    [permissionsAlertController addAction:readOnlyAlertAction];
                    
                    MEGAUser *user = [[MEGASdkManager sharedMEGASdk] contactForEmail:[self.chatRoom peerEmailByHandle:userHandle]];
                    if (!user) {
                        [permissionsAlertController addAction:[self sendParticipantContactRequestAlertActionForHandle:userHandle]];
                    }
                    
                    UIAlertAction *removeParticipantAlertAction = [UIAlertAction actionWithTitle:AMLocalizedString(@"removeParticipant", @"A button title which removes a participant from a chat.") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                        [[MEGASdkManager sharedMEGAChatSdk] removeFromChat:self.chatRoom.chatId userHandle:userHandle delegate:self];
                    }];
                    [permissionsAlertController addAction:removeParticipantAlertAction];
                    
                    
                    if ([[UIDevice currentDevice] iPadDevice]) {
                        permissionsAlertController.modalPresentationStyle = UIModalPresentationPopover;
                        UIPopoverPresentationController *popoverPresentationController = [permissionsAlertController popoverPresentationController];
                        GroupChatDetailsViewTableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
                        popoverPresentationController.sourceRect = cell.contentView.frame;
                        popoverPresentationController.sourceView = cell.contentView;
                    }
                    
                } else {
                    MEGAUser *user = [[MEGASdkManager sharedMEGASdk] contactForEmail:[self.chatRoom peerEmailByHandle:userHandle]];
                    if (!user) {
                        [permissionsAlertController addAction:[self sendParticipantContactRequestAlertActionForHandle:userHandle]];
                    }
                }
                if (permissionsAlertController.actions.count > 1) {
                    [self presentViewController:permissionsAlertController animated:YES completion:nil];
                }
            }
            break;
            
        default:
            break;
    }
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - MEGAChatRequestDelegate

- (void)onChatRequestFinish:(MEGAChatSdk *)api request:(MEGAChatRequest *)request error:(MEGAChatError *)error {
    switch (request.type) {            
        case MEGAChatRequestTypeUpdatePeerPermissions: {
            if (error.type) {
                //TODO: Manage errors of update peer permissions request 
                return;
            }
            break;
        }
            
        default:
            break;
    }
}

- (void)onChatRoomUpdate:(MEGAChatSdk *)api chat:(MEGAChatRoom *)chat {
    MEGALogInfo(@"onChatRoomUpdate %@", chat);
    self.chatRoom = chat;
    switch (chat.changes) {
        case MEGAChatRoomChangeTypeStatus:
            break;
            
        case MEGAChatRoomChangeTypeUnreadCount:
            break;
            
        case MEGAChatRoomChangeTypeOwnPriv:
        case MEGAChatRoomChangeTypeParticipants:            
            [self setParticipants];
            [self.tableView reloadData];
            break;
            
        case MEGAChatRoomChangeTypeTitle:
            self.nameLabel.text = chat.title;
            break;
            
        case MEGAChatRoomChangeTypeUserTyping:
            break;
            
        case MEGAChatRoomChangeTypeClosed:
            [self.navigationController popToRootViewControllerAnimated:YES];
            break;
            
        case MEGAChatRoomChangeTypeUserStopTyping:
            break;
            
        case MEGAChatRoomChangeTypeUpdatePreviewers:
            [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:6]] withRowAnimation:UITableViewRowAnimationAutomatic];
            break;
            
        default:
            break;
    }
}

#pragma mark - MEGAGlobalDelegate

- (void)onUsersUpdate:(MEGASdk *)api userList:(MEGAUserList *)userList {
    [self setParticipants];
    BOOL reloadData = NO;
    for (NSInteger i = 0 ; i < userList.size.integerValue; i++) {
        MEGAUser *user = [userList userAtIndex:i];
        if (user.isOwnChange == 0) {
            reloadData = YES;
            break;
        }
    }
    if (reloadData) {
        [self.tableView reloadData];
    }
}

@end
