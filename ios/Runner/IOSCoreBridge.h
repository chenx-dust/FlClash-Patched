#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^IOSCoreResultHandler)(NSString *_Nullable result);

@interface IOSCoreBridge : NSObject

+ (void)invokeAction:(NSString *)action result:(IOSCoreResultHandler)result;

@end

NS_ASSUME_NONNULL_END
