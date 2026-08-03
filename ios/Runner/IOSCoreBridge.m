#import "IOSCoreBridge.h"

#import "../../core/bride.h"
#import "../../libclash/ios/arm64/libclash.h"
#import <os/log.h>
#import <string.h>

static void IOSCoreReleaseObject(void *obj) {
  if (obj != NULL) {
    CFBridgingRelease(obj);
  }
}

static void *IOSCoreRetainObject(void *obj) {
  return obj == NULL ? NULL : (void *)CFRetain(obj);
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
  @autoreleasepool {
    IOSCoreResultHandler handler = (__bridge IOSCoreResultHandler)invokeInterface;
    NSString *result = data == NULL ? nil : [[NSString alloc] initWithUTF8String:data];
    dispatch_async(dispatch_get_main_queue(), ^{
      @autoreleasepool {
        handler(result);
      }
    });
  }
}

static os_log_t IOSCoreLogger(void) {
  static os_log_t logger;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    NSString *subsystem = [NSBundle.mainBundle.bundleIdentifier stringByAppendingString:@".Runner"];
    logger = os_log_create(subsystem.UTF8String, "Clash");
  });
  return logger;
}

static os_log_type_t IOSCoreLogType(const char *level) {
  if (level == NULL) {
    return OS_LOG_TYPE_DEFAULT;
  }
  if (strcmp(level, "debug") == 0) {
    return OS_LOG_TYPE_DEBUG;
  }
  if (strcmp(level, "warning") == 0) {
    return OS_LOG_TYPE_ERROR;
  }
  if (strcmp(level, "error") == 0) {
    return OS_LOG_TYPE_FAULT;
  }
  return OS_LOG_TYPE_DEFAULT;
}

static void IOSCoreSystemLog(const char *level, const char *message) {
  if (message == NULL) {
    return;
  }
  os_log_with_type(
      IOSCoreLogger(),
      IOSCoreLogType(level),
      "%{public}s",
      message);
}

@implementation IOSCoreBridge

+ (void)initializeBridge {
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    release_object_func = &IOSCoreReleaseObject;
    retain_object_func = &IOSCoreRetainObject;
    free_string_func = &IOSCoreFreeString;
    protect_func = &IOSCoreProtect;
    resolve_process_func = &IOSCoreResolveProcess;
    result_func = &IOSCoreResult;
    system_log_func = &IOSCoreSystemLog;
  });
}

+ (void)invokeMethod:(NSString *)methodCall result:(IOSCoreResultHandler)result {
  [self initializeBridge];
  IOSCoreResultHandler retainedResult = [result copy];
  char *params = strdup(methodCall.UTF8String);
  invokeMethod((void *)CFBridgingRetain(retainedResult), params);
}

+ (void)setEventListener:(IOSCoreResultHandler _Nullable)listener {
  [self initializeBridge];
  if (listener == nil) {
    setEventListener(NULL);
    return;
  }
  IOSCoreResultHandler retainedListener = [listener copy];
  setEventListener((void *)CFBridgingRetain(retainedListener));
}

@end
