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
#   APP HELLO WORLD SPDLOG - CMAKELIST
# ======================================================================================================================

# ----------------------------------------------------------------------------------------------------------------------
# BASIC PROJECT CONFIGURATION

# Minimum CMake version required.
cmake_minimum_required(VERSION 3.31)

# Project definition.
project(HelloWorldSpdlog LANGUAGES CXX)

# For avoid architecture detection warning.
set(CMAKE_SYSTEM_PROCESSOR x86_64 CACHE STRING "")

# Global configurations.
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# ----------------------------------------------------------------------------------------------------------------------
#  ENVIRONMENT SUMMARY

message(STATUS "===================================================================")
message(STATUS " Degoras Project - APP HELLO WORLD SPDLOG")
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

# Json		
find_package(nlohmann_json CONFIG REQUIRED)

# Spdlog
find_package(spdlog CONFIG REQUIRED)

# ----------------------------------------------------------------------------------------------------------------------
# BUILD TARGETS

# Define the main executable target.
add_executable(App_HelloWorldSpdlog App_HelloWorldSpdlog.cpp)

# Link required libraries.
target_link_libraries(App_HelloWorldSpdlog PRIVATE
    spdlog::spdlog
	nlohmann_json::nlohmann_json)

# Static Mongo and Bson.	
target_compile_definitions(App_HelloWorldSpdlog PRIVATE MONGOC_STATIC BSONC_STATIC)

# ----------------------------------------------------------------------------------------------------------------------
# COMPILER CONFIGURATION

# GCC-specific flags.
if (CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
    if (CMAKE_BUILD_TYPE STREQUAL "Debug")
        set(CMAKE_CXX_FLAGS  "${CMAKE_CXX_FLAGS} -Wpedantic -Wall -Wextra -O0")
    else()
        set(CMAKE_CXX_FLAGS  "${CMAKE_CXX_FLAGS} -pedantic -Wall -Wextra -O3")
    endif()
else()
    message(FATAL_ERROR "Compiler not supported by default.")
endif()

# Static linking for MinGW runtime libs.
if (MINGW)
	target_link_options(App_HelloWorldSpdlog PRIVATE -static-libgcc -static-libstdc++)
endif()

# ==================================================================================================
