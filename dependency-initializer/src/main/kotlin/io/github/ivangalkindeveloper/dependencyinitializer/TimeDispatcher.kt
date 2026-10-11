package io.github.ivangalkindeveloper.dependencyinitializer

/** Durations are Double nanoseconds, matching the Swift TimeDispatcher. */
open class TimeDispatcher(protected val nanoTime: () -> Long = System::nanoTime) {
    protected fun diffTime(start: Long): Double = (nanoTime() - start).toDouble()
}
