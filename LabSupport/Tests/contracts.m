#import "LabSupport.h"
#import <signal.h>
#import <sys/wait.h>
int main(void) { @autoreleasepool {
    NSString *output=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    NSDictionary *large=LSSpawn(@"/bin/sh",@[@"-c",@"i=0; while [ $i -lt 10000 ]; do echo report-output; i=$((i+1)); done"],NO,NO,output);
    NSCAssert([large[@"ok"] boolValue] && [NSData dataWithContentsOfFile:output].length>65536,@"Large output must not deadlock a pipe");
    NSDictionary *bad=LSSpawn(@"/nonexistent/lab-command",@[],NO,NO,output);NSCAssert(![bad[@"ok"] boolValue],@"Missing executable");
    NSDictionary *timeout=LSSpawnWithTimeout(@"/bin/sleep",@[@"10"],NO,NO,output,0.1);
    NSCAssert([timeout[@"timed_out"] boolValue] && ![timeout[@"ok"] boolValue],@"Bounded helper timeout");
    NSDictionary *child=LSSpawn(@"/bin/sleep",@[@"20"],NO,YES,output);pid_t pid=[child[@"pid"] intValue];
    NSMutableDictionary *record=[LSProcessIdentity(pid) mutableCopy];record[@"owned"]=@YES;
    NSCAssert(LSIdentityMatches(record,LSProcessIdentity(pid)),@"Exact owned process");
    for(NSString *key in @[@"boot_uuid",@"start_sec",@"start_usec",@"path",@"pid",@"owned"]) {
        NSMutableDictionary *wrong=record.mutableCopy;wrong[key]=@"stale";
        NSCAssert(!LSIdentityMatches(wrong,LSProcessIdentity(pid)),@"Reject reused process identity");
    }
    NSMutableDictionary *wrong=record.mutableCopy;wrong[@"boot_uuid"]=@"stale";
    NSCAssert(![LSStopOwnedProcess(wrong)[@"stopped"] boolValue] && kill(pid,0)==0,@"Must preserve unmatched process");
    NSCAssert([LSStopOwnedProcess(record)[@"stopped"] boolValue] && !LSProcessIdentity(pid).count,@"Stop verified by absence");
    NSDictionary *pending=@{@"run_id":@"a",@"before":@{@"boot_uuid":@"b"}};
    NSDictionary *result=@{@"run_id":@"a",@"boot_uuid":@"b",@"ssh_passed":@YES,@"frida_passed":@NO};
    NSCAssert(LSValidateHostResult(result,pending,@"b"),@"A failed test remains a valid result");
    NSCAssert(!LSValidateHostResult(result,pending,@"newboot"),@"Reject another boot");
    NSCAssert(!LSValidateHostResult(result,@{@"run_id":@"other"},@"b"),@"Reject another run");
    [NSFileManager.defaultManager removeItemAtPath:output error:nil];
    puts("{\"passed\":true,\"checks\":[\"large-output\",\"spawn-failure\",\"timeout\",\"pid-reuse-protection\",\"verified-stop\",\"host-result-run-and-boot-binding\"]}");
} }
