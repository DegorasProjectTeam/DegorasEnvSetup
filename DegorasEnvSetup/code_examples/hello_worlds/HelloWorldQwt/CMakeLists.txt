# ======================================================================================================================
#  Copyright (C) 2025 Degoras Project Team
#                                                                                                                    
#  Authors:
#
#      Ángel Vera Herrera       <avera@roa.es> | <angelvh.engr@gmail.com>                                         
#      Jesús Relinque Madroñal
#
#  Licensed under the MIT License.
# ======================================================================================================================

# ======================================================================================================================
#   APP HELLO WORLD QWT - CMAKELIST
# ======================================================================================================================

# ----------------------------------------------------------------------------------------------------------------------
# BASIC PROJECT CONFIGURATION

# Minimum CMake version required.
cmake_minimum_required(VERSION 3.31)

# Project definition.
project(HelloWorldQwt LANGUAGES CXX)

# For avoid architecture detection warning.
set(CMAKE_SYSTEM_PROCESSOR x86_64 CACHE STRING "")

# Global configurations.
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# ----------------------------------------------------------------------------------------------------------------------
#  ENVIRONMENT SUMMARY

message(STATUS "===================================================================")
message(STATUS " Degoras Project - APP HELLO WORLD QWT")
message(STATUS "-------------------------------------------------------------------")
message(STATUS "  CMAKE_SYSTEM_NAME                : ${CMAKE_SYSTEM_NAME}")
message(STATUS "  CMAKE_SYSTEM_PROCESSOR           : ${CMAKE_SYSTEM_PROCESSOR}")
message(STATUS "  CMAKE_TOOLCHAIN_FILE             : ${CMAKE_TOOLCHAIN_FILE}")
message(STATUS "  CMAKE_GENERATOR                  : ${CMAKE_GENERATOR}")
message(STATUS "  CMAKE_CXX_COMPILER               : ${CMAKE_CXX_COMPILER}")
message(STATUS "  CMAKE_CXX_COMPILER_ID            : ${CMAKE_CXX_COMPILER_ID}")
message(STATUS "  CMAKE_MAKE_PROGRAM               : ${CMAKE_MAKE_PROGRAM}")
message(STATUS "  CMAKE_FIND_PACKAGE_PREFER_CONFIG : ${CMAKE_FIND_PACKAGE_PREFER_CONFIG}")
message(STATUS "  CMAKE_EXPORT_COMPILE_COMMANDS    : ${CMAKE_EXPORT_COMPILE_COMMANDS}")
message(STATUS "  CMAKE_COLOR_DIAGNOSTICS          : ${CMAKE_COLOR_DIAGNOSTICS}")
message(STATUS "  CMAKE_SOURCE_DIR                 : ${CMAKE_SOURCE_DIR}")
message(STATUS "  CMAKE_BINARY_DIR                 : ${CMAKE_BINARY_DIR}")
message(STATUS "  CMAKE_BUILD_TYPE                 : ${CMAKE_BUILD_TYPE}")
message(STATUS "  VCPKG_TARGET_TRIPLET             : ${VCPKG_TARGET_TRIPLET}")
message(STATUS "  VCPKG_HOST_TRIPLET               : ${VCPKG_HOST_TRIPLET}")
message(STATUS "  VCPKG_MANIFEST_MODE              : ${VCPKG_MANIFEST_MODE}")
message(STATUS "===================================================================")

# ----------------------------------------------------------------------------------------------------------------------
# DEPENDENCIES 

# Qt6 modules.
find_package(Qt6 REQUIRED COMPONENTS Core Gui Widgets)

# Qwt modules.
find_package(unofficial-qwt CONFIG REQUIRED)

# ----------------------------------------------------------------------------------------------------------------------
# BUILD TARGETS

# Define the main executable target.
qt6_add_executable(App_HelloWorldQwt App_HelloWorldQwt.cpp)

# Enable Qt’s automatic processing tools.
set_target_properties(App_HelloWorldQwt PROPERTIES
    AUTOMOC ON
    AUTOUIC ON
    AUTORCC ON)
	
# Include directories (and autogen).
get_target_property(_autogen_dir App_HelloWorldQwt AUTOGEN_BUILD_DIR)
target_include_directories(App_HelloWorldQwt PRIVATE 
	${CMAKE_CURRENT_BINARY_DIR}
	${_autogen_dir}/include)
	
# Link required libraries.
target_link_libraries(App_HelloWorldQwt PRIVATE
	Qt6::Gui
	Qt6::Widgets
    unofficial::qwt::qwt)

# ----------------------------------------------------------------------------------------------------------------------
# COMPILER CONFIGURATION

# GCC-specific flags.
if (CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
    if (CMAKE_BUILD_TYPE STREQUAL "Debug")
        set(CMAKE_CXX_FLAGS  "${CMAKE_CXX_FLAGS} -Wpedantic -Wall -Wextra -O0 -fopenmp")
    else()
        set(CMAKE_CXX_FLAGS  "${CMAKE_CXX_FLAGS} -pedantic -Wall -Wextra -O3 -fopenmp")
    endif()
else()
    message(FATAL_ERROR "Compiler not supported by default.")
endif()

# Static linking for MinGW runtime libs.
if (MINGW)
	target_link_options(App_HelloWorldQwt PRIVATE -static-libgcc -static-libstdc++)
endif()

# ----------------------------------------------------------------------------------------------------------------------
#  RUNTIME LIBRARY COPY (only for Debug builds)

if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    set(_QWT_BIN_DIR "${_VCPKG_INSTALLED_DIR}/${VCPKG_TARGET_TRIPLET}/bin")
    set(_QWT_DLL "${_QWT_BIN_DIR}/qwt.dll")

    if(EXISTS "${_QWT_DLL}")
        add_custom_command(TARGET App_HelloWorldQwt POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E echo "[DEGORAS] Copying Qwt runtime library (Debug build)..."
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${_QWT_DLL}"
                "$<TARGET_FILE_DIR:App_HelloWorldQwt>/qwt.dll"
            VERBATIM
        )
    else()
        message(WARNING "[DEGORAS] qwt.dll not found in ${_QWT_BIN_DIR}")
    endif()
endif()

# ----------------------------------------------------------------------------------------------------------------------
#  QT.CONF CONFIG FILE CREATION

if(NOT DEFINED _VCPKG_INSTALLED_DIR)
    set(_VCPKG_INSTALLED_DIR "${VCPKG_ROOT}/installed")
endif()

set(_QT_CONF_PATH "$<TARGET_FILE_DIR:App_HelloWorldQwt>/qt.conf")

if(NOT CMAKE_BUILD_TYPE STREQUAL "Debug")
    add_custom_command(TARGET App_HelloWorldQwt POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E echo "[DEGORAS] Generating qt.conf at: ${_QT_CONF_PATH}"
        COMMAND ${CMAKE_COMMAND} -E rm -f "${_QT_CONF_PATH}"
        COMMAND ${CMAKE_COMMAND} -E echo "[Paths]" > "${_QT_CONF_PATH}"
        COMMAND ${CMAKE_COMMAND} -E echo "Prefix=${_VCPKG_INSTALLED_DIR}/${VCPKG_TARGET_TRIPLET}" >> "${_QT_CONF_PATH}"
        COMMAND ${CMAKE_COMMAND} -E echo "Plugins=Qt6/plugins" >> "${_QT_CONF_PATH}"
        COMMAND ${CMAKE_COMMAND} -E echo "Libraries=lib" >> "${_QT_CONF_PATH}"
        COMMAND ${CMAKE_COMMAND} -E echo "Binaries=bin" >> "${_QT_CONF_PATH}"
        VERBATIM
    )
else()
    message(STATUS "[DEGORAS] qt.conf generation disabled for Debug build")
endif()

# ==================================================================================================
