#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface RedditProxyUI : NSObject

@property (nonatomic, assign) BOOL isModalPresented;

+ (instancetype)sharedInstance;
- (nullable UIViewController *)resolvePresentingViewController:(nullable UIViewController *)caller;
- (void)showSettingsModalFromViewController:(nullable UIViewController *)presentingVC;

@end

NS_ASSUME_NONNULL_END
