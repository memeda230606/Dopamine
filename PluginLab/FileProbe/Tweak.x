#import <Foundation/Foundation.h>

@interface PLProbe : NSObject
- (NSDictionary *)fileProbe;
@end

%group LabOnly
%hook PLProbe
- (NSDictionary *)fileProbe {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSURL *documents = [fm URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
    NSURL *directory = [documents URLByAppendingPathComponent:[@"PluginLab-" stringByAppendingString:NSUUID.UUID.UUIDString]];
    NSError *error = nil;
    BOOL created = [fm createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:nil error:&error];
    NSDictionary *payload = @{@"nonce": NSUUID.UUID.UUIDString, @"text": @"独立插件文件读写验证", @"number": @42};
    NSData *data = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&error];
    NSURL *file = [directory URLByAppendingPathComponent:@"roundtrip.json"];
    BOOL wrote = created && [data writeToURL:file options:NSDataWritingAtomic error:&error];
    NSData *read = wrote ? [NSData dataWithContentsOfURL:file options:0 error:&error] : nil;
    NSDictionary *decoded = read ? [NSJSONSerialization JSONObjectWithData:read options:0 error:&error] : nil;
    BOOL matched = [decoded isEqual:payload];
    BOOL removed = created && [fm removeItemAtURL:directory error:&error];
    return @{@"ok": @(wrote && matched && removed), @"roundtrip": @(matched),
        @"cleaned_up": @(removed), @"scope": @"own-app-documents", @"error": error.localizedDescription ?: @""};
}
%end
%end

%ctor {
    if ([NSBundle.mainBundle.bundleIdentifier isEqual:@"com.mmd.PluginLab"]) %init(LabOnly);
}
