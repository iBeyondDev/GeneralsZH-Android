set(GS_OPENSSL FALSE)
set(GAMESPY_SERVER_NAME "server.cnc-online.net")

FetchContent_Declare(
    gamespy
    GIT_REPOSITORY https://github.com/TheAssemblyArmada/GamespySDK.git
    GIT_TAG        07e3d15c500415abc281efb74322ab6d9c857eb8
)

if(ANDROID)
    # GeneralsX @build android 04/10/2026 Give the GameSpy sources (and only them) a
    # pthread_cancel shim — bionic lacks it. Directory compile options are captured by
    # subdirectories when they are added, so set them just for this call and restore.
    get_directory_property(_gs_saved_compile_options COMPILE_OPTIONS)
    add_compile_options("$<$<COMPILE_LANGUAGE:C>:SHELL:-include ${CMAKE_SOURCE_DIR}/cmake/android/gamespy_pthread_compat.h>")
    FetchContent_MakeAvailable(gamespy)
    set_directory_properties(PROPERTIES COMPILE_OPTIONS "${_gs_saved_compile_options}")
else()
    FetchContent_MakeAvailable(gamespy)
endif()
