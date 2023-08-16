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

  _unset_cc_cxx()

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
    unset(SHA256)
  endif()

  # Check if we need to use the .netrc file for private repos.
  if(EXTERNAL_NETRC)
    set(NETRC "NETRC REQUIRED")
  else()
    unset(NETRC)
  endif()

  #
  # Build the list of cmake definitions passed on to the configuration
  # of the external library. Anything specified in the DEFINE option
  # is included as well as some predefined definitions passed on from
  # the parent project.
  #
  unset(DEFS)                   # List of definitions
  # Add user specified definitions.
  foreach(D ${EXTERNAL_DEFINE})
    list(APPEND DEFS "-D" "${D}")
  endforeach()
  # Add list of definitions propagated from the parent project.
  foreach(I CMAKE_OSX_DEPLOYMENT_TARGET BUILD_SHARED_LIBS)
    if(${I})
      list(APPEND DEFS "-D" "${I}=${${I}}")
    endif()
  endforeach()

  #
  # Set some location variables.
  #
  _set_directories()

  # Replace <INSTALL_DIR> with the absolute path to the install
  # directory.
  if(EXTERNAL_CONFIG_COMMAND)
    list(TRANSFORM EXTERNAL_CONFIG_COMMAND REPLACE "<INSTALL_DIR>" "${install_dir}")
    set(CONFIG_COMMAND ${EXTERNAL_CONFIG_COMMAND})
  else()
    set(CONFIG_COMMAND "${CMAKE_COMMAND}" -G "${CMAKE_GENERATOR}"
      ${DEFS}
      -D "CMAKE_BUILD_TYPE=Release"
      -D "CMAKE_INSTALL_PREFIX=${install_dir}"
      "${src_dir}")
  endif()

  # Process custom build and install commands.
  if(EXTERNAL_BUILD_COMMAND)
    set(BUILD_COMMAND ${EXTERNAL_BUILD_COMMAND})
  else()
    set(BUILD_COMMAND "${CMAKE_COMMAND}" --build . --config Release)
  endif()

  if(EXTERNAL_INSTALL_COMMAND)
    set(INSTALL_COMMAND ${EXTERNAL_INSTALL_COMMAND})
  else()
    set(INSTALL_COMMAND "${CMAKE_COMMAND}" --install . --config Release)
  endif()

  list(APPEND CMAKE_MESSAGE_INDENT "  ")

  _download_external()
endfunction()

#
# cmake_external_find(name [INC header.h] [LIB library name] [REQUIRED])
#
# Searches for a specific header file and/or a library. If they are
# found then a library library by the name 'name' is created. This
# library can then be used as a dependency.
#
function(cmake_external_find NAME)
  set(options REQUIRED)
  set(single_value_args INC LIB)
  set(multi_value_args)
  cmake_parse_arguments(FIND
    "${options}" "${single_value_args}" "${multi_value_args}" ${ARGN})

  set(${NAME}_FOUND TRUE PARENT_SCOPE)
  # If the variable is set in PARENT_SCOPE it doesn't also set it in
  # local scope.
  set(${NAME}_FOUND TRUE)
  add_library(${NAME} INTERFACE)
  if(FIND_INC)
    find_path(INCLUDE_DIR ${FIND_INC} PATHS "${PROJECT_BINARY_DIR}/install/include" NO_DEFAULT_PATH)
    if(INCLUDE_DIR STREQUAL "INCLUDE_DIR-NOTFOUND")
      unset(${NAME}_FOUND PARENT_SCOPE)
      unset(${NAME}_FOUND)
    else()
      target_include_directories(${NAME} INTERFACE "${INCLUDE_DIR}")
    endif()
  endif()
  if(FIND_LIB)
    find_library(LIBRARY_PATH ${FIND_LIB} PATHS "${PROJECT_BINARY_DIR}/install/lib" NO_DEFAULT_PATH)
    if(LIBRARY_PATH STREQUAL "LIBRARY_PATH-NOTFOUND")
      unset(${NAME}_FOUND PARENT_SCOPE)
      unset(${NAME}_FOUND)
    else()
      target_link_libraries(${NAME} INTERFACE "${LIBRARY_PATH}")
    endif()
  endif()
  if(FIND_REQUIRED)
    if(NOT ${NAME}_FOUND)
      message(FATAL_ERROR "${NAME}: Not found")
    endif()
  else()
    if(NOT ${NAME}_FOUND)
      message(WARNING "${NAME}: Library not found")
    endif()
  endif()
endfunction()

function(_unset_cc_cxx)
  #
  # The 'project' command contaminates the environment the first time
  # it detects the compilers. The second time it gets the compilers
  # from the cache and does not set the corresponding environment
  # variables. This changed in 3.24 and later via the policy CMP0132
  # which, when set to NEW will not set the environment variables.
  #
  if(POLICY CMP0132)
    cmake_policy(GET CMP0132 _cmp0132)
    if(NOT _cmp0132 EQUAL "NEW")
      unset(ENV{CC})
      unset(ENV{CXX})
    endif()
  else()
    unset(ENV{CC})
    unset(ENV{CXX})
  endif()
endfunction()

#
# Download the file for NAME from EXTERNAL_URL. The expected hash is
# in EXTERNAL_SHA256.
#
macro(_download_external)
  #
  # Get the filename of the URL which will be part of the complete
  # name of the downloaded archive.
  #
  cmake_path(GET EXTERNAL_URL FILENAME _file)
  message(STATUS "${NAME}: Download ${_file}")
  set(_filename "${CMAKE_CURRENT_BINARY_DIR}/${NAME}/${_file}")
  if(NOT EXISTS "${_filename}")
    file(DOWNLOAD ${EXTERNAL_URL} "${_filename}" ${NETRC})
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
  endif()

  #
  # The 'TOUCH' parameter was added in CMake 3.24. This has the effect
  # that files extracted from an archive will have the current date
  # instead of the date in the archive.
  #
  unset(TOUCH)
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
      # Rename the top level directory to 'src' and remove the
      # temporary directory.
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
  file(MAKE_DIRECTORY "${build_dir}")

  message(STATUS "${NAME}: Configure")
  _verbose(config)
  if("${_filename}" IS_NEWER_THAN "${top_dir}/config.stamp")
    execute_process(
      COMMAND ${CONFIG_COMMAND}
      WORKING_DIRECTORY "${build_dir}"
      RESULT_VARIABLE _result
      ${LOGFILES}
    )
    if(_result EQUAL 0)
      file(TOUCH "${top_dir}/config.stamp")
      set(_config_done TRUE)
    else()
      message(WARNING "${NAME}: Configuration failed")
    endif()
  endif()

  if(EXISTS "${top_dir}/config.stamp")
    message(STATUS "${NAME}: Build")
    _verbose(build)
    if("${top_dir}/config.stamp" IS_NEWER_THAN "${top_dir}/build.stamp")
      execute_process(
        COMMAND ${BUILD_COMMAND}
        WORKING_DIRECTORY "${build_dir}"
        RESULT_VARIABLE _result
        ${LOGFILES}
      )
      if(_result EQUAL 0)
        file(TOUCH "${top_dir}/build.stamp")
      else()
        message(WARNING "${NAME}: Build failed")
      endif()
    endif()
  endif()

  if(EXISTS "${top_dir}/build.stamp")
    message(STATUS "${NAME}: Install")
    _verbose(install)
    if("${top_dir}/build.stamp" IS_NEWER_THAN "${top_dir}/install.stamp")
      execute_process(
        COMMAND ${INSTALL_COMMAND}
        WORKING_DIRECTORY "${build_dir}"
        RESULT_VARIABLE _result
        ${LOGFILES}
      )
      if(_result EQUAL 0)
        file(TOUCH "${top_dir}/install.stamp")
      endif()
    endif()
  endif()

  if(NOT EXISTS "${top_dir}/install.stamp")
    message(FATAL_ERROR "${NAME}: Installation failed")
  endif()
endmacro()

# Set some shorthand variables for the directories used.
macro(_set_directories)
  set(top_dir "${CMAKE_CURRENT_BINARY_DIR}/${NAME}")
  set(tmp_dir "${top_dir}/tmp")
  set(src_dir "${top_dir}/src")
  set(build_dir "${top_dir}/build")
  set(logs_dir "${top_dir}/logs")
  set(download_dir "${top_dir}/download")
  set(install_dir "${PROJECT_BINARY_DIR}/install")
endmacro()
