#include <substrate.h>

#define TAG "[Tweak] "

typedef CFStringRef(sec_task_copy_id_t)(void *task,
                                        CFErrorRef _Nullable *error);
sec_task_copy_id_t *SecTaskCopySigningIdentifier = NULL;

CFTypeRef (*original_SecTaskCopyValueForEntitlement)(
    void *task, CFStringRef entitlement, CFErrorRef _Nullable *error);

CFTypeRef hooked_SecTaskCopyValueForEntitlement(void *task,
                                                CFStringRef entitlement,
                                                CFErrorRef _Nullable *error) {
  NSArray *expected = @[
    @"com.apple.security.get-task-allow",
    @"com.apple.webinspector.allow",
    @"com.apple.private.webinspector.allow-remote-inspection",
    @"com.apple.private.webinspector.allow-carrier-remote-inspection",
  ];
  NSString *casted = (__bridge NSString *)entitlement;
  NSString *identifier =
      (__bridge NSString *)SecTaskCopySigningIdentifier(task, NULL);
  NSLog(@TAG "check entitlement: %@ for %@", casted, identifier);
  if ([expected containsObject:casted]) {
    NSLog(@"set allow %@", identifier);
    return kCFBooleanTrue;
  }
  return original_SecTaskCopyValueForEntitlement(task, entitlement, error);
}

%ctor {
  if (strcmp(getprogname(), "webinspectord") != 0)
    return;

  MSImageRef image = MSGetImageByName(
      "/System/Library/Frameworks/Security.framework/Security");
  if (!image) {
    NSLog(@TAG @"Security framework not found, it is impossible");
    return;
  }
  SecTaskCopySigningIdentifier = (sec_task_copy_id_t *)MSFindSymbol(
      image, "_SecTaskCopySigningIdentifier");
  MSHookFunction(MSFindSymbol(image, "_SecTaskCopyValueForEntitlement"),
                 (void *)hooked_SecTaskCopyValueForEntitlement,
                 (void **)&original_SecTaskCopyValueForEntitlement);
}
