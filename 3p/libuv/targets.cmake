# CMakeLists.txt for libuv

cmake_minimum_required(VERSION 3.0)

find_package(Git REQUIRED)

set(cdir ${CMAKE_CURRENT_LIST_DIR})
include(${cdir}/../common.cmake)
set(uv_down ${3p_src}/libuv)
set(uv_bindir ${3p_bin}/libuv-${CMAKE_BUILD_TYPE})

if (NOT EXISTS ${uv_down})
  execute_process(
    COMMAND
    ${GIT_EXECUTABLE} clone
    --branch v1.x-cmake
    https://github.com/akalsi87/libuv
    ${uv_down}
  )
endif()

if (NOT EXISTS ${uv_bindir})
  execute_process(
    COMMAND
    ${CMAKE_COMMAND}
      -H${uv_down}
      -B${uv_bindir}
      -DLIBUV_BUILD_TESTS=0
      -DLIBUV_EXPORT_CMAKE=1
      -DLIBUV_NO_GNUINSTALLDIRS=1
      -DCMAKE_GENERATOR=${CMAKE_GENERATOR}
      -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
      -DCMAKE_INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX}
  )

  execute_process(
    COMMAND
    ${CMAKE_COMMAND} --build ${uv_bindir}
                     --target install
                     --config ${CMAKE_BUILD_TYPE})
endif()
