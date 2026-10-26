#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, RedditProxyType) {
    RedditProxyTypeHTTP = 0,
    RedditProxyTypeSOCKS5 = 1
};

@interface RedditProxyPreset : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) RedditProxyType type;
@property (nonatomic, copy) NSString *host;
@property (nonatomic, assign) NSInteger port;
+ (instancetype)presetWithName:(NSString *)name type:(RedditProxyType)type host:(NSString *)host port:(NSInteger)port;
@end

@interface RedditProxyManager : NSObject

@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) BOOL hasConfigured;
@property (nonatomic, assign) RedditProxyType proxyType;
@property (nonatomic, copy) NSString *host;
@property (nonatomic, assign) NSInteger port;
@property (nonatomic, copy, nullable) NSString *username;
@property (nonatomic, copy, nullable) NSString *password;

+ (instancetype)sharedManager;
- (void)loadConfiguration;
- (void)saveConfiguration;
- (NSDictionary *)proxyDictionary;
- (NSArray<RedditProxyPreset *> *)availablePresets;
- (void)applyPreset:(RedditProxyPreset *)preset;
- (void)testConnectionWithCompletion:(void (^)(BOOL success, NSTimeInterval latencyMs, NSString * _Nullable message))completion;
- (void)checkCurrentIPAndCountryWithCompletion:(void (^)(BOOL success, NSString * _Nullable ip, NSString * _Nullable country, NSString * _Nullable details))completion;

@end

NS_ASSUME_NONNULL_END
