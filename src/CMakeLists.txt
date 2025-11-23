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

# enable/disable Manual Build
if($ENV{MANUAL_BUILD})
    set(MANUAL_BUILD ON)
else()
    set(MANUAL_BUILD OFF)
endif($ENV{MANUAL_BUILD})

# set version
if("$ENV{OPEN62541_DOWNLOAD_VERSION}" STREQUAL "")
    set(DOWNLOAD_VERSION "v1.4.14")    
else("$ENV{OPEN62541_DOWNLOAD_VERSION}" STREQUAL "")
    set(DOWNLOAD_VERSION $ENV{OPEN62541_DOWNLOAD_VERSION})    
endif("$ENV{OPEN62541_DOWNLOAD_VERSION}" STREQUAL "")

string(REGEX REPLACE "-O([123s]|(fast)|( )|($))" " " CMAKE_C_FLAGS  "${CMAKE_C_FLAGS}")

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

string(REGEX REPLACE "-O([123s]|(fast)|( )|($))" " " BASE_FLAGS "${BASE_FLAGS}")

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
        message(STATUS "Downloading from: ${DOWNLOAD_URL}")
        message(STATUS "Download path: ${DOWNLOAD_PATH}")
        
        file(DOWNLOAD "${DOWNLOAD_URL}" "${DOWNLOAD_PATH}" STATUS DOWNLOAD_STATUS)
        list(GET DOWNLOAD_STATUS 0 STATUS_CODE)
        list(GET DOWNLOAD_STATUS 1 ERROR_MESSAGE)
        
        if(NOT STATUS_CODE EQUAL 0)
            message(FATAL_ERROR "Failed to download open62541 from ${DOWNLOAD_URL}\nError: ${ERROR_MESSAGE}")
        endif()
        
        # Verify the file was downloaded and has content
        if(NOT EXISTS "${DOWNLOAD_PATH}")
            message(FATAL_ERROR "Download file not found at ${DOWNLOAD_PATH}")
        endif()
        
        file(SIZE "${DOWNLOAD_PATH}" DOWNLOAD_SIZE)
        if(DOWNLOAD_SIZE LESS 1000)
            message(FATAL_ERROR "Downloaded file is too small (${DOWNLOAD_SIZE} bytes), likely invalid. URL: ${DOWNLOAD_URL}")
        endif()
        
        message(STATUS "Extracting ${DOWNLOAD_PATH} (${DOWNLOAD_SIZE} bytes)...")
        execute_process(
            COMMAND ${UNPACK_CMD} ${UNPACK_CMD_OPTIONS} ${DOWNLOAD_PATH}
            WORKING_DIRECTORY ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}
            RESULT_VARIABLE EXTRACT_RESULT
            ERROR_VARIABLE EXTRACT_ERROR)
        
        if(NOT EXTRACT_RESULT EQUAL 0)
            message(FATAL_ERROR "Failed to extract ${DOWNLOAD_PATH}\nError: ${EXTRACT_ERROR}")
        endif()
        
        # Verify extracted directories exist
        if(NOT EXISTS "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/${EXTRACTED_FILE}/lib")
            message(FATAL_ERROR "Extracted lib directory not found at ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/${EXTRACTED_FILE}/lib")
        endif()
        
        if(NOT EXISTS "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/${EXTRACTED_FILE}/include")
            message(FATAL_ERROR "Extracted include directory not found at ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/${EXTRACTED_FILE}/include")
        endif()
        
        file(COPY "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/${EXTRACTED_FILE}/lib" DESTINATION "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}")
        file(COPY "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/${EXTRACTED_FILE}/include" DESTINATION "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}")
        
        # Clean up downloaded file and extracted directory
        file(REMOVE "${DOWNLOAD_PATH}")
        file(REMOVE_RECURSE "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/${EXTRACTED_FILE}")
        
        message(STATUS "Successfully extracted open62541 libraries")
    endif()

    set(install_dir ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/lib)

    set(include_dir ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/include)

    include_directories(${include_dir})

    include_directories($ENV{ERL_EI_INCLUDE_DIR})

    include_directories($ENV{CMAKE_SOURCE_DIR})

    include_directories(open62541)

    file(GLOB STATIC_LIBS "$ENV{ERL_EI_LIBDIR}/*.a")

    set (opex62541_PROGRAMS opc_ua_server opc_ua_client client_example server_example)

    foreach(opex62541_PROGRAM ${opex62541_PROGRAMS})
        add_executable( ${opex62541_PROGRAM} "${CMAKE_SOURCE_DIR}/${opex62541_PROGRAM}.c" "${CMAKE_SOURCE_DIR}/erlcmd.c" "${CMAKE_SOURCE_DIR}/common.c" )
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
    set(OPEN62541_BUILD_ARGS -DBUILD_SHARED_LIBS=ON -DCMAKE_BUILD_TYPE=RelWithDebInfo -DUA_NAMESPACE_ZERO=FULL -DUA_LOGLEVEL=601 -DUA_ENABLE_DISCOVERY_MULTICAST=ON -DUA_ENABLE_AMALGAMATION=ON -DUA_ENABLE_ENCRYPTION=OPENSSL)
    endif($ENV{OPEN62541_BUILD_ARGS})
    
    include(ExternalProject)
    
    # open62541 logs collide with opex62541 backend interface, therefore logs are turned off (-DUA_LOGLEVEL > 600).
    # Note: v1.4.x doesn't allow 'make install' with amalgamation, so we copy files manually
    ExternalProject_Add(open62541
        GIT_REPOSITORY    https://github.com/open62541/open62541.git
        GIT_TAG           ${DOWNLOAD_VERSION}
        SOURCE_DIR        "${CMAKE_BINARY_DIR}/open62541-src"
        BINARY_DIR        "${CMAKE_BINARY_DIR}/open62541-build"
        CONFIGURE_COMMAND ""
        BUILD_COMMAND     cmake ${CMAKE_BINARY_DIR}/open62541-src ${OPEN62541_BUILD_ARGS}  -DCMAKE_INSTALL_PREFIX=${CMAKE_LIBRARY_OUTPUT_DIRECTORY} && make -j ${N_CORES}
        INSTALL_COMMAND   sh -c "mkdir -p ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/lib ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/include && cp ${CMAKE_BINARY_DIR}/open62541-build/bin/libopen62541.so* ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/lib/ && cp ${CMAKE_BINARY_DIR}/open62541-build/open62541.h ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/include/"
    )

    include_directories($ENV{ERL_EI_INCLUDE_DIR})

    include_directories(${CMAKE_SOURCE_DIR})

    include_directories(open62541)

    include_directories(${CMAKE_BINARY_DIR}/open62541-build)

    file(GLOB STATIC_LIBS "$ENV{ERL_EI_LIBDIR}/*.a")

    set (opex62541_PROGRAMS opc_ua_server opc_ua_client client_example server_example)

    include_directories(${install_dir})

    foreach(opex62541_PROGRAM ${opex62541_PROGRAMS})
        add_executable( ${opex62541_PROGRAM} ${CMAKE_SOURCE_DIR}/${opex62541_PROGRAM}.c ${CMAKE_SOURCE_DIR}/erlcmd.c ${CMAKE_SOURCE_DIR}/common.c)
        add_dependencies(${opex62541_PROGRAM} open62541)
        target_link_libraries(${opex62541_PROGRAM} ${STATIC_LIBS})
        target_link_libraries(${opex62541_PROGRAM} ${CMAKE_THREAD_LIBS_INIT})
        target_link_libraries(${opex62541_PROGRAM} ${install_dir}/libopen62541.so)
    endforeach(opex62541_PROGRAM)

endif(NOT MANUAL_BUILD)

message(STATUS "Debugs CMAKE_C_FAGS=${CMAKE_C_FLAGS}; BASE_C_FLAGS=${BASE_C_FLAGS}")