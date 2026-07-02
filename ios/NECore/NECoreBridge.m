#import "NECoreBridge.h"

#import "../../core/bride.h"
#import "../../libclash/ios/arm64/libclash.h"
#import <os/log.h>
#import <string.h>

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

static os_log_t NECoreLogger(void) {
  static os_log_t logger;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    logger = os_log_create("com.follow.clash.Y8RH943F65.NECore", "Clash");
  });
  return logger;
}

static os_log_type_t NECoreLogType(const char *level) {
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

static void NECoreSystemLog(const char *level, const char *message) {
  os_log_with_type(
      NECoreLogger(),
      NECoreLogType(level),
      "[%{public}s] %{public}s",
      level == NULL ? "unknown" : level,
      message == NULL ? "" : message);
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
    system_log_func = &NECoreSystemLog;
  });
}

+ (void)invokeAction:(NSString *)action result:(NECoreResultHandler)result {
  [self initializeBridge];
  NECoreResultHandler retainedResult = [result copy];
  char *params = strdup(action.UTF8String);
  invokeAction((void *)CFBridgingRetain(retainedResult), params);
}

+ (void)setEventListener:(NECoreResultHandler _Nullable)listener {
  [self initializeBridge];
  if (listener == nil) {
    setEventListener(NULL);
    return;
  }
  NECoreResultHandler retainedListener = [listener copy];
  setEventListener((void *)CFBridgingRetain(retainedListener));
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

+ (void)setSuspended:(BOOL)suspended {
  [self initializeBridge];
  suspend(suspended ? 1 : 0);
}

@end
