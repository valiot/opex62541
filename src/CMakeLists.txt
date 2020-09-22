set(CMAKE_OSX_DEPLOYMENT_TARGET "10.10" CACHE STRING "")
cmake_minimum_required(VERSION 3.0...3.12)
project(opex62541)
if(${CMAKE_VERSION} VERSION_LESS 3.12)
    cmake_policy(VERSION ${CMAKE_MAJOR_VERSION}.${CMAKE_MINOR_VERSION})
endif()

find_package (Threads)

# Set global property (all targets are impacted)
set_property(GLOBAL PROPERTY RULE_LAUNCH_COMPILE "${CMAKE_COMMAND} -E time")

# make sure our outputs are going somewhere sane
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY $ENV{MIX_COMPILE_PATH}/../priv)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY $ENV{MIX_COMPILE_PATH}/../priv)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY $ENV{MIX_COMPILE_PATH}/../priv)

include(ProcessorCount)
ProcessorCount(N_CORES)

#if crosscompiling (another target), set mbedtls directory
if(NOT $ENV{MIX_TARGET} STREQUAL "host")
    set(MBEDTLS_FOLDER_LIBRARY "$ENV{NERVES_SDK_SYSROOT}/usr/lib")
    set(MBEDTLS_FOLDER_INCLUDE "$ENV{NERVES_SDK_SYSROOT}/usr/include")
endif()

# enable/disable Manual Build
if($ENV{MANUAL_BUILD})
    set(MANUAL_BUILD ON)
else()
    set(MANUAL_BUILD OFF)
endif($ENV{MANUAL_BUILD})

# set version
if("$ENV{OPEN62541_DOWNLOAD_VERSION}" STREQUAL "")
    set(DOWNLOAD_VERSION "v1.0")    
else("$ENV{OPEN62541_DOWNLOAD_VERSION}" STREQUAL "")
    set(DOWNLOAD_VERSION $ENV{OPEN62541_DOWNLOAD_VERSION})    
endif("$ENV{OPEN62541_DOWNLOAD_VERSION}" STREQUAL "")

string(REGEX REPLACE "-O([123s]|(fast)|( )|($))" " " CMAKE_C_FLAGS ${CMAKE_C_FLAGS})

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

string(REGEX REPLACE "-O([123s]|(fast)|( )|($))" " " BASE_FLAGS ${BASE_FLAGS})

set(BASE_C_FLAGS "-g -Wall -Wextra ${BASE_FLAGS} -lpthread")
set(BASE_CXX_FLAGS "${BASE_FLAGS}")

# BUILDING OPEN62541

if(NOT MANUAL_BUILD)
    message(STATUS "DOWNLOAD_BUILD")

    if("$ENV{OPEN62541_BASE_URL}" STREQUAL "")
        set(BASE_URL "https://github.com/valiot/opex62541/releases/download")
    else("$ENV{OPEN62541_BASE_URL}" STREQUAL "")
        set(BASE_URL $ENV{OPEN62541_BASE_URL})    
    endif("$ENV{OPEN62541_BASE_URL}" STREQUAL "")
    
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
        set(FILE_NAME $ENV{MIX_TARGET})
        set(PACKAGE_NAME "${FILE_NAME}.tar.gz")
        set(UNPACK_CMD tar)
        set(UNPACK_CMD_OPTIONS -xvf)
    endif($ENV{MIX_TARGET} STREQUAL "host")
    
    set(DOWNLOAD_URL "${BASE_URL}/${DOWNLOAD_VERSION}/open62541-${PACKAGE_NAME}")

    # Download & Uncompress the package
    set(DOWNLOAD_PATH "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/${PACKAGE_NAME}")
    set(EXTRACTED_FILE "open62541-${FILE_NAME}")

    if ((NOT EXISTS "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/lib") AND (NOT EXISTS "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/include"))
        file(DOWNLOAD "${DOWNLOAD_URL}" "${DOWNLOAD_PATH}")
        execute_process(
            COMMAND ${UNPACK_CMD} ${UNPACK_CMD_OPTIONS} ${DOWNLOAD_PATH} ${EXTRACTED_FILE}
            WORKING_DIRECTORY ${CMAKE_RUNTIME_OUTPUT_DIRECTORY})
        file(REMOVE "${DOWNLOAD_PATH}")
        file(COPY "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/${EXTRACTED_FILE}/lib" DESTINATION "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}")
        file(COPY "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/${EXTRACTED_FILE}/include" DESTINATION "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}")
        
    endif()

    file(REMOVE_RECURSE "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/${EXTRACTED_FILE}")

    set(install_dir ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/lib)

    set(include_dir ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/include)

    include_directories(${include_dir})

    include_directories($ENV{ERL_EI_INCLUDE_DIR})

    include_directories($ENV{CMAKE_SOURCE_DIR})

    include_directories(open62541)

    file(GLOB STATIC_LIBS "$ENV{ERL_EI_LIBDIR}/*.a")

    set (opex62541_PROGRAMS opc_ua_client opc_ua_server)

    foreach(opex62541_PROGRAM ${opex62541_PROGRAMS})
        add_executable( ${opex62541_PROGRAM} "${CMAKE_SOURCE_DIR}/${opex62541_PROGRAM}.c" "${CMAKE_SOURCE_DIR}/erlcmd.c" "${CMAKE_SOURCE_DIR}/common.c")
        target_link_libraries(${opex62541_PROGRAM} ${STATIC_LIBS})
        target_link_libraries(${opex62541_PROGRAM} ${CMAKE_THREAD_LIBS_INIT})
        target_link_libraries(${opex62541_PROGRAM} ${install_dir}/libopen62541.so)
    endforeach(opex62541_PROGRAM)    

else(NOT MANUAL_BUILD)

    message(STATUS "MANUAL_BUILD")
    set(install_dir ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/lib)

    # set version
    if($ENV{OPEN62541_BUILD_ARGS})
    set(OPEN62541_BUILD_ARGS $ENV{OPEN62541_BUILD_ARGS})
    else($ENV{OPEN62541_BUILD_ARGS})
    set(OPEN62541_BUILD_ARGS -DBUILD_SHARED_LIBS=ON -DCMAKE_BUILD_TYPE=RelWithDebInfo -DUA_NAMESPACE_ZERO=FULL -DUA_LOGLEVEL=601 -DUA_ENABLE_DISCOVERY_MULTICAST=ON -DUA_ENABLE_AMALGAMATION=ON -DUA_ENABLE_ENCRYPTION=ON -DUA_ENABLE_DISCOVERY=ON)
    endif($ENV{OPEN62541_BUILD_ARGS})
    
    include(ExternalProject)
    
    # open62541 logs collide with opex62541 backend interface, therefore logs are turned off (-DUA_LOGLEVEL > 600).
    ExternalProject_Add(open62541
        GIT_REPOSITORY    https://github.com/open62541/open62541.git
        GIT_TAG           ${DOWNLOAD_VERSION}
        SOURCE_DIR        "${CMAKE_BINARY_DIR}/open62541-src"
        BINARY_DIR        "${CMAKE_BINARY_DIR}/open62541-build"
        CONFIGURE_COMMAND ""
        BUILD_COMMAND     MBEDTLS_FOLDER_LIBRARY=${MBEDTLS_FOLDER_LIBRARY} MBEDTLS_FOLDER_INCLUDE=${MBEDTLS_FOLDER_INCLUDE} cmake ${CMAKE_BINARY_DIR}/open62541-src ${OPEN62541_BUILD_ARGS}  -DCMAKE_INSTALL_PREFIX=${CMAKE_LIBRARY_OUTPUT_DIRECTORY} && make -j ${N_CORES}
        INSTALL_COMMAND   make install
        PATCH_COMMAND     cp ${CMAKE_SOURCE_DIR}/FindMbedTLS.cmake ${CMAKE_BINARY_DIR}/open62541-src/tools/cmake//FindMbedTLS.cmake
    )

    include_directories($ENV{ERL_EI_INCLUDE_DIR})

    include_directories(${CMAKE_SOURCE_DIR})

    include_directories(open62541)

    include_directories(${CMAKE_BINARY_DIR}/open62541-build)

    file(GLOB STATIC_LIBS "$ENV{ERL_EI_LIBDIR}/*.a")

    set (opex62541_PROGRAMS opc_ua_server opc_ua_client)

    include_directories(${install_dir})

    foreach(opex62541_PROGRAM ${opex62541_PROGRAMS})
        add_executable( ${opex62541_PROGRAM} ${CMAKE_SOURCE_DIR}/${opex62541_PROGRAM}.c ${CMAKE_SOURCE_DIR}/erlcmd.c ${CMAKE_SOURCE_DIR}/common.c)
        add_dependencies(${opex62541_PROGRAM} open62541)
        target_link_libraries(${opex62541_PROGRAM} ${STATIC_LIBS})
        target_link_libraries(${opex62541_PROGRAM} ${CMAKE_THREAD_LIBS_INIT})
        target_link_libraries(${opex62541_PROGRAM} ${install_dir}/libopen62541.so)
    endforeach(opex62541_PROGRAM)

endif(NOT MANUAL_BUILD)

message(STATUS "Debugs CMAKE_C_FAGS=${CMAKE_C_FLAGS}; BASE_C_FLAGS=${BASE_C_FLAGS}; MBEDTLS_FOLDER_LIBRARY=${MBEDTLS_FOLDER_LIBRARY} MBEDTLS_FOLDER_INCLUDE=${MBEDTLS_FOLDER_INCLUDE}")