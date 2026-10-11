package io.ivangalkindeveloper.dependencyinitializer.sample

import io.ivangalkindeveloper.dependencyinitializer.*
import java.util.concurrent.atomic.AtomicInteger
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext

class SampleDatabase {
    val instance: Int = count.incrementAndGet()
    private companion object { val count = AtomicInteger() }
}

class SampleRepository(private val environment: String, val database: SampleDatabase) {
    suspend fun loadProfile(): String { delay(250); return "Profile from $environment" }
    suspend fun loadConfiguration(): String { delay(350); return "Configuration from $environment" }
}

data class AppDependencies(
    val environment: String,
    val database: SampleDatabase,
    val repository: SampleRepository,
    val profile: String,
    val configuration: String,
)

class InitializationProcess(
    val environment: String = "Production",
    var database: SampleDatabase? = null,
    val simulateFailure: Boolean = false,
) : DIProcess<AppDependencies> {
    var repository: SampleRepository? = null
    var profile: String? = null
    var configuration: String? = null

    override val toContainer get() = AppDependencies(
        environment, checkNotNull(database), checkNotNull(repository), checkNotNull(profile), checkNotNull(configuration),
    )
}

val initializationStepSets: List<StepSet<InitializationProcess>> = listOf(
    StepSet(sync = listOf(
        SyncInitializationStep(title = "Database") { it.database = SampleDatabase() },
        SyncInitializationStep(title = "Repository", type = DIStepType.REPEATABLE) {
            it.repository = SampleRepository(it.environment, checkNotNull(it.database))
        },
    )),
    StepSet(async = listOf(
        AsyncInitializationStep(title = "Profile", type = DIStepType.REPEATABLE) { process ->
            val profile = checkNotNull(process.repository).loadProfile()
            withContext(Dispatchers.Main.immediate) { process.profile = profile }
        },
        AsyncInitializationStep(title = "Configuration", type = DIStepType.REPEATABLE) { process ->
            val configuration = checkNotNull(process.repository).loadConfiguration()
            check(!process.simulateFailure) { "Simulated configuration error" }
            withContext(Dispatchers.Main.immediate) { process.configuration = configuration }
        },
    )),
    StepSet(sync = listOf(
        SyncInitializationStep(title = "Validate", type = DIStepType.REPEATABLE) {
            checkNotNull(it.profile); checkNotNull(it.configuration)
        },
    )),
)
