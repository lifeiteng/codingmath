cmake_minimum_required(VERSION 3.0)
project(webrtc_examples)
set (webrtc_examples_VERSION_MAJAR 1)
set (webrtc_examples_VERSION_MINOR 0)

add_definitions(-std=c++11 -static
        -DWEBRTC_POSIX=1
        -DWEBRTC_AUDIO_PROCESSING_ONLY_BUILD=1)

include_directories (webrtc-audio-processing/release/include/webrtc_audio_processing)
link_directories(webrtc-audio-processing/release/lib)
link_libraries(webrtc_audio_processing)

add_executable(webrtc-audio-process src/webrtc_audio_processing.cc)


