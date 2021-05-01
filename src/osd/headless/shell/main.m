#import <Foundation/Foundation.h>

#import <dlfcn.h>
#import <objc/runtime.h>
#import <osd.h>
#import <driver.h>

#include "stdio.h"

@interface MyDelegate: NSObject<OSDDelegate>
@end

@implementation MyDelegate
{
	OSD *_osd;
}
- (instancetype)initWithOSD:(OSD *)osd {
	self = [super init];

	_osd = osd;

	return self;
}

- (void)didInitialize
{
	printf("initializing\n");
	InputDevice *joy = [_osd.joystick addDeviceNamed:@"Joy 1"];
}

- (void)didChangeDisplayBounds:(NSSize)bounds fps:(double)fps aspect:(NSSize)aspect
{
	printf("display bounds update\n");
}

- (void)updateAudioBuffer:(int16_t const *)buffer samples:(NSInteger)samples
{

}

- (void)logLevel:(OSDLogLevel)level message:(NSString *)msg
{
	NSLog(@"%@", (msg));
}
@end

GameDriver *current = nil;

int main(int argc, char *argv[])
{
#if 1
	char const * path = "build/output/build/projects/headless/mamearcade/cmake/mamearcade/libmamearcade_headless.dylib";
#else
	char const * path = "mamedummy_headless.dylib";
#endif
	BOOL r = [NSFileManager.defaultManager isReadableFileAtPath: @"/Volumes/GameData/mame/roms/targ.7z"];
#if LOAD_LIB
	void *handle = dlopen(path, RTLD_LAZY);
	if (handle == nil)
	{
		printf("no library: %s\n", dlerror());
		return 1;
	}
#endif

	@try
	{
		Class driverClass = NSClassFromString(@"DriverList");

		DriverList *drivers = (DriverList *)[driverClass shared];
		for (GameDriver *driver in drivers.allDrivers)
		{
			printf("name: %s\n", driver.fullName.UTF8String);
		}

		@autoreleasepool
		{
			GameDriver * gd = [drivers findWithName:@"targ"];
			gd = [drivers findWithName:@"targ"];
			gd = [drivers findWithName:@"targ"];
			gd = nil;
		}

		{
			GameDriver * gd = [drivers findWithName:@"targ"];
			gd = [drivers findWithName:@"targ"];
			gd = [drivers findWithName:@"targ"];
			gd = nil;
		}

		Class osdClass = NSClassFromString(@"OSD");

		OSD *shared = (OSD *)[osdClass shared];

		shared.delegate = [[MyDelegate alloc] initWithOSD:shared];
		shared.verboseOutput = YES;
		[shared.options setBasePath:@"/Volumes/GameData/mame"];
		printf("diff directory: %s\n", shared.options.diffDirectory.UTF8String);

		[shared setBuffer:malloc(2048*2048*4) size:NSMakeSize(2048, 2048)];

		NSError *err;
		AuditResult *ar;
		BOOL res = [shared setDriver:@"targ" withAuditResult:&ar error:&err];
		if (!res)
		{

			return 0;
		}

		GameDriver *driver = shared.driver;


		printf("state size: %lu\n", shared.stateSize);
		printf("audit result:\n%s\n", ar.description.UTF8String);

		//res = [shared loadSoftware:@"dkong" error:&err];

		printf("supports save: %s\n", shared.supportsSave ? "Y" : "N");

		res = [shared initializeWithError:&err];
		if (!res)
		{

			return 0;
		}

		for (int i = 0; i < 500; i++) {
			[shared execute];
		}
		[shared unload];

	} @finally
	{
#if LOAD_LIB
		dlclose(handle);
#endif
	}

	return 0;
}
