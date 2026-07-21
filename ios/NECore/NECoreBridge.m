#import "NECoreBridge.h"

#import "../../core/bride.h"
#import "../../libclash/ios/arm64/libclash.h"
#import <os/log.h>
#import <string.h>

static void *NECoreCallbackQueueKey(void);
static dispatch_queue_t NECoreCallbackQueue(void);

static void NECoreReleaseObject(void *obj) {
  if (obj != NULL) {
    CFBridgingRelease(obj);
  }
}

static void *NECoreRetainObject(void *obj) {
  return obj == NULL ? NULL : (void *)CFRetain(obj);
}

static void NECoreFreeString(char *data) {
  free(data);
}

static char *NECoreCopyData(NSData *data) {
  char *copy = malloc(data.length + 1);
  if (copy == NULL) {
    return NULL;
  }
  if (data.length > 0) {
    memcpy(copy, data.bytes, data.length);
  }
  copy[data.length] = '\0';
  return copy;
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
  @autoreleasepool {
    NECoreResultHandler handler = (__bridge NECoreResultHandler)invokeInterface;
    NSData *result = data == NULL
        ? nil
        : [[NSData alloc] initWithBytes:data length:strlen(data)];
    dispatch_block_t invokeHandler = ^{
      @autoreleasepool {
        handler(result);
      }
    };
    dispatch_queue_t callbackQueue = NECoreCallbackQueue();
    if (dispatch_get_specific(NECoreCallbackQueueKey()) != NULL) {
      invokeHandler();
      return;
    }
    dispatch_sync(callbackQueue, invokeHandler);
  }
}

static void *NECoreCallbackQueueKey(void) {
  static char queueKey;
  return &queueKey;
}

static dispatch_queue_t NECoreCallbackQueue(void) {
  static dispatch_queue_t callbackQueue;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    callbackQueue = dispatch_queue_create(
        "com.follow.clash.ne-core.callback",
        DISPATCH_QUEUE_SERIAL);
    dispatch_queue_set_specific(
        callbackQueue,
        NECoreCallbackQueueKey(),
        NECoreCallbackQueueKey(),
        NULL);
  });
  return callbackQueue;
}

static os_log_t NECoreLogger(void) {
  static os_log_t logger;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    logger = os_log_create(NSBundle.mainBundle.bundleIdentifier.UTF8String, "Clash");
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
  if (message == NULL) {
    return;
  }
  os_log_with_type(
      NECoreLogger(),
      NECoreLogType(level),
      "%{public}s",
      message);
}

@implementation NECoreBridge

+ (void)initializeBridge {
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    release_object_func = &NECoreReleaseObject;
    retain_object_func = &NECoreRetainObject;
    free_string_func = &NECoreFreeString;
    protect_func = &NECoreProtect;
    resolve_process_func = &NECoreResolveProcess;
    result_func = &NECoreResult;
    system_log_func = &NECoreSystemLog;
  });
}

+ (void)invokeMethod:(NSData *)methodCall result:(NECoreResultHandler)result {
  [self initializeBridge];
  NECoreResultHandler retainedResult = [result copy];
  char *params = NECoreCopyData(methodCall);
  invokeMethod((void *)CFBridgingRetain(retainedResult), params);
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

+ (void)quickSetupWithInitParams:(NSString *)initParams
                     setupParams:(NSData *)setupParams
                          result:(NECoreResultHandler)result {
  [self initializeBridge];
  NECoreResultHandler retainedResult = [result copy];
  quickSetup(
      (void *)CFBridgingRetain(retainedResult),
      strdup(initParams.UTF8String),
      NECoreCopyData(setupParams));
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
