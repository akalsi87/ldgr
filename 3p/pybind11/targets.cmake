# CMakeLists.txt for pybind11

cmake_minimum_required(VERSION 3.0)

find_package(Git REQUIRED)

set(cdir ${CMAKE_CURRENT_LIST_DIR})
include(${cdir}/../common.cmake)
set(pybind11_down ${3p_src}/pybind11)
set(pybind11_bindir ${3p_bin}/pybind11-${CMAKE_BUILD_TYPE})

if (NOT EXISTS ${pybind11_down})
  execute_process(
    COMMAND
    ${GIT_EXECUTABLE} clone
    https://github.com/pybind/pybind11
    ${pybind11_down}
  )
endif()

if (NOT EXISTS ${pybind11_bindir})
  execute_process(
    COMMAND
    ${CMAKE_COMMAND}
      -H${pybind11_down}
      -B${pybind11_bindir}
      -DPYBIND11_TEST=0
      -DPYBIND11_INSTALL=1
      -DCMAKE_GENERATOR=${CMAKE_GENERATOR}
      -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
      -DCMAKE_INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX}
  )

  if (MSVC)
    set(config_arg --config ${CMAKE_BUILD_TYPE})
  endif()

  execute_process(
    COMMAND
    ${CMAKE_COMMAND} --build ${pybind11_bindir} --target install ${config_arg})
endif()
