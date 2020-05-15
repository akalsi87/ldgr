# CMakeLists.txt for zlib

cmake_minimum_required(VERSION 3.8)

find_package(Git REQUIRED)

set(cdir ${CMAKE_CURRENT_LIST_DIR})
include(${cdir}/../common.cmake)
set(zlib_down ${3p_src}/zlib)
set(zlib_bindir ${3p_bin}/zlib-${CMAKE_BUILD_TYPE}-${CSKEL_LIB_TYPE})

if (NOT EXISTS ${zlib_down})
  execute_process(
    COMMAND
    ${GIT_EXECUTABLE} clone
    --branch master
    https://github.com/madler/zlib
    ${zlib_down}
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

if (NOT EXISTS ${zlib_bindir})
  execute_process(
    COMMAND
    ${CMAKE_COMMAND}
      -H${zlib_down}
      -B${zlib_bindir}
      -DCMAKE_GENERATOR=${CMAKE_GENERATOR}
      -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
      -DCMAKE_INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX}
      -DBUILD_SHARED_LIBS=${BUILD_SHARED_LIBS}
      -DCMAKE_CXX_STANDARD=11
      -DCMAKE_C_STANDARD=99
      ${RPATH_DEF}
  )

  execute_process(
    COMMAND
    ${CMAKE_COMMAND} --build ${zlib_bindir}
                     --target install
                     --config ${CMAKE_BUILD_TYPE})

  file(COPY ${zlib_down}/README
       DESTINATION ${CMAKE_INSTALL_PREFIX}/share/zlib)
  file(RENAME ${CMAKE_INSTALL_PREFIX}/share/zlib/README
              ${CMAKE_INSTALL_PREFIX}/share/zlib/LICENSE.zlib)
endif()
