#
# Copyright 2023 Krister Joas
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

cmake_minimum_required(VERSION 3.21.0)

project(cmake-external VERSION 1.1.0)
set(CMAKE_CXX_STANDARD 20)
enable_testing()

list(PREPEND CMAKE_PREFIX_PATH "${PROJECT_BINARY_DIR}/install")
add_subdirectory(external)

find_package(Catch2 REQUIRED)
find_package(fmt REQUIRED)
find_package(Boost 1.82.0
  COMPONENTS date_time timer chrono system thread filesystem
             log serialization locale program_options iostreams
  REQUIRED)

cmake_external_find(libiconv INC iconv.h LIB iconv REQUIRED)

macro(module_found NAME)
  if(${NAME}_FOUND)
    message(STATUS "${NAME} found")
  else()
    message(STATUS "${NAME} NOT found")
  endif()
endmacro()

module_found(Catch2)
module_found(fmt)
module_found(Boost)
module_found(libiconv)

add_subdirectory(src)
