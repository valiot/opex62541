set(CMAKE_OSX_DEPLOYMENT_TARGET "10.10" CACHE STRING "")
cmake_minimum_required(VERSION 3.0...3.12)
project(opex62541)
if(${CMAKE_VERSION} VERSION_LESS 3.12)
    cmake_policy(VERSION ${CMAKE_MAJOR_VERSION}.${CMAKE_MINOR_VERSION})
endif()

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

# BUILDING OPEN62541

if(NOT MANUAL_BUILD)
    set(BASE_URL "https://github.com/open62541/open62541/releases/download")

    # set version
    if($ENV{DOWNLOAD_VERSION})
        set(DOWNLOAD_VERSION $ENV{DOWNLOAD_VERSION})
    else($ENV{DOWNLOAD_VERSION})
        set(DOWNLOAD_VERSION "v1.0")
    endif($ENV{DOWNLOAD_VERSION})
    
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


    message(STATUS "IN IF")
else(NOT MANUAL_BUILD)
    message(STATUS "IN ELSE")
endif(NOT MANUAL_BUILD)

string(TOLOWER ${CMAKE_SYSTEM_NAME} LLL) #CMAKE_SYSTEM_NAME
message(STATUS "Debugs $ENV{MIX_ENV},  ${UNPACK_CMD} ${UNPACK_CMD_OPTIONS} ${DOWNLOAD_PATH} open62541-${FILE_NAME}")