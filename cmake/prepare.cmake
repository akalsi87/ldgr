# prepare.cmake

include(${CMAKE_CURRENT_LIST_DIR}/utils.cmake)

cskel_include_guard(INCLUDED_CSKEL_CMAKE_PREPARE)

# set BIG_ENDIAN to true if big endian else set it to false.
cskel_try_compile_run(
  _endian_test_rc
  BIG_ENDIAN
  "
  #include <stdio.h>
  int main(int argc, const char* argv[])
  {
      short x = 1\;
      unsigned char* b = &x\;
      printf(\"%d\", b[1])\;
      return 0\;
  }"
  c)
if (NOT ${_endian_test_rc} STREQUAL 0)
  cskel_error("Failed to run endianness test program: rc=${_endian_test_rc}")
endif()

# set WORD_SIZE to the size of a pointer (e.g. 32/64).
cskel_try_compile_run(
  _word_size_rc
  WORD_SIZE
  "
  #include <stdio.h>
  int main(int argc, const char* argv[])
  {
      printf(\"%d\", sizeof(void*) * 8)\;
      return 0\;
  }"
  c)

if (NOT ${_word_size_rc} STREQUAL 0)
  cskel_error("Failed to run word-size test program: rc=${_word_size_rc}")
endif()

if (NOT DEFINED BUILD_SHARED_LIBS)
  set(BUILD_SHARED_LIBS OFF)
endif()

if ("${CMAKE_BUILD_TYPE}" STREQUAL "")
  set(CMAKE_BUILD_TYPE Debug)
endif()

if (NOT DEFINED BUILD_TESTING)
  set(BUILD_TESTING ON)
endif()

if (WIN32)
  set(homedir $ENV{USERPROFILE})
  get_filename_component(homedir "${homedir}" ABSOLUTE)
else()
  set(homedir $ENV{HOME})
endif()

if (NOT 3P_ROOT)
  set(3P_ROOT ${homedir}/.cskel)
endif()

set(3p_src ${3P_ROOT}/src)
set(3p_bin ${3P_ROOT}/build)
set(3p_inst ${3P_ROOT}/root)

if (BUILD_SHARED_LIBS)
  set(CSKEL_LIB_TYPE shared)
else()
  set(CSKEL_LIB_TYPE static)
endif()

find_package(Doxygen)

set(_build_quad "${CMAKE_SYSTEM_NAME}_${CMAKE_BUILD_TYPE}_${CSKEL_LIB_TYPE}_${WORD_SIZE}")
string(TOLOWER "${_build_quad}" CSKEL_BUILD_QUAD)

cskel_info("")
cskel_info("${CSKEL_PROJ_NAME}")
cskel_info("")
cskel_info("Root............: ${CSKEL_PROJ_ROOT}")
cskel_info("Operating system: ${CMAKE_SYSTEM_NAME}")
cskel_info("Is Big Endian...: ${BIG_ENDIAN}")
cskel_info("Word size.......: ${WORD_SIZE}")
cskel_info("C Compiler......: ${CMAKE_C_COMPILER}")
cskel_info("C++ Compiler....: ${CMAKE_CXX_COMPILER}")
cskel_info("Build type......: ${CMAKE_BUILD_TYPE}")
cskel_info("Shared libraries: ${BUILD_SHARED_LIBS}")
cskel_info("Testing.........: ${BUILD_TESTING}")
cskel_info("Install folder..: ${CMAKE_INSTALL_PREFIX}")
cskel_info("Build quad......: ${CSKEL_BUILD_QUAD}")
cskel_info("3p root.........: ${3P_ROOT}")
cskel_info("")
