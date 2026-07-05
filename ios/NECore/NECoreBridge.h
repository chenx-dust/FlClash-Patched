#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^NECoreResultHandler)(NSString *_Nullable result);

#define CTLIOCGINFO 0xc0644e03UL
struct ctl_info {
  u_int32_t ctl_id;
  char ctl_name[96];
};
struct sockaddr_ctl {
  u_char sc_len;
  u_char sc_family;
  u_int16_t ss_sysaddr;
  u_int32_t sc_id;
  u_int32_t sc_unit;
  u_int32_t sc_reserved[5];
};

@interface NECoreBridge : NSObject

+ (void)invokeMethod:(NSString *)methodCall result:(NECoreResultHandler)result;
+ (void)setEventListener:(NECoreResultHandler _Nullable)listener;
+ (void)quickSetupWithInitParams:(NSString *)initParams
                     setupParams:(NSString *)setupParams
                          result:(NECoreResultHandler)result;
+ (BOOL)startTunWithFileDescriptor:(int)fileDescriptor
                              stack:(NSString *)stack
                            address:(NSString *)address
                                dns:(NSString *)dns;
+ (void)stopTun;
+ (void)setSuspended:(BOOL)suspended;

@end

NS_ASSUME_NONNULL_END
