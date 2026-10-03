#import <Foundation/Foundation.h>
NSString *LSHash(NSData *data);
void LSLog(NSString *subsystem, NSString *prefix, NSString *phase, NSDictionary *value);
NSDictionary *LSBoot(void);
NSString *LSTail(NSString *path);
NSDictionary *LSSpawn(NSString *path, NSArray<NSString *> *args, BOOL root, BOOL background, NSString *logPath);
NSDictionary *LSSpawnWithTimeout(NSString *path, NSArray<NSString *> *args, BOOL root, BOOL background, NSString *logPath, double timeout);
BOOL LSListening(int port);
// Includes boot UUID, process start time and canonical path; absent fields fail closed.
NSDictionary *LSProcessIdentity(pid_t pid);
BOOL LSIdentityMatches(NSDictionary *record, NSDictionary *current);
NSDictionary *LSStopOwnedProcess(NSDictionary *record);
NSString *LSReportPath(NSString *name);
BOOL LSSaveReport(NSString *name, NSDictionary *report);
NSDictionary *LSReadReport(NSString *name);
BOOL LSValidateHostResult(NSDictionary *result, NSDictionary *pending, NSString *bootUUID);
