#import <Foundation/Foundation.h>
#import "inputenum.h"
#import "oecommon.h"

@class Options;

// callback for getting the value of an item on a device
typedef uint32_t (*ItemGetStateFunc)(void *device_internal, void *item_internal);

extern NSString *const MAMEErrorDomain;

typedef NS_ERROR_ENUM(MAMEErrorDomain, MAMEError)
{
	MAMEErrorUnsupportedROM = -1,
	MAMEErrorAuditFailed = -2,
	MAMEErrorInvalidDriver = -3,
	MAMEErrorMissingFiles = -4,
	MAMEErrorFatal = -5,
};

@class OSD, AuditResult, AuditRecord, Device;

typedef NS_ENUM(NSUInteger, OSDLogLevel)
{
	OSDLogLevelError,
	OSDLogLevelWarning,
	OSDLogLevelInfo,
	OSDLogLevelDebug,
	OSDLogLevelVerbose,
	OSDLogLevelLog,
	OSDLogLevelCount
};


@protocol OSDDelegate <NSObject>
- (void)didInitialize;
- (void)didChangeDisplayBounds:(NSSize)bounds fps:(double)fps aspect:(NSSize)aspect;
- (void)updateAudioBuffer:(int16_t const *)buffer samples:(NSInteger)samples;
- (void)logLevel:(OSDLogLevel)level message:(NSString *)msg;
@end

OE_EXPORTED_CLASS
@interface InputDeviceItem : NSObject
@end

OE_EXPORTED_CLASS
@interface InputDevice : NSObject

@property (nonatomic, readonly) NSUInteger index;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *id;

- (InputItemID)addItemNamed:(NSString *)name id:(InputItemID)iid getter:(ItemGetStateFunc)getter context:(void *)context;
@end

OE_EXPORTED_CLASS
@interface InputClass : NSObject
- (InputDevice *)addDeviceNamed:(NSString *)name;
- (InputDevice *)deviceForIndex:(NSUInteger)index;
@end

OE_EXPORTED_CLASS
@interface OSD : NSObject

+ (OSD *)shared;

@property (nonatomic) id <OSDDelegate> delegate;
@property (nonatomic) BOOL verboseOutput;

@property (nonatomic, readonly) Options *options;

#pragma mark - current game

@property (nonatomic, readonly) InputClass *joystick;
@property (nonatomic, readonly) InputClass *mouse;
@property (nonatomic, readonly) InputClass *keyboard;
@property (nonatomic, readonly) BOOL supportsSave;

/*! name of current driver after calling loadGame:
 * */
@property (nonatomic, readonly) NSString *driverName;
@property (nonatomic, readonly) NSString *driverFullName;
@property (nonatomic, readonly) NSString *driverShortName;
@property (nonatomic, readonly) NSString *softwareName;

/*! maximum size of render buffer in pixels
 */
@property (nonatomic) NSSize maxBufferSize;

- (BOOL)loadGame:(NSString *)name withAuditResult:(AuditResult **)result error:(NSError **)error;
- (BOOL)loadDriver:(NSString *)driver withAuditResult:(AuditResult **)result error:(NSError **)error;
- (BOOL)loadSoftware:(NSString *)name error:(NSError **)error;
- (void)unload;

#pragma mark - save / load

- (BOOL)loadStateFromFileAtPath:(NSString *)fileName error:(NSError **)error;
- (BOOL)saveStateFromFileAtPath:(NSString *)fileName error:(NSError **)error;

#pragma mark - serialization

/*!
 * Returns the number of bytes required to store a save state
 */
- (NSUInteger)stateSize;
- (NSData *)serializeState;
- (BOOL)deserializeState:(NSData *)data;

#pragma mark - execution

- (BOOL)execute;
- (void)scheduleSoftReset;
- (void)scheduleHardReset;
- (void)setBuffer:(void *)buffer size:(NSSize)size;

@end

#pragma mark - Audit

OE_EXPORTED_CLASS
@interface Device : NSObject

@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *shortName;

@end

typedef NS_ENUM(NSInteger, AuditSummary)
{
	AuditSummaryCorrect = 0,
	AuditSummaryNoneNeeded,
	AuditSummaryBestAvailable,
	AuditSummaryIncorrect,
	AuditSummaryNotFound,
};

typedef NS_ENUM(NSInteger, AuditStatus)
{
	AuditStatusGood = 0,
	AuditStatusFoundInvalid,
	AuditStatusNotFound,
	AuditStatusUnverified = 100,
};

typedef NS_ENUM(NSInteger, AuditSubstatus)
{
	AuditSubstatusGood = 0,
	AuditSubstatusGoodNeedsRedump,
	AuditSubstatusFoundNodump,
	AuditSubstatusFoundBadChecksum,
	AuditSubstatusFoundWrongLength,
	AuditSubstatusNotFound,
	AuditSubstatusNotFoundNoDump,
	AuditSubstatusNotFoundOptional,
	AuditSubstatusUnverified = 100,
};

OE_EXPORTED_CLASS
@interface AuditRecord : NSObject

@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSUInteger expectedLength;
@property (nonatomic, readonly) AuditStatus status;
@property (nonatomic, readonly) AuditSubstatus substatus;
@property (nonatomic, readonly) NSString *expectedHashes;
@property (nonatomic, readonly) NSString *actualHashes;
@property (nonatomic, readonly) NSUInteger actualLength;
@property (nonatomic, readonly) Device *sharedDevice;

@end

OE_EXPORTED_CLASS
@interface AuditResult : NSObject

@property (nonatomic, readonly) AuditSummary summary;
@property (nonatomic, readonly) NSArray<AuditRecord *> *records;

@end