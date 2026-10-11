package io.github.ivangalkindeveloper.dependencyinitializer

import kotlinx.coroutines.CoroutineDispatcher

enum class DependencyInitializationStepType { SIMPLE, REPEATABLE }

interface DependencyInitializationStep {
    val title: String?
    val type: DIStepType
}

class SyncInitializationStep<P : DIProcess<*>>(
    override val title: String? = null,
    override val type: DIStepType = DIStepType.SIMPLE,
    val run: (P) -> Unit,
) : DIStep

/** [dispatcher] selects execution context; Kotlin has no equivalent of Swift TaskPriority. */
class AsyncInitializationStep<P : DIProcess<*>>(
    override val title: String? = null,
    override val type: DIStepType = DIStepType.SIMPLE,
    val dispatcher: CoroutineDispatcher? = null,
    val run: suspend (P) -> Unit,
) : DIStep
