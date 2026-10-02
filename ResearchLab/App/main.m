#import <UIKit/UIKit.h>
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
#import "JBInfo.h"
extern char **environ;
extern int posix_spawnattr_set_persona_np(posix_spawnattr_t *, uid_t, uint32_t);
extern int posix_spawnattr_set_persona_uid_np(posix_spawnattr_t *, uid_t);
extern int posix_spawnattr_set_persona_gid_np(posix_spawnattr_t *, gid_t);
extern int proc_pidpath(int, void *, uint32_t);
__attribute__((used, visibility("default"))) const char RLResearchMarker[] = "ResearchLab-owned-target";
__attribute__((used, visibility("default"))) volatile uint32_t RLResearchValue = 20261002;
__attribute__((noinline, used, visibility("default"))) int RLResearchCalculate(int x) { return x * 2; }
static NSString *const State = @"/var/jb/var/root/ResearchLab";
static NSString *const Bin = @"/var/jb/usr/local/lib/ResearchLab";
static void *JBLibrary;
static int (*Trust)(const char *);
static NSString *Hash(NSData *data) {
    unsigned char h[32]; CC_SHA256(data.bytes, (CC_LONG)data.length, h);
    NSMutableString *s=[NSMutableString string];for(int i=0;i<32;i++)[s appendFormat:@"%02x",h[i]];return s;
}
static void Log(NSString *phase, NSDictionary *value) {
    NSData *d=[NSJSONSerialization dataWithJSONObject:value options:0 error:nil];
    if(d.length>600) {
        NSString *encoded=[d base64EncodedStringWithOptions:0],*identifier=NSUUID.UUID.UUIDString;
        NSUInteger total=(encoded.length+599)/600;
        for(NSUInteger i=0;i<total;i++) {
            NSString *part=[encoded substringWithRange:NSMakeRange(i*600,MIN((NSUInteger)600,encoded.length-i*600))];
            os_log_with_type(os_log_create("com.mmd.ResearchLab","Test"),OS_LOG_TYPE_DEFAULT,
                "[RESEARCHLAB_CHUNK] %{public}s %{public}s %lu/%lu %{public}s",identifier.UTF8String,phase.UTF8String,(unsigned long)i,(unsigned long)total,part.UTF8String);
        }
        return;
    }
    os_log_with_type(os_log_create("com.mmd.ResearchLab","Test"),OS_LOG_TYPE_DEFAULT,
        "[RESEARCHLAB] %{public}s %{public}s",phase.UTF8String,[[[NSString alloc]initWithData:d encoding:NSUTF8StringEncoding] UTF8String]);
}
static NSDictionary *Boot(void) {
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
static NSString *Tail(NSString *path) {
    NSData *d=[NSData dataWithContentsOfFile:path];if(d.length>5000)d=[d subdataWithRange:NSMakeRange(d.length-5000,5000)];
    return d?([[NSString alloc]initWithData:d encoding:NSUTF8StringEncoding]?:@"binary output"):@"";
}
static NSDictionary *Spawn(NSString *path,NSArray<NSString *> *args,BOOL root,BOOL background,NSString *logPath) {
    NSMutableArray *all=[NSMutableArray arrayWithObject:path];[all addObjectsFromArray:args];
    char **av=calloc(all.count+1,sizeof(char *));for(NSUInteger i=0;i<all.count;i++)av[i]=(char *)[all[i] UTF8String];
    int fd=open(logPath.fileSystemRepresentation,O_CREAT|O_TRUNC|O_WRONLY,0600);
    if(fd<0){free(av);return @{@"spawn_error":@(errno),@"ok":@NO};}
    posix_spawn_file_actions_t actions;posix_spawn_file_actions_init(&actions);
    posix_spawn_file_actions_addopen(&actions,STDIN_FILENO,"/dev/null",O_RDONLY,0);
    posix_spawn_file_actions_adddup2(&actions,fd,STDOUT_FILENO);posix_spawn_file_actions_adddup2(&actions,fd,STDERR_FILENO);
    if(fd>2)posix_spawn_file_actions_addclose(&actions,fd);
    posix_spawnattr_t attr;posix_spawnattr_init(&attr);
    if(root){posix_spawnattr_set_persona_np(&attr,99,1);posix_spawnattr_set_persona_uid_np(&attr,0);posix_spawnattr_set_persona_gid_np(&attr,0);}
    if(background){posix_spawnattr_setflags(&attr,POSIX_SPAWN_SETPGROUP);posix_spawnattr_setpgroup(&attr,0);}
    pid_t pid=0;int err=posix_spawn(&pid,path.fileSystemRepresentation,&actions,&attr,av,environ);
    posix_spawn_file_actions_destroy(&actions);posix_spawnattr_destroy(&attr);close(fd);free(av);
    if(err)return @{@"ok":@NO,@"spawn_error":@(err),@"error":@(strerror(err))};
    if(background)return @{@"ok":@YES,@"pid":@(pid)};
    int status=0;pid_t waited;BOOL timeout=NO;double deadline=NSProcessInfo.processInfo.systemUptime+45;
    while((waited=waitpid(pid,&status,WNOHANG))==0 || (waited<0 && errno==EINTR)) {
        if(NSProcessInfo.processInfo.systemUptime>deadline){timeout=YES;kill(pid,SIGKILL);while(waitpid(pid,&status,0)<0 && errno==EINTR){}break;}usleep(20000);
    }
    BOOL ok=!timeout && waited==pid && WIFEXITED(status) && WEXITSTATUS(status)==0;
    return @{@"ok":@(ok),@"pid":@(pid),@"timed_out":@(timeout),@"wait_status":@(status),@"output":Tail(logPath)};
}
static BOOL Listening(int port) {
    int fd=socket(AF_INET,SOCK_STREAM,0);struct sockaddr_in a={0};a.sin_family=AF_INET;a.sin_port=htons(port);a.sin_addr.s_addr=htonl(INADDR_LOOPBACK);
    BOOL ok=connect(fd,(struct sockaddr *)&a,sizeof(a))==0;close(fd);return ok;
}
static NSDictionary *Kernel(void) {
    int (*initialize)(void)=dlsym(JBLibrary,"jbclient_initialize_primitives");
    int (*readKernel)(uint64_t,void *,size_t)=dlsym(JBLibrary,"kreadbuf");
    struct system_info *info=dlsym(JBLibrary,"gSystemInfo");
    if(!initialize||!readKernel||!info)return @{@"passed":@NO,@"error":@"libjailbreak 接口缺失"};
    int init=initialize();uint32_t magic=0;int read=-1;
    if(init==0 && info->kernelConstant.base)read=readKernel(info->kernelConstant.base,&magic,sizeof(magic));
    return @{@"passed":@(init==0 && read==0 && magic==MH_MAGIC_64),@"initialize_result":@(init),@"read_result":@(read),
        @"kernel_base":[NSString stringWithFormat:@"0x%llx",info->kernelConstant.base],@"magic":[NSString stringWithFormat:@"0x%08x",magic],
        @"bytes_read":@4,@"kernel_write_tested":@NO};
}
static NSDictionary *Stop(void) {
    NSMutableArray *steps=[NSMutableArray array];
    NSDictionary *records=[NSDictionary dictionaryWithContentsOfFile:[State stringByAppendingPathComponent:@"services.plist"]];
    for(NSString *name in records) {
        NSDictionary *r=records[name];pid_t pid=[r[@"pid"] intValue];char path[4096]={0},expected[4096]={0},actual[4096]={0};
        BOOL exists=pid>1 && proc_pidpath(pid,path,sizeof(path))>0;
        BOOL same=exists && realpath([r[@"path"] fileSystemRepresentation],expected) && realpath(path,actual) && !strcmp(actual,expected);
        BOOL stopped=!exists || (same && kill(pid,SIGTERM)==0);
        [steps addObject:@{@"service":name,@"pid":@(pid),@"same_executable":@(same),@"stopped":@(stopped)}];
    }
    return @{@"services":steps,@"ssh_listening":@(Listening(22222)),@"frida_listening":@(Listening(27042))};
}
static NSDictionary *Prepare(void) {
    NSFileManager *fm=NSFileManager.defaultManager;NSError *error=nil;
    NSMutableDictionary *report=[@{@"before":Boot(),@"root_identity":@{@"uid":@(getuid()),@"euid":@(geteuid()),@"passed":@(getuid()==0 && geteuid()==0)},@"client_tests":@"pending",@"kernel_write_tested":@NO} mutableCopy];
    if(geteuid()!=0){report[@"error"]=@"辅助进程未获得 root";return report;}
    [fm createDirectoryAtPath:State withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:&error];
    chmod(State.fileSystemRepresentation,0700);
    JBLibrary=dlopen("/var/jb/basebin/libjailbreak.dylib",RTLD_NOW|RTLD_LOCAL);Trust=JBLibrary?dlsym(JBLibrary,"jbclient_trust_file_by_path"):NULL;
    if(!Trust){report[@"error"]=@"已有越狱服务客户端不可用";return report;}
    report[@"kernel_read"]=Kernel();Log(@"kernel",report[@"kernel_read"]);
    NSString *nonce=NSUUID.UUID.UUIDString;NSString *marker=[State stringByAppendingPathComponent:[@"root-" stringByAppendingString:nonce]];
    BOOL wrote=[nonce writeToFile:marker atomically:YES encoding:NSUTF8StringEncoding error:&error];chmod(marker.fileSystemRepresentation,0600);
    struct stat st={0};BOOL owned=stat(marker.fileSystemRepresentation,&st)==0 && st.st_uid==0 && (st.st_mode&0777)==0600;
    BOOL roundtrip=[[NSString stringWithContentsOfFile:marker encoding:NSUTF8StringEncoding error:&error] isEqual:nonce];
    BOOL removed=wrote && [fm removeItemAtPath:marker error:&error];
    report[@"root_file"]=@{@"passed":@(wrote && owned && roundtrip && removed),@"owned_by_root":@(owned),@"cleaned_up":@(removed)};
    NSData *manifestData=[NSData dataWithContentsOfFile:[NSBundle.mainBundle pathForResource:@"payload" ofType:@"json"]];
    NSDictionary *manifest=manifestData?[NSJSONSerialization JSONObjectWithData:manifestData options:0 error:&error]:nil;
    if(!manifest){report[@"error"]=@"测试资源清单无法读取";return report;}
    NSMutableArray *assets=[NSMutableArray array];BOOL valid=YES;
    for(NSDictionary *item in manifest[@"files"]) {
        NSString *path=item[@"path"];
        BOOL allowed=[path hasPrefix:[Bin stringByAppendingString:@"/"]] || [@[@"/var/jb/usr/sbin/frida-server",@"/var/jb/usr/lib/frida/frida-agent.dylib",@"/var/jb/etc/pam.d/sshd"] containsObject:path];
        if(!allowed || [path containsString:@".."]){valid=NO;break;}
        NSData *data=[[NSData alloc]initWithBase64EncodedString:item[@"data"] options:0];
        if(!data || ![Hash(data) isEqual:item[@"sha256"]]){valid=NO;break;}
        struct stat fs;BOOL link=lstat(path.fileSystemRepresentation,&fs)==0 && S_ISLNK(fs.st_mode);
        NSData *old=[NSData dataWithContentsOfFile:path];
        BOOL reusable=[@[@"/var/jb/usr/sbin/frida-server",@"/var/jb/usr/lib/frida/frida-agent.dylib",@"/var/jb/etc/pam.d/sshd"] containsObject:path];
        if(old && reusable) {
            int trusted=[item[@"executable"] boolValue]?Trust(path.fileSystemRepresentation):0;
            [assets addObject:@{@"path":path,@"ok":@(trusted==0),@"trust_result":@(trusted),@"reused_existing":@YES,@"symlink":@(link),@"sha256":Hash(old)}];
            valid &= trusted==0;continue;
        }
        if(link || (old && ![Hash(old) isEqual:item[@"sha256"]])){[assets addObject:@{@"path":path,@"ok":@NO,@"error":@"保留已存在的不同版本或符号链接"}];valid=NO;break;}
        [fm createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0755} error:&error];
        BOOL saved=[data writeToFile:path options:NSDataWritingAtomic error:&error];
        BOOL executable=[item[@"executable"] boolValue];chmod(path.fileSystemRepresentation,executable?0755:0644);
        int trusted=saved?(executable?Trust(path.fileSystemRepresentation):0):-1;
        [assets addObject:@{@"path":path,@"ok":@(saved && trusted==0),@"trust_result":@(trusted)}];valid &= saved && trusted==0;
    }
    report[@"assets"]=assets;
    NSMutableArray *deps=[NSMutableArray array];
    for(NSString *path in manifest[@"existing_dependencies"]) {
        if(![path hasPrefix:@"/var/jb/"] || [path containsString:@".."]) {valid=NO;break;}
        int trusted=Trust(path.fileSystemRepresentation);[deps addObject:@{@"path":path,@"trust_result":@(trusted)}];valid &= trusted==0;
    }
    report[@"dependencies"]=deps;
    if(!valid){report[@"error"]=@"资源部署或依赖签名检查未通过";report[@"after"]=Boot();return report;}
    report[@"root_command"]=Spawn(@"/var/jb/usr/bin/id",@[@"-u"],NO,NO,[State stringByAppendingPathComponent:@"id.log"]);
    report[@"frida_server_version"]=Spawn(@"/var/jb/usr/sbin/frida-server",@[@"--version"],NO,NO,[State stringByAppendingPathComponent:@"frida-version.log"]);
    NSString *authorized=[State stringByAppendingPathComponent:@"authorized_keys"];
    NSString *publicKey=[NSString stringWithContentsOfFile:[NSBundle.mainBundle pathForResource:@"client" ofType:@"pub"] encoding:NSUTF8StringEncoding error:&error];
    if(!publicKey || ![publicKey writeToFile:authorized atomically:YES encoding:NSUTF8StringEncoding error:&error]){report[@"error"]=@"SSH 公钥准备失败";return report;}chmod(authorized.fileSystemRepresentation,0600);
    NSString *hostKey=[State stringByAppendingPathComponent:@"ssh_host_ed25519_key"];
    if(![fm fileExistsAtPath:hostKey])report[@"ssh_keygen"]=Spawn([Bin stringByAppendingPathComponent:@"ssh-keygen"],@[@"-t",@"ed25519",@"-N",@"",@"-f",hostKey],NO,NO,[State stringByAppendingPathComponent:@"keygen.log"]);
    if(![fm fileExistsAtPath:hostKey]){report[@"error"]=@"SSH 主机密钥生成失败";return report;}
    report[@"ssh_host_public_key"]=[NSString stringWithContentsOfFile:[hostKey stringByAppendingString:@".pub"] encoding:NSUTF8StringEncoding error:nil]?:@"";
    NSString *config=[NSString stringWithFormat:@"Port 22222\nListenAddress 127.0.0.1\nHostKey %@\nPidFile %@/sshd.pid\nAuthorizedKeysFile %@\nPermitRootLogin prohibit-password\nPubkeyAuthentication yes\nPasswordAuthentication no\nKbdInteractiveAuthentication no\nUsePAM yes\nUsePrivilegeSeparation no\nAllowUsers root\nAllowTcpForwarding no\nX11Forwarding no\nPermitTunnel no\nStrictModes yes\nLogLevel VERBOSE\nSubsystem sftp internal-sftp\n",hostKey,State,authorized];
    NSString *configPath=[State stringByAppendingPathComponent:@"sshd_config"];
    [config writeToFile:configPath atomically:YES encoding:NSUTF8StringEncoding error:&error];chmod(configPath.fileSystemRepresentation,0600);
    NSString *sshd=[Bin stringByAppendingPathComponent:@"sshd"];
    report[@"sshd_config_check"]=Spawn(sshd,@[@"-t",@"-f",configPath],NO,NO,[State stringByAppendingPathComponent:@"sshd-check.log"]);
    NSMutableDictionary *services=[[NSDictionary dictionaryWithContentsOfFile:[State stringByAppendingPathComponent:@"services.plist"]] mutableCopy]?:[NSMutableDictionary dictionary];
    NSArray *specs=@[@{@"name":@"openssh",@"path":sshd,@"args":@[@"-D",@"-e",@"-f",configPath],@"port":@22222},
        @{@"name":@"frida",@"path":@"/var/jb/usr/sbin/frida-server",@"args":@[@"-l",@"127.0.0.1:27042"],@"port":@27042}];
    for(NSDictionary *s in specs) {
        NSString *name=s[@"name"],*log=[State stringByAppendingPathComponent:[name stringByAppendingString:@".log"]];int port=[s[@"port"] intValue];
        if(Listening(port)){report[name]=@{@"started":@NO,@"already_listening":@YES,@"client_test":@"pending"};continue;}
        if([name isEqual:@"openssh"] && ![report[@"sshd_config_check"][@"ok"] boolValue])continue;
        NSDictionary *spawn=Spawn(s[@"path"],s[@"args"],NO,YES,log);pid_t pid=[spawn[@"pid"] intValue];
        if(pid>1){services[name]=@{@"pid":@(pid),@"path":s[@"path"]};[services writeToFile:[State stringByAppendingPathComponent:@"services.plist"] atomically:YES];}
        BOOL listening=NO;for(int i=0;i<30;i++){if((listening=Listening(port)))break;usleep(100000);}
        int status=0;pid_t waited=pid>1?waitpid(pid,&status,WNOHANG):-1;
        report[name]=@{@"spawn":spawn,@"listening":@(listening),@"exited":@(waited==pid && pid>1),@"wait_status":@(status),@"log":Tail(log),@"client_test":@"pending"};
    }
    [services writeToFile:[State stringByAppendingPathComponent:@"services.plist"] atomically:YES];
    report[@"after"]=Boot();return report;
}
static NSDictionary *RunHelper(BOOL stop) {
    NSString *docs=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject;
    NSString *output=[docs stringByAppendingPathComponent:[NSString stringWithFormat:@"helper-%@.json",NSUUID.UUID.UUIDString]];
    NSDictionary *spawn=Spawn(NSBundle.mainBundle.executablePath,@[stop?@"--stop":@"--prepare"],YES,NO,output);
    NSData *data=[NSData dataWithContentsOfFile:output];NSDictionary *r=data?[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]:nil;
    return r?:@{@"error":@"辅助进程未返回完整结果",@"helper":spawn};
}
@interface RLViewController:UIViewController
@property UILabel *result;
@property UIButton *run;
@property UIButton *stop;
@end
@implementation RLViewController
- (void)viewDidLoad {
    [super viewDidLoad];self.view.backgroundColor=UIColor.systemGroupedBackgroundColor;
    UIStackView *stack=[UIStackView new];stack.axis=UILayoutConstraintAxisVertical;stack.spacing=22;stack.translatesAutoresizingMaskIntoConstraints=NO;
    [self.view addSubview:stack];[NSLayoutConstraint activateConstraints:@[[stack.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:30],[stack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24],[stack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24]]];
    UILabel *title=[UILabel new];title.text=@"权限实验室";title.font=[UIFont boldSystemFontOfSize:32];[stack addArrangedSubview:title];
    UILabel *desc=[UILabel new];desc.numberOfLines=0;desc.text=@"root · 内核读取 · Frida · OpenSSH\n本轮不重启系统和桌面";[stack addArrangedSubview:desc];
    self.result=[UILabel new];self.result.numberOfLines=0;self.result.text=@"准备就绪，等待运行。";[stack addArrangedSubview:self.result];
    self.run=[UIButton buttonWithType:UIButtonTypeSystem];self.run.configuration=[UIButtonConfiguration filledButtonConfiguration];[self.run setTitle:@"准备并运行基础测试" forState:0];[self.run addTarget:self action:@selector(runTests) forControlEvents:UIControlEventTouchUpInside];[stack addArrangedSubview:self.run];
    self.stop=[UIButton buttonWithType:UIButtonTypeSystem];[self.stop setTitle:@"停止本次测试服务" forState:0];[self.stop addTarget:self action:@selector(stopServices) forControlEvents:UIControlEventTouchUpInside];[stack addArrangedSubview:self.stop];
    UILabel *note=[UILabel new];note.numberOfLines=0;note.font=[UIFont systemFontOfSize:14];note.textColor=UIColor.secondaryLabelColor;note.text=@"服务仅监听手机本机地址，通过 USB 连接。SSH 使用专用密钥。服务准备后，电脑还会验证 SSH 登录和 Frida 附加；服务启动不等于功能测试通过。内核测试只读取 4 字节，不测试内核写入。";[stack addArrangedSubview:note];
    Log(@"launch",@{@"build":NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"],@"boot":Boot()});
    NSString *mode=NSProcessInfo.processInfo.environment[@"RESEARCHLAB_MODE"];
    if([mode isEqual:@"run"])dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{[self runTests];});
    if([mode isEqual:@"stop"])dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{[self stopServices];});
}
- (void)perform:(BOOL)stop {
    self.run.enabled=NO;self.stop.enabled=NO;self.result.text=stop?@"正在停止测试服务…":@"正在检查权限并准备测试服务…";
    NSDictionary *before=Boot();Log(@"before",before);
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
        NSDictionary *report=RunHelper(stop);NSDictionary *after=Boot();
        BOOL same=before[@"boot_uuid"] && [before[@"boot_uuid"] isEqual:after[@"boot_uuid"]] && before[@"springboard"] && [before[@"springboard"] isEqual:after[@"springboard"]];
        Log(stop?@"stop":@"prepare",report);Log(@"after",after);Log(@"continuity",@{@"same_kernel_and_springboard":@(same)});
        dispatch_async(dispatch_get_main_queue(),^{
            if(stop)self.result.text=@"已请求停止本次服务，请查看电脑核验结果。";
            else self.result.text=[NSString stringWithFormat:@"root 身份：%@\n内核读取：%@\nSSH 服务：%@\nFrida 服务：%@\n%@\n\nSSH 登录及 Frida 功能：等待电脑验证%@",
                [report[@"root_identity"][@"passed"] boolValue]?@"通过":@"未通过",[report[@"kernel_read"][@"passed"] boolValue]?@"通过":@"未通过",
                [report[@"openssh"][@"listening"] boolValue]?@"已监听":@"待检查",[report[@"frida"][@"listening"] boolValue]?@"已监听":@"待检查",
                same?@"系统和桌面均未重启":@"重启状态需核对",report[@"error"]?[@"\n" stringByAppendingString:report[@"error"]]:@""];
            self.run.enabled=YES;self.stop.enabled=YES;
        });
    });
}
- (void)runTests {[self perform:NO];}
- (void)stopServices {[self perform:YES];}
@end
@interface RLAppDelegate:UIResponder<UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end
@implementation RLAppDelegate
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.window=[[UIWindow alloc]initWithFrame:UIScreen.mainScreen.bounds];self.window.rootViewController=[RLViewController new];[self.window makeKeyAndVisible];return YES;
}
@end
int main(int argc,char **argv) {
    @autoreleasepool {
        if(argc==2 && (!strcmp(argv[1],"--prepare") || !strcmp(argv[1],"--stop"))) {
            // Keep low-level library stdout separate from the JSON protocol.
            int protocol=dup(STDOUT_FILENO);
            [NSFileManager.defaultManager createDirectoryAtPath:State withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:nil];
            int internal=open([State stringByAppendingPathComponent:@"helper-internal.log"].fileSystemRepresentation,O_CREAT|O_TRUNC|O_WRONLY,0600);
            if(internal>=0){dup2(internal,STDOUT_FILENO);dup2(internal,STDERR_FILENO);close(internal);}
            NSDictionary *r=!strcmp(argv[1],"--stop")?Stop():Prepare();
            NSData *d=[NSJSONSerialization dataWithJSONObject:r options:0 error:nil];write(protocol,d.bytes,d.length);close(protocol);return 0;
        }
        return UIApplicationMain(argc,argv,nil,NSStringFromClass(RLAppDelegate.class));
    }
}
