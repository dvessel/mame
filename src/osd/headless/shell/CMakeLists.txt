cmake_minimum_required(VERSION 3.14.1)

project(osdtest)

set(
        source_list
        main.m
)

include_directories(../public)

add_executable(osdtest ${source_list})
#set_property (TARGET osdtest APPEND_STRING PROPERTY COMPILE_FLAGS "-fobjc-arc -x objective-c")
#set_property (TARGET osdtest APPEND_STRING PROPERTY COMPILE_FLAGS "-fobjc-arc")
target_compile_options(osdtest PUBLIC "-fobjc-arc" -g)
find_library(CORE_FRAMEWORK Foundation)
target_link_libraries(osdtest ${CORE_FRAMEWORK})