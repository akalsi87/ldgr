# CMakeLists.txt for absl

cmake_minimum_required(VERSION 3.8)

find_package(Git REQUIRED)

set(cdir ${CMAKE_CURRENT_LIST_DIR})
include(${cdir}/../common.cmake)
set(absl_down ${3p_src}/absl)
set(absl_bindir ${3p_bin}/absl-${CMAKE_BUILD_TYPE}-${CSKEL_LIB_TYPE})

if (NOT EXISTS ${absl_down})
  execute_process(
    COMMAND
    ${GIT_EXECUTABLE} clone
    --branch master
    https://github.com/akalsi87/abseil-cpp
    ${absl_down}
  )
endif()

if (UNIX)
  if (BUILD_SHARED_LIBS)
    if(APPLE)
      set(RPATH_DEF -DCMAKE_INSTALL_NAME_DIR:STRING=${CMAKE_INSTALL_NAME_DIR})
    else()
      set(RPATH_DEF -DCMAKE_INSTALL_RPATH:STRING=${CMAKE_INSTALL_RPATH}
                    -DCMAKE_BUILD_WITH_INSTALL_RPATH:BOOL=ON)
    endif()
    set(RPATH_DEF ${RPATH_DEF} -DCMAKE_POSITION_INDEPENDENT_CODE=1)
  endif()
else()
  set(RPATH_DEF )
endif(UNIX)

# Disable shared library build of absl: not supported
set(shlib 0)

if (NOT EXISTS ${absl_bindir})
  execute_process(
    COMMAND
    ${CMAKE_COMMAND}
      -H${absl_down}
      -B${absl_bindir}
      -DCMAKE_GENERATOR=${CMAKE_GENERATOR}
      -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
      -DCMAKE_INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX}
      -DBUILD_SHARED_LIBS=${shlib}
      -DCMAKE_CXX_STANDARD=11
      -DCMAKE_C_STANDARD=99
      ${RPATH_DEF}
      -DABSL_ENABLE_INSTALL=1
      -DABSL_RUN_TESTS=0
      -DBUILD_TESTING=0
  )

  execute_process(
    COMMAND
    ${CMAKE_COMMAND} --build ${absl_bindir}
                     --target install
                     --config ${CMAKE_BUILD_TYPE})

  file(COPY ${absl_down}/LICENSE
       DESTINATION ${CMAKE_INSTALL_PREFIX}/share/absl)
  file(RENAME ${CMAKE_INSTALL_PREFIX}/share/absl/LICENSE
              ${CMAKE_INSTALL_PREFIX}/share/absl/LICENSE.absl)
endif()
