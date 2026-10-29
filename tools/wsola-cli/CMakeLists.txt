cmake_minimum_required(VERSION 3.16)
project(wsola-cli CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release)
endif()

# The algorithm lives in the MLT module; the CLI builds exactly the same file.
set(WSOLA_DIR "" CACHE PATH "The src/modules/wsola directory of MLT")
if(NOT EXISTS "${WSOLA_DIR}/wsola_algorithm.cpp")
  message(FATAL_ERROR "Set -DWSOLA_DIR=<mlt>/src/modules/wsola")
endif()

add_executable(wsola-cli wsola_cli.cpp "${WSOLA_DIR}/wsola_algorithm.cpp")
target_include_directories(wsola-cli PRIVATE "${WSOLA_DIR}")
target_compile_options(wsola-cli PRIVATE -Wall -Wextra)
install(TARGETS wsola-cli RUNTIME DESTINATION bin)
