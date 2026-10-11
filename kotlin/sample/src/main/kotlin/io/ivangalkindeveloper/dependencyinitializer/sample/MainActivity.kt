package io.ivangalkindeveloper.dependencyinitializer.sample

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme {
                val model: InitializationModel = viewModel()
                val state by model.state.collectAsStateWithLifecycle()
                val events by model.events.collectAsStateWithLifecycle()
                Column(
                    Modifier.fillMaxSize().systemBarsPadding().verticalScroll(rememberScrollState()).padding(24.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Text("Dependency Initializer", style = MaterialTheme.typography.headlineSmall)
                    when (val current = state) {
                        InitializationState.Loading -> CircularProgressIndicator()
                        is InitializationState.Ready -> {
                            val container = current.result.container
                            Text("Environment: ${container.environment}")
                            Text("Database instance: ${container.database.instance}")
                            Text(container.profile)
                            Text(container.configuration)
                            Button(onClick = model::repeatAll) { Text("Repeat all steps") }
                            Button(onClick = model::switchEnvironment) { Text("Switch environment (repeatable steps)") }
                            Button(onClick = { model.initialize(simulateFailure = true) }) { Text("Simulate failure") }
                        }
                        is InitializationState.Failed -> {
                            Text(current.message, color = MaterialTheme.colorScheme.error)
                            Button(onClick = { model.initialize() }) { Text("Retry") }
                        }
                    }
                    HorizontalDivider()
                    events.forEach { Text(it) }
                }
            }
        }
    }
}
