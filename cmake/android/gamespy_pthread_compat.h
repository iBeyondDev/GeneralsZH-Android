/*
 * GeneralsX @build android 04/10/2026
 * Force-included into the fetched GameSpy SDK sources on Android only (cmake/gamespy.cmake).
 *
 * bionic does not implement pthread_cancel (asynchronous thread cancellation is
 * unsupported on Android). GameSpy's Linux thread layer calls it only from
 * gsiCancelThread() to tear down its own worker threads; reporting ENOSYS makes
 * that call fail cleanly instead of breaking the build. Online play is not
 * functional in native ports of this engine regardless (lockstep float determinism).
 */
#pragma once

#include <errno.h>
#include <pthread.h>

static inline int pthread_cancel(pthread_t thread)
{
	(void)thread;
	return ENOSYS;
}
