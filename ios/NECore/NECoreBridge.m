#import "NECoreBridge.h"

#import "../../core/bride.h"
#import "../../libclash/ios/arm64/libclash.h"

static void NECoreReleaseObject(void *obj) {
  if (obj != NULL) {
    CFBridgingRelease(obj);
  }
}

static void NECoreFreeString(char *data) {
  free(data);
}

static void NECoreProtect(void *tunInterface, int fd) {}

static char *NECoreResolveProcess(
    void *tunInterface,
    int protocol,
    const char *source,
    const char *target,
    int uid) {
  return strdup("");
}

static void NECoreResult(void *invokeInterface, const char *data) {
  if (invokeInterface == NULL) {
    return;
  }
  NECoreResultHandler handler = (__bridge NECoreResultHandler)invokeInterface;
  NSString *result = data == NULL ? nil : [NSString stringWithUTF8String:data];
  dispatch_async(dispatch_get_main_queue(), ^{
    handler(result);
  });
}

@implementation NECoreBridge

+ (void)initializeBridge {
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    release_object_func = &NECoreReleaseObject;
    free_string_func = &NECoreFreeString;
    protect_func = &NECoreProtect;
    resolve_process_func = &NECoreResolveProcess;
    result_func = &NECoreResult;
  });
}

+ (void)invokeAction:(NSString *)action result:(NECoreResultHandler)result {
  [self initializeBridge];
  NECoreResultHandler retainedResult = [result copy];
  char *params = strdup(action.UTF8String);
  invokeAction((void *)CFBridgingRetain(retainedResult), params);
}

+ (BOOL)startTunWithFileDescriptor:(int)fileDescriptor
                              stack:(NSString *)stack
                            address:(NSString *)address
                                dns:(NSString *)dns {
  [self initializeBridge];
  return startTUN(
      NULL,
      fileDescriptor,
      strdup(stack.UTF8String),
      strdup(address.UTF8String),
      strdup(dns.UTF8String));
}

+ (void)stopTun {
  [self initializeBridge];
  stopTun();
}

@end
