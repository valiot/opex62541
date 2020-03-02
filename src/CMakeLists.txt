set(CMAKE_OSX_DEPLOYMENT_TARGET "10.10" CACHE STRING "")
cmake_minimum_required(VERSION 3.0...3.12)
project(opex62541)
if(${CMAKE_VERSION} VERSION_LESS 3.12)
    cmake_policy(VERSION ${CMAKE_MAJOR_VERSION}.${CMAKE_MINOR_VERSION})
endif()

# Set global property (all targets are impacted)
set_property(GLOBAL PROPERTY RULE_LAUNCH_COMPILE "${CMAKE_COMMAND} -E time")

# make sure our outputs are going somewhere sane
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY $ENV{MIX_COMPILE_PATH}/../priv)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY $ENV{MIX_COMPILE_PATH}/../priv)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY $ENV{MIX_COMPILE_PATH}/../priv)

set(ON_OR_OFF OFF)

if($ENV{MANUAL_BUILD})
    set(MANUAL_BUILD ON)
else()
    set(MANUAL_BUILD OFF)
endif($ENV{MANUAL_BUILD})

# set version
if($ENV{OPEN62541_DOWNLOAD_VERSION})
set(DOWNLOAD_VERSION $ENV{OPEN62541_DOWNLOAD_VERSION})
else($ENV{OPEN62541_DOWNLOAD_VERSION})
set(DOWNLOAD_VERSION "v1.0")
endif($ENV{OPEN62541_DOWNLOAD_VERSION})

# BUILDING OPEN62541

if(NOT MANUAL_BUILD)
    set(BASE_URL "https://github.com/open62541/open62541/releases/download")
    
    # define ARCH
    if($ENV{MIX_TARGET} STREQUAL "host")
        # target n bits
        if(CMAKE_SYSTEM_PROCESSOR STREQUAL "x86_64")
            set(TARGET_N_BITS "64")
        else()
            set(TARGET_N_BITS "32")
        endif(CMAKE_SYSTEM_PROCESSOR STREQUAL "x86_64")
        # package
        if(UNIX)
            set(FILE_NAME "linux${TARGET_N_BITS}")
            set(PACKAGE_NAME "${FILE_NAME}.tar.gz")
            set(UNPACK_CMD tar)
            set(UNPACK_CMD_OPTIONS -xvf)
        elseif(WIN32)
            set(FILE_NAME "win${TARGET_N_BITS}.zip")
            set(PACKAGE_NAME "win${TARGET_N_BITS}.zip")
            set(UNPACK_CMD unzip)
        endif(UNIX)
    else()
        set(FILE_NAME "raspberrypi")
        set(PACKAGE_NAME "${FILE_NAME}.tar.gz")
        set(UNPACK_CMD tar)
        set(UNPACK_CMD_OPTIONS -xvf)
    endif($ENV{MIX_TARGET} STREQUAL "host")
    
    set(DOWNLOAD_URL "${BASE_URL}/${DOWNLOAD_VERSION}/open62541-${PACKAGE_NAME}")

    # Download & Uncompress the package
    set(DOWNLOAD_PATH "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/${PACKAGE_NAME}")
    set(EXTRACTED_FILE "open62541-${FILE_NAME}")

    if (NOT EXISTS "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/${EXTRACTED_FILE}")
        file(DOWNLOAD "${DOWNLOAD_URL}" "${DOWNLOAD_PATH}")
        execute_process(
            COMMAND ${UNPACK_CMD} ${UNPACK_CMD_OPTIONS} ${DOWNLOAD_PATH} ${EXTRACTED_FILE}
            WORKING_DIRECTORY ${CMAKE_RUNTIME_OUTPUT_DIRECTORY})
        file(REMOVE "${DOWNLOAD_PATH}")
    endif()

    set(install_dir ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/${EXTRACTED_FILE}/lib)

else(NOT MANUAL_BUILD)

    set(install_dir ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/lib)

    # set version
    if($ENV{OPEN62541_BUILD_ARGS})
    set(OPEN62541_BUILD_ARGS $ENV{OPEN62541_BUILD_ARGS})
    else($ENV{OPEN62541_BUILD_ARGS})
    set(OPEN62541_BUILD_ARGS "-DBUILD_SHARED_LIBS=ON -DCMAKE_BUILD_TYPE=RelWithDebInfo -DUA_NAMESPACE_ZERO=FULL")
    endif($ENV{OPEN62541_BUILD_ARGS})
    
    include(ExternalProject)
    
    ExternalProject_Add(open62541
        GIT_REPOSITORY    https://github.com/open62541/open62541.git
        GIT_TAG           ${DOWNLOAD_VERSION}
        SOURCE_DIR        "${CMAKE_BINARY_DIR}/open62541-src"
        BINARY_DIR        "${CMAKE_BINARY_DIR}/open62541-build"
        CONFIGURE_COMMAND ""
        BUILD_COMMAND     cmake ${CMAKE_BINARY_DIR}/open62541-src -DCMAKE_INSTALL_PREFIX=${CMAKE_LIBRARY_OUTPUT_DIRECTORY} ${OPEN62541_BUILD_ARGS} && make
        INSTALL_COMMAND   make install
        TEST_COMMAND      ""
    )

endif(NOT MANUAL_BUILD)

# OPEX62541 SOURCE CODE BUILD
# C compiler specific settings
if (CMAKE_C_COMPILER_ID STREQUAL "Clang")
    # using Clang
    set(BASE_RELEASE_FLAGS "${CMAKE_C_FLAGS} -std=c99")
    set(BASE_DEBUG_FLAGS "${CMAKE_C_FLAGS}  -std=c99")
elseif (CMAKE_C_COMPILER_ID STREQUAL "GNU")
    # using GCC
    set(BASE_RELEASE_FLAGS "${CMAKE_C_FLAGS} -std=c99")
    set(BASE_DEBUG_FLAGS "${CMAKE_C_FLAGS}  -std=c99")
elseif (CMAKE_C_COMPILER_ID STREQUAL "Intel")
    # using Intel C/C++
    MESSAGE("Intel C compiler not supported!")
endif()

if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    set(BASE_FLAGS "${BASE_DEBUG_FLAGS}")
else()
    set(BASE_FLAGS "${BASE_RELEASE_FLAGS}")
endif()

set(BASE_C_FLAGS "${BASE_FLAGS} -std=c99")
set(BASE_CXX_FLAGS "${BASE_FLAGS}")

add_executable(main ${PROJECT_SOURCE_DIR}/compile_test.c)
set_property(TARGET main PROPERTY RULE_LAUNCH_COMPILE "${CMAKE_COMMAND} -E time")
target_link_libraries(main ${install_dir}/libopen62541.so)

message(STATUS "Debugs $ENV{MIX_ENV}, ${__TIME__}")