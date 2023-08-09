cmake_minimum_required(VERSION 3.21.0)

project(cmake-external VERSION 1.1.0)

set(CMAKE_CXX_STANDARD 20)

list(PREPEND CMAKE_PREFIX_PATH "${PROJECT_BINARY_DIR}/install")
add_subdirectory(external)

find_package(Boost
  COMPONENTS date_time timer chrono system thread filesystem
             log serialization locale program_options iostreams
  REQUIRED)
find_package(fmt REQUIRED)
find_package(Catch2 REQUIRED)
