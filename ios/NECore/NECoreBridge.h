#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^NECoreResultHandler)(NSString *_Nullable result);

@interface NECoreBridge : NSObject

+ (void)invokeAction:(NSString *)action result:(NECoreResultHandler)result;
+ (void)stopTun;

@end

NS_ASSUME_NONNULL_END
