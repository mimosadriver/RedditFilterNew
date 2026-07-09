/*
 * RedditFilter - Tweak.x
 * Blocks promoted/sponsored posts in the Reddit feed.
 */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "FilterManager.h"
#import "SettingsViewController.h"

#pragma mark - Ad detection helper

static BOOL RFBoolForKey(id object, NSString *key) {
    if (!object) return NO;
    @try {
        id value = [object valueForKey:key];
        if ([value isKindOfClass:[NSNumber class]]) {
            return [value boolValue];
        }
    } @catch (__unused NSException *e) {}
    return NO;
}

static NSString *RFStringForKey(id object, NSString *key) {
    if (!object) return nil;
    @try {
        id value = [object valueForKey:key];
        if ([value isKindOfClass:[NSString class]]) {
            return value;
        }
    } @catch (__unused NSException *e) {}
    return nil;
}

static BOOL RFShouldRemovePost(id post) {
    if (!post) return NO;

    if (RFBoolForKey(post, @"isAdPost"))                  return YES;
    if (RFBoolForKey(post, @"isPromoted"))                return YES;
    if (RFBoolForKey(post, @"isPromotedCommunityPostV2")) return YES;
    if (RFBoolForKey(post, @"isAdPostPDP"))               return YES;

    @try {
        id adPost = [post valueForKey:@"adPost"];
        if (adPost && ![adPost isKindOfClass:[NSNull class]]) return YES;
    } @catch (__unused NSException *e) {}

    FilterManager *fm = [FilterManager sharedManager];
    if ([fm isEnabled]) {
        NSString *sub = RFStringForKey(post, @"subredditName");
        if (sub && [fm shouldFilterSubreddit:sub]) return YES;

        NSString *prefixed = RFStringForKey(post, @"prefixedName");
        if (prefixed && [fm shouldFilterSubreddit:prefixed]) return YES;

        NSString *title = RFStringForKey(post, @"title");
        if (title && [fm shouldFilterKeyword:title]) return YES;
    }

    return NO;
}

#pragma mark - HOOK 1: HidingFeedElementTransformer

%hook _TtC42FeedKit_Services_HidingElementService_Impl28HidingFeedElementTransformer

- (BOOL)shouldHidePost:(id)post {
    BOOL orig = %orig;
    if (orig) return YES;
    return RFShouldRemovePost(post);
}

%end

#pragma mark - HOOK 2: AdHidingFeedElementTransformer

%hook _TtC29RedditAds_FeedComponents_Impl30AdHidingFeedElementTransformer

- (BOOL)shouldHidePost:(id)post {
    BOOL orig = %orig;
    if (orig) return YES;
    return RFShouldRemovePost(post);
}

%end

#pragma mark - HOOK 3: AdFilteringFeedElementTransformer

%hook _TtC29RedditAds_FeedComponents_Impl33AdFilteringFeedElementTransformer

- (BOOL)shouldHidePost:(id)post {
    BOOL orig = %orig;
    if (orig) return YES;
    return RFShouldRemovePost(post);
}

%end

#pragma mark - HOOK 4: Kill the blank ad spacer

%hook _TtC29RedditAds_FeedComponents_Impl24AdFeedBlankUnitSliceView

- (CGSize)intrinsicContentSize {
    return CGSizeMake(0, 0);
}

- (void)layoutSubviews {
    %orig;
    UIView *view = (UIView *)self;
    view.hidden = YES;
    CGRect f = view.frame;
    f.size.height = 0;
    view.frame = f;
}

%end

#pragma mark - HOOK 5: Settings injection

static BOOL gSettingsInjected = NO;

%hook UITableViewController

- (void)viewDidLoad {
    %orig;
    if (gSettingsInjected) return;

    NSString *className = NSStringFromClass([self class]);
    BOOL isSettingsVC = [className containsString:@"Settings"] &&
                        [className rangeOfString:@"Reddit" options:NSCaseInsensitiveSearch].location != NSNotFound;
    if (!isSettingsVC) return;

    NSBundle *bundle = [NSBundle mainBundle];
    if (![bundle.bundleIdentifier isEqualToString:@"com.reddit.Reddit"] &&
        ![bundle.bundleIdentifier isEqualToString:@"com.atebits.reddit"]) return;

    gSettingsInjected = YES;

    UIBarButtonItem *filterBtn = [[UIBarButtonItem alloc]
        initWithTitle:@"Filters"
                style:UIBarButtonItemStylePlain
               target:self
               action:@selector(rf_openFilterSettings)];

    NSMutableArray *items = [self.navigationItem.rightBarButtonItems mutableCopy] ?: [NSMutableArray array];
    [items addObject:filterBtn];
    self.navigationItem.rightBarButtonItems = items;
}

%new
- (void)rf_openFilterSettings {
    RFSettingsViewController *vc = [[RFSettingsViewController alloc] initWithStyle:UITableViewStyleInsetGrouped];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    [self presentViewController:nav animated:YES completion:nil];
}

%end

#pragma mark - Constructor

%ctor {
    [[FilterManager sharedManager] reload];
    NSLog(@"[RedditFilter] loaded — ad blocking active");
}
