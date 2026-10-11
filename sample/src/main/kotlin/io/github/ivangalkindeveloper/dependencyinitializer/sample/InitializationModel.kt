package io.github.ivangalkindeveloper.dependencyinitializer.sample

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import io.github.ivangalkindeveloper.dependencyinitializer.*
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

sealed interface InitializationState {
    data object Loading : InitializationState
    data class Ready(val result: DIResult<InitializationProcess, AppDependencies>) : InitializationState
    data class Failed(val message: String) : InitializationState
}

class InitializationModel : ViewModel() {
    private val mutableState = MutableStateFlow<InitializationState>(InitializationState.Loading)
    val state = mutableState.asStateFlow()
    private val mutableEvents = MutableStateFlow<List<String>>(emptyList())
    val events = mutableEvents.asStateFlow()
    private var task: Job? = null

    init { initialize() }

    fun initialize(simulateFailure: Boolean = false) = start {
        DependencyInitializer(
            createProcess = { InitializationProcess(simulateFailure = simulateFailure) },
            stepSets = initializationStepSets,
            onStart = { mutableEvents.value = listOf("Initialization started") },
            onStartStep = { log("Start: ${it.title}") },
            onSuccessStep = { step, duration, _ -> log("Done: ${step.title} (${(duration / 1_000_000).toLong()} ms)") },
            onSuccess = { result, duration ->
                log("Ready in ${(duration / 1_000_000).toLong()} ms")
                mutableState.value = InitializationState.Ready(result)
            },
            onError = { error, _, step, _ ->
                log("Error: ${step.title}")
                mutableState.value = InitializationState.Failed(error.message ?: "Initialization failed")
            },
        ).run()
    }

    fun repeatAll() {
        val result = (state.value as? InitializationState.Ready)?.result ?: return
        start { result.runRepeat() }
    }

    fun switchEnvironment() {
        val result = (state.value as? InitializationState.Ready)?.result ?: return
        val environment = if (result.container.environment == "Production") "Sandbox" else "Production"
        start {
            result.runRepeat(
                createProcess = { InitializationProcess(environment, database = result.container.database) },
                stepSets = result.repeatStepSets,
            )
        }
    }

    private fun start(block: suspend () -> Unit) {
        task?.cancel()
        mutableState.value = InitializationState.Loading
        task = viewModelScope.launch { block() }
    }

    private fun log(event: String) { mutableEvents.value = mutableEvents.value + event }
}
