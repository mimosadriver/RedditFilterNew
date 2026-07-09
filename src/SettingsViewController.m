#import "SettingsViewController.h"
#import "FilterManager.h"

typedef NS_ENUM(NSInteger, RFSection) {
    RFSectionToggle = 0,
    RFSectionSubreddits,
    RFSectionKeywords,
    RFSectionCount
};

@interface RFSettingsViewController ()
@property (nonatomic, strong) NSMutableArray<NSString *> *subreddits;
@property (nonatomic, strong) NSMutableArray<NSString *> *keywords;
@end

@implementation RFSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"RedditFilter";
    [self reloadData];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemDone
        target:self
        action:@selector(dismiss)];
    
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"cell"];
}

- (void)reloadData {
    FilterManager *fm = [FilterManager sharedManager];
    self.subreddits = [[fm blockedSubreddits] mutableCopy];
    self.keywords = [[fm blockedKeywords] mutableCopy];
    [self.tableView reloadData];
}

- (void)dismiss {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return RFSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case RFSectionToggle:    return 1;
        case RFSectionSubreddits: return self.subreddits.count + 1; // +1 for Add row
        case RFSectionKeywords:   return self.keywords.count + 1;
        default: return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case RFSectionToggle:    return @"Filter Status";
        case RFSectionSubreddits: return @"Blocked Subreddits";
        case RFSectionKeywords:   return @"Blocked Keywords";
        default: return nil;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    switch (section) {
        case RFSectionSubreddits: return @"Enter subreddit names without r/ prefix (e.g. worldnews)";
        case RFSectionKeywords:   return @"Posts whose titles contain any keyword will be hidden";
        default: return nil;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    cell.textLabel.textColor = [UIColor labelColor];
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.accessoryView = nil;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    
    FilterManager *fm = [FilterManager sharedManager];
    
    switch (indexPath.section) {
        case RFSectionToggle: {
            cell.textLabel.text = @"Filtering Enabled";
            UISwitch *sw = [[UISwitch alloc] init];
            sw.on = [fm isEnabled];
            [sw addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = sw;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            break;
        }
        case RFSectionSubreddits: {
            if (indexPath.row < (NSInteger)self.subreddits.count) {
                cell.textLabel.text = self.subreddits[indexPath.row];
                cell.textLabel.textColor = [UIColor labelColor];
            } else {
                cell.textLabel.text = @"+ Add Subreddit";
                cell.textLabel.textColor = [UIColor systemBlueColor];
            }
            break;
        }
        case RFSectionKeywords: {
            if (indexPath.row < (NSInteger)self.keywords.count) {
                cell.textLabel.text = self.keywords[indexPath.row];
                cell.textLabel.textColor = [UIColor labelColor];
            } else {
                cell.textLabel.text = @"+ Add Keyword";
                cell.textLabel.textColor = [UIColor systemBlueColor];
            }
            break;
        }
    }
    
    return cell;
}

- (void)toggleChanged:(UISwitch *)sw {
    [[FilterManager sharedManager] setEnabled:sw.on];
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == RFSectionSubreddits) {
        if (indexPath.row < (NSInteger)self.subreddits.count) {
            // Already existing: do nothing (delete via swipe)
        } else {
            [self promptAddItemForSection:RFSectionSubreddits];
        }
    } else if (indexPath.section == RFSectionKeywords) {
        if (indexPath.row < (NSInteger)self.keywords.count) {
            // Already existing: do nothing (delete via swipe)
        } else {
            [self promptAddItemForSection:RFSectionKeywords];
        }
    }
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == RFSectionToggle) return UITableViewCellEditingStyleNone;
    
    if (indexPath.section == RFSectionSubreddits) {
        return (indexPath.row < (NSInteger)self.subreddits.count) ? UITableViewCellEditingStyleDelete : UITableViewCellEditingStyleNone;
    }
    if (indexPath.section == RFSectionKeywords) {
        return (indexPath.row < (NSInteger)self.keywords.count) ? UITableViewCellEditingStyleDelete : UITableViewCellEditingStyleNone;
    }
    return UITableViewCellEditingStyleNone;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle != UITableViewCellEditingStyleDelete) return;
    
    FilterManager *fm = [FilterManager sharedManager];
    
    if (indexPath.section == RFSectionSubreddits && indexPath.row < (NSInteger)self.subreddits.count) {
        NSString *name = self.subreddits[indexPath.row];
        [fm removeSubreddit:name];
        [self.subreddits removeObjectAtIndex:indexPath.row];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    } else if (indexPath.section == RFSectionKeywords && indexPath.row < (NSInteger)self.keywords.count) {
        NSString *kw = self.keywords[indexPath.row];
        [fm removeKeyword:kw];
        [self.keywords removeObjectAtIndex:indexPath.row];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}

#pragma mark - Add prompt

- (void)promptAddItemForSection:(RFSection)section {
    NSString *title = (section == RFSectionSubreddits) ? @"Add Subreddit" : @"Add Keyword";
    NSString *placeholder = (section == RFSectionSubreddits) ? @"e.g. worldnews" : @"e.g. giveaway";
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = placeholder;
        textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        textField.autocorrectionType = UITextAutocorrectionTypeNo;
    }];
    
    UIAlertAction *add = [UIAlertAction actionWithTitle:@"Add" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *text = alert.textFields.firstObject.text;
        if (text.length == 0) return;
        
        // Strip r/ prefix for subreddits
        if (section == RFSectionSubreddits) {
            if ([text.lowercaseString hasPrefix:@"r/"]) {
                text = [text substringFromIndex:2];
            }
            [[FilterManager sharedManager] addSubreddit:text];
            [self.subreddits addObject:text];
        } else {
            [[FilterManager sharedManager] addKeyword:text];
            [self.keywords addObject:text];
        }
        
        // Insert new row before the Add row
        NSInteger newRow = (section == RFSectionSubreddits) ? self.subreddits.count - 1 : self.keywords.count - 1;
        NSIndexPath *newPath = [NSIndexPath indexPathForRow:newRow inSection:section];
        [self.tableView insertRowsAtIndexPaths:@[newPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    }];
    
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];
    [alert addAction:add];
    [alert addAction:cancel];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
