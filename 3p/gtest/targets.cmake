# CMakeLists.txt for gtest and gmock

cmake_minimum_required(VERSION 3.8)

find_package(Git REQUIRED)

set(cdir ${CMAKE_CURRENT_LIST_DIR})
include(${cdir}/../common.cmake)
set(gt_down ${3p_src}/gtest)
set(gt_inst ${3P_ROOT}/gtest)
set(gt_bindir ${3p_bin}/gtest-${CMAKE_BUILD_TYPE})

if (NOT EXISTS ${gt_down})
  execute_process(
    COMMAND
    ${GIT_EXECUTABLE} clone
    https://github.com/google/googletest
    ${gt_down}
  )
endif()

if (NOT EXISTS ${gt_bindir})
  execute_process(
    COMMAND
    ${CMAKE_COMMAND}
      -H${gt_down}
      -B${gt_bindir}
      -DCMAKE_GENERATOR=${CMAKE_GENERATOR}
      -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
      -DBUILD_SHARED_LIBS=0
      -DCMAKE_CXX_STANDARD=11
      -DBUILD_GMOCK=1
      -DCMAKE_INSTALL_PREFIX=${gt_inst}
      -Dgtest_force_shared_crt=1
  )

  if (MSVC)
    set(config_arg --config ${CMAKE_BUILD_TYPE})
  endif()

  execute_process(
    COMMAND
    ${CMAKE_COMMAND} --build ${gt_bindir} --target install ${config_arg})
endif()

# This is a private install and not exported
list(APPEND CMAKE_PREFIX_PATH ${gt_inst})
find_package(GTest CONFIG REQUIRED)
