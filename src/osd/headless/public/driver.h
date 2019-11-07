#import <Foundation/Foundation.h>

@interface Drivers: NSObject
- (void)writeXMLIncludeDTD:(BOOL)dtd patterns:(NSArray<NSString *> *)patterns;
@end

@interface GameDriver: NSObject
@end