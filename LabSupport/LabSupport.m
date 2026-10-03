#import "LabSupport.h"
#import <CommonCrypto/CommonDigest.h>
#import <os/log.h>
#import <sys/sysctl.h>
#import <sys/stat.h>
#import <sys/wait.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <spawn.h>
#import <fcntl.h>
#import <dlfcn.h>
#import <pwd.h>
#import <mach-o/loader.h>
#import <TargetConditionals.h>
extern char **environ;
extern int posix_spawnattr_set_persona_np(posix_spawnattr_t *, uid_t, uint32_t);
extern int posix_spawnattr_set_persona_uid_np(posix_spawnattr_t *, uid_t);
extern int posix_spawnattr_set_persona_gid_np(posix_spawnattr_t *, gid_t);
extern int proc_pidpath(int, void *, uint32_t);
NSString *LSHash(NSData *data) {
    unsigned char h[32]; CC_SHA256(data.bytes, (CC_LONG)data.length, h);
    NSMutableString *s=[NSMutableString string];for(int i=0;i<32;i++)[s appendFormat:@"%02x",h[i]];return s;
}
void LSLog(NSString *subsystem, NSString *prefix, NSString *phase, NSDictionary *value) {
    NSData *d=[NSJSONSerialization dataWithJSONObject:value options:0 error:nil];
    if(d.length>600) {
        NSString *encoded=[d base64EncodedStringWithOptions:0],*identifier=NSUUID.UUID.UUIDString;
        NSUInteger total=(encoded.length+599)/600;
        for(NSUInteger i=0;i<total;i++) {
            NSString *part=[encoded substringWithRange:NSMakeRange(i*600,MIN((NSUInteger)600,encoded.length-i*600))];
            os_log_with_type(os_log_create(subsystem.UTF8String,"Test"),OS_LOG_TYPE_DEFAULT,
                "[%{public}s_CHUNK] %{public}s %{public}s %lu/%lu %{public}s",prefix.UTF8String,identifier.UTF8String,phase.UTF8String,(unsigned long)i,(unsigned long)total,part.UTF8String);
        }
        return;
    }
    os_log_with_type(os_log_create(subsystem.UTF8String,"Test"),OS_LOG_TYPE_DEFAULT,
        "[%{public}s] %{public}s %{public}s",prefix.UTF8String,phase.UTF8String,[[[NSString alloc]initWithData:d encoding:NSUTF8StringEncoding] UTF8String]);
}
NSDictionary *LSBoot(void) {
    NSMutableDictionary *v=[@{@"pid":@(getpid()),@"uid":@(getuid()),@"euid":@(geteuid())} mutableCopy];
    char u[128]={0};size_t size=sizeof(u);if(!sysctlbyname("kern.bootsessionuuid",u,&size,NULL,0))v[@"boot_uuid"]=@(u);
    int mib[]={CTL_KERN,KERN_PROC,KERN_PROC_ALL,0};size=0;
    if(!sysctl(mib,4,NULL,&size,NULL,0)) {
        size+=32*sizeof(struct kinfo_proc);struct kinfo_proc *ps=calloc(1,size);
        if(ps && !sysctl(mib,4,ps,&size,NULL,0))for(size_t i=0;i<size/sizeof(*ps);i++)if(!strcmp(ps[i].kp_proc.p_comm,"SpringBoard")) {
            struct timeval t=ps[i].kp_proc.p_starttime;v[@"springboard"]=@{@"pid":@(ps[i].kp_proc.p_pid),@"sec":@((long long)t.tv_sec),@"usec":@(t.tv_usec)};break;
        }free(ps);
    }return v;
}
NSString *LSTail(NSString *path) {
    NSData *d=[NSData dataWithContentsOfFile:path];if(d.length>5000)d=[d subdataWithRange:NSMakeRange(d.length-5000,5000)];
    return d?([[NSString alloc]initWithData:d encoding:NSUTF8StringEncoding]?:@"binary output"):@"";
}
NSDictionary *LSSpawnWithTimeout(NSString *path,NSArray<NSString *> *args,BOOL root,BOOL background,NSString *logPath,double duration) {
    NSMutableArray *all=[NSMutableArray arrayWithObject:path];[all addObjectsFromArray:args];
    char **av=calloc(all.count+1,sizeof(char *));for(NSUInteger i=0;i<all.count;i++)av[i]=(char *)[all[i] UTF8String];
    int fd=open(logPath.fileSystemRepresentation,O_CREAT|O_TRUNC|O_WRONLY,0600);
    if(fd<0){free(av);return @{@"spawn_error":@(errno),@"ok":@NO};}
    posix_spawn_file_actions_t actions;posix_spawn_file_actions_init(&actions);
    posix_spawn_file_actions_addopen(&actions,STDIN_FILENO,"/dev/null",O_RDONLY,0);
    posix_spawn_file_actions_adddup2(&actions,fd,STDOUT_FILENO);posix_spawn_file_actions_adddup2(&actions,fd,STDERR_FILENO);
    if(fd>2)posix_spawn_file_actions_addclose(&actions,fd);
    posix_spawnattr_t attr;posix_spawnattr_init(&attr);
    if(root){
#if TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR
    posix_spawnattr_set_persona_np(&attr,99,1);posix_spawnattr_set_persona_uid_np(&attr,0);posix_spawnattr_set_persona_gid_np(&attr,0);
#else
    posix_spawn_file_actions_destroy(&actions);posix_spawnattr_destroy(&attr);close(fd);free(av);return @{@"ok":@NO,@"error":@"Root persona unavailable"};
#endif
    }
    if(background){posix_spawnattr_setflags(&attr,POSIX_SPAWN_SETPGROUP);posix_spawnattr_setpgroup(&attr,0);}
    pid_t pid=0;int err=posix_spawn(&pid,path.fileSystemRepresentation,&actions,&attr,av,environ);
    posix_spawn_file_actions_destroy(&actions);posix_spawnattr_destroy(&attr);close(fd);free(av);
    if(err)return @{@"ok":@NO,@"spawn_error":@(err),@"error":@(strerror(err))};
    if(background)return @{@"ok":@YES,@"pid":@(pid)};
    int status=0;pid_t waited;BOOL timeout=NO;double deadline=NSProcessInfo.processInfo.systemUptime+duration;
    while((waited=waitpid(pid,&status,WNOHANG))==0 || (waited<0 && errno==EINTR)) {
        if(NSProcessInfo.processInfo.systemUptime>deadline){timeout=YES;kill(pid,SIGKILL);while(waitpid(pid,&status,0)<0 && errno==EINTR){}break;}usleep(20000);
    }
    BOOL ok=!timeout && waited==pid && WIFEXITED(status) && WEXITSTATUS(status)==0;
    return @{@"ok":@(ok),@"pid":@(pid),@"timed_out":@(timeout),@"wait_status":@(status),@"output":LSTail(logPath)};
}
BOOL LSListening(int port) {
    int fd=socket(AF_INET,SOCK_STREAM,0);struct sockaddr_in a={0};a.sin_family=AF_INET;a.sin_port=htons(port);a.sin_addr.s_addr=htonl(INADDR_LOOPBACK);
    BOOL ok=connect(fd,(struct sockaddr *)&a,sizeof(a))==0;close(fd);return ok;
}
NSDictionary *LSProcessIdentity(pid_t pid) {
    if(pid<=1)return @{};
    int mib[]={CTL_KERN,KERN_PROC,KERN_PROC_PID,pid};struct kinfo_proc p={0};size_t size=sizeof(p);
    char path[4096]={0},canonical[4096]={0};
    if(sysctl(mib,4,&p,&size,NULL,0)||size!=sizeof(p)||p.kp_proc.p_stat==SZOMB || proc_pidpath(pid,path,sizeof(path))<=0 || !realpath(path,canonical))return @{};
    NSString *boot=LSBoot()[@"boot_uuid"];if(!boot)return @{};
    return @{@"pid":@(pid),@"path":@(canonical),@"boot_uuid":boot,@"start_sec":@((long long)p.kp_proc.p_starttime.tv_sec),@"start_usec":@(p.kp_proc.p_starttime.tv_usec)};
}
BOOL LSIdentityMatches(NSDictionary *record,NSDictionary *current) {
    if(![record[@"owned"] isEqual:@YES])return NO;
    for(NSString *k in @[@"pid",@"path",@"boot_uuid",@"start_sec",@"start_usec"])
        if(!record[k]||![record[k] isEqual:current[k]])return NO;
    return [record[@"pid"] intValue]>1;
}
static BOOL LSOriginalProcessGone(NSDictionary *record) {
    pid_t pid=[record[@"pid"] intValue];if(pid<=1)return NO;
    NSDictionary *current=LSProcessIdentity(pid);
    if(current.count)return !LSIdentityMatches(record,current);
    return kill(pid,0)<0 && errno==ESRCH;
}
NSDictionary *LSStopOwnedProcess(NSDictionary *record) {
    pid_t pid=[record[@"pid"] intValue];NSDictionary *identity=LSProcessIdentity(pid);
    if(!identity.count)return @{@"stopped":@(LSOriginalProcessGone(record)),@"identity_unavailable":@YES};
    if(!LSIdentityMatches(record,identity))return @{@"stopped":@NO,@"error":@"进程身份不匹配，保留现有进程"};
    int rc=kill(pid,SIGTERM),termError=errno;
    for(int i=0;i<100;i++) { int status=0;waitpid(pid,&status,WNOHANG);if(LSOriginalProcessGone(record))return @{@"stopped":@YES,@"signal":@"TERM"};usleep(20000); }
    // Recheck identity immediately before escalating; never kill a reused PID.
    if(rc || !LSIdentityMatches(record,LSProcessIdentity(pid)))return @{@"stopped":@NO,@"errno":@(termError)};
    kill(pid,SIGKILL);
    for(int i=0;i<100;i++){int status=0;waitpid(pid,&status,WNOHANG);if(LSOriginalProcessGone(record))return @{@"stopped":@YES,@"signal":@"KILL"};usleep(20000);}
    return @{@"stopped":@NO,@"error":@"退出等待超时"};
}
NSString *LSReportPath(NSString *name) {
    return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject stringByAppendingPathComponent:[name stringByAppendingString:@".json"]];
}
BOOL LSSaveReport(NSString *name,NSDictionary *report) {
    NSData *data=[NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:nil];
    return data && [data writeToFile:LSReportPath(name) options:NSDataWritingAtomic error:nil];
}
NSDictionary *LSReadReport(NSString *name) {
    NSData *data=[NSData dataWithContentsOfFile:LSReportPath(name)];
    id value=data?[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]:nil;
    return [value isKindOfClass:NSDictionary.class]?value:@{};
}
BOOL LSValidateHostResult(NSDictionary *result,NSDictionary *pending,NSString *bootUUID) {
    return [result[@"run_id"] isKindOfClass:NSString.class] && [result[@"run_id"] isEqual:pending[@"run_id"]] &&
        bootUUID && [result[@"boot_uuid"] isEqual:bootUUID] && [pending[@"before"][@"boot_uuid"] isEqual:bootUUID] &&
        [result[@"ssh_passed"] isKindOfClass:NSNumber.class] && [result[@"frida_passed"] isKindOfClass:NSNumber.class];
}

NSDictionary *LSSpawn(NSString *path,NSArray<NSString *> *args,BOOL root,BOOL background,NSString *logPath) { return LSSpawnWithTimeout(path,args,root,background,logPath,45); }
