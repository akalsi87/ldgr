# CMakeLists.txt for type_safe

cmake_minimum_required(VERSION 3.0)

find_package(Git REQUIRED)

set(cdir ${CMAKE_CURRENT_LIST_DIR})
include(${cdir}/../common.cmake)
set(ts_down ${3p_src}/type_safe)
set(ts_bindir ${3p_bin}/type_safe)

if (NOT EXISTS ${ts_down})
  execute_process(
    COMMAND
    ${GIT_EXECUTABLE} clone
    --recurse-submodules
    https://github.com/foonathan/type_safe
    ${ts_down}/int
  )
endif()

if (NOT EXISTS ${ts_bindir})
  file(WRITE ${ts_down}/CMakeLists.txt "
    cmake_minimum_required(VERSION 3.0)
    add_subdirectory(int)
    ")
  execute_process(
    COMMAND
    ${CMAKE_COMMAND}
      -H${ts_down}/int/external/debug_assert
      -B${ts_bindir}/debug_assert
      -DCMAKE_GENERATOR=${CMAKE_GENERATOR}
      -DCMAKE_BUILD_TYPE=RelWithDebInfo
      -DBUILD_SHARED_LIBS=0
      -DCMAKE_CXX_STANDARD=11
      -DCMAKE_INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX}
  )
  execute_process(
    COMMAND
    ${CMAKE_COMMAND} --build ${ts_bindir}/debug_assert --target install)
  execute_process(
    COMMAND
    ${CMAKE_COMMAND}
      -H${ts_down}
      -B${ts_bindir}
      -DCMAKE_GENERATOR=${CMAKE_GENERATOR}
      -DCMAKE_BUILD_TYPE=RelWithDebInfo
      -DBUILD_SHARED_LIBS=0
      -DCMAKE_CXX_STANDARD=11
      -DCMAKE_INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX}
      -DCMAKE_PREFIX_PATH=${CMAKE_INSTALL_PREFIX}
      -DTYPE_SAFE_BUILD_TEST_EXAMPLE=0
      -DTYPE_SAFE_HAS_IMPORTED_TARGETS:BOOL=ON
  )
  execute_process(
    COMMAND
    ${CMAKE_COMMAND} --build ${ts_bindir} --target install)
endif()
