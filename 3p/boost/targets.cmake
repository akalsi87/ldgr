# CMakeLists.txt for boost

cmake_minimum_required(VERSION 3.0)

find_package(Git REQUIRED)

## TWEAK PARAMS HERE
set(version 1.72.0)
set(mods chrono filesystem system thread iostreams)
## TWEAK PARAMS HERE

set(bbranch boost-${version})
string(REPLACE "-" "_" fname ${bbranch})
string(REPLACE "." "_" fname ${fname})

set(cdir ${CMAKE_CURRENT_LIST_DIR})
include(${cdir}/../common.cmake)
set(boost_down ${3p_src}/boost)
set(boost_bindir ${3p_bin}/boost-${CMAKE_BUILD_TYPE}-${CSKEL_LIB_TYPE})

if (${CMAKE_SIZEOF_VOID_P} EQUAL 8 AND WIN32 AND MSVC)
  if (${CMAKE_GENERATOR} MATCHES "64")
    set(bitness address-model=64)
  else()
    set(bitness address-model=32)
  endif()
else()
  set(bitness )
endif()

set(withmods)
set(knownwiths
  chrono
  context
  filesystem
  graph_parallel
  iostreams
  locale
  mpi
  program_options
  python
  regex
  serialization
  signals
  system
  thread
  timer
  wave)
foreach(mod ${mods})
  list(FIND knownwiths ${mod} f)
  if (${f} GREATER -1)
    set(withmods ${withmods} ${mod})
  endif()
endforeach()

if (WIN32)
  set(b2 b2.exe)
  set(bstrap ${boost_down}/bootstrap.bat)
else()
  set(b2 ./b2)
  set(bstrap ${boost_down}/bootstrap.sh)
endif()

message("Downloading ${bbranch}...")
if (NOT EXISTS ${boost_down})
  file(DOWNLOAD
    https://dl.bintray.com/boostorg/release/${version}/source/${fname}.tar.gz
    ${boost_down}/../${bbranch}.tar.gz)
  execute_process(
    COMMAND
    ${CMAKE_COMMAND} -E tar xfz ${bbranch}.tar.gz
    WORKING_DIRECTORY ${boost_down}/..)

  get_filename_component(parent ${boost_down} DIRECTORY)
  file(RENAME ${parent}/${fname} ${boost_down})

  execute_process(
    COMMAND
    ${CMAKE_COMMAND} -E remove ${boost_down}/../${bbranch}.tar.gz)
endif()

# toolset detection
if (NOT WIN32)
  if ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "Clang")
    set(toolset clang)
  elseif ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU")
    set(toolset gcc)
  endif()
else()
  if ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU" OR
      "${CMAKE_CXX_COMPILER_ID}" MATCHES "MinGW")
    set(toolset gcc)
  elseif ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "MSVC")
    set(toolset msvc)
    string(LENGTH "${MSVC_TOOLSET_VERSION}" l)
    math(EXPR l "${l} - 1")
    string(SUBSTRING "${MSVC_TOOLSET_VERSION}" 0 ${l} tver)
    string(SUBSTRING "${MSVC_TOOLSET_VERSION}" ${l} -1 tver_p)
    set(toolset ${toolset}-${tver}.${tver_p})
  endif()
endif()

if (NOT EXISTS ${boost_bindir})
  message("-- Building boost ${bitness} ${toolset}")
  execute_process(
    COMMAND
    ${bstrap} --with-toolset=${toolset}
    WORKING_DIRECTORY ${boost_down}
    RESULT_VARIABLE rc
  )
  if (NOT ${rc} EQUAL 0)
    message(FATAL_ERROR "b2 headers failed...")
  endif()

  if ("${CMAKE_BUILD_TYPE}" STREQUAL Debug)
    set(var debug)
  else()
    set(var release)
  endif()

  if (BUILD_SHARED_LIBS)
    set(ln shared)
    if (APPLE)
      set(rpath linkflags=-Wl,-rpath,@executable_path/../lib)
    elseif(NOT WIN32)
      set(rpath linkflags='-Wl,-rpath,$ORIGIN/../lib'
                linkflags='-Wl,-rpath,$ORIGIN')
    else()
      set(rpath )
    endif()
  else()
    set(ln static)
    set(rpath )
  endif()

  foreach(mod ${withmods})
    set(withs ${withs} --with-${mod})
  endforeach(mod)

  message("target: b2 headers")
  execute_process(
    COMMAND
    ${b2} headers
    WORKING_DIRECTORY ${boost_down}
    RESULT_VARIABLE rc
  )
  if (NOT ${rc} EQUAL 0)
    message(FATAL_ERROR "b2 headers failed...")
  endif()

  message("target: b2 stage")
  execute_process(
    COMMAND
    ${b2} --build-dir=${boost_bindir}
          -j 4
          -q
          -d+2
          ${withs}
          variant=${var}
          link=${ln}
          threading=multi
          visibility=hidden
          runtime-link=shared
          ${bitness}
          ${rpath}
          stage
    WORKING_DIRECTORY ${boost_down}
    RESULT_VARIABLE rc
  )
  if (NOT ${rc} EQUAL 0)
    message(FATAL_ERROR "boost build failed...")
  endif()

  message("target: b2 install")
  execute_process(
    COMMAND
    ${b2} --prefix=${CMAKE_INSTALL_PREFIX}
          --build-dir=${boost_bindir}
          -j 4
          -q
          -d+2
          ${withs}
          variant=${var}
          link=${ln}
          threading=multi
          visibility=hidden
          runtime-link=shared
          ${bitness}
          ${rpath}
          install
    WORKING_DIRECTORY ${boost_down}
    RESULT_VARIABLE rc
  )
  if (NOT ${rc} EQUAL 0)
    message(FATAL_ERROR "boost install failed...")
  endif()

  # install LICENSE
  file(COPY ${boost_down}/LICENSE_1_0.txt
       DESTINATION ${CMAKE_INSTALL_PREFIX}/share/boost)
  file(RENAME ${CMAKE_INSTALL_PREFIX}/share/boost/LICENSE_1_0.txt
              ${CMAKE_INSTALL_PREFIX}/share/boost/LICENSE.boost)

  # On Windows, move DLLs to bin/ instead of lib/
  if (WIN32 AND BUILD_SHARED_LIBS)
    file(MAKE_DIRECTORY ${CMAKE_INSTALL_PREFIX}/bin)
    file(GLOB dlls "${CMAKE_INSTALL_PREFIX}/lib/*.dll")
    foreach(dll ${dlls})
      get_filename_component(name ${dll} NAME)
      file(RENAME ${dll} ${CMAKE_INSTALL_PREFIX}/bin/${name})
    endforeach()
  endif()
endif()

# set(Boost_DEBUG 1)
# set(Boost_VERBOSE 1)
# if (NOT BUILD_SHARED_LIBS)
#   set(Boost_USE_STATIC_LIBS 1)
# endif()
# cm_find_pkg(
#   Boost 1.71 CONFIG REQUIRED
#   COMPONENTS thread filesystem iostreams system)
