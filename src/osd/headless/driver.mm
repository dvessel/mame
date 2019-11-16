#import "driver+private.h"
#import <emu.h>
#import "../../frontend/mame/info.h"

OE_STATIC_ASSERT(GameDriverMachineTypeArcade == MACHINE_TYPE_ARCADE);
OE_STATIC_ASSERT(GameDriverMachineUnemulatedProtection == MACHINE_UNEMULATED_PROTECTION);
OE_STATIC_ASSERT(GameDriverMachineImperfectTiming == MACHINE_IMPERFECT_TIMING);
OE_STATIC_ASSERT(GameDriverMachineIsSkeleton == MACHINE_IS_SKELETON);
OE_STATIC_ASSERT(GameDriverMachineIsSkeletonMechanical == MACHINE_IS_SKELETON_MECHANICAL);

//@implementation Drivers
//
//- (void)writeXMLIncludeDTD:(BOOL)dtd patterns:(NSArray<NSString *> *)patterns
//{
//	std::vector<std::string> args;
//	args.reserve(patterns.count);
//	for (NSString *p in patterns)
//	{
//		args.emplace_back(p.UTF8String);
//	}
//
//	emu_options options;
//	info_xml_creator creator(options, dtd);
//	creator.output(std::cout, args);
//	std::cout.flush();
//}
//
//@end

@implementation GameDriver {
	game_driver const *_driver;
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
	return NSSTRING_NO_COPY(_driver->name);
}

- (NSString *)shortName
{
	return NSSTRING_NO_COPY(_driver->type.shortname());
}

- (NSString *)fullName
{
	return NSSTRING_NO_COPY(_driver->type.fullname());
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@ (%@)", self.fullName, self.name];
}

- (GameDriverOptions)flags
{
	return static_cast<GameDriverOptions>(_driver->flags);
}

@end