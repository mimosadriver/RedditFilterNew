#import "FilterManager.h"

static NSString *const kPrefsPath = @"/var/mobile/Library/Preferences/com.ryan.redditfilter.plist";
static NSString *const kKeySubreddits = @"blockedSubreddits";
static NSString *const kKeyKeywords = @"blockedKeywords";
static NSString *const kKeyEnabled = @"enabled";

@interface FilterManager ()
@property (nonatomic, strong) NSMutableArray<NSString *> *mutableSubreddits;
@property (nonatomic, strong) NSMutableArray<NSString *> *mutableKeywords;
@property (nonatomic, assign) BOOL filterEnabled;
@end

@implementation FilterManager

+ (instancetype)sharedManager {
    static FilterManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[FilterManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self reload];
    }
    return self;
}

- (void)reload {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:kPrefsPath];
    
    NSArray *subs = prefs[kKeySubreddits];
    self.mutableSubreddits = subs ? [subs mutableCopy] : [NSMutableArray array];
    
    NSArray *kws = prefs[kKeyKeywords];
    self.mutableKeywords = kws ? [kws mutableCopy] : [NSMutableArray array];
    
    // Default to enabled
    self.filterEnabled = prefs[kKeyEnabled] ? [prefs[kKeyEnabled] boolValue] : YES;
}

- (void)save {
    NSDictionary *prefs = @{
        kKeySubreddits: [self.mutableSubreddits copy],
        kKeyKeywords: [self.mutableKeywords copy],
        kKeyEnabled: @(self.filterEnabled)
    };
    [prefs writeToFile:kPrefsPath atomically:YES];
}

#pragma mark - Filtering logic

- (BOOL)shouldFilterSubreddit:(NSString *)subredditName {
    if (!self.filterEnabled || !subredditName || subredditName.length == 0) return NO;
    
    NSString *lowered = [subredditName lowercaseString];
    // Strip r/ prefix if present
    NSString *stripped = lowered;
    if ([stripped hasPrefix:@"r/"]) {
        stripped = [stripped substringFromIndex:2];
    }
    
    for (NSString *blocked in self.mutableSubreddits) {
        NSString *blockedLow = [blocked lowercaseString];
        if ([stripped hasPrefix:@"r/"]) {
            blockedLow = [[blocked lowercaseString] hasPrefix:@"r/"] ? [blocked lowercaseString] : [@"r/" stringByAppendingString:[blocked lowercaseString]];
        }
        if ([stripped isEqualToString:blockedLow] || [lowered isEqualToString:blockedLow]) {
            return YES;
        }
        // Also try raw match
        if ([stripped isEqualToString:[blocked lowercaseString]]) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)shouldFilterKeyword:(NSString *)postTitle {
    if (!self.filterEnabled || !postTitle || postTitle.length == 0) return NO;
    
    NSString *lowered = [postTitle lowercaseString];
    for (NSString *kw in self.mutableKeywords) {
        if (kw.length == 0) continue;
        if ([lowered containsString:[kw lowercaseString]]) {
            return YES;
        }
    }
    return NO;
}

#pragma mark - Subreddit management

- (NSArray<NSString *> *)blockedSubreddits {
    return [self.mutableSubreddits copy];
}

- (void)addSubreddit:(NSString *)name {
    NSString *trimmed = [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (trimmed.length == 0) return;
    if (![self.mutableSubreddits containsObject:trimmed]) {
        [self.mutableSubreddits addObject:trimmed];
        [self save];
    }
}

- (void)removeSubreddit:(NSString *)name {
    [self.mutableSubreddits removeObject:name];
    [self save];
}

- (void)setBlockedSubreddits:(NSArray<NSString *> *)subreddits {
    self.mutableSubreddits = [subreddits mutableCopy];
    [self save];
}

#pragma mark - Keyword management

- (NSArray<NSString *> *)blockedKeywords {
    return [self.mutableKeywords copy];
}

- (void)addKeyword:(NSString *)keyword {
    NSString *trimmed = [keyword stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (trimmed.length == 0) return;
    if (![self.mutableKeywords containsObject:trimmed]) {
        [self.mutableKeywords addObject:trimmed];
        [self save];
    }
}

- (void)removeKeyword:(NSString *)keyword {
    [self.mutableKeywords removeObject:keyword];
    [self save];
}

- (void)setBlockedKeywords:(NSArray<NSString *> *)keywords {
    self.mutableKeywords = [keywords mutableCopy];
    [self save];
}

#pragma mark - Toggle

- (BOOL)isEnabled {
    return self.filterEnabled;
}

- (void)setEnabled:(BOOL)enabled {
    self.filterEnabled = enabled;
    [self save];
}

@end
