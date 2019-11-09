#include <Foundation/Foundation.h>
#import "oecommon.h"

OE_EXPORTED_CLASS
@interface Options : NSObject

// macros

#define PATH_PROPERTY(OPT, SET, GET) @property (nonatomic) NSString *GET##Path;
#define BOOL_PROPERTY(OPT, SET, GET) @property (nonatomic) BOOL GET
#define INT_PROPERTY(OPT, SET, GET) @property (nonatomic) NSInteger GET
#define FLOAT_PROPERTY(OPT, SET, GET) @property (nonatomic) float GET

#pragma mark - paths

PATH_PROPERTY(MEDIAPATH, Roms, roms)
PATH_PROPERTY(HASHPATH, Hash, hash)
PATH_PROPERTY(SAMPLEPATH, Samples, samples)
PATH_PROPERTY(ARTPATH, Art, art)
PATH_PROPERTY(CTRLRPATH, Controller, controller)
PATH_PROPERTY(CHEATPATH, Cheat, cheat)
PATH_PROPERTY(CROSSHAIRPATH, CrossHair, crossHair)
PATH_PROPERTY(PLUGINSPATH, Plugins, plugins)
PATH_PROPERTY(LANGUAGEPATH, Language, language)
PATH_PROPERTY(NVRAM_DIRECTORY, NVRAM, NVRAM)
PATH_PROPERTY(CFG_DIRECTORY, CFG, CFG)

/*! Sets a common base path for option paths
 *
 * @param path the common base path
 */
- (void)setBasePath:(NSString *)path;

#pragma mark - core performance options

BOOL_PROPERTY(AUTOFRAMESKIP, AutoFrameskip, autoFrameskip);
BOOL_PROPERTY(FRAMESKIP, Frameskip, frameskip);
FLOAT_PROPERTY(SPEED, Speed, speed);

#pragma mark - core render options

BOOL_PROPERTY(KEEPASPECT, KeepAspect, keepAspect);
BOOL_PROPERTY(UNEVENSTRETCH, UnevenStretch, unevenStretch);
BOOL_PROPERTY(UNEVENSTRETCHX, UnevenStretchX, unevenStretchX);
BOOL_PROPERTY(UNEVENSTRETCHY, UnevenStretchY, unevenStretchY);
BOOL_PROPERTY(AUTOSTRETCHXY, AutoStretchXY, autoStretchXY);
BOOL_PROPERTY(INTOVERSCAN, IntOverscan, intOverscan);
INT_PROPERTY(INTSCALEX, IntScaleX, intScaleX);
INT_PROPERTY(INTSCALEY, IntScaleY, intScaleY);

#pragma mark - core rotation options

BOOL_PROPERTY(ROTATE, Rotate, Rotate);
BOOL_PROPERTY(ROR, ROR, ROR);
BOOL_PROPERTY(ROL, ROL, ROL);
BOOL_PROPERTY(AUTOROR, AutoROR, AutoROR);
BOOL_PROPERTY(AUTOROL, AutoROL, AutoROL);
BOOL_PROPERTY(FLIPX, FlipX, flipX);
BOOL_PROPERTY(FLIPY, FlipY, flipY);

#undef PATH_PROPERTY
#undef BOOL_PROPERTY
#undef INT_PROPERTY
#undef FLOAT_PROPERTY

@end