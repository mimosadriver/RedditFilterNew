#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FilterManager : NSObject

+ (instancetype)sharedManager;

// Returns YES if the subreddit should be hidden
- (BOOL)shouldFilterSubreddit:(NSString *)subredditName;

// Returns YES if the post title contains a blocked keyword
- (BOOL)shouldFilterKeyword:(NSString *)postTitle;

// Subreddit list management
- (NSArray<NSString *> *)blockedSubreddits;
- (void)addSubreddit:(NSString *)name;
- (void)removeSubreddit:(NSString *)name;
- (void)setBlockedSubreddits:(NSArray<NSString *> *)subreddits;

// Keyword list management
- (NSArray<NSString *> *)blockedKeywords;
- (void)addKeyword:(NSString *)keyword;
- (void)removeKeyword:(NSString *)keyword;
- (void)setBlockedKeywords:(NSArray<NSString *> *)keywords;

// Toggle filtering on/off
- (BOOL)isEnabled;
- (void)setEnabled:(BOOL)enabled;

// Force reload from disk
- (void)reload;

@end

NS_ASSUME_NONNULL_END
