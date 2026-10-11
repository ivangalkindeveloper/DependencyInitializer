package io.ivangalkindeveloper.dependencyinitializer

/** Mutable assembly process. [toContainer] is read on the main dispatcher after all sets succeed. */
interface DependencyInitializationProcess<out T> {
    val toContainer: T
}
