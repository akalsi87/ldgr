# CMakeLists.txt

cmake_minimum_required(VERSION 3.0)

include(cmake/utils.cmake)

set(CSKEL_FLAT_LAYOUT
    OFF
    CACHE BOOL "Flat layout vs directory per target"
  )

project(
  ${CSKEL_PROJ_NAME}
  VERSION 0.1.0
  LANGUAGES C CXX
  )

include(cmake/helpers.cmake)

#[[ Set the compiler standards ]]

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_C_STANDARD 99)

#[[ 3rd party dependencies ]]

#[[ fmt dependency ]]
cskel_install_3p(fmtlib)
cskel_find_pkg(fmt)


#[[ Add library: ldgr ]]

cskel_add_library(NAME ldgr VERSION 0.1.1)
target_link_libraries(ldgr PUBLIC fmt::fmt)
add_library(ldgr::ldgr ALIAS ldgr)

if (WIN32)
  target_compile_definitions(
    ldgr PRIVATE _CRT_SECURE_NO_WARNINGS _SCL_SECURE_NO_WARNINGS
                _WINSOCK_DEPRECATED_NO_WARNINGS
    )
endif ()

cskel_add_tests(NAME ldgr)

#[[ Setup install and license ]]

cskel_config_install_exports()

install(
  FILES ${PROJECT_SOURCE_DIR}/LICENSE.md
  DESTINATION share/${CSKEL_PROJ_NAME}
  RENAME LICENSE.${CSKEL_PROJ_NAME}
  )
