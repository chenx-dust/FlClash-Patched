#import "IOSCoreBridge.h"

#import "../../core/bride.h"
#import "../../libclash/ios/arm64/libclash.h"

static void IOSCoreReleaseObject(void *obj) {
  if (obj != NULL) {
    CFBridgingRelease(obj);
  }
}

static void IOSCoreFreeString(char *data) {
  free(data);
}

static void IOSCoreProtect(void *tunInterface, int fd) {}

static char *IOSCoreResolveProcess(
    void *tunInterface,
    int protocol,
    const char *source,
    const char *target,
    int uid) {
  return strdup("");
}

static void IOSCoreResult(void *invokeInterface, const char *data) {
  if (invokeInterface == NULL) {
    return;
  }
  IOSCoreResultHandler handler = (__bridge IOSCoreResultHandler)invokeInterface;
  NSString *result = data == NULL ? nil : [NSString stringWithUTF8String:data];
  dispatch_async(dispatch_get_main_queue(), ^{
    handler(result);
  });
}

@implementation IOSCoreBridge

+ (void)initializeBridge {
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    release_object_func = &IOSCoreReleaseObject;
    free_string_func = &IOSCoreFreeString;
    protect_func = &IOSCoreProtect;
    resolve_process_func = &IOSCoreResolveProcess;
    result_func = &IOSCoreResult;
  });
}

+ (void)invokeAction:(NSString *)action result:(IOSCoreResultHandler)result {
  [self initializeBridge];
  IOSCoreResultHandler retainedResult = [result copy];
  char *params = strdup(action.UTF8String);
  invokeAction((void *)CFBridgingRetain(retainedResult), params);
}

@end
