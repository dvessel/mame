#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class GameDriver;

OE_EXPORTED_CLASS
@interface DriverList: NSObject

@property(class, readonly, nonatomic) DriverList *shared;

#pragma mark - Instance

@property (readonly, nonatomic) NSArray<GameDriver *> *allDrivers;

- (nullable GameDriver *)findWithName:(NSString *)name NS_RETURNS_RETAINED;

@end

NS_ASSUME_NONNULL_END
