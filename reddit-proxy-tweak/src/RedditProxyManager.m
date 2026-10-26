#import "RedditProxyManager.h"
#import <CFNetwork/CFNetwork.h>

static NSString * const kPrefEnabled = @"RedditProxy_Enabled";
static NSString * const kPrefConfigured = @"RedditProxy_Configured";
static NSString * const kPrefResetV4 = @"RedditProxy_Reset_V4";
static NSString * const kPrefType = @"RedditProxy_Type";
static NSString * const kPrefHost = @"RedditProxy_Host";
static NSString * const kPrefPort = @"RedditProxy_Port";
static NSString * const kPrefUser = @"RedditProxy_User";
static NSString * const kPrefPass = @"RedditProxy_Pass";

// CFNetwork proxy dictionary keys (runtime string equivalents)
static NSString * const kRPHTTPEnable = @"HTTPEnable";
static NSString * const kRPHTTPPort = @"HTTPPort";
static NSString * const kRPHTTPProxy = @"HTTPProxy";
static NSString * const kRPHTTPSEnable = @"HTTPSEnable";
static NSString * const kRPHTTPSPort = @"HTTPSPort";
static NSString * const kRPHTTPSProxy = @"HTTPSProxy";
static NSString * const kRPSOCKSEnable = @"SOCKSEnable";
static NSString * const kRPSOCKSPort = @"SOCKSPort";
static NSString * const kRPSOCKSProxy = @"SOCKSProxy";

@implementation RedditProxyPreset
+ (instancetype)presetWithName:(NSString *)name type:(RedditProxyType)type host:(NSString *)host port:(NSInteger)port {
    RedditProxyPreset *p = [[self alloc] init];
    p.name = name;
    p.type = type;
    p.host = host;
    p.port = port;
    return p;
}
@end

@implementation RedditProxyManager

+ (instancetype)sharedManager {
    static RedditProxyManager *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[RedditProxyManager alloc] init];
        [instance loadConfiguration];
    });
    return instance;
}

- (NSString *)configFilePath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docDir = paths.firstObject;
    return [docDir stringByAppendingPathComponent:@"RedditProxy.json"];
}

- (void)loadConfiguration {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    // Force default to OFF on upgrade to clean up any old dead configs
    if (![defaults boolForKey:kPrefResetV4]) {
        [defaults setBool:YES forKey:kPrefResetV4];
        self.enabled = NO;
        self.hasConfigured = NO;
        self.proxyType = RedditProxyTypeHTTP;
        self.host = @"34.43.46.91";
        self.port = 443;
        self.username = nil;
        self.password = nil;
        [self saveConfiguration];
        NSLog(@"[RedditProxy] Reset to OFF by default for V4.");
        return;
    }

    // 1. Try reading from Documents/RedditProxy.json (allows manual edit via Files app)
    NSString *path = [self configFilePath];
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (data) {
        NSError *err = nil;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&err];
        if ([json isKindOfClass:[NSDictionary class]]) {
            self.enabled = json[@"enabled"] ? [json[@"enabled"] boolValue] : NO;
            self.hasConfigured = json[@"hasConfigured"] ? [json[@"hasConfigured"] boolValue] : YES;
            NSString *typeStr = json[@"type"];
            self.proxyType = ([typeStr isEqualToString:@"SOCKS5"]) ? RedditProxyTypeSOCKS5 : RedditProxyTypeHTTP;
            self.host = json[@"host"] ?: @"34.43.46.91";
            self.port = json[@"port"] ? [json[@"port"] integerValue] : 443;
            self.username = json[@"username"];
            self.password = json[@"password"];
            NSLog(@"[RedditProxy] Loaded config from JSON file: %@:%ld (%@)", self.host, (long)self.port, self.enabled ? @"ENABLED" : @"DISABLED");
            return;
        }
    }

    // 2. Fallback to NSUserDefaults
    if ([defaults objectForKey:kPrefHost]) {
        self.enabled = [defaults objectForKey:kPrefEnabled] ? [defaults boolForKey:kPrefEnabled] : NO;
        self.hasConfigured = [defaults boolForKey:kPrefConfigured];
        self.proxyType = (RedditProxyType)[defaults integerForKey:kPrefType];
        self.host = [defaults stringForKey:kPrefHost] ?: @"34.43.46.91";
        self.port = [defaults integerForKey:kPrefPort] ?: 443;
        self.username = [defaults stringForKey:kPrefUser];
        self.password = [defaults stringForKey:kPrefPass];
    } else {
        // Defaults: Disabled by default to prevent network lockouts!
        self.enabled = NO;
        self.hasConfigured = NO;
        self.proxyType = RedditProxyTypeHTTP;
        self.host = @"34.43.46.91";
        self.port = 443;
        self.username = nil;
        self.password = nil;
        [self saveConfiguration];
    }
}

- (void)saveConfiguration {
    // Save to NSUserDefaults
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:self.enabled forKey:kPrefEnabled];
    [defaults setBool:self.hasConfigured forKey:kPrefConfigured];
    [defaults setInteger:self.proxyType forKey:kPrefType];
    [defaults setObject:self.host forKey:kPrefHost];
    [defaults setInteger:self.port forKey:kPrefPort];
    [defaults setObject:self.username forKey:kPrefUser];
    [defaults setObject:self.password forKey:kPrefPass];
    [defaults synchronize];

    // Save to Documents/RedditProxy.json for easy access via Files app
    NSMutableDictionary *json = [NSMutableDictionary dictionary];
    json[@"enabled"] = @(self.enabled);
    json[@"hasConfigured"] = @(self.hasConfigured);
    json[@"type"] = (self.proxyType == RedditProxyTypeSOCKS5) ? @"SOCKS5" : @"HTTP";
    json[@"host"] = self.host ?: @"";
    json[@"port"] = @(self.port);
    if (self.username) json[@"username"] = self.username;
    if (self.password) json[@"password"] = self.password;
    json[@"description"] = @"Reddit Proxy Configuration for bypassing network blocks in Vietnam. Edit this file directly in the Files app.";

    NSData *data = [NSJSONSerialization dataWithJSONObject:json options:NSJSONWritingPrettyPrinted error:nil];
    if (data) {
        [data writeToFile:[self configFilePath] atomically:YES];
    }
    NSLog(@"[RedditProxy] Configuration saved: %@:%ld (%@)", self.host, (long)self.port, self.enabled ? @"ENABLED" : @"DISABLED");
}

- (NSDictionary *)proxyDictionary {
    if (!self.enabled || self.host.length == 0 || self.port <= 0) {
        return @{};
    }

    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    if (self.proxyType == RedditProxyTypeSOCKS5) {
        dict[kRPSOCKSEnable] = @YES;
        dict[kRPSOCKSProxy] = self.host;
        dict[kRPSOCKSPort] = @(self.port);
        dict[(NSString *)kCFStreamPropertySOCKSVersion] = (NSString *)kCFStreamSocketSOCKSVersion5;
        dict[(NSString *)kCFStreamPropertySOCKSProxyHost] = self.host;
        dict[(NSString *)kCFStreamPropertySOCKSProxyPort] = @(self.port);
        if (self.username.length > 0) {
            dict[(NSString *)kCFStreamPropertySOCKSUser] = self.username;
        }
        if (self.password.length > 0) {
            dict[(NSString *)kCFStreamPropertySOCKSPassword] = self.password;
        }
    } else {
        // HTTP & HTTPS Proxy
        dict[kRPHTTPEnable] = @YES;
        dict[kRPHTTPProxy] = self.host;
        dict[kRPHTTPPort] = @(self.port);

        dict[kRPHTTPSEnable] = @YES;
        dict[kRPHTTPSProxy] = self.host;
        dict[kRPHTTPSPort] = @(self.port);
    }

    return [dict copy];
}

- (NSArray<RedditProxyPreset *> *)availablePresets {
    return @[
        [RedditProxyPreset presetWithName:@"🇸🇬 [SG] Singapore Fast SOCKS5" type:RedditProxyTypeSOCKS5 host:@"143.198.90.221" port:1088],
        [RedditProxyPreset presetWithName:@"🇰🇷 [KR] South Korea Fast HTTP" type:RedditProxyTypeHTTP host:@"112.216.54.226" port:12121],
        [RedditProxyPreset presetWithName:@"🇮🇩 [ID] Indonesia / SG HTTP" type:RedditProxyTypeHTTP host:@"8.215.25.3" port:2081],
        [RedditProxyPreset presetWithName:@"🇺🇸 [US] Google Anycast HTTP" type:RedditProxyTypeHTTP host:@"34.43.46.91" port:443],
        [RedditProxyPreset presetWithName:@"⚡ [LOCAL] Clash / Shadowrocket (7890)" type:RedditProxyTypeHTTP host:@"127.0.0.1" port:7890],
        [RedditProxyPreset presetWithName:@"⚡ [LOCAL] Sing-box / V2Ray (10808)" type:RedditProxyTypeSOCKS5 host:@"127.0.0.1" port:10808],
        [RedditProxyPreset presetWithName:@"⚡ [LOCAL] SOCKS5 Loopback (1080)" type:RedditProxyTypeSOCKS5 host:@"127.0.0.1" port:1080]
    ];
}

- (void)applyPreset:(RedditProxyPreset *)preset {
    self.host = preset.host;
    self.port = preset.port;
    self.proxyType = preset.type;
    self.enabled = YES;
    [self saveConfiguration];
}

- (void)checkCurrentIPAndCountryWithCompletion:(void (^)(BOOL success, NSString * _Nullable ip, NSString * _Nullable country, NSString * _Nullable details))completion {
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    if (self.enabled) {
        config.connectionProxyDictionary = [self proxyDictionary];
    }
    config.timeoutIntervalForRequest = 4.0;
    config.timeoutIntervalForResource = 4.0;

    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
    NSURL *url = [NSURL URLWithString:@"https://cloudflare.com/cdn-cgi/trace"];

    NSURLSessionDataTask *task = [session dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (!error && data) {
            NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            NSString *ip = @"Unknown";
            NSString *loc = @"Unknown";
            NSString *colo = @"";
            for (NSString *line in [str componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
                if ([line hasPrefix:@"ip="]) {
                    ip = [line substringFromIndex:3];
                } else if ([line hasPrefix:@"loc="]) {
                    loc = [line substringFromIndex:4];
                } else if ([line hasPrefix:@"colo="]) {
                    colo = [line substringFromIndex:5];
                }
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                NSString *flag = @"🌐";
                if ([loc isEqualToString:@"SG"]) flag = @"🇸🇬";
                else if ([loc isEqualToString:@"KR"]) flag = @"🇰🇷";
                else if ([loc isEqualToString:@"JP"]) flag = @"🇯🇵";
                else if ([loc isEqualToString:@"US"]) flag = @"🇺🇸";
                else if ([loc isEqualToString:@"VN"]) flag = @"🇻🇳";
                else if ([loc isEqualToString:@"ID"]) flag = @"🇮🇩";
                else if ([loc isEqualToString:@"TH"]) flag = @"🇹🇭";

                NSString *details = [NSString stringWithFormat:@"%@ Country: %@\n🌍 Public IP: %@\n🏢 Edge Datacenter: %@\n🔀 Status: %@",
                                     flag, loc, ip, colo, self.enabled ? @"Proxied" : @"Direct Connection (Stock)"];
                completion(YES, ip, loc, details);
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, nil, nil, error ? error.localizedDescription : @"Failed to fetch location");
            });
        }
    }];
    [task resume];
}

- (void)testConnectionWithCompletion:(void (^)(BOOL success, NSTimeInterval latencyMs, NSString * _Nullable message))completion {
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    config.connectionProxyDictionary = [self proxyDictionary];
    config.timeoutIntervalForRequest = 5.0;
    config.timeoutIntervalForResource = 5.0;

    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
    NSURL *url = [NSURL URLWithString:@"https://www.reddit.com/api/v1/scopes"];

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:5.0];
    [req setValue:@"Reddit/2026.26.0 (iOS)" forHTTPHeaderField:@"User-Agent"];

    NSDate *startDate = [NSDate date];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:req completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:startDate] * 1000.0;
        dispatch_async(dispatch_get_main_queue(), ^{
            NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)response;
            NSInteger status = httpResp.statusCode;
            if (!error && (status == 200 || status == 301 || status == 302 || status == 403)) {
                // Any response from Reddit server proves proxy tunnel connected successfully
                completion(YES, elapsed, [NSString stringWithFormat:@"Proxy connected to Reddit successfully!\nLatency: %.0f ms (HTTP %ld)", elapsed, (long)status]);
            } else if (error) {
                NSString *errDesc = error.localizedDescription;
                if (error.code == 310) {
                    errDesc = @"Proxy tunnel rejected or timed out (Error 310).\nPlease select another preset or use local Clash/Shadowrocket.";
                }
                completion(NO, elapsed, errDesc);
            } else {
                completion(NO, elapsed, [NSString stringWithFormat:@"HTTP error status %ld", (long)status]);
            }
        });
    }];
    [task resume];
}

@end
