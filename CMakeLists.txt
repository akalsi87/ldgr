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

#[[ Boost dependency ]]
# cskel_install_3p(boost)
# set(Boost_DEBUG 1)
# set(Boost_VERBOSE 1)
# if (NOT BUILD_SHARED_LIBS)
#   set(Boost_USE_STATIC_LIBS 1)
# endif ()
# if (POLICY CMP0074)
#   cmake_policy(SET CMP0074 NEW)
# endif ()
# set(ENV{Boost_DIR} ${CMAKE_INSTALL_PREFIX})
# set(ENV{BOOSTROOT} ${CMAKE_INSTALL_PREFIX})
# set(ENV{BOOST_ROOT} ${CMAKE_INSTALL_PREFIX})
# cskel_find_pkg(
#   Boost
#   1.72
#   CONFIG
#   REQUIRED
#   COMPONENTS
#   chrono
#   thread
#   filesystem
#   iostreams
#   system
#   )

#[[ Add library: pkg ]]

cskel_add_library(NAME pkg VERSION 0.1.1)
target_link_libraries(pkg PUBLIC)

if (WIN32)
  target_compile_definitions(
    pkg PRIVATE _CRT_SECURE_NO_WARNINGS _SCL_SECURE_NO_WARNINGS
                _WINSOCK_DEPRECATED_NO_WARNINGS
    )
endif ()

cskel_add_tests(NAME pkg)

#[[ Setup install and license ]]

cskel_config_install_exports()

install(
  FILES ${PROJECT_SOURCE_DIR}/LICENSE.md
  DESTINATION share/${CSKEL_PROJ_NAME}
  RENAME LICENSE.${CSKEL_PROJ_NAME}
  )
