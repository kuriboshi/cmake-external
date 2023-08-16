#
# Copyright 2020-2023 Krister Joas
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

file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/cmake)
file(COPY_FILE
  ${CMAKE_CURRENT_SOURCE_DIR}/../cmake-external.cmake
  ${CMAKE_CURRENT_BINARY_DIR}/cmake/cmake-external.cmake
)
set(CMAKE_MODULE_PATH ${CMAKE_CURRENT_BINARY_DIR}/cmake)

include(cmake-external)

cmake_external(catch2
  URL https://github.com/catchorg/Catch2/archive/v3.3.2.tar.gz
  SHA256 8361907f4d9bff3ae7c1edb027f813659f793053c99b67837a0c0375f065bae2
)

cmake_external(fmt
  URL https://github.com/fmtlib/fmt/archive/9.1.0.tar.gz
  SHA256 5dea48d1fcddc3ec571ce2058e13910a0d4a6bab4cc09a809d8b1dd1c88ae6f2
  DEFINE FMT_DOC=OFF FMT_TEST=OFF
)

cmake_external(boost
  URL https://github.com/boostorg/boost/releases/download/boost-1.82.0/boost-1.82.0.tar.gz
  SHA256 b62bd839ea6c28265af9a1f68393eda37fab3611425d3b28882d8e424535ec9d
)

cmake_external(libiconv
  URL https://ftp.gnu.org/gnu/libiconv/libiconv-1.17.tar.gz
  SHA256 8f74213b56238c85a50a5329f77e06198771e70dd9a739779f4c02f65d971313
  CONFIG_COMMAND ../src/configure --prefix <INSTALL_DIR>
  BUILD_COMMAND make all
  INSTALL_COMMAND make install
)
