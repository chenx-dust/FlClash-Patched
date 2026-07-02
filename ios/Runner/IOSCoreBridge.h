#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^IOSCoreResultHandler)(NSString *_Nullable result);

@interface IOSCoreBridge : NSObject

+ (void)invokeMethod:(NSString *)methodCall result:(IOSCoreResultHandler)result;
+ (void)setEventListener:(IOSCoreResultHandler _Nullable)listener;

@end

NS_ASSUME_NONNULL_END
