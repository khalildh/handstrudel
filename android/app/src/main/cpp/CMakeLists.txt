cmake_minimum_required(VERSION 3.22.1)
project(handstrudel_tsf)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Drop TinySoundFont's stdio dependency — we feed it bytes from Java rather
# than loading from a FILE*, and the Android NDK strips fopen/fread paths
# we don't use anyway.
add_compile_definitions(TSF_NO_STDIO)

# -O3 + fast-math for the audio render path (TSF is very float-heavy).
add_compile_options(-O3 -ffast-math)

add_library(handstrudel_tsf SHARED
    tsf_jni.cpp
)

find_library(log-lib log)
target_link_libraries(handstrudel_tsf ${log-lib})
