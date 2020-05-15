# helpers.cmake

include(${CMAKE_CURRENT_LIST_DIR}/utils.cmake)

cskel_include_guard(INCLUDED_CSKEL_CMAKE_HELPERS)

include(${CMAKE_CURRENT_LIST_DIR}/prepare.cmake)

if (NOT DEFINED CSKEL_FLAT_LAYOUT)
  set(CSKEL_FLAT_LAYOUT OFF)
endif()

if (NOT CSKEL_FLAT_LAYOUT)
  set(CSKEL_LAYOUT_STYLE subdir CACHE STRING "")
  set(_cskel_sep "/" CACHE BOOL "")
else()
  set(CSKEL_LAYOUT_STYLE flat CACHE STRING "")
  set(_cskel_sep "_" CACHE BOOL "")
endif()

cskel_info("Layout style....: ${CSKEL_LAYOUT_STYLE}")

add_custom_target(
  check
  COMMAND ${CMAKE_COMMAND} -E echo "ALL TESTS PASSED")

cskel_info("Tests target....: check")

#[[ Global data ]]

set(_targets )
set(_libs )
set(_find_pkg_names )
set(_find_pkg_args )

#[[ section ends ]]


macro(add_tgt_dir_once NAME TGT)
  if (NOT TARGET CSKEL__OUT_${NAME})
    # cskel_info("Output target...: ${NAME}")
    string(REPLACE "/" "_" tgt_name "${NAME}")

    # add_custom_target(
    #   CSKEL__OUT_${tgt_name}
    #  SOURCES
    #   ${CSKEL_PROJ_ROOT}/${NAME}
    #  COMMAND
    #   ${CMAKE_COMMAND} -E echo "${NAME} directory updated..."
    #   )
    # add_dependencies(${TGT} CSKEL__OUT_${tgt_name})

    set_property(
     DIRECTORY
     APPEND
     PROPERTY
      CMAKE_CONFIGURE_DEPENDS
      ${CSKEL_PROJ_ROOT}/${NAME})
  endif()
endmacro(add_tgt_dir_once)

macro(add_tgt_dir_dep_lib NAME)
  if (CSKEL_FLAT_LAYOUT)
    add_tgt_dir_once(include ${NAME})
    add_tgt_dir_once(src ${NAME})
    add_tgt_dir_once(tests ${NAME})
  else()
    add_tgt_dir_once(include/${NAME} ${NAME})
    add_tgt_dir_once(src/${NAME} ${NAME})
    add_tgt_dir_once(tests/${NAME} ${NAME})
  endif()
endmacro(add_tgt_dir_dep_lib)

macro(add_tgt_dir_dep_exe NAME)
  if (CSKEL_FLAT_LAYOUT)
    add_tgt_dir_once(include)
    add_tgt_dir_once(src)
    add_tgt_dir_once(tests)
    add_dependencies(${NAME} src)
  else()
    add_tgt_dir_once(include/${NAME})
    add_tgt_dir_once(src/${NAME})
    add_tgt_dir_once(tests/${NAME})
    add_dependencies(${NAME} src/${NAME})
  endif()
endmacro(add_tgt_dir_dep_exe)

#[[ On Windows, don't rely on SDKs being available ]]

if (WIN32)
  include(InstallRequiredSystemLibraries)
endif()

#[[ section ends ]]

#[[ Sanitize RPATH definitions
    - On Windows, DLLs must be present in PATH or same directory as the
      executables
    - On Linux, RPATH can be set correctly for installed files
    - On OS X, RPATH is embedded along with each dependency ]]

if (UNIX)
  if(APPLE)
    set(CMAKE_INSTALL_NAME_DIR "@executable_path/../lib")
    set(RPATH_DEF "-DCMAKE_INSTALL_NAME_DIR:STRING=${CMAKE_INSTALL_NAME_DIR}")
  else()
    set(CMAKE_INSTALL_RPATH "\$ORIGIN/../lib:\$ORIGIN:${CMAKE_INSTALL_PREFIX}/lib")
    set(CMAKE_BUILD_WITH_INSTALL_RPATH ON)
    set(RPATH_DEF "-DCMAKE_INSTALL_RPATH:STRING=${CMAKE_INSTALL_RPATH}")
  endif()
else()
  set(RPATH_DEF )
endif(UNIX)

#[[ section ends ]]


#[[ Enable code coverage
    - Only done on Debug Linux builds
    - Set CSKEL_CODECOV to true if enabled]]
if ("${CMAKE_BUILD_TYPE}" STREQUAL "Debug" AND ${CMAKE_SYSTEM_NAME} MATCHES "Linux"
    AND NOT DEFINED CSKEL_CODECOV)
  find_program(GCOV_PATH gcov)
  find_program(LCOV_PATH  NAMES lcov lcov.bat lcov.exe lcov.perl)
  find_program(GENHTML_PATH NAMES genhtml genhtml.perl genhtml.bat)
  set(comp_flags_cov -fprofile-arcs -ftest-coverage)
  set(link_flags_cov --coverage)
  set(link_libs_cov gcov)
  if (LCOV_PATH AND GCOV_PATH AND GENHTML_PATH)
    set(CSKEL_CODECOV ON)
    set(open_cmd xdg-open)
    add_custom_target(
      coverage
        COMMAND ${LCOV_PATH}
                --zerocounters
                --directory ${CMAKE_BINARY_DIR}
        COMMAND ${CMAKE_COMMAND} --build ${CMAKE_BINARY_DIR} --target check
        COMMAND ${LCOV_PATH}
                -c
                --directory ${CMAKE_BINARY_DIR}
                --output-file ${CMAKE_BINARY_DIR}/cov.info.init.0
        COMMAND ${LCOV_PATH}
                --remove ${CMAKE_BINARY_DIR}/cov.info.init.0
                --output-file ${CMAKE_BINARY_DIR}/cov.info
                '/usr/include/*'
                '/usr/lib/*'
                '${3P_ROOT}/*'
        COMMAND ${GENHTML_PATH}
                ${CMAKE_BINARY_DIR}/cov.info
                --output-directory ${CMAKE_BINARY_DIR}/cov
        COMMAND ${open_cmd} ${CMAKE_BINARY_DIR}/cov/index.html)
    add_dependencies(coverage check)
  else()
    cskel_info("Code coverage dependencies:")
    if (NOT LCOV_PATH)
      cskel_info("  [x] lcov not found")
    endif()
    if (NOT GCOV_PATH)
      cskel_info("  [x] gcov not found")
    endif()
    if (NOT GENHTML_PATH)
      cskel_info("  [x] genhtml not found")
    endif()
    set(CSKEL_CODECOV OFF)
  endif()
else()
  set(CSKEL_CODECOV OFF)
endif()

cskel_info("Code coverage...: ${CSKEL_CODECOV}")
if (CSKEL_CODECOV)
  cskel_info("Coverage target.: coverage")
endif()

#[[ section ends ]]

#[[ On Windows, don't rely on SDKs being available ]]

if (DOXYGEN_FOUND)
  cskel_info("Doxygen.........: ON")
  cskel_info("Doxygen target..: docs")
  set(doxy_in ${PROJECT_SOURCE_DIR}/doc/Doxyfile.in)
  add_custom_target(docs COMMAND ${CMAKE_COMMAND} -E echo "Docs generated")
else()
  cskel_info("Doxygen.........: OFF")
endif()

cskel_info("")

#[[ section ends ]]

function(lsprn hd)
  set(_args "${ARGV}")
  set(spc "")
  foreach(f ${_args})
    set(_f "${f}")
    string(REPLACE "${CSKEL_PROJ_ROOT}/" "" "_f" "${_f}")
    cskel_info("${spc}${_f}")
    set(spc "    ")
  endforeach()
endfunction()

# cskel_add_library(NAME <name>
#                   VERSION version
#                   [DISABLE_WARNINGS])
function(cskel_add_library)
  set(options DISABLE_WARNINGS)
  set(one_value NAME VERSION)
  set(multi_value )
  cmake_parse_arguments(
    ""
    "${options}"
    "${one_value}"
    "${multi_value}"
    ${ARGN})

  string(TOUPPER "${_NAME}" _UNAME)
  string(REPLACE "." ";" ver_list "${_VERSION}")

  file(GLOB_RECURSE
       export_hdr
       ${PROJECT_SOURCE_DIR}/include/${_NAME}${_cskel_sep}*.h
       ${PROJECT_SOURCE_DIR}/include/${_NAME}${_cskel_sep}*.hpp
       ${PROJECT_SOURCE_DIR}/include/${_NAME}${_cskel_sep}*.hxx)

  file(GLOB_RECURSE
       src_files
       ${PROJECT_SOURCE_DIR}/src/${_NAME}${_cskel_sep}*.c
       ${PROJECT_SOURCE_DIR}/src/${_NAME}${_cskel_sep}*.cpp
       ${PROJECT_SOURCE_DIR}/src/${_NAME}${_cskel_sep}*.cxx)

  list(GET ver_list 0 ver_maj)
  list(GET ver_list 1 ver_min)
  list(GET ver_list 2 ver_patch)

  ## Add export header
  set(xprt_hdr ${CMAKE_BINARY_DIR}/include/${_NAME}${_cskel_sep}exports.h)
  if (NOT EXISTS ${xprt_hdr})
    file(WRITE ${xprt_hdr} "/*! exports.h */
#ifndef ${_UNAME}_EXPORTS_H
#define ${_UNAME}_EXPORTS_H
#if defined(USE_${_UNAME}_STATIC)
#  define ${_UNAME}_API
#elif defined(_WIN32) && !defined(__GCC__)
#  ifdef BUILDING_${_UNAME}_SHARED
#    define ${_UNAME}_API __declspec(dllexport)
#  else
#    define ${_UNAME}_API __declspec(dllimport)
#  endif
#else
#  ifdef BUILDING_${_UNAME}_SHARED
#    define ${_UNAME}_API __attribute__((visibility(\"default\")))
#  else
#    define ${_UNAME}_API
#  endif
#endif
#if defined(__cplusplus)
#  define ${_UNAME}_EXTERN_C extern \"C\"
#else
#  define ${_UNAME}_EXTERN_C extern
#endif
#define ${_UNAME}_C_API ${_UNAME}_EXTERN_C ${_UNAME}_API
#define ${_UNAME}_MAJOR_VER ${ver_maj}
#define ${_UNAME}_MINOR_VER ${ver_min}
#define ${_UNAME}_PATCH_VER ${ver_patch}
#define ${_UNAME}_VERSION_NUMBER \
  (${_UNAME}_MAJOR_VER * 10000 + \
   ${_UNAME}_MINOR_VER * 100 + \
   ${_UNAME}_PATCH_VER)
#endif/*${_UNAME}_EXPORTS_H*/
")
  endif()

  ## Add the library
  add_library(${_NAME} ${src_files} ${export_hdr} ${xprt_hdr})
  add_tgt_dir_dep_lib(${_NAME})

  ## Set compiler definitions
  if (BUILD_SHARED_LIBS)
    set(private_defs BUILDING_${_UNAME}_SHARED)
    set(public_defs )
  else()
    set(private_defs )
    set(public_defs USE_${_UNAME}_STATIC)
  endif()

  if (BUILD_SHARED_LIBS)
    set_target_properties(
      ${_NAME}
      PROPERTIES
        VERSION ${_VERSION}
        SOVERSION ${ver_maj})
  endif()

  target_compile_definitions(
    ${_NAME}
    PUBLIC
      ${public_defs}
    PRIVATE
      ${private_defs}
      ${_UNAME}_VER_MAJ=${ver_maj}
      ${_UNAME}_VER_MIN=${ver_min}
      ${_UNAME}_VER_PATCH=${ver_patch}
      ${_UNAME}_VER_STRING=\"${_VERSION}\")

  if (NOT _DISABLE_WARNINGS)
    if (MSVC)
      target_compile_options(${_NAME} PRIVATE /W3 /WX)
    else()
      target_compile_options(
        ${_NAME} PRIVATE -Wall -Werror -Wno-unused-function)
    endif()
  endif()

  if (CSKEL_CODECOV)
    target_compile_options(${_NAME} PRIVATE ${comp_flags_cov})
    if (link_libs_cov)
      target_link_libraries(${_NAME} PRIVATE ${link_libs_cov})
    endif()
    if (link_flags_cov)
      get_target_property(_ln_flags ${_NAME} LINK_FLAGS)
      if (_ln_flags)
        list(APPEND _ln_flags ${link_flags_cov})
      else()
        set(_ln_flags ${link_flags_cov})
      endif()
      set_target_properties(${_NAME} PROPERTIES LINK_FLAGS "${_ln_flags}")
    endif()
  endif()

  if (DOXYGEN_FOUND)
    file(MAKE_DIRECTORY ${CMAKE_BINARY_DIR}/doc-${_NAME})
    configure_file(${doxy_in} ${CMAKE_BINARY_DIR}/doc-${_NAME}/Doxyfile @ONLY)
    add_custom_target(
            doc-${_NAME} ALL
            COMMAND ${DOXYGEN_EXECUTABLE} ${CMAKE_BINARY_DIR}/doc-${_NAME}/Doxyfile
            WORKING_DIRECTORY ${CMAKE_BINARY_DIR}/doc-${_NAME}
            COMMENT "Generating API docs")
    add_dependencies(docs doc-${_NAME})
    install(DIRECTORY ${CMAKE_BINARY_DIR}/doc-${_NAME}/html
            DESTINATION share/${CSKEL_PROJ_NAME}/doc/${_NAME})
  endif()

  ## Set include directories
  target_include_directories(
    ${_NAME}
    PUBLIC
      $<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/include>
      $<INSTALL_INTERFACE:include>
    PRIVATE
      $<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/src>
      $<BUILD_INTERFACE:${CMAKE_BINARY_DIR}/include>)

  ## Install configs
  export(
    TARGETS ${_NAME}
    FILE ${PROJECT_BINARY_DIR}/${_NAME}-targets.cmake)

  install(
    TARGETS ${_NAME}
    EXPORT ${_NAME}-targets
    RUNTIME DESTINATION bin
    LIBRARY DESTINATION lib
    ARCHIVE DESTINATION lib
    INCLUDES DESTINATION include)

  ## Install headers
  install(
    DIRECTORY include/
    DESTINATION include
    FILES_MATCHING REGEX ".*[/\\]${_NAME}[_/\\].*\\.h[px]*$")

  install(
    FILES ${xprt_hdr}
    DESTINATION include/${_NAME})

  ## Install targets export
  install(
    EXPORT ${_NAME}-targets
    NAMESPACE ${CSKEL_PROJ_NAME}::
    DESTINATION lib/cmake/${CSKEL_PROJ_NAME}
    COMPONENT dev)

  list(FIND _targets ${_NAME} _index)
  if (${_index} EQUAL -1)
    set(_targets "${_targets};${_NAME}" CACHE STRING "Targets" FORCE)
    set(_libs "${_libs};${_NAME}" CACHE STRING "Libs" FORCE)
  endif()

  cskel_info("Library.........: ${_NAME}")
  lsprn("  Export headers:" ${export_hdr})
  lsprn("  Source files..:" ${src_files})
endfunction(cskel_add_library)

# cskel_add_executable(NAME <name>
#                      VERSION version
#                      [DISABLE_WARNINGS])
function(cskel_add_executable)
  set(options DISABLE_WARNINGS)
  set(one_value NAME VERSION)
  set(multi_value )
  cmake_parse_arguments(
    ""
    "${options}"
    "${one_value}"
    "${multi_value}"
    ${ARGN})

  string(TOUPPER "${_NAME}" _UNAME)
  string(REPLACE "." ";" ver_list "${_VERSION}")

  list(GET ver_list 0 ver_maj)
  list(GET ver_list 1 ver_min)
  list(GET ver_list 2 ver_patch)

  file(GLOB_RECURSE
       src_files
       ${PROJECT_SOURCE_DIR}/src/${_NAME}${_cskel_sep}*.c
       ${PROJECT_SOURCE_DIR}/src/${_NAME}${_cskel_sep}*.cpp
       ${PROJECT_SOURCE_DIR}/src/${_NAME}${_cskel_sep}*.cxx)

  ## Add the executable
  add_executable(${_NAME} ${src_files})
  add_tgt_dir_dep_exe(${_NAME})

  target_compile_definitions(
    ${_NAME}
    PRIVATE
      ${_UNAME}_VER_MAJ=${ver_maj}
      ${_UNAME}_VER_MIN=${ver_min}
      ${_UNAME}_VER_PATCH=${ver_patch}
      ${_UNAME}_VER_STRING=\"${_VERSION}\")

  if (NOT _DISABLE_WARNINGS)
    if (MSVC)
      target_compile_options(${_NAME} PRIVATE /W3 /WX)
    else()
      target_compile_options(
        ${_NAME} PRIVATE -Wall -Werror -Wno-unused-function)
    endif()
  endif()

  if (CSKEL_CODECOV)
    target_compile_options(${_NAME} PRIVATE ${comp_flags_cov})
    if (link_libs_cov)
      target_link_libraries(${_NAME} PRIVATE ${link_libs_cov})
    endif()
    if (link_flags_cov)
      get_target_property(_ln_flags ${_NAME} LINK_FLAGS)
      if (_ln_flags)
        list(APPEND _ln_flags ${link_flags_cov})
      else()
        set(_ln_flags ${link_flags_cov})
      endif()
      set_target_properties(${_NAME} PROPERTIES LINK_FLAGS "${_ln_flags}")
    endif()
  endif()

  if (DOXYGEN_FOUND)
    file(MAKE_DIRECTORY ${CMAKE_BINARY_DIR}/doc-${_NAME})
    configure_file(${doxy_in} ${CMAKE_BINARY_DIR}/doc-${_NAME}/Doxyfile @ONLY)
    add_custom_target(
            doc-${_NAME} ALL
            COMMAND ${DOXYGEN_EXECUTABLE} ${CMAKE_BINARY_DIR}/doc-${_NAME}/Doxyfile
            WORKING_DIRECTORY ${CMAKE_BINARY_DIR}/doc-${_NAME}
            COMMENT "Generating API docs")
    add_dependencies(docs doc-${_NAME})
    install(DIRECTORY ${CMAKE_BINARY_DIR}/doc-${_NAME}/html
            DESTINATION share/${CSKEL_PROJ_NAME}/doc/${_NAME})
  endif()

  ## Set include directories
  target_include_directories(
    ${_NAME}
    PUBLIC
      $<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/include>
      $<INSTALL_INTERFACE:include>
    PRIVATE
      $<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/src>
      $<BUILD_INTERFACE:${CMAKE_BINARY_DIR}/include>)

  ## Install configs
  export(
    TARGETS ${_NAME}
    FILE ${PROJECT_BINARY_DIR}/${_NAME}-targets.cmake)

  install(
    TARGETS ${_NAME}
    EXPORT ${_NAME}-targets
    RUNTIME DESTINATION bin)

  ## Install targets export
  install(
    EXPORT ${_NAME}-targets
    NAMESPACE ${CSKEL_PROJ_NAME}::
    DESTINATION lib/cmake/${CSKEL_PROJ_NAME}
    COMPONENT dev)

  list(FIND _targets ${_NAME} _index)
  if (${_index} EQUAL -1)
    set(_targets "${_targets};${_NAME}" CACHE STRING "Targets" FORCE)
  endif()
  # force build when building check
  add_dependencies(check ${_NAME})

  cskel_info("Executable......: ${_NAME}")
  lsprn("  Source files..:" ${src_files})
endfunction(cskel_add_executable)

# cskel_add_tests(NAME <name> [DISABLE_WARNINGS])
#  If 'NO_BUILD_TESTING' is truthy, test targets are not created.
function(cskel_add_tests)
  if (NOT BUILD_TESTING)
    return()
  endif()
  set(options DISABLE_WARNINGS)
  set(one_value NAME)
  set(multi_value )
  cmake_parse_arguments(
    ""
    "${options}"
    "${one_value}"
    "${multi_value}"
    ${ARGN})

  set(test_dir ${PROJECT_SOURCE_DIR}/tests)
  file(GLOB_RECURSE
       tst_files
       ${test_dir}/${_NAME}${_cskel_sep}*.c
       ${test_dir}/${_NAME}${_cskel_sep}*.cpp
       ${test_dir}/${_NAME}${_cskel_sep}*.cxx)

  add_executable(${_NAME}-lib-tests ${tst_files} ${test_dir}/tmain.cpp)

  target_include_directories(
    ${_NAME}-lib-tests
    PRIVATE
      ${PROJECT_SOURCE_DIR}/include
      ${CMAKE_BINARY_DIR}/include
      ${PROJECT_SOURCE_DIR}/tests)

  if (NOT _DISABLE_WARNINGS)
    if (MSVC)
      target_compile_options(${_NAME}-lib-tests PRIVATE /W3 /WX)
    else()
      target_compile_options(
        ${_NAME}-lib-tests PRIVATE -Wall -Werror -Wno-unused-function)
    endif()
  endif()

  if (CSKEL_CODECOV)
    target_compile_options(${_NAME}-lib-tests PRIVATE ${comp_flags_cov})
    if (link_libs_cov)
      target_link_libraries(${_NAME}-lib-tests PRIVATE ${link_libs_cov})
    endif()
    if (link_flags_cov)
      get_target_property(_ln_flags ${_NAME}-lib-tests LINK_FLAGS)
      if (_ln_flags)
        list(APPEND _ln_flags ${link_flags_cov})
      else()
        set(_ln_flags ${link_flags_cov})
      endif()
      set_target_properties(${_NAME}-lib-tests PROPERTIES LINK_FLAGS "${_ln_flags}")
    endif()
  endif()

  target_link_libraries(
    ${_NAME}-lib-tests
    PRIVATE
    ${_NAME}
    GTest::gtest GTest::gmock)

  if (WIN32)
    add_custom_target(
      ${_NAME}-lib-tests-run
      DEPENDS ${_NAME}-lib-tests
      COMMAND set "PATH=${CMAKE_INSTALL_PREFIX}/bin;%PATH%"
      COMMAND $<TARGET_FILE:${_NAME}-lib-tests>)
  elseif(APPLE)
    add_custom_target(
      ${_NAME}-lib-tests-run
      DEPENDS ${_NAME}-lib-tests
      COMMAND ${CMAKE_COMMAND} -E env DYLD_LIBRARY_PATH=${CMAKE_INSTALL_PREFIX}/lib
              $<TARGET_FILE:${_NAME}-lib-tests>)
  else()
    add_custom_target(
      ${_NAME}-lib-tests-run
      DEPENDS ${_NAME}-lib-tests
      COMMAND $<TARGET_FILE:${_NAME}-lib-tests>)
  endif()

  add_test(
    ${_NAME}-ctest
   COMMAND
    ${CMAKE_COMMAND} --build ${CMAKE_BINARY_DIR}
                     --target ${_NAME}-lib-tests-run)
  add_dependencies(check ${_NAME}-lib-tests-run)

  cskel_info("Tests...........: ${_NAME}")
  lsprn("  Source files..:" ${tst_files})
endfunction(cskel_add_tests)

# cskel_find_pkg(<package> [version] [EXACT] [QUIET] [MODULE]
#                [REQUIRED] [[COMPONENTS] [components...]]
#                [OPTIONAL_COMPONENTS components...]
#                [NO_POLICY_SCOPE])
macro(cskel_find_pkg)
  find_package(${ARGN})
  list(APPEND _find_pkg_names ${ARGV0})
  set(_find_pkg_args_${ARGV0} "${ARGN}")
endmacro(cskel_find_pkg)

# cskel_config_install_exports()
function(cskel_config_install_exports)
  set(pkg_cfg ${CMAKE_BINARY_DIR}/pkgcfg.cmake.in)
  set(PROJ ${PROJECT_NAME})
  string(TOUPPER "${PROJ}" PROJUPPER)

  file(WRITE ${pkg_cfg} "# ${PROJ}-config.cmake
# Config file for the ${PROJ} package.
# It defines the following variables:
#  ${PROJUPPER}_INCLUDE_DIRS - include directories for ${PROJ}
#  ${PROJUPPER}_LIBRARIES    - libraries to link against
# Find dependent packages here
")

  foreach(dep ${_find_pkg_names})
    set(fp_args ${_find_pkg_args_${dep}})
    string(REPLACE ";" " " fp_args "${fp_args}")
    file(APPEND ${pkg_cfg} "find_package(${fp_args})\n")
  endforeach()

  file(APPEND ${pkg_cfg} "
if (${PROJUPPER}_CMAKE_DIR)
  # already imported
  return()
endif()
# Compute paths
get_filename_component(${PROJUPPER}_CMAKE_DIR \"\${CMAKE_CURRENT_LIST_FILE}\" PATH)
# Set include dir
set(${PROJUPPER}_INCLUDE_DIRS include)
# Our library dependencies (contains definitions for IMPORTED targets)
")

  foreach(tgt ${_targets})
    file(APPEND ${pkg_cfg}
         "include(\${${PROJUPPER}_CMAKE_DIR}/${tgt}-targets.cmake)\n")
    file(APPEND ${pkg_cfg}
         "message(\"-- Imported target ${PROJ}::${tgt}\")\n")
  endforeach()

  string(REPLACE ";" " " all_libs "${_libs}")
  file(APPEND ${pkg_cfg} "
# These are IMPORTED targets created by ${PROJ}-targets.cmake
set(${PROJUPPER}_LIBRARIES ${all_libs})
")

  configure_file(
    ${pkg_cfg}
    ${PROJECT_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/${PROJ}-config.cmake @ONLY)

  export(PACKAGE ${PROJ})

  install(
    FILES ${PROJECT_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/${PROJ}-config.cmake
    DESTINATION lib/cmake/${PROJ}
    COMPONENT dev)
endfunction(cskel_config_install_exports)

# cskel_install_3p(NAME)
macro(cskel_install_3p NAME)
  include(${CSKEL_PROJ_ROOT}/3p/${NAME}/targets.cmake)
endmacro(cskel_install_3p)

cskel_install_3p(gtest)
