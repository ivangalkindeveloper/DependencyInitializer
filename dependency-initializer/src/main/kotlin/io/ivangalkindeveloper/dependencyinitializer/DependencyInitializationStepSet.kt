package io.ivangalkindeveloper.dependencyinitializer

import java.util.Collections

/** Exactly one of [sync] and [async] must be supplied. Empty individual sets are allowed. */
class DependencyInitializationStepSet<P : DIProcess<*>>(
    sync: List<SyncInitializationStep<P>>? = null,
    async: List<AsyncInitializationStep<P>>? = null,
) {
    init { require((sync == null) != (async == null)) { "Provide either sync or async steps, exclusively" } }

    internal val syncSteps = sync?.let { Collections.unmodifiableList(it.toList()) }
    internal val asyncSteps = async?.let { Collections.unmodifiableList(it.toList()) }

    val isAsync: Boolean get() = asyncSteps != null
    val steps: List<DIStep> get() = syncSteps ?: asyncSteps!!

    internal val repeatable: StepSet<P>?
        get() = if (syncSteps != null) {
            syncSteps.filter { it.type == DIStepType.REPEATABLE }.takeIf { it.isNotEmpty() }?.let { StepSet(sync = it) }
        } else {
            asyncSteps!!.filter { it.type == DIStepType.REPEATABLE }.takeIf { it.isNotEmpty() }?.let { StepSet(async = it) }
        }
}
