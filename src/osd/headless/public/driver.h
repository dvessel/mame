#import <Foundation/Foundation.h>
#import "oecommon.h"

//OE_EXPORTED_CLASS
//@interface Drivers: NSObject
//- (void)writeXMLIncludeDTD:(BOOL)dtd patterns:(NSArray<NSString *> *)patterns;
//@end

typedef NS_OPTIONS(NSUInteger, GameDriverOptions)
{
	/*! coin-operated machine for public use */
	GameDriverMachineTypeArcade = 0x00000008,
	
	/*! console system */
	GameDriverMachineTypeConsole = 0x00000010,
	
	/*! any kind of computer including home computers, minis, calculators, etc */
	GameDriverMachineTypeComputer = 0x00000018,
	
	/*! any other emulated system (e.g. clock, satellite receiver, ...) */
	GameDriverMachineTypeOther = 0x00000038,
	
	/*! driver is not in a working state */
	GameDriverMachineNotWorking = 0x00000040,
	
	/*! system supports save states */
	GameDriverMachineSupportsSave = 0x00000080,
	
	/*! screen flip support is missing */
	GameDriverMachineNoCocktail = 0x00000100,
	
	/*! this driver entry is a BIOS root */
	GameDriverMachineIsBiosRoot = 0x00000200,
	
	/*! requires external artwork for key game elements */
	GameDriverMachineRequiresArtwork = 0x00000400,
	
	/*! artwork is clickable and requires mouse cursor */
	GameDriverMachineClickableArtwork = 0x00000800,
	
	/*! unofficial hardware modification */
	GameDriverMachineUnofficial = 0x00001000,
	
	/*! system has no sound output */
	GameDriverMachineNoSoundHw = 0x00002000,
	
	/*! contains mechanical parts (pinball, redemption games, ...) */
	GameDriverMachineMechanical = 0x00004000,
	
	/*! official system with blatantly incomplete hardware/software */
	GameDriverMachineIsIncomplete = 0x00008000,
	
	// flags that map to device feature flags
	
	/*! game's protection not fully emulated */
	GameDriverMachineUnemulatedProtection     = 0x0000000100000000,
	
	/*! colors are totally wrong */
	GameDriverMachineWrongColors              = 0x0000000200000000,
	
	/*! colors are not 100% accurate, but close */
	GameDriverMachineImperfectColors          = 0x0000000400000000,
	
	/*! graphics are wrong/incomplete */
	GameDriverMachineImperfectGraphics        = 0x0000000800000000,
	
	/*! sound is missing */
	GameDriverMachineNoSound                  = 0x0000001000000000,
	
	/*! sound is known to be wrong */
	GameDriverMachineImperfectSound           = 0x0000002000000000,
	
	/*! controls are known to be imperfectly emulated */
	GameDriverMachineImperfectControls        = 0x0000004000000000,
	
	/*! any game/system that has unemulated audio capture device */
	GameDriverMachineNoDeviceMicrophone       = 0x0000008000000000,
	
	/*! any game/system that has unemulated hardcopy output device */
	GameDriverMachineNoDevicePrinter          = 0x0000010000000000,
	
	/*! any game/system that has unemulated local networking */
	GameDriverMachineNoDeviceLan              = 0x0000020000000000,
	
	/*! timing is known to be imperfectly emulated */
	GameDriverMachineImperfectTiming          = 0x0000040000000000,
	
	// useful combination flags
	
	/*! flag combination for skeleton drivers */
	GameDriverMachineIsSkeleton               = GameDriverMachineNoSound | GameDriverMachineNotWorking,
	
	/*! flag combination for skeleton mechanical machines */
	GameDriverMachineIsSkeletonMechanical    = GameDriverMachineIsSkeleton | GameDriverMachineMechanical | GameDriverMachineRequiresArtwork
};


OE_EXPORTED_CLASS
@interface GameDriver: NSObject

@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *shortName;
@property (nonatomic, readonly) NSString *fullName;
@property (nonatomic, readonly) GameDriverOptions flags;

@end