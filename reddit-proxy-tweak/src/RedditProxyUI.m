#import "RedditProxyUI.h"
#import "RedditProxyManager.h"

@implementation RedditProxyUI

+ (instancetype)sharedInstance {
    static RedditProxyUI *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[RedditProxyUI alloc] init];
    });
    return instance;
}

- (UIViewController *)topViewControllerFrom:(UIViewController *)vc {
    if ([vc isKindOfClass:[UINavigationController class]]) {
        return [self topViewControllerFrom:[(UINavigationController *)vc visibleViewController]];
    }
    if ([vc isKindOfClass:[UITabBarController class]]) {
        return [self topViewControllerFrom:[(UITabBarController *)vc selectedViewController]];
    }
    if (vc.presentedViewController) {
        return [self topViewControllerFrom:vc.presentedViewController];
    }
    return vc;
}

- (UIViewController *)resolvePresentingViewController:(nullable UIViewController *)caller {
    if (caller) {
        return [self topViewControllerFrom:caller];
    }
    UIWindow *keyWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive && [scene isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *windowScene = (UIWindowScene *)scene;
                for (UIWindow *w in windowScene.windows) {
                    if (w.isKeyWindow) {
                        keyWindow = w;
                        break;
                    }
                }
            }
        }
    }
    if (!keyWindow) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        keyWindow = [UIApplication sharedApplication].keyWindow ?: [UIApplication sharedApplication].windows.firstObject;
#pragma clang diagnostic pop
    }
    return [self topViewControllerFrom:keyWindow.rootViewController];
}

- (void)showSettingsModalFromViewController:(nullable UIViewController *)presentingVC {
    if (self.isModalPresented) {
        return;
    }

    UIViewController *top = [self resolvePresentingViewController:presentingVC];
    if (!top || [top isKindOfClass:[UIAlertController class]]) {
        return;
    }

    self.isModalPresented = YES;

    RedditProxyManager *mgr = [RedditProxyManager sharedManager];
    NSString *statusStr = mgr.enabled ? @"🟢 ACTIVE" : @"⚪ DISABLED";
    NSString *typeStr = (mgr.proxyType == RedditProxyTypeSOCKS5) ? @"SOCKS5" : @"HTTP";
    NSString *msg = [NSString stringWithFormat:@"Status: %@\nType: %@\nServer: %@:%ld\n\nConfigure proxy settings to bypass Vietnamese ISP blocking.", statusStr, typeStr, mgr.host, (long)mgr.port];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Reddit Proxy (Vietnam Bypass)"
                                                                   message:msg
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    // Toggle Action
    NSString *toggleTitle = mgr.enabled ? @"Turn Proxy OFF" : @"Turn Proxy ON";
    [alert addAction:[UIAlertAction actionWithTitle:toggleTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        self.isModalPresented = NO;
        mgr.enabled = !mgr.enabled;
        [mgr saveConfiguration];
        [self showToast:[NSString stringWithFormat:@"Proxy %@", mgr.enabled ? @"Enabled" : @"Disabled"] from:top];
    }]];

    // Presets
    [alert addAction:[UIAlertAction actionWithTitle:@"Select Free Fast Preset..." style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self showPresetsModalFrom:top];
    }]];

    // Custom Server
    [alert addAction:[UIAlertAction actionWithTitle:@"Configure Custom Host & Port..." style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self showCustomServerModalFrom:top];
    }]];

    // Test Connection
    [alert addAction:[UIAlertAction actionWithTitle:@"Test Reddit Connection" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self runConnectionTestFrom:top];
    }]];

    // Check Current IP & Country
    [alert addAction:[UIAlertAction actionWithTitle:@"🌍 Check My IP & Country Location" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self runLocationCheckFrom:top];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        self.isModalPresented = NO;
    }]];

    if (alert.popoverPresentationController) {
        alert.popoverPresentationController.sourceView = top.view;
        alert.popoverPresentationController.sourceRect = CGRectMake(top.view.bounds.size.width / 2, top.view.bounds.size.height / 2, 1, 1);
    }
    [top presentViewController:alert animated:YES completion:nil];
}

- (void)showPresetsModalFrom:(UIViewController *)top {
    RedditProxyManager *mgr = [RedditProxyManager sharedManager];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Fast Proxy Presets"
                                                                   message:@"Select a server to route Reddit traffic:"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    for (RedditProxyPreset *p in [mgr availablePresets]) {
        NSString *title = [NSString stringWithFormat:@"%@ (%@:%ld)", p.name, p.host, (long)p.port];
        [alert addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            self.isModalPresented = NO;
            [mgr applyPreset:p];
            [self showToast:[NSString stringWithFormat:@"Applied %@", p.name] from:top];
        }]];
    }

    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        self.isModalPresented = NO;
    }]];

    if (alert.popoverPresentationController) {
        alert.popoverPresentationController.sourceView = top.view;
        alert.popoverPresentationController.sourceRect = CGRectMake(top.view.bounds.size.width / 2, top.view.bounds.size.height / 2, 1, 1);
    }
    [top presentViewController:alert animated:YES completion:nil];
}

- (void)showCustomServerModalFrom:(UIViewController *)top {
    RedditProxyManager *mgr = [RedditProxyManager sharedManager];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Configure Proxy Server"
                                                                   message:@"Enter proxy IP/domain and port:"
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"Proxy Host / IP (e.g. 127.0.0.1)";
        textField.text = mgr.host;
    }];

    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"Port (e.g. 8080 or 1080)";
        textField.text = [NSString stringWithFormat:@"%ld", (long)mgr.port];
        textField.keyboardType = UIKeyboardTypeNumberPad;
    }];

    [alert addAction:[UIAlertAction actionWithTitle:@"Save as HTTP" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        self.isModalPresented = NO;
        NSString *host = alert.textFields[0].text;
        NSInteger port = [alert.textFields[1].text integerValue];
        if (host.length > 0 && port > 0) {
            mgr.host = host;
            mgr.port = port;
            mgr.proxyType = RedditProxyTypeHTTP;
            mgr.enabled = YES;
            [mgr saveConfiguration];
            [self showToast:@"HTTP Proxy Saved & Active" from:top];
        }
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"Save as SOCKS5" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        self.isModalPresented = NO;
        NSString *host = alert.textFields[0].text;
        NSInteger port = [alert.textFields[1].text integerValue];
        if (host.length > 0 && port > 0) {
            mgr.host = host;
            mgr.port = port;
            mgr.proxyType = RedditProxyTypeSOCKS5;
            mgr.enabled = YES;
            [mgr saveConfiguration];
            [self showToast:@"SOCKS5 Proxy Saved & Active" from:top];
        }
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        self.isModalPresented = NO;
    }]];
    [top presentViewController:alert animated:YES completion:nil];
}

- (void)runConnectionTestFrom:(UIViewController *)top {
    [self showToast:@"Testing connection to Reddit..." from:top];
    [[RedditProxyManager sharedManager] testConnectionWithCompletion:^(BOOL success, NSTimeInterval latencyMs, NSString * _Nullable message) {
        NSString *title = success ? @"✅ Proxy Test Passed" : @"❌ Proxy Test Failed";
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            self.isModalPresented = NO;
        }]];
        [top presentViewController:alert animated:YES completion:nil];
    }];
}

- (void)runLocationCheckFrom:(UIViewController *)top {
    [self showToast:@"Checking IP & Country..." from:top];
    [[RedditProxyManager sharedManager] checkCurrentIPAndCountryWithCompletion:^(BOOL success, NSString * _Nullable ip, NSString * _Nullable country, NSString * _Nullable details) {
        NSString *title = success ? @"Location & IP Check" : @"Location Check Failed";
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:details preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            self.isModalPresented = NO;
        }]];
        [top presentViewController:alert animated:YES completion:nil];
    }];
}

- (void)showToast:(NSString *)msg from:(UIViewController *)top {
    if (!top) return;

    UILabel *toast = [[UILabel alloc] init];
    toast.text = msg;
    toast.textColor = [UIColor whiteColor];
    toast.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    toast.textAlignment = NSTextAlignmentCenter;
    toast.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.92];
    toast.layer.cornerRadius = 14;
    toast.layer.masksToBounds = YES;
    toast.alpha = 0.0;

    CGSize size = [msg sizeWithAttributes:@{NSFontAttributeName: toast.font}];
    toast.frame = CGRectMake((top.view.bounds.size.width - (size.width + 32)) / 2, top.view.bounds.size.height - 110, size.width + 32, 32);

    [top.view addSubview:toast];
    [UIView animateWithDuration:0.2 animations:^{
        toast.alpha = 1.0;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.3 delay:1.8 options:0 animations:^{
            toast.alpha = 0.0;
        } completion:^(BOOL finished) {
            [toast removeFromSuperview];
        }];
    }];
}

@end
