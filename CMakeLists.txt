cmake_minimum_required(VERSION 3.15)
project(langover VERSION 1.1.0 LANGUAGES C RC)

# ── Build settings ──
set(CMAKE_C_STANDARD 11)

# Static link CRT so the .exe has zero runtime dependencies
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")

# For MinGW: static link libgcc
if(MINGW)
    set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -static")
endif()

# ── Source files ──
set(SOURCES
    src/langover.c
    src/langover.rc
)

# ── Build as Windows GUI application (no console window) ──
add_executable(langover WIN32 ${SOURCES})

target_include_directories(langover PRIVATE src)

# ── Link Windows libraries ──
target_link_libraries(langover PRIVATE
    user32
    shell32
    gdi32
)

# ── Compiler warnings ──
if(MSVC)
    target_compile_options(langover PRIVATE /W4 /WX /utf-8)
    # Disable specific warnings that are noise for this project
    target_compile_options(langover PRIVATE /wd4100) # unreferenced formal parameter
elseif(MINGW OR CMAKE_C_COMPILER_ID STREQUAL "GNU")
    target_compile_options(langover PRIVATE -Wall -Wextra -Werror -municode)
endif()

# ── Install ──
install(TARGETS langover RUNTIME DESTINATION .)
