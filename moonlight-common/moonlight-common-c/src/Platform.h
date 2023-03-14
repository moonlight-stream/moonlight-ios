#pragma once

#ifdef _WIN32
// Prevent bogus definitions of error codes
// that are incompatible with Winsock errors.
#define _CRT_NO_POSIX_ERROR_CODES

// Ignore CRT warnings about sprintf(), memcpy(), etc.
#define _CRT_SECURE_NO_WARNINGS 1
#define _CRT_NONSTDC_NO_DEPRECATE 1
#endif

#include <stdlib.h>
#include <string.h>
#include <stdint.h>

#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#include <Windows.h>
#include <Winsock2.h>
#include <ws2tcpip.h>
#elif defined(__vita__)
#include <unistd.h>
#include <sys/time.h>
#include <netinet/in.h>
#include <psp2/kernel/threadmgr.h>
#elif defined(__WIIU__)
#include <unistd.h>
#include <sys/time.h>
#include <netinet/in.h>
#include <malloc.h>
#include <coreinit/thread.h>
#include <coreinit/fastmutex.h>
#include <coreinit/fastcondition.h>
#include <fcntl.h>
#else
#include <unistd.h>
#include <pthread.h>
#include <sys/time.h>
#include <sys/ioctl.h>
#include <arpa/inet.h>
#include <netinet/in.h>
#include <fcntl.h>
#endif

#ifdef _WIN32
# define LC_WINDOWS
#else
# define LC_POSIX
# if defined(__APPLE__)
#  define LC_DARWIN
# endif
#endif

#include <stdio.h>
#include "Limelight.h"

#define Limelog(s, ...) \
    if (ListenerCallbacks.logMessage) \
        ListenerCallbacks.logMessage(s, ##__VA_ARGS__)

#if defined(LC_WINDOWS)
#include <crtdbg.h>
#ifdef LC_DEBUG
#define LC_ASSERT(x) __analysis_assume(x); \
                       _ASSERTE(x)
#else
#define LC_ASSERT(x)
#endif
#else
#ifndef LC_DEBUG
#ifndef NDEBUG
#define NDEBUG
#endif
#else
#ifdef NDEBUG
#undef NDEBUG
#endif
#endif
#include <assert.h>
#define LC_ASSERT(x) assert(x)
#endif

#ifdef _MSC_VER
#pragma intrinsic(_byteswap_ushort)
#define BSWAP16(x) _byteswap_ushort(x)
#pragma intrinsic(_byteswap_ulong)
#define BSWAP32(x) _byteswap_ulong(x)
#pragma intrinsic(_byteswap_uint64)
#define BSWAP64(x) _byteswap_uint64(x)
#elif (__GNUC__ > 4) || (__GNUC__ == 4 && __GNUC_MINOR__ >= 8)
#define BSWAP16(x) __builtin_bswap16(x)
#define BSWAP32(x) __builtin_bswap32(x)
#define BSWAP64(x) __builtin_bswap64(x)
#elif defined(__has_builtin) && __has_builtin(__builtin_bswap16)
#define BSWAP16(x) __builtin_bswap16(x)
#define BSWAP32(x) __builtin_bswap32(x)
#define BSWAP64(x) __builtin_bswap64(x)
#else
#error Please define your platform byteswap macros!
#endif

#if (defined(__BYTE_ORDER__) && (__BYTE_ORDER__ == __ORDER_BIG_ENDIAN__)) || defined(__BIG_ENDIAN__)
#define LE16(x) BSWAP16(x)
#define LE32(x) BSWAP32(x)
#define LE64(x) BSWAP64(x)
#define BE16(x) (x)
#define BE32(x) (x)
#define BE64(x) (x)
#else
#define LE16(x) (x)
#define LE32(x) (x)
#define LE64(x) (x)
#define BE16(x) BSWAP16(x)
#define BE32(x) BSWAP32(x)
#define BE64(x) BSWAP64(x)
#endif

int initializePlatform(void);
void cleanupPlatform(void);

uint64_t PltGetMillis(void);
