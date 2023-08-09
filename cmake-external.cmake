#
# Copyright 2022-2023 Krister Joas
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# Configure and build an external library.
#
# cmake_external(<name> <options>...)
#
# Dowload an archive from a URL and verify its integrity with a SHA256
# hash. Extract the archive and configure, build, and install the
# library in a common install directory.
#
# Options:
#   URL <url>                 URL from where to download the source code.
#   SHA256 <sha256>           The SHA256 checksum of the library (optional but a
#                             warning will be issued if not specified).
#   CONFIG_COMMAND <command>  The configure command if different from the default.
#   BUILD_COMMAND <command>   The build command if different from the default.
#   INSTALL_COMMAND <command> The install command if different from the default.
#   NETRC                     Require the use of NETRC when downloading files (used
#                             if any of the URL's refer to a private repository).
#
# The the default build and install command are
#     cmake --build . --config Release
# and
#     cmake --install . --config Release
#
function(cmake_external NAME)

  message(STATUS "External dependency: ${NAME}")

  #
  # Parse function arguments.
  #
  set(options NETRC VERBOSE)
  set(single_value_args URL SHA256)
  set(multi_value_args DEFINE CONFIG_COMMAND BUILD_COMMAND INSTALL_COMMAND)
  cmake_parse_arguments(EXTERNAL
    "${options}" "${single_value_args}" "${multi_value_args}" ${ARGN})

  # URL is mandatory.
  if(NOT EXTERNAL_URL)
    message(FATAL_ERROR "cmake_external: Missing URL for ${NAME}")
  endif()

  # SHA256 is optional but recommended.
  if(EXTERNAL_SHA256)
    set(SHA256 "URL_HASH SHA256=${EXTERNAL_SHA256}")
  else()
    message(WARNING "cmake_external: Missing SHA256 for ${NAME}")
    set(SHA256 "")
  endif()

  # Check if we need to use the .netrc file for private repos.
  if(EXTERNAL_NETRC)
    set(NETRC "NETRC REQUIRED")
  else()
    set(NETRC)
  endif()

  #
  # Build the list of cmake definitions passed on to the configuration
  # of the external library. Anything specified in the DEFINE option
  # is included as well as some predefined definitions passed on from
  # the parent project.
  #
  set(DEFS "")                  # List of definitions
  set(prefix "\n  ")            # Prefix to keep the output tidy
  # Add user specified definitions.
  foreach(D ${EXTERNAL_DEFINE})
    string(APPEND DEFS "${prefix}-D ${D}")
  endforeach()
  # Add list of definitions propagated from the parent project.
  foreach(I CMAKE_OSX_DEPLOYMENT_TARGET BUILD_SHARED_LIBS)
    if(${I})
      string(
        APPEND DEFS
        "${prefix}-D ${I}=${${I}}")
    endif()
  endforeach()

  # Process custom build and install commands.
  if(EXTERNAL_CONFIG_COMMAND)
    set(CONFIG_COMMAND "${EXTERNAL_CONFIG_COMMAND}")
  else()
    set(CONFIG_COMMAND "${CMAKE_COMMAND} .")
  endif()

  # Process custom build and install commands.
  if(EXTERNAL_BUILD_COMMAND)
    set(BUILD_COMMAND "${EXTERNAL_BUILD_COMMAND}")
  else()
    set(BUILD_COMMAND "${CMAKE_COMMAND} --build . --config Release")
  endif()

  if(EXTERNAL_INSTALL_COMMAND)
    set(INSTALL_COMMAND "${EXTERNAL_INSTALL_COMMAND}")
  else()
    set(INSTALL_COMMAND "${CMAKE_COMMAND} --install . --config Release")
  endif()

  list(APPEND CMAKE_MESSAGE_INDENT "  ")
  _download_external()
  #_build_external2()

endfunction()

#
# Download the file for NAME from EXTERNAL_URL. The expected hash is
# in EXTERNAL_SHA256.
#
macro(_download_external)
  #
  # Set some location variables.
  #
  _set_directories()
  #
  # Get the filename of the URL which will be part of the complete
  # name of the downloaded archive.
  #
  cmake_path(GET EXTERNAL_URL FILENAME _file)
  message(STATUS "${NAME}: Download ${_file}")
  set(_filename "${CMAKE_CURRENT_BINARY_DIR}/${NAME}-${_file}")
  if(NOT EXISTS "${_filename}")
    file(DOWNLOAD ${EXTERNAL_URL} "${_filename}" ${NETRC})
  endif()

  #
  # Check if the file hash match with the expected hash.
  #
  message(CHECK_START "${NAME}: Check hash")
  file(SHA256 "${_filename}" _hash)
  if(NOT ${_hash} STREQUAL ${EXTERNAL_SHA256})
    # Bail out if the SHA256 hashes don't match.
    message(CHECK_FAIL "hash mismatch")
    message(FATAL_ERROR "SHA256 mismatch for ${NAME}:\n  expected ${EXTERNAL_SHA256}\n       got ${_hash}")
  endif()
  message(CHECK_PASS "hash match")
  if(CMAKE_VERSION VERSION_GREATER_EQUAL "3.24")
    set(TOUCH TOUCH)
  endif()

  #
  # Extract archive and move it to the 'src' directory.
  #
  if(NOT EXISTS "${src_dir}")
    file(ARCHIVE_EXTRACT INPUT "${_filename}" DESTINATION "${tmp_dir}" ${TOUCH})

    # Find out if we have a single directory in the top level of the
    # extracted archive.
    file(GLOB _top "${tmp_dir}/*")
    list(LENGTH _top _len)

    if(_len EQUAL 1 AND IS_DIRECTORY "${_top}")
      # Rename the top level directory.
      cmake_path(GET _top FILENAME _element)
      file(RENAME "${tmp_dir}/${_element}" "${src_dir}")
      # Remove what's left over of the temporary directory.
      file(REMOVE_RECURSE "${tmp_dir}")
    else()
      # If there are more files in the top level of the extracted
      # archive we simply rename the temporary directory.
      file(RENAME "${tmp_dir}" "${src_dir}")
    endif()
  endif()
  _build_external()
endmacro()

#
# Set LOGFILES depending on the setting of EXTERNAL_VERBOSE. A 'true'
# value means the output to stdout and stderr goes to the terminal,
# while a 'false' value means we're send the output to log files.
#
macro(_verbose STAGE)
  if(EXTERNAL_VERBOSE)
    unset(LOGFILES)
  else()
    set(LOGFILES
      OUTPUT_FILE "${logs_dir}/${STAGE}-out.log"
      ERROR_FILE "${logs_dir}/${STAGE}-err.log"
    )
  endif()
endmacro()

#
# Configure, build, and install the external dependency.
#
macro(_build_external)
  file(MAKE_DIRECTORY "${logs_dir}")
  file(WRITE
    "${download_dir}/build.cmake.in"
    [[
message(STATUS "@NAME@: Configure")
_verbose(config)
if(EXTERNAL_CONFIG_COMMAND)
  file(MAKE_DIRECTORY "@build_dir@")
  list(TRANSFORM CONFIG_COMMAND REPLACE "<INSTALL_DIR>" "@install_dir@")
  execute_process(
    COMMAND ${CONFIG_COMMAND}
    WORKING_DIRECTORY "@build_dir@"
    ${LOGFILES}
  )
else()
  execute_process(
    COMMAND @CMAKE_COMMAND@
      -G "@CMAKE_GENERATOR@"@DEFS@
      -D CMAKE_BUILD_TYPE=Release
      -D CMAKE_INSTALL_PREFIX=@install_dir@
      -S @src_dir@
      -B @build_dir@
     ${LOGFILES})
endif()
message(STATUS "@NAME@: Build")
_verbose(build)
execute_process(
  COMMAND @BUILD_COMMAND@
  WORKING_DIRECTORY "@build_dir@"
  ${LOGFILES})
message(STATUS "@NAME@: Install")
_verbose(install)
execute_process(
  COMMAND @INSTALL_COMMAND@
  WORKING_DIRECTORY "@build_dir@"
  ${LOGFILES})
]])
  configure_file("${download_dir}/build.cmake.in"
    "${download_dir}/build.cmake" @ONLY)
  include("${download_dir}/build.cmake")
endmacro()

# Alternative using ExternalProject to download, configure, and build.
macro(_build_external2)
  # Generate the cmake configuration file, configure, and install the
  # external library to a location within the build hierarchy.
  file(
    WRITE "${download_dir}/CMakeLists.txt.in"
    [[
cmake_minimum_required(VERSION ${CMAKE_MINIMUM_REQUIRED_VERSION})

project(${NAME}.download NONE)

if(POLICY CMP0135)
  cmake_policy(SET CMP0135 NEW)
endif()

include(ExternalProject)

ExternalProject_Add(${NAME}.external
  URL ${EXTERNAL_URL}
  ${SHA256}
  ${NETRC}
  SOURCE_DIR ${src_dir}
  BINARY_DIR ${build_dir}
  INSTALL_DIR ${PROJECT_BINARY_DIR}/install
  CONFIGURE_COMMAND "${CMAKE_COMMAND}"
    -G "${CMAKE_GENERATOR}"${DEFS}
    -D CMAKE_BUILD_TYPE=Release
    -D CMAKE_INSTALL_PREFIX=<INSTALL_DIR>
    <SOURCE_DIR>
  BUILD_COMMAND ${BUILD_COMMAND}
  INSTALL_COMMAND ${INSTALL_COMMAND}
  TEST_COMMAND ""
  USES_TERMINAL_BUILD TRUE
  LOG_DOWNLOAD ${ENABLE_LOG}
  LOG_CONFIGURE ${ENABLE_LOG}
  LOG_BUILD ${ENABLE_LOG}
  LOG_INSTALL ${ENABLE_LOG}
  LOG_DIR ${CMAKE_CURRENT_BINARY_DIR}/logs
  DOWNLOAD_NO_PROGRESS TRUE
  )
]])

  if(EXTERNAL_VERBOSE)
    set(ENABLE_LOG)
  else()
    set(ENABLE_LOG "TRUE")
  endif()
  configure_file("${download_dir}/CMakeLists.txt.in"
                 "${download_dir}/CMakeLists.txt")

  execute_process(COMMAND "${CMAKE_COMMAND}" -G "${CMAKE_GENERATOR}" .
                  WORKING_DIRECTORY "${download_dir}")
  execute_process(COMMAND "${CMAKE_COMMAND}" --build .
                  WORKING_DIRECTORY "${download_dir}")
endmacro()

# Set some shorthand variables for the directories used.
macro(_set_directories)
  set(tmp_dir "${CMAKE_CURRENT_BINARY_DIR}/${NAME}/tmp")
  set(src_dir "${CMAKE_CURRENT_BINARY_DIR}/${NAME}/src")
  set(build_dir "${CMAKE_CURRENT_BINARY_DIR}/${NAME}/build")
  set(logs_dir "${CMAKE_CURRENT_BINARY_DIR}/${NAME}/logs")
  set(download_dir "${CMAKE_CURRENT_BINARY_DIR}/${NAME}/download")
  set(install_dir "${PROJECT_BINARY_DIR}/install")
endmacro()
