cmake_minimum_required(VERSION 3.16)
project(NeoverseBenchmarking LANGUAGES C CXX)

# Set C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Default build type
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
endif()

# Detect Neoverse processor type and features
include(cmake/DetectNeoverse.cmake)

# Set compiler flags based on detected hardware
include(cmake/CompilerFlags.cmake)

# Find required packages
find_package(OpenMP REQUIRED)
find_package(PkgConfig REQUIRED)

# Optional packages
find_package(NUMA QUIET)
find_package(hwloc QUIET)

# Include directories
include_directories(include)

# Source files
set(CORE_SOURCES
    src/core/matrix.c
    src/core/benchmark.c
    src/core/utils.c
)

set(BASELINE_SOURCES
    src/baseline/matrix_baseline.c
)

set(OPTIMIZED_SOURCES
    src/optimized/matrix_compiler.c
    src/optimized/matrix_neon.c
    src/optimized/matrix_sve.c
    src/optimized/matrix_memory.c
    src/optimized/matrix_threading.c
)

# Create libraries
add_library(neoverse_core ${CORE_SOURCES})
add_library(neoverse_baseline ${BASELINE_SOURCES})
add_library(neoverse_optimized ${OPTIMIZED_SOURCES})

# Link libraries
target_link_libraries(neoverse_core OpenMP::OpenMP_C)
if(NUMA_FOUND)
    target_link_libraries(neoverse_core ${NUMA_LIBRARIES})
endif()

# Create executables
add_executable(baseline_benchmark src/benchmarks/baseline_benchmark.c)
target_link_libraries(baseline_benchmark neoverse_core neoverse_baseline)

add_executable(optimization_benchmark src/benchmarks/optimization_benchmark.c)
target_link_libraries(optimization_benchmark neoverse_core neoverse_optimized)

add_executable(comparison_benchmark src/benchmarks/comparison_benchmark.c)
target_link_libraries(comparison_benchmark neoverse_core neoverse_baseline neoverse_optimized)

# Install targets
install(TARGETS baseline_benchmark optimization_benchmark comparison_benchmark
        RUNTIME DESTINATION bin)

# Add custom targets for different optimization categories
add_custom_target(test_compiler
    COMMAND ./optimization_benchmark --category=compiler
    DEPENDS optimization_benchmark
    COMMENT "Running compiler optimization tests"
)

add_custom_target(test_simd
    COMMAND ./optimization_benchmark --category=simd
    DEPENDS optimization_benchmark
    COMMENT "Running SIMD optimization tests"
)

add_custom_target(test_memory
    COMMAND ./optimization_benchmark --category=memory
    DEPENDS optimization_benchmark
    COMMENT "Running memory optimization tests"
)

add_custom_target(test_all
    COMMAND ./comparison_benchmark --all
    DEPENDS comparison_benchmark
    COMMENT "Running comprehensive benchmark comparison"
)

# Print configuration summary
message(STATUS "Neoverse Benchmarking Configuration:")
message(STATUS "  Processor Type: ${NEOVERSE_TYPE}")
message(STATUS "  CPU Cores: ${CPU_CORES}")
message(STATUS "  NEON Support: ${HAS_NEON}")
message(STATUS "  SVE Support: ${HAS_SVE}")
message(STATUS "  SVE2 Support: ${HAS_SVE2}")
message(STATUS "  LSE Atomics: ${HAS_LSE}")
message(STATUS "  Crypto Extensions: ${HAS_CRYPTO}")
message(STATUS "  Build Type: ${CMAKE_BUILD_TYPE}")
message(STATUS "  C Compiler: ${CMAKE_C_COMPILER}")
message(STATUS "  CXX Compiler: ${CMAKE_CXX_COMPILER}")
message(STATUS "  Compiler Flags: ${CMAKE_C_FLAGS}")
