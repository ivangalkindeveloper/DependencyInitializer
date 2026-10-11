plugins { kotlin("jvm"); `java-library`; `maven-publish` }
kotlin {
    jvmToolchain(17)
    compilerOptions { jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_1_8) }
}
java {
    sourceCompatibility = JavaVersion.VERSION_1_8
    targetCompatibility = JavaVersion.VERSION_1_8
    withSourcesJar()
}
dependencies {
    api("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.10.2")
    runtimeOnly("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")
    testImplementation(kotlin("test-junit"))
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.10.2")
}
publishing {
    publications {
        create<MavenPublication>("maven") {
            from(components["java"])
            artifactId = "dependency-initializer"
            pom { name.set("DependencyInitializer"); description.set("Kotlin Android port of the Swift DependencyInitializer package") }
        }
    }
}
