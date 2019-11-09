#import <Foundation/Foundation.h>

// standard includes
#include <unistd.h>
#include <algorithm>

// MAME headers
#include "emu.h"
#include "../../frontend/mame/audit.h"
#include "osdepend.h"
#include "emuopts.h"
#include "../../frontend/mame/ui/menuitem.h"
#include "validity.h"
#include "render.h"
#include "ui/uimain.h"
#include <inputdev.h>
#include <os/log.h>

// OSD headers
#include "../modules/osdhelper.h"
#include "public/headless.h"
#include "options+private.h"
#include "modules/lib/osdlib.h"
#include "modules/lib/osdobj_common.h"
#import "../../../frontend/mame/mame.h"

// Renderer headers
#include "rendersw.hxx"

#define NSSTRING_NO_COPY(x) [[NSString alloc] initWithBytesNoCopy:(void *)(x) length:strlen(x) encoding:NSUTF8StringEncoding freeWhenDone:NO];

// static assertions

#define OE_STATIC_ASSERT(_condition, ...) static_assert(_condition, "" __VA_ARGS__)

#define OE_ENUM_CHECK(_enum, _src, _c99enumcount) \
    OE_STATIC_ASSERT(_enum::_src == _enum(_c99enumcount) )

// sanity checks

OE_ENUM_CHECK(media_auditor::summary, NOTFOUND, AuditSummaryNotFound);

OE_ENUM_CHECK(media_auditor::audit_status, GOOD, AuditStatusGood);
OE_ENUM_CHECK(media_auditor::audit_status, UNVERIFIED, AuditStatusUnverified);

OE_ENUM_CHECK(media_auditor::audit_substatus, GOOD, AuditSubstatusGood);
OE_ENUM_CHECK(media_auditor::audit_substatus, UNVERIFIED, AuditSubstatusUnverified);

static os_log_t OE_LOG;

NSString *const MAMEErrorDomain = @"org.openemu.mame.ErrorDomain";

void osd_setup_osd_specific_emu_options(emu_options &opts)
{
	[OSD class];
}

#pragma mark - osd_options

const options_entry osd_options::s_option_entries[] =
		{
				{nullptr, nullptr,                OPTION_HEADER, "OSD VIDEO OPTIONS"},
				{OSDOPTION_VIDEO, OSDOPTVAL_AUTO, OPTION_STRING, "video output method: "},
				{nullptr}
		};

osd_options::osd_options()
		: emu_options()
{
	add_entries(osd_options::s_option_entries);
}

#pragma mark - definition

class headless_osd_interface : public osd_interface, osd_output
{
public:
	enum osd_state
	{
		uninitialized,
		initialized,
		error,
	};
	
	explicit headless_osd_interface(osd_options &options);
	~headless_osd_interface() final;
	
	// current state
	osd_state state() const
	{ return m_state; };
	
	// general overridables
	void init(running_machine &machine) override;
	void exit();
	void update(bool skip_redraw) override;
	
	// debugger overridables
	void init_debugger() override
	{};
	
	void wait_for_debugger(device_t &device, bool firststop) override
	{};
	
	// audio overridables
	void update_audio_stream(const int16_t *buffer, int samples_this_frame) override;
	
	void set_mastervolume(int attenuation) override
	{};
	
	bool no_sound() override
	{ return false; };
	
	// input overridables
	void customize_input_type_list(simple_list<input_type_entry> &typelist) override;
	
	// video overridables
	void add_audio_to_recording(const int16_t *buffer, int samples_this_frame) override
	{};
	
	std::vector<ui::menu_item> get_slider_list() override
	{ return m_sliders; };
	
	void *buffer() const
	{ return m_buffer; }
	
	osd_dim buffer_size() const
	{ return m_buffer_size; }
	
	void set_buffer(void *buffer, osd_dim size);
	
	// font interface
	osd_font::ptr font_alloc() override;
	bool
	get_font_families(std::string const &font_path, std::vector<std::pair<std::string, std::string> > &result) override;
	
	// command option overrides
	bool execute_command(const char *command) override
	{ return false; }
	
	// midi interface
	osd_midi_device *create_midi_device() override
	{ return nullptr; };
	
	// osd_output interface ...
	void output_callback(osd_output_channel channel, util::format_argument_pack<std::ostream> const &args) override;
	
	bool verbose() const
	{ return m_print_verbose; }
	
	void set_verbose(bool print_verbose) override
	{ m_print_verbose = print_verbose; }
	
	// other
	void set_delegate(id <OSDDelegate> delegate)
	{ m_delegate = delegate; }

protected:
	
	// internal state
	running_machine *m_machine;
	osd_options &m_options;
	
	osd_state m_state;
	
	// ui
	std::vector<ui::menu_item> m_sliders;
	bool m_print_verbose;
	
	// video
	double m_fps;
	render_target *m_target;
	void *m_buffer;
	osd_dim m_buffer_size;
	osd_dim m_target_size;
	
	// delegate
	id <OSDDelegate> m_delegate;
};

#pragma mark - Other categories

@interface AuditResult ()
@property (nonatomic, readonly) game_driver const *gameDriver;
+ (instancetype)auditResultWithOptions:(Options *)options driverName:(NSString *)driverName;
@end

@interface InputClass ()
- (instancetype)initWithClass:(input_class *)clas;
@end

#pragma mark - OSD Objective C Interface

#pragma clang diagnostic ignored "-Wenum-compare"

static_assert(InputItemID::InputItemID_ABSOLUTE_MAXIMUM == input_item_id::ITEM_ID_ABSOLUTE_MAXIMUM,
              "enum is different");

@implementation OSD
{
	Options *_options;
	headless_osd_interface *_osd;
	mame_machine_manager *_manager;
	machine_config *_config;
	running_machine *_machine;
	game_driver const *_gameDriver;
	BOOL _supportsSave;
	NSString *_basePath;
	
	InputClass *_joystick;
	InputClass *_mouse;
	InputClass *_keyboard;
	
	
	bool _isEmpty;
}

+ (void)initialize
{
	OE_LOG = os_log_create("org.mamedev.mame", "");
}

- (instancetype)init
{
	self = [super init];
	if (self == nil)
	{
		return nil;
	}
	
	_options = [Options new];
	
	osd_options *opt = _options.options;
	
	_osd = global_alloc(headless_osd_interface(*opt));
	
	_manager = mame_machine_manager::instance(*_options.options, *_osd);
	_manager->start_http_server();
	_manager->start_luaengine();
	
	// arbitrary size
	_maxBufferSize = NSMakeSize(2048, 2048);
	
	return self;
}

- (void)dealloc
{
	[self _freeMachine];
	global_free(_manager);
	global_free(_osd);
}

- (InputClass *)joystick
{
	if (_joystick == nil)
	{
		_joystick = [[InputClass alloc] initWithClass:&_machine->input().device_class(DEVICE_CLASS_JOYSTICK)];
	}
	return _joystick;
}

- (InputClass *)mouse
{
	if (_mouse == nil)
	{
		_mouse = [[InputClass alloc] initWithClass:&_machine->input().device_class(DEVICE_CLASS_MOUSE)];
	}
	return _mouse;
}

- (InputClass *)keyboard
{
	if (_keyboard == nil)
	{
		_keyboard = [[InputClass alloc] initWithClass:&_machine->input().device_class(DEVICE_CLASS_KEYBOARD)];
	}
	return _keyboard;
}

- (void)setDelegate:(id <OSDDelegate>)delegate
{
	_delegate = delegate;
	_osd->set_delegate(delegate);
}

- (void)setVerboseOutput:(BOOL)val
{
	_osd->set_verbose(val);
}

- (BOOL)verboseOutput
{
	return (BOOL) _osd->verbose();
}

- (void)setBuffer:(void *)buffer size:(NSSize)size
{
	auto dim = osd_dim(static_cast<int>(size.width), static_cast<int>(size.height));
	_osd->set_buffer(buffer, dim);
}

- (NSString *)driverFullName
{
	if (_gameDriver == nil)
	{
		return @"";
	}
	
	return NSSTRING_NO_COPY(_gameDriver->type.fullname());
}

- (NSString *)driverShortName
{
	if (_gameDriver == nil)
	{
		return @"";
	}
	
	return NSSTRING_NO_COPY(_gameDriver->type.shortname());
}

- (BOOL)loadGame:(NSString *)name withAuditResult:(AuditResult **)result error:(NSError **)error
{
	BOOL res = [self loadDriver:name withAuditResult:result error:error];
	if (!res)
	{
		return NO;
	}
	
	return [self _initializeGame:error];
}

- (BOOL)loadDriver:(NSString *)driver withAuditResult:(AuditResult **)result error:(NSError **)error
{
	_driverName = driver;
	
	AuditResult *ar = [AuditResult auditResultWithOptions:_options driverName:driver];
	if (ar == nil)
	{
		// nil indicates the driver was not found
		if (error)
		{
			NSDictionary<NSErrorUserInfoKey, id> *info = @{
					NSLocalizedDescriptionKey: NSLocalizedString(@"Invalid driver", "Driver not supported"),
			};
			*error = [NSError errorWithDomain:MAMEErrorDomain code:MAMEErrorInvalidDriver userInfo:info];
		}
		return NO;
	}
	
	if (result)
	{
		*result = ar;
	}
	
	if (ar.summary == AuditSummaryIncorrect || ar.summary == AuditSummaryNotFound)
	{
		if (error != nil)
		{
			NSDictionary<NSErrorUserInfoKey, id> *info = @{
					NSLocalizedDescriptionKey: NSLocalizedString(@"Audit failed", "audit failed"),
					NSLocalizedFailureReasonErrorKey: ar.description,
			};
			*error = [NSError errorWithDomain:MAMEErrorDomain code:MAMEErrorAuditFailed userInfo:info];
		}
		osd_printf_error("audit failed: %s", ar.description.UTF8String);
		
		return NO;
	}
	
	_gameDriver = ar.gameDriver;
	
	if (_gameDriver->flags & (MACHINE_CLICKABLE_ARTWORK | MACHINE_REQUIRES_ARTWORK))
	{
		NSDictionary<NSErrorUserInfoKey, id> *info = @{
				NSLocalizedDescriptionKey: NSLocalizedString(
						@"Systems which require artwork to operate are not supported", "System not supported"),
		};
		*error = [NSError errorWithDomain:MAMEErrorDomain code:MAMEErrorUnsupportedROM userInfo:info];
		return NO;
	}
	
	if (_gameDriver->flags & MACHINE_MECHANICAL)
	{
		NSDictionary<NSErrorUserInfoKey, id> *info = @{
				NSLocalizedDescriptionKey: NSLocalizedString(@"Mechanical systems are not supported",
				                                             "System not supported"),
		};
		*error = [NSError errorWithDomain:MAMEErrorDomain code:MAMEErrorUnsupportedROM userInfo:info];
		return NO;
	}
	
	try
	{
		_options.options->set_system_name(driver.UTF8String);
	}
	catch (options_error_exception &ex)
	{
		// NOTE(sgc): this should never happen, given we've validated the system
		return NO;
	}
	
	return YES;
}

- (BOOL)loadSoftware:(NSString *)name error:(NSError **)error
{
	_softwareName = name;
	try
	{
		_options.options->set_software(_softwareName.UTF8String);
		
	}
	catch (options_error_exception &ex)
	{
		// NOTE(sgc): this should never happen, given we've validated the system
		return NO;
	}
	
	return [self _initializeGame:error];
}


- (void)unload
{
	_osd->set_buffer(nullptr, osd_dim());
	[self _freeMachine];
}

#pragma mark - save / load

- (BOOL)loadStateFromFileAtPath:(NSString *)fileName error:(NSError **)error
{
	if (_supportsSave)
	{
		std::string name(fileName.UTF8String);
		_machine->immediate_load(name.c_str());
		return YES;
	}
	return NO;
}

- (BOOL)saveStateFromFileAtPath:(NSString *)fileName error:(NSError **)error
{
	if (_supportsSave)
	{
		std::string name(fileName.UTF8String);
		_machine->immediate_save(name.c_str());
		return YES;
	}
	return NO;
}


#pragma mark - serialization

- (NSUInteger)stateSize
{
	if (!_supportsSave)
	{
		return 0;
	}
	
	return static_cast<NSUInteger >(_machine->save().state_size());
}

- (NSData *)serializeState
{
	if (!_supportsSave)
	{
		return nil;
	}
	
	auto sz = static_cast<size_t>(_machine->save().state_size());
	void *buf = malloc(sz);
	auto res = _machine->save().write_data(buf, sz);
	if (res != STATERR_NONE)
	{
		free(buf);
		return nil;
	}
	
	return [[NSData alloc] initWithBytesNoCopy:buf length:sz freeWhenDone:YES];
}

- (BOOL)deserializeState:(NSData *)data
{
	if (!_supportsSave)
	{
		return NO;
	}
	
	auto res = _machine->save().read_data(const_cast<void *>(data.bytes), data.length);
	return res == STATERR_NONE;
}


- (void)_freeMachine
{
	_gameDriver = nil;
	_joystick = nil;
	_mouse = nil;
	_keyboard = nil;
	_supportsSave = NO;
	
	_manager->set_machine(nullptr);
	
	if (_machine)
	{
		_machine->headless_deinit();
		global_free(_machine);
		_machine = nil;
	}
	
	if (_config)
	{
		global_free(_config);
		_config = nil;
	}
}

- (BOOL)_initializeGame:(NSError **)error
{
	[self _freeMachine];
	
	_manager->clear_new_driver_pending();
	
	// if no driver, use the internal empty driver
	_gameDriver = _options.options->system();
	if (_gameDriver == nullptr)
	{
		_gameDriver = &GAME_NAME(___empty);
	}
	
	// otherwise, perform validity checks before anything else
	_isEmpty = (_gameDriver == &GAME_NAME(___empty));
	if (!_isEmpty)
	{
		validity_checker valid(*_options.options);
		valid.set_verbose(false);
		valid.check_shared_source(*_gameDriver);
	}
	
	_config = global_alloc(machine_config(*_gameDriver, *_options.options));
	_machine = global_alloc(running_machine(*_config, *_manager));
	_manager->set_machine(_machine);
	
	// TODO(sgc): this could error due to invalid BIOS; need to extract this properly
	int ok = _machine->headless_init(_isEmpty);
	if (ok != EMU_ERR_NONE || _osd->state() == headless_osd_interface::osd_state::error)
	{
		[self _freeMachine];
		
		if (error != nil)
		{
			NSDictionary<NSErrorUserInfoKey, id> *info = @{
					NSLocalizedDescriptionKey: NSLocalizedString(@"Failed to initialize; unsupported ROM",
					                                             @"init failed")
			};
			*error = [NSError errorWithDomain:MAMEErrorDomain code:MAMEErrorUnsupportedROM userInfo:info];
		}
		
		return NO;
	}
	
	_supportsSave = (_machine->system().flags & MACHINE_SUPPORTS_SAVE) != 0;
	
	return _machine->phase() == machine_phase::RUNNING;
}

#pragma mark - Execution

- (BOOL)execute
{
	if (_manager->new_driver_pending())
	{
		_manager->commit_new_driver();
		if (![self _initializeGame:nil])
		{
			return NO;
		};
	}
	
	_machine->headless_run();
	
	return YES;
}

- (void)scheduleSoftReset
{
	_machine->schedule_soft_reset();
}

- (void)scheduleHardReset
{
	[self unload];
	[self _initializeGame:nil];
}

+ (OSD *)shared
{
	static OSD *shared;
	
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		shared = [[OSD alloc] init];
	});
	
	return shared;
}

@end

@implementation InputDeviceItem
@end

@implementation InputDevice
{
	input_device *_device;
}

- (instancetype)initWithDevice:(input_device *)device
{
	if (!(self = [super init]))
	{
		return nil;
	}
	
	_device = device;
	
	return self;
}

- (NSUInteger)index
{
	return static_cast<NSUInteger>(_device->devindex());
}

- (NSString *)name
{
	return NSSTRING_NO_COPY(_device->name());
}

- (NSString *)id
{
	return NSSTRING_NO_COPY(_device->id());
}

- (InputItemID)addItemNamed:(NSString *)name id:(InputItemID)iid getter:(ItemGetStateFunc)getter context:(void *)context
{
	return static_cast<InputItemID>(_device->add_item(name.UTF8String, static_cast<input_item_id>(iid),
	                                                  reinterpret_cast<item_get_state_func>(getter), context));
}

@end

@implementation InputClass
{
	input_class *_class;
	NSMutableArray<InputDevice *> *_devices;
}

- (instancetype)initWithClass:(input_class *)clas
{
	if (!(self = [super init]))
	{
		return nil;
	}
	
	_class = clas;
	_devices = [[NSMutableArray alloc] initWithCapacity:DEVICE_INDEX_MAXIMUM];
	for (NSUInteger i = 0; i < DEVICE_INDEX_MAXIMUM; i++)
	{
		auto device = _class->device(static_cast<int>(i));
		if (device != nullptr)
		{
			_devices[i] = [[InputDevice alloc] initWithDevice:device];
		}
	}
	
	return self;
}

- (InputDevice *)addDeviceNamed:(NSString *)name
{
	auto device = _class->add_device(name.UTF8String, name.UTF8String);
	auto dev = [[InputDevice alloc] initWithDevice:device];
	_devices[static_cast<NSUInteger>(device->devindex())] = dev;
	return dev;
}

- (InputDevice *)deviceForIndex:(NSUInteger)index
{
	return _devices[index];
}

@end

#pragma mark - headless_osd_interface implementation

#pragma mark - construction / destruction

headless_osd_interface::headless_osd_interface(osd_options &options)
		: m_machine(nullptr), m_options(options), m_state(uninitialized), m_print_verbose(false),
		  m_fps(60.0), m_target(nullptr), m_buffer(nullptr)
{
	osd_output::push(this);
}

headless_osd_interface::~headless_osd_interface()
{
	osd_output::pop(this);
}

#pragma mark - general overridables

void headless_osd_interface::init(running_machine &machine)
{
	screen_device_iterator iter(machine.root_device());
	
	auto first_screen = iter.first();
	if (!first_screen)
	{
		m_state = osd_state::error;
		return;
	}
	
	if (true)
	{
		auto i = 0;
		for (auto &screen: iter)
		{
			auto aspect = screen.physical_aspect();
			bool rotated = (screen.orientation() & ORIENTATION_SWAP_XY) == ORIENTATION_SWAP_XY;
			
			os_log_debug(OE_LOG, "screen %d, dimensions %d x %d, visible area: %d x %d, physical aspect: %d:%d, "
			                     "rotated: [%{public}s]",
			             i,
			             screen.width(), screen.height(),
			             screen.visible_area().width(), screen.visible_area().height(),
			             aspect.first, aspect.second,
			             rotated ? "Y" : "N");
			i++;
		}
	}
	
	m_state = osd_state::initialized;
	m_machine = &machine;
	m_target = m_machine->render().target_alloc();
	
	os_log_debug(OE_LOG, "target allocated: %d x %d", m_target->width(), m_target->height());
	
	m_fps = ATTOSECONDS_TO_HZ(first_screen->refresh_attoseconds());
	auto aspect = first_screen->physical_aspect();
	bool rotated = (first_screen->orientation() & ORIENTATION_SWAP_XY) == ORIENTATION_SWAP_XY;
	if (rotated)
	{
		std::swap(aspect.first, aspect.second);
	}
	
	// get more info about target
	{
		render_layer_config temp = m_target->layer_config();
		layout_view *view = m_target->current_view();
		float view_aspect = view->effective_aspect(temp);
		if (rotated) view_aspect = 1.0f / view_aspect;
		os_log_debug(OE_LOG, "view aspect = %03f", view_aspect);
	}
	
	s32 width, height;
	m_target->compute_minimum_size(width, height);
	
	os_log_debug(OE_LOG, "target compute_minimum_size: %d x %d", width, height);
	
	m_target_size = osd_dim(width, height);
	m_target->set_bounds(width, height, 0.0);
	
	{
		s32 propwidth = width, propheight = width;
		m_target->compute_visible_area(propwidth, propheight, 1.0, m_target->orientation(), propwidth, propheight);
		os_log_debug(OE_LOG, "target compute_visible_area: %d x %d", propwidth, propheight);
	}
	
	// ensure we get called on the way out
	machine.add_notifier(MACHINE_NOTIFY_EXIT, machine_notify_delegate(&headless_osd_interface::exit, this));
	
	[m_delegate willInitializeWithBounds:NSMakeSize(width, height) fps:static_cast<float>(m_fps) aspect:NSMakeSize(
			aspect.first, aspect.second)];
}

void headless_osd_interface::exit()
{
	m_state = osd_state::uninitialized;
	m_machine->render().target_free(m_target);
}

void headless_osd_interface::update(bool skip_redraw)
{
	if (!skip_redraw && m_buffer != nullptr)
	{
		auto &prim = m_target->get_primitives();
		u32 width = static_cast<u32>(m_buffer_size.width());
		u32 height = static_cast<u32>(m_buffer_size.height());
		
		prim.acquire_lock();
		software_renderer<uint32_t, 0, 0, 0, 16, 8, 0>::draw_primitives(prim, m_buffer, width, height, width);
		prim.release_lock();
	}
}

#pragma mark - audio overridables

void headless_osd_interface::update_audio_stream(const int16_t *buffer, int samples_this_frame)
{
	[m_delegate updateAudioBuffer:buffer samples:samples_this_frame];
}

#pragma mark - input overridables

void headless_osd_interface::customize_input_type_list(simple_list<input_type_entry> &typelist)
{
	// This function is called on startup, before reading the
	// configuration from disk. Scan the list, and change the
	// default control mappings you want. It is quite possible
	// you won't need to change a thing.
	
	// loop over the defaults
	for (input_type_entry &entry : typelist)
	{
		switch (entry.type())
		{
			// Select + X => UI_CONFIGURE (Menu)
//			case IPT_UI_CONFIGURE:
//				entry.defseq(SEQ_TYPE_STANDARD).set(KEYCODE_TAB, input_seq::or_code, JOYCODE_SELECT, JOYCODE_BUTTON3);
//				break;
//
//				// Select + Start => CANCEL
//			case IPT_UI_CANCEL:
//				entry.defseq(SEQ_TYPE_STANDARD).set(KEYCODE_ESC, input_seq::or_code, JOYCODE_SELECT, JOYCODE_START);
//				break;
			
			// leave everything else alone
			default:
				break;
		}
	}
}

#pragma mark - video overridables

void headless_osd_interface::set_buffer(void *buffer, osd_dim size)
{
	m_buffer = buffer;
	m_buffer_size = size;
}

#pragma mark - font interface

osd_font::ptr headless_osd_interface::font_alloc()
{
	return nullptr;
}

bool headless_osd_interface::get_font_families(std::string const &font_path,
                                               std::vector<std::pair<std::string, std::string> > &result)
{
	return false;
}

#pragma mark - output

void headless_osd_interface::output_callback(osd_output_channel channel,
                                             util::format_argument_pack<std::ostream> const &args)
{
	static OSDLogLevel levels[OSD_OUTPUT_CHANNEL_COUNT] = {
			[OSD_OUTPUT_CHANNEL_ERROR] = OSDLogLevelError,
			[OSD_OUTPUT_CHANNEL_WARNING] = OSDLogLevelWarning,
			[OSD_OUTPUT_CHANNEL_INFO] = OSDLogLevelInfo,
			[OSD_OUTPUT_CHANNEL_DEBUG] = OSDLogLevelDebug,
			[OSD_OUTPUT_CHANNEL_VERBOSE] = OSDLogLevelVerbose,
			[OSD_OUTPUT_CHANNEL_LOG] = OSDLogLevelLog,
	};
	
	if (channel == OSD_OUTPUT_CHANNEL_VERBOSE && !m_print_verbose)
	{
		return;
	}
	
	auto str = string_format(args);
	NSString *msg = [[NSString alloc] initWithBytesNoCopy:const_cast<char *>(str.c_str())
	                                               length:str.length()
	                                             encoding:NSUTF8StringEncoding
	                                         freeWhenDone:NO];
	
	[m_delegate logLevel:levels[channel] message:msg];
}

#pragma mark - Auditing

@implementation Device
{
	device_t *_device;
}

- (instancetype)initWithDevice:(device_t *)device
{
	if ((self = [super init]))
	{
		_device = device;
	}
	return self;
}

- (NSString *)name
{
	return NSSTRING_NO_COPY(_device->name());
}

- (NSString *)shortName
{
	return NSSTRING_NO_COPY(_device->shortname());
}

@end

@implementation AuditRecord
{
	Device *device;
}

- (instancetype)initFromRecord:(media_auditor::audit_record const *)record
{
	if ((self = [super init]))
	{
		_name = @(record->name());
		_expectedLength = record->expected_length();
		_status = (AuditStatus) record->status();
		_substatus = (AuditSubstatus) record->substatus();
		_expectedHashes = @(record->expected_hashes().macro_string().c_str());
		_actualHashes = @(record->actual_hashes().macro_string().c_str());
		_actualLength = record->actual_length();
		device_t *pDevice = record->shared_device();
		if (pDevice)
		{
			_sharedDevice = [[Device alloc] initWithDevice:pDevice];
		}
	}
	
	return self;
}

- (NSString *)description
{
	return _name;
}

@end

@implementation AuditResult
{
	NSString *_description;
}

+ (instancetype)auditResultWithOptions:(Options *)options driverName:(NSString *)driverName
{
	driver_enumerator enumerator(*options.options, driverName.UTF8String);
	
	if (enumerator.count() == 0)
	{
		return nil;
	}
	
	enumerator.next();
	
	AuditResult *ar = [AuditResult new];
	ar->_gameDriver = &enumerator.driver();
	
	media_auditor auditor(enumerator);
	ar->_summary = (AuditSummary) auditor.audit_media(AUDIT_VALIDATE_FAST);
	
	NSMutableArray<AuditRecord *> *records = [NSMutableArray arrayWithCapacity:auditor.records().size()];
	
	for (media_auditor::audit_record const &record : auditor.records())
	{
		[records addObject:[[AuditRecord alloc] initFromRecord:&record]];
	}
	ar->_records = records;
	std::ostringstream output;
	auditor.summarize(enumerator.driver().name, &output);
	ar->_description = @(output.str().c_str());
	
	return ar;
}

- (NSString *)description
{
	return _description;
}

@end

@implementation Options
{
	osd_options *_options;
}

- (instancetype)init
{
	if ((self = [super init]))
	{
		_options = global_alloc(osd_options);
		_options->set_value(OPTION_PLUGINS, 0, OPTION_PRIORITY_HIGH); // disable LUA plugins
		_options->set_value(OPTION_READCONFIG, 0, OPTION_PRIORITY_HIGH); // disable reading .ini files
		_options->set_value(OPTION_SAMPLERATE, 48000, OPTION_PRIORITY_HIGH);
		_options->set_value(OSDOPTION_VIDEO, OSDOPTVAL_NONE, OPTION_PRIORITY_MAXIMUM);
		// disable throttling as OpenEmu handles frame pacing
		_options->set_value(OPTION_THROTTLE, 0, OPTION_PRIORITY_HIGH);
		_options->set_value(OPTION_CHEAT, 1, OPTION_PRIORITY_HIGH);
		_options->set_value(OPTION_SKIP_GAMEINFO, 1, OPTION_PRIORITY_HIGH);
		_options->set_value(OPTION_SKIP_WARNINGS, 1, OPTION_PRIORITY_HIGH);
		_options->set_value(OPTION_HEADLESS, 1, OPTION_PRIORITY_HIGH);
		_options->set_value(OPTION_READCFG, 0, OPTION_PRIORITY_HIGH);
		_options->set_value(OPTION_WRITECFG, 0, OPTION_PRIORITY_HIGH);
		_options->set_value(OPTION_BIOS, "default", OPTION_PRIORITY_HIGH);
	}
	return self;
}

- (void)dealloc
{
	global_free(_options);
}

- (osd_options *)options
{
	return _options;
}

#pragma mark - core search path options

#define PATH_PROPERTY(OPT, SET, GET) \
- (void)set##SET##Path:(NSString *)path \
{ \
    _options->set_value(OPTION_ ## OPT, path.UTF8String, OPTION_PRIORITY_HIGH); \
} \
\
- (NSString *)GET##Path \
{ \
    return @(_options->value(OPTION_ ## OPT)); \
}


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

#undef PATH_PROPERTY

- (void)setBasePath:(NSString *)path
{
	_options->set_value(OPTION_MEDIAPATH, [NSString pathWithComponents:@[path, @"roms"]].UTF8String,
	                    OPTION_PRIORITY_HIGH);
	_options->set_value(OPTION_HASHPATH, [NSString pathWithComponents:@[path, @"hash"]].UTF8String,
	                    OPTION_PRIORITY_HIGH);
	_options->set_value(OPTION_SAMPLEPATH, [NSString pathWithComponents:@[path, @"samples"]].UTF8String,
	                    OPTION_PRIORITY_HIGH);
	_options->set_value(OPTION_ARTPATH, [NSString pathWithComponents:@[path, @"artwork"]].UTF8String,
	                    OPTION_PRIORITY_HIGH);
	_options->set_value(OPTION_CTRLRPATH, [NSString pathWithComponents:@[path, @"ctrlr"]].UTF8String,
	                    OPTION_PRIORITY_HIGH);
	_options->set_value(OPTION_CHEATPATH, [NSString pathWithComponents:@[path, @"cheat"]].UTF8String,
	                    OPTION_PRIORITY_HIGH);
	_options->set_value(OPTION_CROSSHAIRPATH, [NSString pathWithComponents:@[path, @"crosshair"]].UTF8String,
	                    OPTION_PRIORITY_HIGH);
	_options->set_value(OPTION_PLUGINSPATH, [NSString pathWithComponents:@[path, @"plugins"]].UTF8String,
	                    OPTION_PRIORITY_HIGH);
	_options->set_value(OPTION_LANGUAGEPATH, [NSString pathWithComponents:@[path, @"language"]].UTF8String,
	                    OPTION_PRIORITY_HIGH);
	_options->set_value(OPTION_NVRAM_DIRECTORY, [NSString pathWithComponents:@[path, @"nvram"]].UTF8String,
	                    OPTION_PRIORITY_HIGH);
	_options->set_value(OPTION_CFG_DIRECTORY, [NSString pathWithComponents:@[path, @"cfg"]].UTF8String,
	                    OPTION_PRIORITY_HIGH);
}

#define INT_PROPERTY(OPT, SET, GET) \
- (void)set##SET:(NSInteger)value \
{ \
    _options->set_value(OPTION_ ## OPT, static_cast<int>(value), OPTION_PRIORITY_HIGH); \
} \
\
- (NSInteger)GET \
{ \
    return static_cast<NSInteger>(_options->int_value(OPTION_ ## OPT)); \
}

#define BOOL_PROPERTY(OPT, SET, GET) \
- (void)set##SET:(BOOL)value \
{ \
    _options->set_value(OPTION_ ## OPT, static_cast<int>(value), OPTION_PRIORITY_HIGH); \
} \
\
- (BOOL)GET \
{ \
    return static_cast<BOOL>(_options->int_value(OPTION_ ## OPT) != 0); \
}

#define FLOAT_PROPERTY(OPT, SET, GET) \
- (void)set##SET:(float)value \
{ \
    _options->set_value(OPTION_ ## OPT, value, OPTION_PRIORITY_HIGH); \
} \
\
- (float)GET \
{ \
    return _options->int_value(OPTION_ ## OPT); \
}

#define STRING_PROPERTY(OPT, SET, GET) \
- (void)set##SET:(NSString *)value \
{ \
    _options->set_value(OPTION_ ## OPT, value.UTF8String, OPTION_PRIORITY_HIGH); \
} \
\
- (float)GET \
{ \
    return @(_options->value(OPTION_ ## OPT)); \
}

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

@end