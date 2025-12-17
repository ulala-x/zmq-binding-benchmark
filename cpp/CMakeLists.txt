cmake_minimum_required(VERSION 3.15)
project(zmq_benchmark_cpp)

# C++17 Standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Release build with optimizations
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
endif()

# Optimization flags
set(CMAKE_CXX_FLAGS_RELEASE "-O3 -march=native -flto")

# Platform-specific libzmq detection
set(LIBZMQ_NATIVE_DIR "${CMAKE_SOURCE_DIR}/third-party/libzmq-native")
set(CPPZMQ_INCLUDE_DIR "${CMAKE_SOURCE_DIR}/third-party/cppzmq")

if(WIN32)
    # Windows
    if(CMAKE_SYSTEM_PROCESSOR MATCHES "ARM64")
        set(LIBZMQ_LIB "${LIBZMQ_NATIVE_DIR}/dist/windows-arm64/libzmq.lib")
        set(LIBZMQ_DLL "${LIBZMQ_NATIVE_DIR}/dist/windows-arm64/libzmq.dll")
    else()
        set(LIBZMQ_LIB "${LIBZMQ_NATIVE_DIR}/dist/windows-x64/libzmq.lib")
        set(LIBZMQ_DLL "${LIBZMQ_NATIVE_DIR}/dist/windows-x64/libzmq.dll")
    endif()

    # Check if library exists
    if(NOT EXISTS ${LIBZMQ_LIB})
        message(FATAL_ERROR "libzmq not found at ${LIBZMQ_LIB}. Please build libzmq-native first.")
    endif()

elseif(APPLE)
    # macOS
    if(CMAKE_SYSTEM_PROCESSOR MATCHES "arm64")
        set(LIBZMQ_LIB "${LIBZMQ_NATIVE_DIR}/dist/macos-arm64/libzmq.dylib")
    else()
        set(LIBZMQ_LIB "${LIBZMQ_NATIVE_DIR}/dist/macos-x64/libzmq.dylib")
    endif()

    # Check if library exists
    if(NOT EXISTS ${LIBZMQ_LIB})
        message(FATAL_ERROR "libzmq not found at ${LIBZMQ_LIB}. Please build libzmq-native first.")
    endif()

else()
    # Linux
    if(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64")
        set(LIBZMQ_LIB "${LIBZMQ_NATIVE_DIR}/dist/linux-arm64/libzmq.so")
    else()
        set(LIBZMQ_LIB "${LIBZMQ_NATIVE_DIR}/dist/linux-x64/libzmq.so")
    endif()

    # Check if library exists
    if(NOT EXISTS ${LIBZMQ_LIB})
        message(FATAL_ERROR "libzmq not found at ${LIBZMQ_LIB}. Please build libzmq-native first.")
    endif()
endif()

message(STATUS "Using libzmq library: ${LIBZMQ_LIB}")
message(STATUS "Using cppzmq headers: ${CPPZMQ_INCLUDE_DIR}")

# Detect platform-specific include directory
if(WIN32)
    if(CMAKE_SYSTEM_PROCESSOR MATCHES "ARM64")
        set(LIBZMQ_INCLUDE_DIR "${LIBZMQ_NATIVE_DIR}/build/windows-arm64/install/include")
    else()
        set(LIBZMQ_INCLUDE_DIR "${LIBZMQ_NATIVE_DIR}/build/windows-x64/install/include")
    endif()
elseif(APPLE)
    if(CMAKE_SYSTEM_PROCESSOR MATCHES "arm64")
        set(LIBZMQ_INCLUDE_DIR "${LIBZMQ_NATIVE_DIR}/build/macos-arm64/install/include")
    else()
        set(LIBZMQ_INCLUDE_DIR "${LIBZMQ_NATIVE_DIR}/build/macos-x64/install/include")
    endif()
else()
    if(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64")
        set(LIBZMQ_INCLUDE_DIR "${LIBZMQ_NATIVE_DIR}/build/linux-arm64/install/include")
    else()
        set(LIBZMQ_INCLUDE_DIR "${LIBZMQ_NATIVE_DIR}/build/linux-x64/install/include")
    endif()
endif()

message(STATUS "Using libzmq headers: ${LIBZMQ_INCLUDE_DIR}")

# Include directories
include_directories(
    ${CPPZMQ_INCLUDE_DIR}
    ${LIBZMQ_INCLUDE_DIR}
)

# Common link libraries
set(COMMON_LIBRARIES ${LIBZMQ_LIB})

# Platform-specific threading library
if(NOT WIN32)
    find_package(Threads REQUIRED)
    list(APPEND COMMON_LIBRARIES Threads::Threads)
endif()

# Build executables
add_executable(local_lat src/local_lat.cpp)
target_link_libraries(local_lat ${COMMON_LIBRARIES})

add_executable(remote_lat src/remote_lat.cpp)
target_link_libraries(remote_lat ${COMMON_LIBRARIES})

add_executable(local_thr src/local_thr.cpp)
target_link_libraries(local_thr ${COMMON_LIBRARIES})

add_executable(remote_thr src/remote_thr.cpp)
target_link_libraries(remote_thr ${COMMON_LIBRARIES})

# Set RPATH for Linux/macOS
if(UNIX)
    # Get absolute path for RPATH
    get_filename_component(LIBZMQ_DIR "${LIBZMQ_LIB}" DIRECTORY)
    set_target_properties(local_lat remote_lat local_thr remote_thr
        PROPERTIES
        BUILD_RPATH "${LIBZMQ_DIR}"
        INSTALL_RPATH "${LIBZMQ_DIR}"
    )
    message(STATUS "RPATH set to: ${LIBZMQ_DIR}")
endif()

# Windows: Copy DLL to output directory
if(WIN32)
    add_custom_command(TARGET local_lat POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different "${LIBZMQ_DLL}" "$<TARGET_FILE_DIR:local_lat>")
    add_custom_command(TARGET remote_lat POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different "${LIBZMQ_DLL}" "$<TARGET_FILE_DIR:remote_lat>")
    add_custom_command(TARGET local_thr POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different "${LIBZMQ_DLL}" "$<TARGET_FILE_DIR:local_thr>")
    add_custom_command(TARGET remote_thr POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different "${LIBZMQ_DLL}" "$<TARGET_FILE_DIR:remote_thr>")
endif()

# Print build configuration
message(STATUS "Build type: ${CMAKE_BUILD_TYPE}")
message(STATUS "CXX flags: ${CMAKE_CXX_FLAGS_RELEASE}")
message(STATUS "System: ${CMAKE_SYSTEM_NAME}")
message(STATUS "Processor: ${CMAKE_SYSTEM_PROCESSOR}")
