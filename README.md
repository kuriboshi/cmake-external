# cmake-external

Simple CMake dependency manager. If you want a more comprehensive and
well supported dependency manager you might be better off with
something like [vcpkg](https://vcpkg.io) or [conan](conan.io).

## Usage

In you top level `CMakeLists.txt` file add the following two lines
after the call to `project`. The external projects will be installed
in the directory added to the `CMAKE_PREFIX_PATH`.

```
list(PREPEND CMAKE_PREFIX_PATH "${PROJECT_BINARY_DIR}/install")
add_subdirectory(external)
```

Create a directory called `external` (it can be called anything). In
this directory create a `CMakeLists.txt` file. At the beginning of the
file, put the following CMake commands to download the desired version
of cmake-external.cmake. Update the SHA256 hash to match the version
of the file. See the table at the end of this file.

The location of the download file can of course be adjusted to your
needs.

```
file(DOWNLOAD
  https://raw.githubusercontent.com/kuriboshi/cmake-external/v1.1.0/cmake-external.cmake
  ${CMAKE_CURRENT_BINARY_DIR}/cmake/cmake-external.cmake
  EXPECTED_HASH SHA256=3d616b2d2fc702e7caef237ef86777b6e679140d31e9f2037b4a45b3ce97b81e
set(CMAKE_MODULE_PATH ${CMAKE_CURRENT_BINARY_DIR}/cmake)
include(cmake-external)
```

### Function: `cmake_external`

After the code downloading the `cmake-external.cmake` file you can add
calls to `cmake_external` for the external libraries you depend on.
For example, let's say you need the `fmt` library.

```
cmake_external(fmt
  URL https://github.com/fmtlib/fmt/archive/9.1.0.tar.gz
  SHA256 5dea48d1fcddc3ec571ce2058e13910a0d4a6bab4cc09a809d8b1dd1c88ae6f2
  DEFINE FMT_DOC=OFF FMT_TEST=OFF
)
```

In this example we add version `9.1.0` of the `fmt` library from
_GitHub_.  In addition to the `URL` and the `SHA256` arguments two
defines which will be added to the CMake command line when configuring
`fmt`. In this case we want to minimize the build time so we turn off
documentation and tests.

The `cmake_external` command will do the following steps.

- Download the archive
- Check its SHA256 hash value
- Unpack the archive
- Configure the library with CMake
- Build it
- Install it in `${PROJECT_BINARY_DIR}/install`

If any of these steps fail the configuration will fail.

In order to use the libraries in your own project call `find_package`.

```
find_package(fmt REQUIRED)
```

It's possible to change the default configure, build, and install
commands in order to support libraries which do not use CMake to build
or have some peculiar requirements. This has only been tested with a
few libraries which use `configure` to configure and `make` to build
and install.

Since different libraries use different methods to configure and build
it's difficult to predict how well this will work for any particular
library.

In this repository there is an example of how to do this for
`libiconv`. The call to `cmake_external` looks like this.

```
cmake_external(libiconv
  URL https://ftp.gnu.org/gnu/libiconv/libiconv-1.17.tar.gz
  SHA256 8f74213b56238c85a50a5329f77e06198771e70dd9a739779f4c02f65d971313
  CONFIG_COMMAND ../src/configure --prefix <INSTALL_DIR>
  BUILD_COMMAND make all
  INSTALL_COMMAND make install
)
```

There are a few things to pay attention to. One is the use of
`<INSTALL_DIR>` to represent the real installation directory. Another
is that the source code can be accessed through the relative directory
`../src` and this is used to execute the `configure` script in this
case. The configuration, build, and install steps are all executed in
a directory separate from the source directory. In source builds are
not supported.

### Function: `cmake_external_find`

For cases where `find_package` cannot be used, libraries which don't
provide configuration files for use with CMake, can be handled using
the `cmake_external_find` command. It can search for header files
and/or libraries. If they are found the variable `${NAME}_FOUND`,
where NAME is the name given to the `cmake_external_find` command, is
set and an `INTERFACE` library is provided by the name NAME.

In the example of `libiconv` the following could be used to find the
library. The `INTERFACE` library `libiconv` can then later be used in
a call to `target_link_libraries` for any target requiring the
library.

```
cmake_external_find(libiconv INC iconv.h LIB iconv REQUIRED)
```

## Versions

Version | SHA256
--------|-------
`v1.0.1` | `eb85f6bfd601ad472160a1d9d2880ac57a96ce635132a4162c1a5a13d9ab9152`
`v1.1.0` | `3d616b2d2fc702e7caef237ef86777b6e679140d31e9f2037b4a45b3ce97b81e`
