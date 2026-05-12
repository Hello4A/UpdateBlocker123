#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

// 123云盘 2.1.5: com.mfcloudcalculate.123networkdisk
// 作用：尽量让 App 认为本机版本已经足够新，从源头阻止 Flutter 内部 AppUpdateDialogWidget 弹出。
// 不处理登录、会员、授权、风控等逻辑。

static NSString * const kTargetBundleID = @"com.mfcloudcalculate.123networkdisk";
static NSString * const kFakeShortVersion = @"99.99.99";
static NSString * const kFakeBuildVersion = @"999999";
static const double kFarFutureTimestampMs = 4102444800000.0; // 2100-01-01 00:00:00 UTC, milliseconds

typedef void (^FlutterResult)(id _Nullable result);

static BOOL UBIsTargetApp(void) {
    static BOOL checked = NO;
    static BOOL isTarget = NO;
    if (!checked) {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        isTarget = [bundleID isEqualToString:kTargetBundleID];
        checked = YES;
    }
    return isTarget;
}

static BOOL UBIsVersionKey(id key) {
    if (![key isKindOfClass:NSString.class]) return NO;
    NSString *s = (NSString *)key;
    return [s isEqualToString:@"CFBundleShortVersionString"] ||
           [s isEqualToString:@"CFBundleVersion"] ||
           [s isEqualToString:@"x-app-version"] ||
           [s isEqualToString:@"app-version"];
}

static BOOL UBIsUpdatePromptKey(id key) {
    if (![key isKindOfClass:NSString.class]) return NO;
    NSString *s = [(NSString *)key lowercaseString];
    return [s containsString:@"lastupdateprompttimestamp"] ||
           [s containsString:@"storelastupdateprompttimestamp"];
}

static NSString *UBSpoofedVersionForKey(id key) {
    if (![key isKindOfClass:NSString.class]) return nil;
    NSString *s = (NSString *)key;
    if ([s isEqualToString:@"CFBundleVersion"]) return kFakeBuildVersion;
    return kFakeShortVersion;
}

static NSDictionary *UBPackageInfoDictionary(void) {
    NSBundle *bundle = [NSBundle mainBundle];
    NSDictionary *info = [bundle infoDictionary];
    NSString *displayName = info[@"CFBundleDisplayName"] ?: info[@"CFBundleName"] ?: @"123云盘";
    NSString *packageName = [bundle bundleIdentifier] ?: kTargetBundleID;
    return @{
        @"appName": displayName,
        @"packageName": packageName,
        @"version": kFakeShortVersion,
        @"buildNumber": kFakeBuildVersion,
        @"buildSignature": @""
    };
}

%hook NSBundle

- (id)objectForInfoDictionaryKey:(NSString *)key {
    if (UBIsTargetApp() && UBIsVersionKey(key)) {
        NSString *v = UBSpoofedVersionForKey(key);
        if (v) return v;
    }
    return %orig;
}

- (NSDictionary *)infoDictionary {
    NSDictionary *orig = %orig;
    if (!UBIsTargetApp() || !orig) return orig;

    NSMutableDictionary *dict = [orig mutableCopy];
    dict[@"CFBundleShortVersionString"] = kFakeShortVersion;
    dict[@"CFBundleVersion"] = kFakeBuildVersion;
    return [dict copy];
}

%end

// package_info_plus.framework 会把 Info.plist 里的版本号传回 Dart。
// 这里直接拦截 getAll，避免 Flutter 层拿到 2.1.5 后触发 /api/version_upgrade 的升级判断。
%hook FLTPackageInfoPlusPlugin

- (void)handleMethodCall:(id)call result:(FlutterResult)result {
    if (UBIsTargetApp() && result && [call respondsToSelector:@selector(method)]) {
        NSString *method = ((NSString *(*)(id, SEL))objc_msgSend)(call, @selector(method));
        if ([method isEqualToString:@"getAll"]) {
            result(UBPackageInfoDictionary());
            return;
        }
    }
    %orig;
}

%end

// 123云盘 Dart AOT 中存在 lastUpdatePromptTimestamp / storeLastUpdatePromptTimestamp。
// 把“上次提示时间”固定到未来，避免非强制更新反复弹。
%hook NSUserDefaults

- (id)objectForKey:(NSString *)defaultName {
    if (UBIsTargetApp() && UBIsUpdatePromptKey(defaultName)) {
        return @(kFarFutureTimestampMs);
    }
    return %orig;
}

- (double)doubleForKey:(NSString *)defaultName {
    if (UBIsTargetApp() && UBIsUpdatePromptKey(defaultName)) {
        return kFarFutureTimestampMs;
    }
    return %orig;
}

- (NSInteger)integerForKey:(NSString *)defaultName {
    if (UBIsTargetApp() && UBIsUpdatePromptKey(defaultName)) {
        return (NSInteger)kFarFutureTimestampMs;
    }
    return %orig;
}

- (void)setObject:(id)value forKey:(NSString *)defaultName {
    if (UBIsTargetApp() && UBIsUpdatePromptKey(defaultName)) {
        %orig(@(kFarFutureTimestampMs), defaultName);
        return;
    }
    %orig;
}

- (void)setDouble:(double)value forKey:(NSString *)defaultName {
    if (UBIsTargetApp() && UBIsUpdatePromptKey(defaultName)) {
        %orig(kFarFutureTimestampMs, defaultName);
        return;
    }
    %orig;
}

- (void)setInteger:(NSInteger)value forKey:(NSString *)defaultName {
    if (UBIsTargetApp() && UBIsUpdatePromptKey(defaultName)) {
        %orig((NSInteger)kFarFutureTimestampMs, defaultName);
        return;
    }
    %orig;
}

%end

// 如果某些原生请求会设置 x-app-version / app-version，顺手替换成高版本。
// Flutter 的 Dio/dart:io 不一定经过 NSURLRequest，所以这个只是辅助保险。
%hook NSMutableURLRequest

- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    if (UBIsTargetApp() && UBIsVersionKey(field)) {
        %orig(kFakeShortVersion, field);
        return;
    }
    %orig;
}

- (void)addValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    if (UBIsTargetApp() && UBIsVersionKey(field)) {
        %orig(kFakeShortVersion, field);
        return;
    }
    %orig;
}

%end

%ctor {
    if (!UBIsTargetApp()) return;

    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    NSArray<NSString *> *keys = @[
        @"lastUpdatePromptTimestamp",
        @"storeLastUpdatePromptTimestamp",
        @"flutter.lastUpdatePromptTimestamp",
        @"flutter.storeLastUpdatePromptTimestamp"
    ];
    for (NSString *key in keys) {
        [ud setDouble:kFarFutureTimestampMs forKey:key];
    }
    [ud synchronize];
}
