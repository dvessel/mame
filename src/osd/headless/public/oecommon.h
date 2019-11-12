#pragma once

#ifndef OE_EXPORTED_CLASS
#define OE_EXPORTED_CLASS     __attribute__((visibility("default")))
#endif

#ifndef OE_STATIC_ASSERT
#define OE_STATIC_ASSERT(_condition, ...) static_assert(_condition, "" __VA_ARGS__)
#endif

#ifndef OE_ENUM_CHECK
#define OE_ENUM_CHECK(_enum, _src, _c99enumcount) \
    OE_STATIC_ASSERT(_enum::_src == _enum(_c99enumcount) )
#endif
