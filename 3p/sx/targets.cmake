# CMakeLists.txt for sx

cmake_minimum_required(VERSION 3.8)

find_package(Git REQUIRED)

set(cdir ${CMAKE_CURRENT_LIST_DIR})
include(${cdir}/../common.cmake)
set(sx_down ${3p_src}/sx)
set(sx_bindir ${3p_bin}/sx-${CMAKE_BUILD_TYPE}-${CSKEL_LIB_TYPE})

if (NOT EXISTS ${sx_down})
  execute_process(
    COMMAND
    ${GIT_EXECUTABLE} clone
    https://github.com/akalsi87/sx
    ${sx_down}
  )
endif()

if (NOT EXISTS ${sx_bindir})
  execute_process(
    COMMAND
    ${CMAKE_COMMAND}
      -H${sx_down}
      -B${sx_bindir}
      -DCMAKE_GENERATOR=${CMAKE_GENERATOR}
      -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
      -DSX_SHARED_LIB=${BUILD_SHARED_LIBS}
      -DCMAKE_C_STANDARD=99
      -DSX_BUILD_TESTS=0
      -DCMAKE_INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX}
  )

  execute_process(
    COMMAND
    ${CMAKE_COMMAND} --build ${sx_bindir} --target install)

  file(COPY ${sx_down}/LICENSE
       DESTINATION ${CMAKE_INSTALL_PREFIX}/share/sx)
  file(RENAME ${CMAKE_INSTALL_PREFIX}/share/sx/LICENSE
              ${CMAKE_INSTALL_PREFIX}/share/sx/LICENSE.sx)
endif()
