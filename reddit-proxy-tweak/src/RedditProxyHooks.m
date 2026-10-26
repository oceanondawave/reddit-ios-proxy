#import "RedditProxyHooks.h"
#import "RedditProxyManager.h"
#import "RedditProxyUI.h"
#import "fishhook.h"
#import <objc/runtime.h>
#import <CFNetwork/CFNetwork.h>
#import <UIKit/UIKit.h>

static NSInteger const kRedditProxyActionTag = 1338;

static void SwizzleInstanceMethod(Class cls, SEL origSel, SEL swizzledSel) {
    Method origMethod = class_getInstanceMethod(cls, origSel);
    Method swizzledMethod = class_getInstanceMethod(cls, swizzledSel);
    if (!origMethod || !swizzledMethod) {
        NSLog(@"[RedditProxy] Note: Method %@ not found on %@", NSStringFromSelector(origSel), NSStringFromClass(cls));
        return;
    }
    BOOL didAdd = class_addMethod(cls, origSel, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod));
    if (didAdd) {
        class_replaceMethod(cls, swizzledSel, method_getImplementation(origMethod), method_getTypeEncoding(origMethod));
    } else {
        method_exchangeImplementations(origMethod, swizzledMethod);
    }
}

static void SwizzleClassMethod(Class cls, SEL origSel, SEL swizzledSel) {
    Class metaCls = object_getClass((id)cls);
    Method origMethod = class_getClassMethod(cls, origSel);
    Method swizzledMethod = class_getClassMethod(cls, swizzledSel);
    if (!origMethod || !swizzledMethod) {
        NSLog(@"[RedditProxy] Note: Class method %@ not found on %@", NSStringFromSelector(origSel), NSStringFromClass(cls));
        return;
    }
    BOOL didAdd = class_addMethod(metaCls, origSel, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod));
    if (didAdd) {
        class_replaceMethod(metaCls, swizzledSel, method_getImplementation(origMethod), method_getTypeEncoding(origMethod));
    } else {
        method_exchangeImplementations(origMethod, swizzledMethod);
    }
}

#pragma mark - CFNetwork C Hook

static CFDictionaryRef (*orig_CFNetworkCopySystemProxySettings)(void) = NULL;

static CFDictionaryRef my_CFNetworkCopySystemProxySettings(void) {
    RedditProxyManager *mgr = [RedditProxyManager sharedManager];
    if (mgr.enabled) {
        NSDictionary *proxyDict = [mgr proxyDictionary];
        if (proxyDict.count > 0) {
            return (CFDictionaryRef)CFBridgingRetain(proxyDict);
        }
    }
    if (orig_CFNetworkCopySystemProxySettings) {
        return orig_CFNetworkCopySystemProxySettings();
    }
    return NULL;
}

#pragma mark - NSURLSessionConfiguration Swizzles

@interface NSURLSessionConfiguration (RedditProxySwizzle)
@end

@implementation NSURLSessionConfiguration (RedditProxySwizzle)

- (NSDictionary *)rp_connectionProxyDictionary {
    RedditProxyManager *mgr = [RedditProxyManager sharedManager];
    if (mgr.enabled) {
        NSDictionary *dict = [mgr proxyDictionary];
        if (dict.count > 0) {
            return dict;
        }
    }
    return [self rp_connectionProxyDictionary];
}

+ (NSURLSessionConfiguration *)rp_defaultSessionConfiguration {
    NSURLSessionConfiguration *config = [self rp_defaultSessionConfiguration];
    RedditProxyManager *mgr = [RedditProxyManager sharedManager];
    if (mgr.enabled) {
        config.connectionProxyDictionary = [mgr proxyDictionary];
        config.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    }
    return config;
}

+ (NSURLSessionConfiguration *)rp_ephemeralSessionConfiguration {
    NSURLSessionConfiguration *config = [self rp_ephemeralSessionConfiguration];
    RedditProxyManager *mgr = [RedditProxyManager sharedManager];
    if (mgr.enabled) {
        config.connectionProxyDictionary = [mgr proxyDictionary];
        config.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    }
    return config;
}

@end

#pragma mark - NSURLSession Swizzles

@interface NSURLSession (RedditProxySwizzle)
@end

@implementation NSURLSession (RedditProxySwizzle)

+ (NSURLSession *)rp_sessionWithConfiguration:(NSURLSessionConfiguration *)configuration {
    RedditProxyManager *mgr = [RedditProxyManager sharedManager];
    if (mgr.enabled && configuration) {
        configuration.connectionProxyDictionary = [mgr proxyDictionary];
    }
    return [self rp_sessionWithConfiguration:configuration];
}

+ (NSURLSession *)rp_sessionWithConfiguration:(NSURLSessionConfiguration *)configuration
                                     delegate:(nullable id <NSURLSessionDelegate>)delegate
                                delegateQueue:(nullable NSOperationQueue *)queue {
    RedditProxyManager *mgr = [RedditProxyManager sharedManager];
    if (mgr.enabled && configuration) {
        configuration.connectionProxyDictionary = [mgr proxyDictionary];
    }
    return [self rp_sessionWithConfiguration:configuration delegate:delegate delegateQueue:queue];
}

@end

#pragma mark - UserDrawerViewController Hooks (Settings Entry Point)

@interface NSObject ()
- (NSMutableArray *)availableUserActions;
- (UITableView *)actionsTableView;
@end

@interface UIViewController (RedditUserDrawer)
- (void)rp_defineAvailableUserActions;
- (UITableViewCell *)rp_tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)rp_tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath;
@end

@implementation UIViewController (RedditUserDrawer)

- (void)rp_defineAvailableUserActions {
    [self rp_defineAvailableUserActions];
    if ([self respondsToSelector:@selector(availableUserActions)]) {
        NSMutableArray *actions = [self availableUserActions];
        if ([actions isKindOfClass:[NSMutableArray class]]) {
            NSNumber *proxyAction = @(kRedditProxyActionTag);
            if (![actions containsObject:proxyAction]) {
                [actions addObject:proxyAction];
            }
        }
    }
}

- (UITableViewCell *)rp_tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self respondsToSelector:@selector(availableUserActions)]) {
        NSArray *actions = [self availableUserActions];
        if ([actions isKindOfClass:[NSArray class]] && indexPath.row < (NSInteger)actions.count) {
            NSNumber *actionNum = actions[indexPath.row];
            if ([actionNum integerValue] == kRedditProxyActionTag) {
                UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"RedditProxyUserDrawerCell"];
                if (!cell) {
                    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"RedditProxyUserDrawerCell"];
                    cell.backgroundColor = [UIColor clearColor];
                    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
                    if (@available(iOS 13.0, *)) {
                        cell.textLabel.textColor = [UIColor labelColor];
                        cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
                    }
                }
                RedditProxyManager *mgr = [RedditProxyManager sharedManager];
                cell.textLabel.text = @"Proxy Settings (Vietnam)";
                if (@available(iOS 13.0, *)) {
                    cell.imageView.image = [UIImage systemImageNamed:@"network"];
                    cell.imageView.tintColor = mgr.enabled ? [UIColor systemGreenColor] : [UIColor systemGrayColor];
                }
                if (mgr.enabled) {
                    cell.detailTextLabel.text = [NSString stringWithFormat:@"Active: %@:%ld (%@)", mgr.host, (long)mgr.port, (mgr.proxyType == RedditProxyTypeSOCKS5) ? @"SOCKS5" : @"HTTP"];
                } else {
                    cell.detailTextLabel.text = @"Disabled (Tap to configure)";
                }
                return cell;
            }
        }
    }
    return [self rp_tableView:tableView cellForRowAtIndexPath:indexPath];
}

- (void)rp_tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self respondsToSelector:@selector(availableUserActions)]) {
        NSArray *actions = [self availableUserActions];
        if ([actions isKindOfClass:[NSArray class]] && indexPath.row < (NSInteger)actions.count) {
            NSNumber *actionNum = actions[indexPath.row];
            if ([actionNum integerValue] == kRedditProxyActionTag) {
                [tableView deselectRowAtIndexPath:indexPath animated:YES];
                [[RedditProxyUI sharedInstance] showSettingsModalFromViewController:self];
                return;
            }
        }
    }
    [self rp_tableView:tableView didSelectRowAtIndexPath:indexPath];
}

@end

#pragma mark - FeedFilterSettingsViewController Hooks (Mod Settings Integration)

@interface UIViewController (RedditFilterSettings)
- (NSInteger)rp_filter_tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section;
- (UITableViewCell *)rp_filter_tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)rp_filter_tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath;
@end

@implementation UIViewController (RedditFilterSettings)

- (NSInteger)rp_filter_tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger origCount = [self rp_filter_tableView:tableView numberOfRowsInSection:section];
    return (section == 0) ? (origCount + 1) : origCount;
}

- (UITableViewCell *)rp_filter_tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger origCount = [self rp_filter_tableView:tableView numberOfRowsInSection:indexPath.section] - 1;
    if (indexPath.section == 0 && indexPath.row == origCount) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"RedditProxyFilterCell"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"RedditProxyFilterCell"];
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
        RedditProxyManager *mgr = [RedditProxyManager sharedManager];
        cell.textLabel.text = @"Proxy Settings (Vietnam)";
        if (@available(iOS 13.0, *)) {
            cell.imageView.image = [UIImage systemImageNamed:@"network"];
            cell.imageView.tintColor = mgr.enabled ? [UIColor systemGreenColor] : [UIColor systemGrayColor];
        }
        cell.detailTextLabel.text = mgr.enabled ? [NSString stringWithFormat:@"Active (%@:%ld)", mgr.host, (long)mgr.port] : @"Disabled";
        return cell;
    }
    return [self rp_filter_tableView:tableView cellForRowAtIndexPath:indexPath];
}

- (void)rp_filter_tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger origCount = [self rp_filter_tableView:tableView numberOfRowsInSection:indexPath.section] - 1;
    if (indexPath.section == 0 && indexPath.row == origCount) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        [[RedditProxyUI sharedInstance] showSettingsModalFromViewController:self];
        return;
    }
    [self rp_filter_tableView:tableView didSelectRowAtIndexPath:indexPath];
}

@end

#pragma mark - UIWindow Shake Hook

static NSTimeInterval g_lastShakeTime = 0;

@interface UIWindow (RedditProxyEvent)
- (void)rp_sendEvent:(UIEvent *)event;
@end

@implementation UIWindow (RedditProxyEvent)

- (void)rp_sendEvent:(UIEvent *)event {
    if (event.type == UIEventTypeMotion && event.subtype == UIEventSubtypeMotionShake) {
        NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
        if (now - g_lastShakeTime > 1.5) {
            g_lastShakeTime = now;
            dispatch_async(dispatch_get_main_queue(), ^{
                [[RedditProxyUI sharedInstance] showSettingsModalFromViewController:nil];
            });
        }
    }
    [self rp_sendEvent:event];
}

@end

#pragma mark - UINavigationBar Long-Press Hook

@interface UINavigationBar (RedditProxyGesture)
- (void)rp_layoutSubviews;
- (void)rp_handleNavLongPress:(UILongPressGestureRecognizer *)gesture;
@end

@implementation UINavigationBar (RedditProxyGesture)

- (void)rp_handleNavLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        [[RedditProxyUI sharedInstance] showSettingsModalFromViewController:nil];
    }
}

- (void)rp_layoutSubviews {
    [self rp_layoutSubviews];
    BOOL hasGesture = NO;
    for (UIGestureRecognizer *g in self.gestureRecognizers) {
        if ([g isKindOfClass:[UILongPressGestureRecognizer class]]) {
            hasGesture = YES;
            break;
        }
    }
    if (!hasGesture) {
        UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(rp_handleNavLongPress:)];
        lp.minimumPressDuration = 0.8;
        [self addGestureRecognizer:lp];
    }
}

@end

#pragma mark - Hook Registration

@implementation RedditProxyHooks

+ (void)installHooks {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSLog(@"[RedditProxy] Installing proxy networking & settings hooks...");

        // 1. Swizzle UIWindow sendEvent: (Shake phone to open Proxy Settings anywhere)
        SwizzleInstanceMethod([UIWindow class], @selector(sendEvent:), @selector(rp_sendEvent:));

        // 2. Swizzle UINavigationBar layoutSubviews (Long-press top navigation bar to open Settings)
        SwizzleInstanceMethod([UINavigationBar class], @selector(layoutSubviews), @selector(rp_layoutSubviews));

        // 3. Swizzle NSURLSessionConfiguration
        SwizzleInstanceMethod([NSURLSessionConfiguration class],
                              @selector(connectionProxyDictionary),
                              @selector(rp_connectionProxyDictionary));

        SwizzleClassMethod([NSURLSessionConfiguration class],
                           @selector(defaultSessionConfiguration),
                           @selector(rp_defaultSessionConfiguration));

        SwizzleClassMethod([NSURLSessionConfiguration class],
                           @selector(ephemeralSessionConfiguration),
                           @selector(rp_ephemeralSessionConfiguration));

        // 2. Swizzle NSURLSession constructors
        SwizzleClassMethod([NSURLSession class],
                           @selector(sessionWithConfiguration:),
                           @selector(rp_sessionWithConfiguration:));

        SwizzleClassMethod([NSURLSession class],
                           @selector(sessionWithConfiguration:delegate:delegateQueue:),
                           @selector(rp_sessionWithConfiguration:delegate:delegateQueue:));

        // 3. Rebind CFNetworkCopySystemProxySettings with fishhook
        struct rebinding rebindings[] = {
            {
                "CFNetworkCopySystemProxySettings",
                (void *)my_CFNetworkCopySystemProxySettings,
                (void **)&orig_CFNetworkCopySystemProxySettings
            }
        };
        rebind_symbols(rebindings, 1);

        // 4. Hook UserDrawerViewController (Side menu / Settings in Reddit)
        Class drawerCls = objc_getClass("UserDrawerViewController");
        if (drawerCls) {
            SwizzleInstanceMethod(drawerCls, @selector(defineAvailableUserActions), @selector(rp_defineAvailableUserActions));
            SwizzleInstanceMethod(drawerCls, @selector(tableView:cellForRowAtIndexPath:), @selector(rp_tableView:cellForRowAtIndexPath:));
            SwizzleInstanceMethod(drawerCls, @selector(tableView:didSelectRowAtIndexPath:), @selector(rp_tableView:didSelectRowAtIndexPath:));
            NSLog(@"[RedditProxy] UserDrawerViewController hooked successfully.");
        }

        // 5. Hook FeedFilterSettingsViewController (RedditFilter settings menu)
        Class filterSettingsCls = objc_getClass("FeedFilterSettingsViewController");
        if (filterSettingsCls) {
            SwizzleInstanceMethod(filterSettingsCls, @selector(tableView:numberOfRowsInSection:), @selector(rp_filter_tableView:numberOfRowsInSection:));
            SwizzleInstanceMethod(filterSettingsCls, @selector(tableView:cellForRowAtIndexPath:), @selector(rp_filter_tableView:cellForRowAtIndexPath:));
            SwizzleInstanceMethod(filterSettingsCls, @selector(tableView:didSelectRowAtIndexPath:), @selector(rp_filter_tableView:didSelectRowAtIndexPath:));
            NSLog(@"[RedditProxy] FeedFilterSettingsViewController hooked successfully.");
        }

        NSLog(@"[RedditProxy] All hooks successfully installed.");
    });
}

@end
