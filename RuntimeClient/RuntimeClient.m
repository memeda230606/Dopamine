#import "RuntimeClient.h"
#import "LabSupport.h"
#import <dlfcn.h>
#import <mach-o/loader.h>
// Single canonical ABI definition, private to this adapter.
#import "../BaseBin/libjailbreak/src/info.h"
@implementation DORuntimeClient {
    void *_library;
    NSString *_fingerprint;
    BOOL _abiKnown;
}
+ (instancetype)sharedClient { static id client; static dispatch_once_t once; dispatch_once(&once,^{client=[self new];});return client; }
- (instancetype)init {
    if((self=[super init])) {
        NSString *path=@"/var/jb/basebin/libjailbreak.dylib";
        NSData *data=[NSData dataWithContentsOfFile:path];
        NSDictionary *abi=[NSDictionary dictionaryWithContentsOfFile:[NSBundle.mainBundle pathForResource:@"RuntimeABI" ofType:@"plist"]];
        _fingerprint=data?LSHash(data):@"";
        _abiKnown=[abi[@"backend_sha256"] containsObject:_fingerprint];
        // Unknown backends are rejected before loading or touching exported structure data.
        if(_abiKnown)_library=dlopen(path.fileSystemRepresentation,RTLD_NOW|RTLD_LOCAL);
    }return self;
}
- (NSDictionary *)status {
    char *(*getRoot)(void)=_library?dlsym(_library,"jbclient_get_jbroot"):NULL;
    char *root=getRoot?getRoot():NULL;NSString *path=root?@(root):@"";
    BOOL exports=_library && dlsym(_library,"jbclient_trust_file_by_path") && dlsym(_library,"jbclient_initialize_primitives") && dlsym(_library,"kreadbuf") && dlsym(_library,"gSystemInfo");
    return @{@"available":@(exports && path.length>0),@"abi_verified":@(_abiKnown),@"backend_sha256":_fingerprint?:@"",@"root":path,@"abi_policy":@"exact-backend-fingerprint"};
}
- (int)trustFile:(NSString *)path {
    int (*trust)(const char *)=_library?dlsym(_library,"jbclient_trust_file_by_path"):NULL;
    return trust?trust(path.fileSystemRepresentation):-1;
}
- (NSDictionary *)readKernelHeader {
    if(![self.status[@"available"] boolValue])return @{@"passed":@NO,@"error":@"运行环境不可用或 ABI 不匹配",@"runtime":self.status};
    int (*initialize)(void)=dlsym(_library,"jbclient_initialize_primitives");
    int (*readKernel)(uint64_t,void *,size_t)=dlsym(_library,"kreadbuf");
    struct system_info *info=dlsym(_library,"gSystemInfo");
    int init=initialize();uint32_t magic=0;int read=-1;
    if(init==0 && info->kernelConstant.base)read=readKernel(info->kernelConstant.base,&magic,sizeof(magic));
    return @{@"passed":@(init==0 && read==0 && magic==MH_MAGIC_64),@"initialize_result":@(init),@"read_result":@(read),
        @"kernel_base":[NSString stringWithFormat:@"0x%llx",info->kernelConstant.base],@"magic":[NSString stringWithFormat:@"0x%08x",magic],@"bytes_read":@4,@"kernel_write_tested":@NO,@"abi_verified":@YES};
}
@end
