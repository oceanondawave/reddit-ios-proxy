#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "RedditProxyManager.h"
#import "RedditProxyHooks.h"
#import "RedditProxyUI.h"

__attribute__((constructor))
static void RedditProxyInit(void) {
    NSLog(@"[RedditProxy] Initializing RedditProxy tweak");

    // 1. Initialize manager & load configuration
    [RedditProxyManager sharedManager];

    // 2. Install networking & settings UI hooks
    [RedditProxyHooks installHooks];

    // 3. Handle activation & first-launch prompt
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        RedditProxyManager *mgr = [RedditProxyManager sharedManager];
        [mgr loadConfiguration];

        if (!mgr.hasConfigured) {
            static BOOL promptShown = NO;
            if (promptShown) return;
            promptShown = YES;

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                UIViewController *top = [[RedditProxyUI sharedInstance] resolvePresentingViewController:nil];
                if (top) {
                    UIAlertController *prompt = [UIAlertController alertControllerWithTitle:@"Reddit Proxy (Vietnam)"
                                                                                   message:@"Reddit Proxy tweak is installed (currently DISABLED so your app works normally).\n\nWould you like to configure and enable a proxy now?\n\n(Tip: You can shake your phone anytime to open Proxy Settings)."
                                                                            preferredStyle:UIAlertControllerStyleAlert];

                    [prompt addAction:[UIAlertAction actionWithTitle:@"Configure Now" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                        mgr.hasConfigured = YES;
                        [mgr saveConfiguration];
                        [RedditProxyUI sharedInstance].isModalPresented = NO;
                        [[RedditProxyUI sharedInstance] showSettingsModalFromViewController:top];
                    }]];

                    [prompt addAction:[UIAlertAction actionWithTitle:@"Keep Disabled" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                        mgr.hasConfigured = YES;
                        [mgr saveConfiguration];
                    }]];

                    [top presentViewController:prompt animated:YES completion:nil];
                }
            });
        }
    }];
}
