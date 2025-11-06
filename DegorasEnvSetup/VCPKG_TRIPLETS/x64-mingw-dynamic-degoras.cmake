# =====================================================================
# DEGORAS-PROJECT MINGW64 CONTROLLED TRIPLET
# Target: x64-mingw-dynamic-degoras
# Last updated: 2025-11-04
# =====================================================================

# Initial log.
message(STATUS "[DEGORAS] Using DEGORAS-PROJECT custom triplet")

# Target ABI and linkage
set(VCPKG_TARGET_ARCHITECTURE x64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE dynamic)
set(VCPKG_CMAKE_SYSTEM_NAME MinGW)

# Policies suitable for MinGW
set(VCPKG_POLICY_ALLOW_OBSOLETE_MSVCRT enabled)
set(VCPKG_POLICY_DLLS_WITHOUT_LIBS enabled)

# Keep the environment deterministic
set(VCPKG_ENV_PASSTHROUGH PATH)
set(VCPKG_ENV_PASSTHROUGH_UNTRACKED "")

# System processor hint (needed for some Qt and pkg-config logic)
set(VCPKG_CMAKE_SYSTEM_PROCESSOR x86_64)

# Build type — only release binaries
set(VCPKG_BUILD_TYPE release)

# Optional: ensure no debug packages even if referenced
set(VCPKG_DISABLE_METRICS ON)