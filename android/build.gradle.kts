allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Align every module (the app plus every native plugin subproject) onto
// Java/Kotlin 17, so no module ever has a Kotlin JVM target above its Java
// target. Several plugins used here (photo_manager, flutter_image_compress,
// image_picker_android) each pin their own Kotlin Gradle Plugin version via
// a local `buildscript` block, independent of the version this project
// centralizes in settings.gradle.kts. That means a statically-typed
// reference to AGP's BaseExtension or Kotlin's KotlinCompile task class
// written here would resolve against only one of those versions and could
// silently fail to match objects created by a plugin pinning a different
// one. Configuring by property/method name through Gradle's Groovy interop
// (`withGroovyBuilder`) dispatches at runtime instead, so it reaches every
// module regardless of which plugin-specific Kotlin/AGP version created it.
subprojects {
    // The existing `evaluationDependsOn(":app")` above (needed by the Flutter
    // Gradle plugin) forces :app, and transitively every plugin subproject
    // referenced from it, to be evaluated eagerly while ROOT's own script is
    // still running - so by the time we get here every subproject is
    // typically already evaluated, and calling `afterEvaluate` on it would
    // throw ("Cannot run Project.afterEvaluate(Action) when the project is
    // already evaluated"). Guard on project state instead of assuming either
    // ordering.
    val alignCompileOptions: () -> Unit = {
        extensions.findByName("android")?.let { androidExt ->
            try {
                androidExt.withGroovyBuilder {
                    "compileOptions" {
                        setProperty("sourceCompatibility", JavaVersion.VERSION_17)
                        setProperty("targetCompatibility", JavaVersion.VERSION_17)
                    }
                }
            } catch (_: Throwable) {
                // No compileOptions on this "android" extension; nothing to align.
            }
        }
    }
    if (state.executed) {
        alignCompileOptions()
    } else {
        afterEvaluate { alignCompileOptions() }
    }
    tasks.matching { it.name.startsWith("compile") && it.name.contains("Kotlin") }.configureEach {
        try {
            withGroovyBuilder {
                "kotlinOptions" {
                    setProperty("jvmTarget", "17")
                }
            }
        } catch (_: Throwable) {
            // Kotlin Gradle Plugin 2.2+ dropped the legacy kotlinOptions DSL in
            // favor of compilerOptions; modules on that line already set their
            // own jvmTarget and don't need this override.
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
