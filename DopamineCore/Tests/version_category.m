#import <Foundation/Foundation.h>
#import "NSString+Version.h"

// Link through an archive, as an independent host does. Merely seeing the selector
// at compile time must not make this test pass when the category is not loaded.
int main(void) {
    @autoreleasepool {
        if (![NSString instancesRespondToSelector:@selector(numericalVersionRepresentation)]) return 1;
        NSString *installed = [NSString stringWithFormat:@"%@", @"1.0.9"];
        NSString *bundled = @"1.0.10";
        if ([installed numericalVersionRepresentation] >= [bundled numericalVersionRepresentation]) return 2;
        if ([@"1.0.10" numericalVersionRepresentation] != [bundled numericalVersionRepresentation]) return 3;
        if ([@"2" numericalVersionRepresentation] <= [bundled numericalVersionRepresentation]) return 4;
        puts("{\"passed\":true,\"version_category_loaded_from_archive\":true}");
    }
    return 0;
}
