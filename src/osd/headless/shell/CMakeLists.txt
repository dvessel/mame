cmake_minimum_required(VERSION 3.14.1)

project(osdtest)

set(
        source_list
        main.m
)

include_directories(../public)

add_executable(osdtest ${source_list})

option(USE_DYLIB "Use dynamic library" ON)

if (USE_DYLIB)
    set(EXTRA_LIBS mametiny_headless)
    message("Linking dynamic library: [YES]")
    target_compile_definitions(osdtest PRIVATE LOAD_LIB=0)
else()
    message("Linking dynamic library: [NO]")
    target_compile_definitions(osdtest PRIVATE LOAD_LIB=1)
endif()

target_link_options(osdtest PUBLIC "LINKER:-no_deduplicate")
target_compile_options(osdtest PUBLIC "-fobjc-arc" -g)
find_library(CORE_FRAMEWORK Foundation)
target_link_libraries(osdtest ${CORE_FRAMEWORK} ${EXTRA_LIBS})
