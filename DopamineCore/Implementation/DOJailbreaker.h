//
//  Jailbreaker.h
//  Dopamine
//
//  Created by Lars Fröder on 10.01.24.
//

#import <Foundation/Foundation.h>
#import "DOCore.h"

#import <xpc/xpc.h>

NS_ASSUME_NONNULL_BEGIN

@interface DOJailbreaker : NSObject
{
    xpc_object_t _systemInfoXdict;
}

- (DOResult *)run;
- (void)finalize;
#if DOPAMINE_NO_REBOOT_TEST
- (NSDictionary *)finishNoRebootTest;
#endif

- (BOOL)contiguousMappingWorkaroundNeeded;
- (void)applyContiguousMappingWorkaround;

@end

NS_ASSUME_NONNULL_END
