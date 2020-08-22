# utils.cmake

if (INCLUDED_CSKEL_CMAKE_UTILS)
  return()
endif ()
set(INCLUDED_CSKEL_CMAKE_UTILS 1)

cmake_minimum_required(VERSION 3.0)

find_package(Git)
if (Git_FOUND)
  execute_process(
    COMMAND ${GIT_EXECUTABLE} rev-parse --show-toplevel
    RESULT_VARIABLE _git_proj_rc
    OUTPUT_VARIABLE _git_proj_name
    OUTPUT_STRIP_TRAILING_WHITESPACE
    )
  if (NOT ${_git_proj_rc} STREQUAL 0)
    message(FATAL_ERROR "Failed to find repository root")
  endif ()
else ()
  message(FATAL_ERROR "Could not find 'git'")
endif ()

# CSKEL_PROJ_ROOT: Root absolute path of the project
set(CSKEL_PROJ_ROOT ${_git_proj_name})
# CSKEL_PROJ_NAME: Base name of the root path, i.e. name of the project
get_filename_component(CSKEL_PROJ_NAME "${CSKEL_PROJ_ROOT}" NAME)

# cskel_info(...)
#
# Log information at INFO level.
macro (cskel_info)
  message("${CSKEL_PROJ_NAME} INFO  " ${ARGN})
endmacro (cskel_info)

# cskel_error(...)
#
# Log information at ERROR level and terminate CMake generation.
macro (cskel_error)
  message(FATAL_ERROR "${CSKEL_PROJ_NAME} ERROR " ${ARGN})
endmacro (cskel_error)

# cskel_include_guard(NAME)
#
# Sets up an include guard for the scope with the variable 'NAME'.
macro (cskel_include_guard NAME)
  if (${NAME})
    return()
  endif ()
  set(${NAME} TRUE)
endmacro (cskel_include_guard)

# cskel_try_compile_run(RESULT_VAR OUTPUT_VAR LITERAL_CODE EXTENSION)
#
# Try to compile and run 'LITERAL_CODE' as a file with extension
# 'EXTENSION' and assign the result of the execution to the name
# '$RESULT_VAR' and the output to the variable '$OUTPUT_VAR'.
macro (cskel_try_compile_run RESULT_VAR OUTPUT_VAR LITERAL_CODE
       EXTENSION
  )
  if (NOT cm__tmp_nam)
    set(cm__tmp_nam 0)
  else ()
    math(EXPR cm__tmp_nam "${cm__tmp_nam} + 1")
  endif ()

  set(cm__test_base "cskel_try_compile_run_${cm__tmp_nam}")
  file(WRITE "${CMAKE_BINARY_DIR}/${cm__test_base}.${EXTENSION}"
       ${LITERAL_CODE}
    )
  try_run(
    ${RESULT_VAR} _comp_res ${CMAKE_BINARY_DIR}
    "${CMAKE_BINARY_DIR}/${cm__test_base}.${EXTENSION}"
    RUN_OUTPUT_VARIABLE ${OUTPUT_VAR}
    COMPILE_OUTPUT_VARIABLE _comp_out
    )
  if (NOT ${RESULT_VAR} STREQUAL 0)
    cskel_error("Failed to compile+run ${cm__test_base}:")
    cskel_error("Compile result: ${_comp_res}")
    cskel_error("Compile output: ${_comp_out}")
    cskel_error("Run result: ${${RESULT_VAR}}")
    cskel_error("Run output: ${${OUTPUT_VAR}}")
  endif ()
endmacro (cskel_try_compile_run)
