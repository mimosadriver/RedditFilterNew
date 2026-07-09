/*
 * RedditFilter - Tweak.x
 *
 * PRIMARY GOAL: Block promoted/sponsored posts (ads) from the Reddit feed.
 * BONUS: Optional subreddit / keyword filtering via in-app settings.
 *
 * ── How Reddit serves ads ───────────────────────────────────────────────
 *   Reddit's feed is a pipeline of FeedElementTransformers. Ads flow through
 *   dedicated transformers in the RedditAds_FeedComponents_Impl module:
 *     • AdFilteringFeedElementTransformer
 *     • AdHidingFeedElementTransformer
 *   Post models expose ObjC-bridged getters that flag an ad:
 *     • -isAdPost            (BOOL)
 *     • -isPromoted          (BOOL)
 *     • -isPromotedCommunityPostV2 (BOOL)
 *   Comment ads expose:
 *     • -isCommercialCommunication (BOOL)
 *
 * ── Strategy ────────────────────────────────────────────────────────────
 *   1. Hook the HidingFeedElementTransformer's -shouldHidePost: and return
 *      YES for anything flagged as an ad (via the getters above, read by KVC).
 *   2. Also apply the optional subreddit/keyword filter there.
 *   3. Neutralise AdFeedBlankUnitFactory so removed ads don't leave a blank
 *      spacer gap in the feed.
 *   4. Inject a small settings screen so the bonus filters are editable.
 *
 * ── Why KVC instead of typed calls ──────────────────────────────────────
 *   Reddit is ~90% Swift. The classes are Swift but expose these properties
 *   as ObjC selectors (confirmed via the mangled getter symbols isAdPostSbvg,
 *   isPromotedSbvg, etc.). KVC (-valueForKey:) resolves those bridged getters
 *   at runtime and gracefully misses (caught) on object types that lack them,
 *   so the hook never crashes across minor Reddit version bumps.
 */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "FilterManager.h"
#import "SettingsViewController.h"

#pragma mark - Ad detection helper

// Reads a BOOL-ish property via KVC without throwing.
static BOOL RFBoolForKey(id object, NSString *key) {
    if (!object) return NO;
    @try {
        id value = [object valueForKey:key];
        if ([value isKindOfClass:[NSNumber class]]) {
            return [value boolValue];
        }
    } @catch (__unused NSException *e) {
        // Property doesn't exist on this object type — expected, ignore.
    }
    return NO;
}

// Reads an NSString property via KVC without throwing.
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

// The core decision: should this post object be removed from the feed?
static BOOL RFShouldRemovePost(id post) {
    if (!post) return NO;

    // ── 1. Ad detection (always on) ──────────────────────────────────
    if (RFBoolForKey(post, @"isAdPost"))                 return YES;
    if (RFBoolForKey(post, @"isPromoted"))               return YES;
    if (RFBoolForKey(post, @"isPromotedCommunityPostV2")) return YES;
    if (RFBoolForKey(post, @"isAdPostPDP"))              return YES;

    // Nested ad payload — some models wrap the ad flag in an `adPost` object.
    @try {
        id adPost = [post valueForKey:@"adPost"];
        if (adPost && ![adPost isKindOfClass:[NSNull class]]) return YES;
    } @catch (__unused NSException *e) {}

    // ── 2. Optional user filters (subreddit / keyword) ───────────────
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

// _TtC42FeedKit_Services_HidingElementService_Impl28HidingFeedElementTransformer
%hook _TtC42FeedKit_Services_HidingElementService_Impl28HidingFeedElementTransformer

- (BOOL)shouldHidePost:(id)post {
    if (%orig) return YES;             // respect Reddit's own hide logic
    return RFShouldRemovePost(post);
}

%end

#pragma mark - HOOK 2: AdHidingFeedElementTransformer

// _TtC29RedditAds_FeedComponents_Impl30AdHidingFeedElementTransformer
%hook _TtC29RedditAds_FeedComponents_Impl30AdHidingFeedElementTransformer

- (BOOL)shouldHidePost:(id)post {
    if (%orig) return YES;
    return RFShouldRemovePost(post);
}

%end

#pragma mark - HOOK 3: AdFilteringFeedElementTransformer

// This transformer decides whether an ad element is eligible to be inserted.
// _TtC29RedditAds_FeedComponents_Impl33AdFilteringFeedElementTransformer
//
// We can't rely on a single known selector name here across versions, so we
// hook -shouldHidePost: if present (same shape as the others). If the class
// doesn't expose it, this %hook simply has nothing to override — harmless.
%hook _TtC29RedditAds_FeedComponents_Impl33AdFilteringFeedElementTransformer

- (BOOL)shouldHidePost:(id)post {
    // For the *ad* transformer, hide aggressively: any post reaching this
    // transformer that our detector flags is an ad by definition.
    if (%orig) return YES;
    return RFShouldRemovePost(post);
}

%end

#pragma mark - HOOK 4: Kill the blank ad spacer

// When an ad is removed, Reddit can leave an AdFeedBlankUnit placeholder,
// producing an empty gap. We force its height to zero.
// _TtC29RedditAds_FeedComponents_Impl26AdFeedBlankUnitFactoryImpl
%hook _TtC29RedditAds_FeedComponents_Impl24AdFeedBlankUnitSliceView

- (CGSize)intrinsicContentSize {
    return CGSizeMake(0, 0);
}

- (void)layoutSubviews {
    %orig;
    // Collapse the view entirely
    self.hidden = YES;
    CGRect f = self.frame;
    f.size.height = 0;
    self.frame = f;
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
    NSLog(@"[RedditFilter] loaded — ad blocking active; %lu subreddits, %lu keywords in optional filter",
        (unsigned long)[[FilterManager sharedManager] blockedSubreddits].count,
        (unsigned long)[[FilterManager sharedManager] blockedKeywords].count);
}
