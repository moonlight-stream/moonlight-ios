#pragma once

#include "Limelight.h"
#include "Platform.h"

typedef void(*ThreadEntry)(void* context);

#if defined(LC_WINDOWS)
typedef SRWLOCK PLT_MUTEX;
typedef CONDITION_VARIABLE PLT_COND;
typedef struct _PLT_THREAD {
    HANDLE handle;
    bool cancelled;
} PLT_THREAD;
#elif defined(__vita__)
typedef int PLT_MUTEX;
typedef int PLT_COND;
typedef struct _PLT_THREAD {
    int handle;
    int cancelled;
    void *context;
    bool alive;
} PLT_THREAD;
#elif defined(__WIIU__)
typedef OSFastMutex PLT_MUTEX;
typedef OSFastCondition PLT_COND;
typedef struct _PLT_THREAD {
    OSThread thread;
    int cancelled;
} PLT_THREAD;
#elif defined (LC_POSIX)
typedef pthread_mutex_t PLT_MUTEX;
typedef pthread_cond_t PLT_COND;
typedef struct _PLT_THREAD {
    pthread_t thread;
    bool cancelled;
} PLT_THREAD;
#else
#error Unsupported platform
#endif

#ifdef LC_WINDOWS
typedef HANDLE PLT_EVENT;
#else
typedef struct _PLT_EVENT {
    PLT_MUTEX mutex;
    PLT_COND cond;
    bool signalled;
} PLT_EVENT;
#endif

int PltCreateMutex(PLT_MUTEX* mutex);
void PltDeleteMutex(PLT_MUTEX* mutex);
void PltLockMutex(PLT_MUTEX* mutex);
void PltUnlockMutex(PLT_MUTEX* mutex);

int PltCreateThread(const char* name, ThreadEntry entry, void* context, PLT_THREAD* thread);
void PltCloseThread(PLT_THREAD* thread);
void PltInterruptThread(PLT_THREAD* thread);
bool PltIsThreadInterrupted(PLT_THREAD* thread);
void PltJoinThread(PLT_THREAD* thread);

int PltCreateEvent(PLT_EVENT* event);
void PltCloseEvent(PLT_EVENT* event);
void PltSetEvent(PLT_EVENT* event);
void PltClearEvent(PLT_EVENT* event);
void PltWaitForEvent(PLT_EVENT* event);

int PltCreateConditionVariable(PLT_COND* cond, PLT_MUTEX* mutex);
void PltDeleteConditionVariable(PLT_COND* cond);
void PltSignalConditionVariable(PLT_COND* cond);
void PltWaitForConditionVariable(PLT_COND* cond, PLT_MUTEX* mutex);

void PltSleepMs(int ms);
void PltSleepMsInterruptible(PLT_THREAD* thread, int ms);
