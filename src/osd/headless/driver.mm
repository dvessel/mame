#import "driver+private.h"
#import "DriverList+Private.h"
#import <emu.h>
#import "../../frontend/mame/infoxml.h"

OE_STATIC_ASSERT(GameDriverMachineTypeArcade == MACHINE_TYPE_ARCADE);
OE_STATIC_ASSERT(GameDriverMachineUnemulatedProtection == MACHINE_UNEMULATED_PROTECTION);
OE_STATIC_ASSERT(GameDriverMachineImperfectTiming == MACHINE_IMPERFECT_TIMING);
OE_STATIC_ASSERT(GameDriverMachineIsSkeleton == MACHINE_IS_SKELETON);
OE_STATIC_ASSERT(GameDriverMachineIsSkeletonMechanical == MACHINE_IS_SKELETON_MECHANICAL);

@implementation GameDriver {
	game_driver const *_driver;
	NSString *_name;
	NSString *_shortName;
	NSString *_fullName;
	NSString *_parent;
}

- (instancetype)initWithGameDriver:(game_driver const *)driver
{
	if ((self = [super init]))
	{
		_driver = driver;
	}
	return self;
}

- (NSString *)name
{
	return _name ?: (_name = NSSTRING_NO_COPY(_driver->name));
}

- (NSString *)shortName
{
	return _shortName ?: (_shortName = NSSTRING_NO_COPY(_driver->type.shortname()));
}

- (NSString *)fullName
{
	return _fullName ?: (_fullName = NSSTRING_NO_COPY(_driver->type.fullname()));
}

- (NSString * __nullable)parent
{
	if (_driver->parent == nullptr) return nil;

	return _parent ?: (_parent = NSSTRING_NO_COPY(_driver->parent));
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@ (%@)", self.fullName, self.name];
}

- (GameDriverOptions)flags
{
	return static_cast<GameDriverOptions>(_driver->flags);
}

- (void)dealloc
{
	NSLog(@"%@: dealloc", NSStringFromClass(self.class));
}

@end

#import "drivenum.h"

static GameDriver * __strong * s_drivers_sorted;

@implementation DriverList {
	CFArrayRef _items;
}

+ (DriverList *)shared
{
	static DriverList *obj;

	static dispatch_once_t once;
	dispatch_once(&once, ^{
		s_drivers_sorted = static_cast<GameDriver * __strong *>(calloc(driver_list::total(), sizeof(GameDriver *)));
		for (size_t i = 0; i < driver_list::total(); i++)
		{
			s_drivers_sorted[i] = [[GameDriver alloc] initWithGameDriver:&driver_list::driver(i)];
		}

		obj = [DriverList new];
		obj->_items = CFArrayCreate(kCFAllocatorDefault, (const void * *)(void *)s_drivers_sorted, static_cast<CFIndex>(driver_list::total()), &kCFTypeArrayCallBacks);
	});

	return obj;
}

- (NSArray<GameDriver *> *)allDrivers
{
	return (__bridge NSArray *)_items;
}

- (GameDriver *)findWithName:(NSString *)name
{
	auto index = driver_list::find(name.UTF8String);
	if (index == -1) {
		return nil;
	}

	return s_drivers_sorted[index];
}

@end
