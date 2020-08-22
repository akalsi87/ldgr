# CMakeLists.txt for fmtlib

cmake_minimum_required(VERSION 3.0)

find_package(Git REQUIRED)

set(cdir ${CMAKE_CURRENT_LIST_DIR})
include(${cdir}/../common.cmake)
set(fmtlib_down ${3p_src}/fmtlib)
set(fmtlib_bindir ${3p_bin}/fmtlib-${CMAKE_BUILD_TYPE})

if (NOT EXISTS ${fmtlib_down})
  execute_process(
    COMMAND
    ${GIT_EXECUTABLE} clone
    https://github.com/fmtlib/fmt
    ${fmtlib_down}
  )
endif()

if (UNIX)
  if(APPLE)
    set(RPATH_DEF -DCMAKE_INSTALL_NAME_DIR:STRING=${CMAKE_INSTALL_NAME_DIR})
  else()
    set(RPATH_DEF -DCMAKE_INSTALL_RPATH:STRING=${CMAKE_INSTALL_RPATH} -DCMAKE_BUILD_WITH_INSTALL_RPATH:BOOL=ON)
  endif()
else()
  set(RPATH_DEF )
endif(UNIX)

if (NOT EXISTS ${fmtlib_bindir})
  execute_process(
    COMMAND
    ${CMAKE_COMMAND}
      -H${fmtlib_down}
      -B${fmtlib_bindir}
      ${RPATH_DEF}
      -DFMT_TEST=OFF
      -DFMT_INSTALL=ON
      -DFMT_OS=ON
      -DCMAKE_GENERATOR=${CMAKE_GENERATOR}
      -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
      -DCMAKE_INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX}
      -UCMAKE_INSTALL_LIBDIR
      -DCMAKE_INSTALL_LIBDIR=lib
  )

  if (MSVC)
    set(config_arg --config ${CMAKE_BUILD_TYPE})
  endif()

  execute_process(
    COMMAND
    ${CMAKE_COMMAND} --build ${fmtlib_bindir} --target install ${config_arg})
endif()
