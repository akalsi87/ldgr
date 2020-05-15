# CMakeLists.txt for mbedtls

cmake_minimum_required(VERSION 3.8)

find_package(Git REQUIRED)

include(${CMAKE_CURRENT_LIST_DIR}/../zlib/targets.cmake)

set(cdir ${CMAKE_CURRENT_LIST_DIR})
include(${cdir}/../common.cmake)
set(mbedtls_down ${3p_src}/mbedtls)
set(mbedtls_bindir ${3p_bin}/mbedtls-${CMAKE_BUILD_TYPE}-${CSKEL_LIB_TYPE})

if (NOT EXISTS ${mbedtls_down})
  execute_process(
    COMMAND
    ${GIT_EXECUTABLE} clone
    --branch master
    https://github.com/akalsi87/mbedtls
    ${mbedtls_down}
  )
  execute_process(
    COMMAND
    ${GIT_EXECUTABLE} submodule init
    WORKING_DIRECTORY
    ${mbedtls_down}
  )
  execute_process(
    COMMAND
    ${GIT_EXECUTABLE} submodule update
    WORKING_DIRECTORY
    ${mbedtls_down}
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

if (NOT WIN32)
  if (BUILD_SHARED_LIBS)
    set(shlib -DUSE_SHARED_MBEDTLS_LIBRARY=1 -DUSE_STATIC_MBEDTLS_LIBRARY=0)
  else()
    set(shlib -DUSE_SHARED_MBEDTLS_LIBRARY=0 -DUSE_STATIC_MBEDTLS_LIBRARY=1)
  endif()
else()
  set(shlib -DUSE_SHARED_MBEDTLS_LIBRARY=0 -DUSE_STATIC_MBEDTLS_LIBRARY=1)
endif()

if (NOT EXISTS ${mbedtls_bindir})
  execute_process(
    COMMAND
    ${CMAKE_COMMAND}
      -H${mbedtls_down}
      -B${mbedtls_bindir}
      -DCMAKE_GENERATOR=${CMAKE_GENERATOR}
      -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
      -DCMAKE_INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX}
      -DENABLE_TESTING=0
      -DCMAKE_CXX_STANDARD=11
      -DCMAKE_C_STANDARD=99
      -DENABLE_PROGRAMS=0
      ${RPATH_DEF}
      ${shlib}
      -DENABLE_ZLIB_SUPPORT=1
      -DZLIB_ROOT=${CMAKE_INSTALL_PREFIX}
  )

  execute_process(
    COMMAND
    ${CMAKE_COMMAND} --build ${mbedtls_bindir}
                     --target install
                     --config ${CMAKE_BUILD_TYPE})

  file(COPY ${mbedtls_down}/LICENSE
       DESTINATION ${CMAKE_INSTALL_PREFIX}/share/mbedtls)
  file(COPY ${mbedtls_down}/apache-2.0.txt
       DESTINATION ${CMAKE_INSTALL_PREFIX}/share/mbedtls)
  file(RENAME ${CMAKE_INSTALL_PREFIX}/share/mbedtls/LICENSE
              ${CMAKE_INSTALL_PREFIX}/share/mbedtls/LICENSE.mbedtls)
  file(RENAME ${CMAKE_INSTALL_PREFIX}/share/mbedtls/apache-2.0.txt
              ${CMAKE_INSTALL_PREFIX}/share/mbedtls/LICENSE.mbedtls.apache-2)
endif()
