#import "OfflineViewController.h"

#import "SVProgressHUD.h"
#import "UIScrollView+EmptyDataSet.h"

#import "NSString+MNZCategory.h"
#import "MEGANavigationController.h"
#import "MEGASdkManager.h"
#import "PreviewDocumentViewController.h"
#import "Helper.h"
#import "MEGAReachabilityManager.h"
#import "NSFileManager+MNZCategory.h"
#import "OfflineTableViewCell.h"
#import "OpenInActivity.h"
#import "SortByTableViewController.h"
#import "UIImageView+MNZCategory.h"

#import "MEGAStore.h"
#import "MEGAAVViewController.h"
#import "MEGAQLPreviewController.h"

static NSString *kFileName = @"kFileName";
static NSString *kIndex = @"kIndex";
static NSString *kPath = @"kPath";
static NSString *kModificationDate = @"kModificationDate";
static NSString *kFileSize = @"kFileSize";
static NSString *kisDirectory = @"kisDirectory";

@interface OfflineViewController () <UIViewControllerTransitioningDelegate, UIDocumentInteractionControllerDelegate, UISearchBarDelegate, UISearchResultsUpdating, UIViewControllerPreviewingDelegate, DZNEmptyDataSetSource, DZNEmptyDataSetDelegate, MEGATransferDelegate, MGSwipeTableCellDelegate, UITableViewDataSource, UITableViewDelegate> {
    NSString *previewDocumentPath;
    BOOL allItemsSelected;
}

@property (weak, nonatomic) IBOutlet UITableView *tableView;

@property (nonatomic) id<UIViewControllerPreviewing> previewingContext;

@property (nonatomic, strong) NSMutableArray *offlineSortedItems;
@property (nonatomic, strong) NSMutableArray *offlineFiles;
@property (nonatomic, strong) NSMutableArray *offlineMultimediaFiles;
@property (nonatomic, strong) NSMutableArray *offlineItems;

@property (nonatomic, strong) NSString *folderPathFromOffline;

@property (nonatomic, strong) NSMutableArray *selectedItems;

@property (weak, nonatomic) IBOutlet UIBarButtonItem *selectAllBarButtonItem;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *moreBarButtonItem;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *editBarButtonItem;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *sortByBarButtonItem;

@property (weak, nonatomic) IBOutlet UIToolbar *toolbar;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *activityBarButtonItem;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *deleteBarButtonItem;

@property (strong, nonatomic) UIDocumentInteractionController *documentInteractionController;

@property (nonatomic) NSMutableArray *searchItemsArray;
@property (nonatomic) UISearchController *searchController;

@end

@implementation OfflineViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.tableView.emptyDataSetSource = self;
    self.tableView.emptyDataSetDelegate = self;
    
    if (self.folderPathFromOffline == nil) {
        [self.navigationItem setTitle:AMLocalizedString(@"offline", @"Offline")];
    } else {
        NSString *currentFolderName = [self.folderPathFromOffline lastPathComponent];
        [self.navigationItem setTitle:currentFolderName];
    }
    
    UIBarButtonItem *flexibleItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    
    [self.toolbar setFrame:CGRectMake(0, 0, CGRectGetWidth(self.view.frame), 49)];
    [self.toolbar setItems:@[self.activityBarButtonItem, flexibleItem, self.deleteBarButtonItem]];
    
    self.editBarButtonItem.title = AMLocalizedString(@"edit", @"Caption of a button to edit the files that are selected");
    self.navigationItem.rightBarButtonItem = self.moreBarButtonItem;
    
    self.searchController = [Helper customSearchControllerWithSearchResultsUpdaterDelegate:self searchBarDelegate:self];
    [self.tableView setContentOffset:CGPointMake(0, CGRectGetHeight(self.searchController.searchBar.frame))];
    self.definesPresentationContext = YES;
    
    [self.view addGestureRecognizer:[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPress:)]];
    
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [[NSNotificationCenter defaultCenter] addObserver:self.tableView selector:@selector(reloadEmptyDataSet) name:kReachabilityChangedNotification object:nil];
    
    [[MEGASdkManager sharedMEGASdk] addMEGATransferDelegate:self];
    [[MEGASdkManager sharedMEGASdkFolder] addMEGATransferDelegate:self];
    [[MEGAReachabilityManager sharedManager] retryPendingConnections];
    [[MEGASdkManager sharedMEGASdkFolder] retryPendingConnections];
    
    // If the user has activated the logs, then they are imported to the offline section from the shared sandbox:
    if ([[[NSUserDefaults alloc] initWithSuiteName:@"group.mega.ios"] boolForKey:@"logging"]) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSString *logsPath = [[[fileManager containerURLForSecurityApplicationGroupIdentifier:@"group.mega.ios"] URLByAppendingPathComponent:@"logs"] path];
        if ([fileManager fileExistsAtPath:logsPath]) {
            NSString *documentProviderLog = @"MEGAiOS.docExt.log";
            NSString *fileProviderLog = @"MEGAiOS.fileExt.log";
            NSString *shareExtensionLog = @"MEGAiOS.shareExt.log";
            [fileManager mnz_removeItemAtPath:[[self currentOfflinePath] stringByAppendingPathComponent:documentProviderLog]];
            [fileManager copyItemAtPath:[logsPath stringByAppendingPathComponent:documentProviderLog]  toPath:[[self currentOfflinePath] stringByAppendingPathComponent:documentProviderLog] error:nil];
            [fileManager mnz_removeItemAtPath:[[self currentOfflinePath] stringByAppendingPathComponent:fileProviderLog]];
            [fileManager copyItemAtPath:[logsPath stringByAppendingPathComponent:fileProviderLog] toPath:[[self currentOfflinePath] stringByAppendingPathComponent:fileProviderLog] error:nil];
            [fileManager mnz_removeItemAtPath:[[self currentOfflinePath] stringByAppendingPathComponent:shareExtensionLog]];
            [fileManager copyItemAtPath:[logsPath stringByAppendingPathComponent:shareExtensionLog] toPath:[[self currentOfflinePath] stringByAppendingPathComponent:shareExtensionLog] error:nil];
        }
    }
    
    if (!self.tableView.tableHeaderView) {
        self.tableView.tableHeaderView = self.searchController.searchBar;
    }
    
    [self reloadUI];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self.tableView name:kReachabilityChangedNotification object:nil];
    
    [[MEGASdkManager sharedMEGASdk] removeMEGATransferDelegate:self];
    [[MEGASdkManager sharedMEGASdkFolder] removeMEGATransferDelegate:self];
    
    if (self.tableView.isEditing) {
        self.selectedItems = nil;
        [self setTableViewEditing:NO animated:NO];
    }
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        [self.tableView reloadEmptyDataSet];
    } completion:nil];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    
    if ([self.traitCollection respondsToSelector:@selector(forceTouchCapability)]) {
        if (self.traitCollection.forceTouchCapability == UIForceTouchCapabilityAvailable) {
            if (!self.previewingContext) {
                self.previewingContext = [self registerForPreviewingWithDelegate:self sourceView:self.view];
            }
        } else {
            [self unregisterForPreviewingWithContext:self.previewingContext];
            self.previewingContext = nil;
        }
    }
}

- (void)willTransitionToTraitCollection:(UITraitCollection *)newCollection withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super willTransitionToTraitCollection:newCollection withTransitionCoordinator:coordinator];
    
    [coordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        if (UIDevice.currentDevice.iPhone4X || UIDevice.currentDevice.iPhone5X) {
            CGRect frame = [UIApplication sharedApplication].keyWindow.rootViewController.view.frame;
            if (frame.size.width > frame.size.height) {
                CGFloat oldWidth = frame.size.width;
                frame.size.width = frame.size.height;
                frame.size.height = oldWidth;
                [UIApplication sharedApplication].keyWindow.rootViewController.view.frame = frame;
            }
        }
    }];
}

#pragma mark - Private

- (void)reloadUI {
    self.offlineSortedItems = [[NSMutableArray alloc] init];
    self.offlineFiles = [[NSMutableArray alloc] init];
    self.offlineMultimediaFiles = [[NSMutableArray alloc] init];
    self.offlineItems = [[NSMutableArray alloc] init];
    
    NSString *directoryPathString = [self currentOfflinePath];
    NSArray *directoryContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directoryPathString error:NULL];
    
    int offsetIndex = 0;
    for (int i = 0; i < (int)[directoryContents count]; i++) {
        NSString *filePath = [directoryPathString stringByAppendingPathComponent:[directoryContents objectAtIndex:i]];
        NSString *fileName = [NSString stringWithFormat:@"%@", [directoryContents objectAtIndex:i]];
        
        // Inbox folder in documents folder is created by the system. Don't show it
        if ([[[Helper pathForOffline] stringByAppendingPathComponent:@"Inbox"] isEqualToString:filePath]) {
            continue;
        }
        
        if (![fileName.lowercaseString.pathExtension isEqualToString:@"mega"]) {
            
            NSMutableDictionary *tempDictionary = [NSMutableDictionary new];
            [tempDictionary setValue:fileName forKey:kFileName];
            [tempDictionary setValue:[NSNumber numberWithInt:offsetIndex] forKey:kIndex];
            [tempDictionary setValue:[NSURL fileURLWithPath:filePath] forKey:kPath];
            
            NSDictionary *filePropertiesDictionary = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
            BOOL isDirectory;
            [[NSFileManager defaultManager] fileExistsAtPath:filePath isDirectory:&isDirectory];
            
            [tempDictionary setValue:[NSNumber numberWithBool:isDirectory] forKey:kisDirectory];
            
            [tempDictionary setValue:[filePropertiesDictionary objectForKey:NSFileSize] forKey:kFileSize];
            [tempDictionary setValue:[filePropertiesDictionary valueForKey:NSFileModificationDate] forKey:kModificationDate];
            
            [self.offlineItems addObject:tempDictionary];
            
            if (!isDirectory) {
                if (!fileName.mnz_isMultimediaPathExtension) {
                    offsetIndex++;
                }
            }
        }
    }
    
    //Sort configuration by default is "default ascending"
    if (![[NSUserDefaults standardUserDefaults] integerForKey:@"OfflineSortOrderType"]) {
        [[NSUserDefaults standardUserDefaults] setInteger:1 forKey:@"OfflineSortOrderType"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    MEGASortOrderType sortOrderType = [[NSUserDefaults standardUserDefaults] integerForKey:@"OfflineSortOrderType"];
    [self sortBySortType:sortOrderType];
    
    offsetIndex = 0;
    for (NSDictionary *p in self.offlineItems) {
        NSURL *fileURL = [p objectForKey:kPath];
        NSString *fileName = [p objectForKey:kFileName];
        
        // Inbox folder in documents folder is created by the system. Don't show it
        if ([[[Helper pathForOffline] stringByAppendingPathComponent:@"Inbox"] isEqualToString:[fileURL path]]) {
            continue;
        }
        
        if (![fileName.lowercaseString.pathExtension isEqualToString:@"mega"]) {
            
            NSMutableDictionary *tempDictionary = [NSMutableDictionary new];
            [tempDictionary setValue:fileName forKey:kFileName];
            [tempDictionary setValue:[NSNumber numberWithInt:offsetIndex] forKey:kIndex];
            [tempDictionary setValue:fileURL forKey:kPath];
            
            NSDictionary *filePropertiesDictionary = [[NSFileManager defaultManager] attributesOfItemAtPath:[fileURL path] error:nil];
            BOOL isDirectory;
            [[NSFileManager defaultManager] fileExistsAtPath:[fileURL path] isDirectory:&isDirectory];
            
            [tempDictionary setValue:[NSNumber numberWithBool:isDirectory] forKey:kisDirectory];
            
            [tempDictionary setValue:[filePropertiesDictionary objectForKey:NSFileSize] forKey:kFileSize];
            [tempDictionary setValue:[filePropertiesDictionary valueForKey:NSFileModificationDate] forKey:kModificationDate];
            
            [self.offlineSortedItems addObject:tempDictionary];
            
            if (!isDirectory) {
                if (fileName.mnz_isMultimediaPathExtension) {
                    AVURLAsset *asset = [AVURLAsset assetWithURL:fileURL];
                    if (asset.playable) {
                        [self.offlineMultimediaFiles addObject:[fileURL path]];
                    } else {
                        offsetIndex++;
                        [self.offlineFiles addObject:[fileURL path]];                        
                    }
                } else {
                    offsetIndex++;
                    [self.offlineFiles addObject:[fileURL path]];
                }
            }
        }
    }
    
    if ([self.offlineSortedItems count] == 0) {
        self.tableView.tableHeaderView = nil;
    } else {
        if (!self.tableView.tableHeaderView) {
            self.tableView.tableHeaderView = self.searchController.searchBar;
        }
    }
    
    [self updateNavigationBarTitle];
    
    [self.tableView reloadData];
}

- (NSString *)currentOfflinePath {
    NSString *pathString = [Helper pathForOffline];
    if (self.folderPathFromOffline != nil) {
        pathString = [pathString stringByAppendingPathComponent:self.folderPathFromOffline];
    }
    return pathString;
}

- (NSString *)folderPathFromOffline:(NSString *)absolutePath folder:(NSString *)folderName {
    
    NSArray *directoryPathComponents = [absolutePath pathComponents];
    NSUInteger directoryPathComponentsCount = directoryPathComponents.count;
    
    NSString *documentDirectory = [[Helper pathForOffline] lastPathComponent];
    NSUInteger documentsDirectoryPosition = 0;
    for (NSUInteger i = 0; i < directoryPathComponentsCount; i++) {
        NSString *folderString = [directoryPathComponents objectAtIndex:i];
        if ([folderString isEqualToString:documentDirectory]) {
            documentsDirectoryPosition = i;
            break;
        }
    }
    
    NSUInteger numberOfChildFolders = (directoryPathComponentsCount - (documentsDirectoryPosition + 1));
    NSIndexSet *indexSet = [[NSIndexSet alloc] initWithIndexesInRange:NSMakeRange((documentsDirectoryPosition + 1), numberOfChildFolders)];
    NSArray *childFoldersArray = [directoryPathComponents objectsAtIndexes:indexSet];
    
    NSString *pathFromOffline = @"";
    if (childFoldersArray.count > 1) {
        for (NSString *folderString in childFoldersArray) {
            pathFromOffline = [pathFromOffline stringByAppendingPathComponent:folderString];
        }
    } else {
        pathFromOffline = folderName;
    }
    
    return pathFromOffline;
}

- (NSArray *)offlinePathOnFolder:(NSString *)path {
    NSString *relativePath = [Helper pathRelativeToOfflineDirectory:path];
    NSMutableArray *offlinePathsOnFolder = [[NSMutableArray alloc] init];
    
    NSArray *directoryContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:nil];
    for (NSString *item in directoryContents) {
        NSDictionary *attributesDictionary = [[NSFileManager defaultManager] attributesOfItemAtPath:[path stringByAppendingPathComponent:item] error:nil];
        if ([attributesDictionary objectForKey:NSFileType] == NSFileTypeDirectory) {
            [offlinePathsOnFolder addObject:[relativePath stringByAppendingPathComponent:item]];
            [offlinePathsOnFolder addObjectsFromArray:[self offlinePathOnFolder:[path stringByAppendingPathComponent:item]]];
        } else {
            [offlinePathsOnFolder addObject:[relativePath stringByAppendingPathComponent:item]];
        }
    }
    
    return offlinePathsOnFolder;
}

- (void)cancelPendingTransfersOnFolder:(NSString *)folderPath folderLink:(BOOL)isFolderLink {
    MEGATransferList *transferList;
    NSInteger transferListSize;
    if (isFolderLink) {
        transferList = [[MEGASdkManager sharedMEGASdkFolder] transfers];
        transferListSize = [transferList.size integerValue];
    } else {
        transferList = [[MEGASdkManager sharedMEGASdk] transfers];
        transferListSize = [transferList.size integerValue];
    }
    
    for (NSInteger i = 0; i < transferListSize; i++) {
        MEGATransfer *transfer = [transferList transferAtIndex:i];
        if (transfer.type == MEGATransferTypeUpload) {
            continue;
        }
        
        if ([transfer.parentPath isEqualToString:[folderPath stringByAppendingString:@"/"]]) {
            if (isFolderLink) {
                [[MEGASdkManager sharedMEGASdkFolder] cancelTransferByTag:transfer.tag];
            } else {
                [[MEGASdkManager sharedMEGASdk] cancelTransferByTag:transfer.tag];
            }
        } else {
            NSString *lastPathComponent = [folderPath lastPathComponent];
            NSArray *pathComponentsArray = [transfer.parentPath pathComponents];
            NSUInteger pathComponentsArrayCount = [pathComponentsArray count];
            for (NSUInteger j = 0; j < pathComponentsArrayCount; j++) {
                NSString *folderString = [pathComponentsArray objectAtIndex:j];
                if ([folderString isEqualToString:lastPathComponent]) {
                    if (isFolderLink) {
                        [[MEGASdkManager sharedMEGASdkFolder] cancelTransferByTag:transfer.tag];
                    } else {
                        [[MEGASdkManager sharedMEGASdk] cancelTransferByTag:transfer.tag];
                    }
                    break;
                }
            }
        }
    }
}

- (BOOL)isDirectorySelected {
    BOOL isDirectory = NO;
    for (NSURL *url in self.selectedItems) {
        [[NSFileManager defaultManager] fileExistsAtPath:url.path isDirectory:&isDirectory];
        if (isDirectory) {
            return isDirectory;
        }
    }
    return isDirectory;
}

- (void)sortBySortType:(MEGASortOrderType)sortOrderType {
    NSSortDescriptor *sortDescriptor = nil;
    NSSortDescriptor *sortDirectoryDescriptor = nil;
    
    switch (sortOrderType) {
        case MEGASortOrderTypeDefaultAsc:
            sortDescriptor = [[NSSortDescriptor alloc] initWithKey:kFileName ascending:YES selector:@selector(localizedStandardCompare:)];
            sortDirectoryDescriptor = [[NSSortDescriptor alloc] initWithKey:kisDirectory ascending:NO];
            break;
        case MEGASortOrderTypeDefaultDesc:
            sortDescriptor = [[NSSortDescriptor alloc] initWithKey:kFileName ascending:NO selector:@selector(localizedStandardCompare:)];
            sortDirectoryDescriptor = [[NSSortDescriptor alloc] initWithKey:kisDirectory ascending:YES];
            break;
        case MEGASortOrderTypeSizeAsc:
            sortDescriptor = [[NSSortDescriptor alloc] initWithKey:kFileSize ascending:YES];
            sortDirectoryDescriptor = [[NSSortDescriptor alloc] initWithKey:kisDirectory ascending:NO];
            break;
        case MEGASortOrderTypeSizeDesc:
            sortDescriptor = [[NSSortDescriptor alloc] initWithKey:kFileSize ascending:NO];
            sortDirectoryDescriptor = [[NSSortDescriptor alloc] initWithKey:kisDirectory ascending:YES];
            break;
        case MEGASortOrderTypeModificationAsc:
            sortDescriptor = [[NSSortDescriptor alloc] initWithKey:kModificationDate ascending:YES];
            sortDirectoryDescriptor = [[NSSortDescriptor alloc] initWithKey:kisDirectory ascending:NO];
            break;
        case MEGASortOrderTypeModificationDesc:
            sortDescriptor = [[NSSortDescriptor alloc] initWithKey:kModificationDate ascending:NO];
            sortDirectoryDescriptor = [[NSSortDescriptor alloc] initWithKey:kisDirectory ascending:YES];
            break;
            
        default:
            break;
    }
    
    NSArray *sortDescriptors = [NSArray arrayWithObjects:sortDirectoryDescriptor, sortDescriptor, nil];
    NSArray *sortedArray = [self.offlineItems sortedArrayUsingDescriptors:sortDescriptors];
    self.offlineItems = [NSMutableArray arrayWithArray:sortedArray];
}

- (NSDictionary *)itemAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *item = nil;
    if (indexPath) {
        if (self.searchController.isActive) {
            item = [self.searchItemsArray objectAtIndex:indexPath.row];
        } else {
            item = [self.offlineSortedItems objectAtIndex:indexPath.row];
        }
    }
    return item;
}

- (BOOL)removeOfflineNodeCell:(NSString *)itemPath {
    NSArray *offlinePathsOnFolderArray;
    MOOfflineNode *offlineNode;
    
    BOOL isDirectory;
    [[NSFileManager defaultManager] fileExistsAtPath:itemPath isDirectory:&isDirectory];
    if (isDirectory) {
        if ([[[[MEGASdkManager sharedMEGASdk] transfers] size] integerValue] != 0) {
            [self cancelPendingTransfersOnFolder:itemPath folderLink:NO];
        }
        if ([[[[MEGASdkManager sharedMEGASdkFolder] transfers] size] integerValue] != 0) {
            [self cancelPendingTransfersOnFolder:itemPath folderLink:YES];
        }
        offlinePathsOnFolderArray = [self offlinePathOnFolder:itemPath];
    }
    
    NSError *error = nil;
    BOOL success = [ [NSFileManager defaultManager] removeItemAtPath:itemPath error:&error];
    offlineNode = [[MEGAStore shareInstance] fetchOfflineNodeWithPath:[Helper pathRelativeToOfflineDirectory:itemPath]];
    if (!success || error) {
        [SVProgressHUD showErrorWithStatus:@""];
        return NO;
    } else {
        if (isDirectory) {
            for (NSString *localPathAux in offlinePathsOnFolderArray) {
                offlineNode = [[MEGAStore shareInstance] fetchOfflineNodeWithPath:localPathAux];
                if (offlineNode) {
                    [[MEGAStore shareInstance] removeOfflineNode:offlineNode];
                }
            }
        } else {
            if (offlineNode) {
                [[MEGAStore shareInstance] removeOfflineNode:offlineNode];
            }
        }
        [self reloadUI];
        return YES;
    }
}

- (MEGAQLPreviewController *)qlPreviewControllerForIndexPath:(NSIndexPath *)indexPath {
    MEGAQLPreviewController *previewController = [[MEGAQLPreviewController alloc] initWithArrayOfFiles:self.offlineFiles];
    
    NSInteger selectedIndexFile = [[[self.offlineSortedItems objectAtIndex:indexPath.row] objectForKey:kIndex] integerValue];
    previewController.currentPreviewItemIndex = selectedIndexFile;
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    return previewController;
}

- (void)updateNavigationBarTitle {
    NSString *navigationTitle;
    if (self.tableView.isEditing) {
        if (self.selectedItems.count == 0) {
            navigationTitle = AMLocalizedString(@"selectTitle", @"Title shown on the Camera Uploads section when the edit mode is enabled. On this mode you can select photos");
        } else {
            navigationTitle = (self.selectedItems.count == 1) ? [NSString stringWithFormat:AMLocalizedString(@"oneItemSelected", @"Title shown on the Camera Uploads section when the edit mode is enabled and you have selected one photo"), self.selectedItems.count] : [NSString stringWithFormat:AMLocalizedString(@"itemsSelected", @"Title shown on the Camera Uploads section when the edit mode is enabled and you have selected more than one photo"), self.selectedItems.count];
        }
    } else {
        if (self.folderPathFromOffline == nil) {
            navigationTitle = AMLocalizedString(@"offline", @"Offline");
        } else {
            navigationTitle = [self.folderPathFromOffline lastPathComponent];
        }
    }
    
    self.navigationItem.title = navigationTitle;
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger rows = self.searchController.isActive ? self.searchItemsArray.count : self.offlineSortedItems.count;
    if (rows == 0) {
        self.sortByBarButtonItem.enabled = NO;
        [self.editBarButtonItem setEnabled:NO];
    } else {
        self.sortByBarButtonItem.enabled = YES;
        [self.editBarButtonItem setEnabled:YES];
    }
    return rows;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    OfflineTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"offlineTableViewCell" forIndexPath:indexPath];
    
    NSString *directoryPathString = [self currentOfflinePath];
    NSString *nameString = [[self itemAtIndexPath:indexPath] objectForKey:kFileName];
    NSString *pathForItem = [directoryPathString stringByAppendingPathComponent:nameString];
    
    [cell setItemNameString:nameString];
    
    MOOfflineNode *offNode = [[MEGAStore shareInstance] fetchOfflineNodeWithPath:[Helper pathRelativeToOfflineDirectory:pathForItem]];
    NSString *handleString = [offNode base64Handle];
    
    [cell.thumbnailPlayImageView setHidden:YES];
    
    BOOL isDirectory;
    [[NSFileManager defaultManager] fileExistsAtPath:pathForItem isDirectory:&isDirectory];
    if (isDirectory) {
        [cell.thumbnailImageView setImage:[Helper folderImage]];
        
        NSInteger files = 0;
        NSInteger folders = 0;
        
        NSArray *directoryContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:pathForItem error:nil];
        for (NSString *file in directoryContents) {
            BOOL isDirectory;
            NSString *path = [pathForItem stringByAppendingPathComponent:file];
            if (![path.pathExtension.lowercaseString isEqualToString:@"mega"]) {
                [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory];
                isDirectory ? folders++ : files++;
            }
            
        }
        
        [cell.infoLabel setText:[NSString mnz_stringByFiles:files andFolders:folders]];
    } else {
        NSString *extension = [[nameString pathExtension] lowercaseString];
        
        if (!handleString) {
            NSString *fpLocal = [[MEGASdkManager sharedMEGASdk] fingerprintForFilePath:pathForItem];
            if (fpLocal) {
                MEGANode *node = [[MEGASdkManager sharedMEGASdk] nodeForFingerprint:fpLocal];
                if (node) {
                    handleString = [node base64Handle];
                    [[MEGAStore shareInstance] insertOfflineNode:node api:[MEGASdkManager sharedMEGASdk] path:[[Helper pathRelativeToOfflineDirectory:pathForItem] decomposedStringWithCanonicalMapping]];
                }
            }
        }
        
        NSString *thumbnailFilePath = [Helper pathForSharedSandboxCacheDirectory:@"thumbnailsV3"];
        thumbnailFilePath = [thumbnailFilePath stringByAppendingPathComponent:handleString];
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:thumbnailFilePath] && handleString) {
            UIImage *thumbnailImage = [UIImage imageWithContentsOfFile:thumbnailFilePath];
            if (thumbnailImage != nil) {
                [cell.thumbnailImageView setImage:thumbnailImage];
                if (nameString.mnz_isVideoPathExtension) {
                    [cell.thumbnailPlayImageView setHidden:NO];
                }
            }
            
        } else {
            if (nameString.mnz_isImagePathExtension) {
                if (![[NSFileManager defaultManager] fileExistsAtPath:thumbnailFilePath]) {
                    [[MEGASdkManager sharedMEGASdk] createThumbnail:pathForItem destinatioPath:thumbnailFilePath];
                }
            } else {
                [cell.thumbnailImageView mnz_setImageForExtension:extension];
            }
        }
        
        NSDictionary *filePropertiesDictionary = [[NSFileManager defaultManager] attributesOfItemAtPath:pathForItem error:nil];
        
        time_t rawtime = [[filePropertiesDictionary valueForKey:NSFileModificationDate] timeIntervalSince1970];
        NSString *date = [Helper dateWithISO8601FormatOfRawTime:rawtime];
        
        unsigned long long size;
        size = [[[NSFileManager defaultManager] attributesOfItemAtPath:pathForItem error:nil] fileSize];
        
        NSString *sizeString = [NSByteCountFormatter stringFromByteCount:size countStyle:NSByteCountFormatterCountStyleMemory];
        NSString *sizeAndDate = [NSString stringWithFormat:@"%@ • %@", sizeString, date];
        [cell.infoLabel setText:sizeAndDate];
    }
    [cell.nameLabel setText:[[MEGASdkManager sharedMEGASdk] unescapeFsIncompatible:nameString]];
    
    if (self.tableView.isEditing) {
        for (NSURL *url in self.selectedItems) {
            if ([url.path isEqualToString:pathForItem]) {
                [self.tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
            }
        }
        
        UIView *view = [[UIView alloc] init];
        view.backgroundColor = UIColor.clearColor;
        cell.selectedBackgroundView = view;
    }
    
    if (@available(iOS 11.0, *)) {
        cell.thumbnailImageView.accessibilityIgnoresInvertColors = YES;
        cell.thumbnailPlayImageView.accessibilityIgnoresInvertColors = YES;
    } else {
        cell.delegate = self;
    }
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (tableView.isEditing) {
        NSURL *filePathURL = [[self itemAtIndexPath:indexPath] objectForKey:kPath];
        [self.selectedItems addObject:filePathURL];
        
        [self updateNavigationBarTitle];
        
        if (self.selectedItems.count > 0) {
            [self.activityBarButtonItem setEnabled:![self isDirectorySelected]];
            [self.deleteBarButtonItem setEnabled:YES];
        }
        
        if (self.selectedItems.count == self.offlineSortedItems.count) {
            allItemsSelected = YES;
        } else {
            allItemsSelected = NO;
        }
        
        return;
    }
    
    OfflineTableViewCell *cell = (OfflineTableViewCell *)[tableView cellForRowAtIndexPath:indexPath];
    NSString *itemNameString = [cell itemNameString];
    previewDocumentPath = [[self currentOfflinePath] stringByAppendingPathComponent:itemNameString];
    
    BOOL isDirectory;
    [[NSFileManager defaultManager] fileExistsAtPath:previewDocumentPath isDirectory:&isDirectory];
    if (isDirectory) {
        NSString *folderPathFromOffline = [self folderPathFromOffline:previewDocumentPath folder:[cell itemNameString]];
        
        OfflineViewController *offlineVC = [self.storyboard instantiateViewControllerWithIdentifier:@"OfflineViewControllerID"];
        [offlineVC setFolderPathFromOffline:folderPathFromOffline];
        if (self.searchController.isActive) {
            [self.searchController dismissViewControllerAnimated:YES completion:^{
                [self.navigationController pushViewController:offlineVC animated:YES];
            }];
        } else {
            [self.navigationController pushViewController:offlineVC animated:YES];
        }
    } else if (previewDocumentPath.mnz_isMultimediaPathExtension) {
        AVURLAsset *asset = [AVURLAsset assetWithURL:[NSURL fileURLWithPath:previewDocumentPath]];
        
        if (asset.playable) {
            MEGAAVViewController *megaAVViewController = [[MEGAAVViewController alloc] initWithURL:[NSURL fileURLWithPath:previewDocumentPath]];
            [self presentViewController:megaAVViewController animated:YES completion:nil];
        } else {
            MEGAQLPreviewController *previewController = [self qlPreviewControllerForIndexPath:indexPath];
            [self presentViewController:previewController animated:YES completion:nil];
        }
        
    } else if ([previewDocumentPath.pathExtension isEqualToString:@"pdf"]){
        MEGANavigationController *navigationController = [[UIStoryboard storyboardWithName:@"Cloud" bundle:nil] instantiateViewControllerWithIdentifier:@"previewDocumentNavigationID"];
        PreviewDocumentViewController *previewController = navigationController.viewControllers.firstObject;
        previewController.filesPathsArray = self.offlineFiles;
        previewController.nodeFileIndex = [[[self itemAtIndexPath:indexPath] objectForKey:kIndex] integerValue];
        [self presentViewController:navigationController animated:YES completion:nil];
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    } else {
        MEGAQLPreviewController *previewController = [self qlPreviewControllerForIndexPath:indexPath];
        [self presentViewController:previewController animated:YES completion:nil];
    }
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (tableView.isEditing) {
        NSURL *filePathURL = [[self itemAtIndexPath:indexPath] objectForKey:kPath];
        
        NSMutableArray *tempArray = [self.selectedItems copy];
        for (NSURL *url in tempArray) {
            if ([[url filePathURL] isEqual:filePathURL]) {
                [self.selectedItems removeObject:url];
            }
        }
        
        [self updateNavigationBarTitle];
        
        if (self.selectedItems.count == 0) {
            [self.activityBarButtonItem setEnabled:NO];
            [self.deleteBarButtonItem setEnabled:NO];
        } else {
            [self.activityBarButtonItem setEnabled:![self isDirectorySelected]];
            [self.deleteBarButtonItem setEnabled:YES];
        }
        
        allItemsSelected = NO;
        
        return;
    }
}

- (void)setTableViewEditing:(BOOL)editing animated:(BOOL)animated {
    [self.tableView setEditing:editing animated:animated];
    
    [self updateNavigationBarTitle];
    
    if (editing) {
        self.navigationItem.rightBarButtonItem = self.editBarButtonItem;
        self.editBarButtonItem.title = AMLocalizedString(@"cancel", @"Button title to cancel something");
        
        self.navigationItem.leftBarButtonItems = @[self.selectAllBarButtonItem];
        [self.toolbar setAlpha:0.0];
        [self.tabBarController.tabBar addSubview:self.toolbar];
        [UIView animateWithDuration:0.33f animations:^ {
            [self.toolbar setAlpha:1.0];
        }];
        
        for (OfflineTableViewCell *cell in [self.tableView visibleCells]) {
            UIView *view = [[UIView alloc] init];
            view.backgroundColor = UIColor.clearColor;
            cell.selectedBackgroundView = view;
        }
    } else {
        self.editBarButtonItem.title = AMLocalizedString(@"edit", @"Caption of a button to edit the files that are selected");
        self.navigationItem.rightBarButtonItem = self.moreBarButtonItem;
        
        allItemsSelected = NO;
        self.selectedItems = nil;
        self.navigationItem.leftBarButtonItems = @[];
        
        [UIView animateWithDuration:0.33f animations:^ {
            [self.toolbar setAlpha:0.0];
        } completion:^(BOOL finished) {
            if (finished) {
                [self.toolbar removeFromSuperview];
            }
        }];
        
        for (OfflineTableViewCell *cell in [self.tableView visibleCells]) {
            cell.selectedBackgroundView = nil;
        }
    }
    
    if (!self.selectedItems) {
        self.selectedItems = [[NSMutableArray alloc] init];
        
        [self.activityBarButtonItem setEnabled:NO];
        [self.deleteBarButtonItem setEnabled:NO];
    }
}


- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {    
    UIContextualAction *deleteAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:@"Share" handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        OfflineTableViewCell *cell = (OfflineTableViewCell *)[tableView cellForRowAtIndexPath:indexPath];
        NSString *itemPath = [[self currentOfflinePath] stringByAppendingPathComponent:[cell itemNameString]];
        [self removeOfflineNodeCell:itemPath];
    }];
    deleteAction.image = [UIImage imageNamed:@"delete"];
    deleteAction.backgroundColor = [UIColor colorWithRed:0.94 green:0.22 blue:0.23 alpha:1];
    return [UISwipeActionsConfiguration configurationWithActions:@[deleteAction]];
}

#pragma clang diagnostic pop

#pragma mark - IBActions

- (IBAction)editTapped:(UIBarButtonItem *)sender {
    BOOL enableEditing = !self.tableView.isEditing;
    [self setTableViewEditing:enableEditing animated:YES];
}

- (IBAction)selectAllAction:(UIBarButtonItem *)sender {
    [self.selectedItems removeAllObjects];
    
    if (!allItemsSelected) {
        NSURL *filePathURL = nil;
        
        for (NSInteger i = 0; i < self.offlineSortedItems.count; i++) {
            filePathURL = [[self.offlineSortedItems objectAtIndex:i] objectForKey:kPath];
            [self.selectedItems addObject:filePathURL];
        }
        
        allItemsSelected = YES;
    } else {
        allItemsSelected = NO;
    }
    
    if (self.selectedItems.count == 0) {
        [self.activityBarButtonItem setEnabled:NO];
        [self.deleteBarButtonItem setEnabled:NO];
    } else if (self.selectedItems.count >= 1) {
        [self.activityBarButtonItem setEnabled:![self isDirectorySelected]];
        [self.deleteBarButtonItem setEnabled:YES];
    }
    
    [self updateNavigationBarTitle];
    
    [self.tableView reloadData];
}

- (IBAction)activityTapped:(UIBarButtonItem *)sender {
    NSMutableArray *activitiesMutableArray = [[NSMutableArray alloc] init];
    if (self.selectedItems.count == 1) {
        OpenInActivity *openInActivity = [[OpenInActivity alloc] initOnBarButtonItem:sender];
        [activitiesMutableArray addObject:openInActivity];
    }
    UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:self.selectedItems applicationActivities:activitiesMutableArray];
    if (self.selectedItems.count > 5) {
        activityViewController.excludedActivityTypes = @[UIActivityTypeSaveToCameraRoll];
    }
    activityViewController.popoverPresentationController.barButtonItem = self.activityBarButtonItem;
    [activityViewController setCompletionWithItemsHandler:^(NSString *activityType, BOOL completed,  NSArray *returnedItems, NSError *activityError) {
        if (completed) {
            [self setTableViewEditing:NO animated:YES];
        }
    }];
    
    [self presentViewController:activityViewController animated:YES completion:nil];
}

- (IBAction)deleteTapped:(UIBarButtonItem *)sender {
    NSString *message;
    if (self.selectedItems.count == 1) {
        message = AMLocalizedString(@"removeItemFromOffline", nil);
    } else {
        message = AMLocalizedString(@"removeItemsFromOffline", nil);
    }
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:AMLocalizedString(@"remove", nil) message:message preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"ok", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        for (NSURL *url in self.selectedItems) {
            [self removeOfflineNodeCell:url.path];
        }
        [self reloadUI];
        [self setTableViewEditing:NO animated:YES];
    }]];
    [alertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alertController animated:YES completion:nil];
}

- (IBAction)sortByTapped:(UIBarButtonItem *)sender {
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Cloud" bundle:nil];
    SortByTableViewController *sortByTableViewController = [storyboard instantiateViewControllerWithIdentifier:@"sortByTableViewControllerID"];
    sortByTableViewController.offline = YES;
    
    MEGANavigationController *megaNavigationController = [[MEGANavigationController alloc] initWithRootViewController:sortByTableViewController];
    
    [self presentViewController:megaNavigationController animated:YES completion:nil];
}

- (IBAction)moreAction:(UIBarButtonItem *)sender {
    UIAlertController *moreAlertController = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [moreAlertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"cancel", @"Button title to cancel something") style:UIAlertActionStyleCancel handler:nil]];
    
    UIAlertAction *sortByAlertAction = [UIAlertAction actionWithTitle:AMLocalizedString(@"sortTitle", @"Section title of the 'Sort by'") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self sortByTapped:self.sortByBarButtonItem];
    }];
    [sortByAlertAction setValue:[UIColor mnz_black333333] forKey:@"titleTextColor"];
    [moreAlertController addAction:sortByAlertAction];
    
    if (self.offlineSortedItems.count) {
        UIAlertAction *selectAlertAction = [UIAlertAction actionWithTitle:AMLocalizedString(@"select", @"Button that allows you to select a given folder") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [self editTapped:self.editButtonItem];
        }];
        [selectAlertAction setValue:[UIColor mnz_black333333] forKey:@"titleTextColor"];
        [moreAlertController addAction:selectAlertAction];
    }
    
    if ([[UIDevice currentDevice] iPadDevice]) {
        moreAlertController.modalPresentationStyle = UIModalPresentationPopover;
        moreAlertController.popoverPresentationController.barButtonItem = self.moreBarButtonItem;
        moreAlertController.popoverPresentationController.sourceView = self.view;
    }
    
    [self presentViewController:moreAlertController animated:YES completion:nil];
}

#pragma mark - UISearchBarDelegate

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    self.searchItemsArray = nil;
}

#pragma mark - UISearchResultsUpdating

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *searchString = searchController.searchBar.text;
    if (searchController.isActive) {
        if ([searchString isEqualToString:@""]) {
            self.searchItemsArray = self.offlineSortedItems;
        } else {
            NSPredicate *resultPredicate = [NSPredicate predicateWithFormat:@"SELF.kFileName contains[c] %@", searchString];
            self.searchItemsArray = [[self.offlineSortedItems filteredArrayUsingPredicate:resultPredicate] mutableCopy];
        }
    }
    
    [self.tableView reloadData];
}

#pragma mark - UILongPressGestureRecognizer

- (void)longPress:(UILongPressGestureRecognizer *)longPressGestureRecognizer {
    CGPoint touchPoint = [longPressGestureRecognizer locationInView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:touchPoint];
    
    if (!indexPath || ![self.tableView numberOfRowsInSection:indexPath.section]) {
        return;
    }
    
    if (longPressGestureRecognizer.state == UIGestureRecognizerStateBegan) {        
        if (self.tableView.isEditing) {
            // Only stop editing if long pressed over a cell that is the only one selected or when selected none
            if (self.selectedItems.count == 0) {
                [self setTableViewEditing:NO animated:YES];
            }
            if (self.selectedItems.count == 1) {
                NSURL *offlineUrlSelected = self.selectedItems.firstObject;
                NSURL *offlineUrlPressed = [[self.offlineSortedItems objectAtIndex:indexPath.row] objectForKey:kPath];
                if ([[offlineUrlPressed path] compare:[offlineUrlSelected path]] == NSOrderedSame) {
                    [self setTableViewEditing:NO animated:YES];
                }
            }
        } else {
            [self setTableViewEditing:YES animated:YES];
            [self tableView:self.tableView didSelectRowAtIndexPath:indexPath];
            [self.tableView selectRowAtIndexPath:indexPath animated:YES scrollPosition:UITableViewScrollPositionNone];
        }
    }
    
    if (longPressGestureRecognizer.state == UIGestureRecognizerStateEnded) {
        [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
    }
}

#pragma mark - UIViewControllerPreviewingDelegate

- (UIViewController *)previewingContext:(id<UIViewControllerPreviewing>)previewingContext viewControllerForLocation:(CGPoint)location {
    if (self.tableView.isEditing) {
        return nil;
    }
    
    CGPoint rowPoint = [self.tableView convertPoint:location fromView:self.view];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:rowPoint];
    if (!indexPath || ![self.tableView numberOfRowsInSection:indexPath.section]) {
        return nil;
    }
    
    previewingContext.sourceRect = [self.tableView convertRect:[self.tableView cellForRowAtIndexPath:indexPath].frame toView:self.view];
    
    OfflineTableViewCell *cell = (OfflineTableViewCell *)[self.tableView cellForRowAtIndexPath:indexPath];
    NSString *itemNameString = cell.itemNameString;
    previewDocumentPath = [[self currentOfflinePath] stringByAppendingPathComponent:itemNameString];
    
    BOOL isDirectory;
    [[NSFileManager defaultManager] fileExistsAtPath:previewDocumentPath isDirectory:&isDirectory];
    if (isDirectory) {
        NSString *folderPathFromOffline = [self folderPathFromOffline:previewDocumentPath folder:cell.itemNameString];
        
        OfflineViewController *offlineVC = [self.storyboard instantiateViewControllerWithIdentifier:@"OfflineViewControllerID"];
        offlineVC.folderPathFromOffline = folderPathFromOffline;
        offlineVC.peekIndexPath = indexPath;
        
        return offlineVC;
    } else if (previewDocumentPath.mnz_isMultimediaPathExtension) {
        AVURLAsset *asset = [AVURLAsset assetWithURL:[NSURL fileURLWithPath:previewDocumentPath]];
        
        if (asset.playable) {
            MEGAAVViewController *megaAVViewController = [[MEGAAVViewController alloc] initWithURL:[NSURL fileURLWithPath:previewDocumentPath]];
            return megaAVViewController;
        } else {
            return [self qlPreviewControllerForIndexPath:indexPath];
        }
    } else if ([previewDocumentPath.pathExtension isEqualToString:@"pdf"]){
        MEGANavigationController *navigationController = [[UIStoryboard storyboardWithName:@"Cloud" bundle:nil] instantiateViewControllerWithIdentifier:@"previewDocumentNavigationID"];
        PreviewDocumentViewController *previewController = navigationController.viewControllers.firstObject;
        previewController.filesPathsArray = self.offlineFiles;
        previewController.nodeFileIndex = [[[self itemAtIndexPath:indexPath] objectForKey:kIndex] integerValue];
        
        [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
        
        return navigationController;
    } else {
        return [self qlPreviewControllerForIndexPath:indexPath];
    }
    
    return nil;
}

- (void)previewingContext:(id<UIViewControllerPreviewing>)previewingContext commitViewController:(UIViewController *)viewControllerToCommit {
    if (viewControllerToCommit.class == OfflineViewController.class) {
        [self.navigationController pushViewController:viewControllerToCommit animated:YES];
    } else {
        [self.navigationController presentViewController:viewControllerToCommit animated:YES completion:nil];
    }
}

- (NSArray<id<UIPreviewActionItem>> *)previewActionItems {
    UIPreviewAction *deleteAction = [UIPreviewAction actionWithTitle:AMLocalizedString(@"remove", @"Title for the action that allows to remove a file or folder")
                                                               style:UIPreviewActionStyleDestructive
                                                             handler:^(UIPreviewAction * _Nonnull action, UIViewController * _Nonnull previewViewController) {
                                                                 OfflineViewController *offlineVC = (OfflineViewController *)previewViewController;
                                                                 [offlineVC tableView:offlineVC.tableView commitEditingStyle:UITableViewCellEditingStyleDelete forRowAtIndexPath:offlineVC.peekIndexPath];
                                                             }];
    
    return @[deleteAction];
}

#pragma mark - DZNEmptyDataSetSource

- (NSAttributedString *)titleForEmptyDataSet:(UIScrollView *)scrollView {
    NSString *text = @"";
    if ([MEGAReachabilityManager isReachable]) {
        if (self.searchController.isActive) {
            if (self.searchController.searchBar.text.length > 0) {
                text = AMLocalizedString(@"noResults", @"Title shown when you make a search and there is 'No Results'");
            }
        } else {
            if (self.folderPathFromOffline == nil) {
                text = AMLocalizedString(@"offlineEmptyState_title", @"Title shown when the Offline section is empty, when you don't have download any files. Keep the upper.");
            } else {
                text = AMLocalizedString(@"emptyFolder", @"Title shown when a folder doesn't have any files");
            }
        }
    } else {
        text = AMLocalizedString(@"noInternetConnection",  @"No Internet Connection");
    }
    
    return [[NSAttributedString alloc] initWithString:text attributes:[Helper titleAttributesForEmptyState]];
}

- (UIImage *)imageForEmptyDataSet:(UIScrollView *)scrollView {
    UIImage *image;
    if ([MEGAReachabilityManager isReachable]) {
        if (self.searchController.isActive) {
            if (self.searchController.searchBar.text.length > 0) {
                return [UIImage imageNamed:@"searchEmptyState"];
            } else {
                return nil;
            }
        } else {
            if (self.folderPathFromOffline == nil) {
                image = [UIImage imageNamed:@"offlineEmptyState"];
            } else {
                image = [UIImage imageNamed:@"folderEmptyState"];
            }
        }
    } else {
        image = [UIImage imageNamed:@"noInternetEmptyState"];
    }
    return image;
}

- (UIColor *)backgroundColorForEmptyDataSet:(UIScrollView *)scrollView {
    return [UIColor whiteColor];
}

- (CGFloat)spaceHeightForEmptyDataSet:(UIScrollView *)scrollView {
    return [Helper spaceHeightForEmptyState];
}

- (CGFloat)verticalOffsetForEmptyDataSet:(UIScrollView *)scrollView {
    return [Helper verticalOffsetForEmptyStateWithNavigationBarSize:self.navigationController.navigationBar.frame.size searchBarActive:self.searchController.isActive];
}

#pragma mark - MEGATransferDelegate

- (void)onTransferFinish:(MEGASdk *)api transfer:(MEGATransfer *)transfer error:(MEGAError *)error {
    if ([error type]) {
        return;
    }
    
    if ([transfer type] == MEGATransferTypeDownload) {
        [self reloadUI];
    }
}

#pragma mark - MGSwipeTableCellDelegate

- (BOOL)swipeTableCell:(MGSwipeTableCell*) cell canSwipe:(MGSwipeDirection) direction fromPoint:(CGPoint)point {
    if (self.tableView.isEditing) {
        return NO;
    }
    
    if (direction == MGSwipeDirectionLeftToRight) {
        return NO;
    }
    
    return YES;
}

- (NSArray*)swipeTableCell:(MGSwipeTableCell*) cell swipeButtonsForDirection:(MGSwipeDirection)direction
             swipeSettings:(MGSwipeSettings*) swipeSettings expansionSettings:(MGSwipeExpansionSettings*) expansionSettings {
    
    swipeSettings.transition = MGSwipeTransitionDrag;
    expansionSettings.buttonIndex = 0;
    expansionSettings.expansionLayout = MGSwipeExpansionLayoutCenter;
    expansionSettings.fillOnTrigger = NO;
    expansionSettings.threshold = 2;
    
    if (direction == MGSwipeDirectionRightToLeft) {
        
        MGSwipeButton *deleteButton = [MGSwipeButton buttonWithTitle:@"" icon:[UIImage imageNamed:@"delete"] backgroundColor:[UIColor colorWithRed:0.93 green:0.22 blue:0.23 alpha:1.0] padding:25 callback:^BOOL(MGSwipeTableCell *sender) {
            OfflineTableViewCell *offlineCell = (OfflineTableViewCell *)cell;
            NSString *itemPath = [[self currentOfflinePath] stringByAppendingPathComponent:[offlineCell itemNameString]];
            [self removeOfflineNodeCell:itemPath];
            return YES;
        }];
        [deleteButton iconTintColor:[UIColor whiteColor]];
        
        return @[deleteButton];
    }
    else {
        return nil;
    }
}

@end
