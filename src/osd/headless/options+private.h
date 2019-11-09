#pragma once

#include "public/options.h"

class osd_options;

@interface Options(Private)

@property (nonatomic, readonly) osd_options *options;

@end