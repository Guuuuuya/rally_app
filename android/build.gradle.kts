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

    // mapbox_maps_flutter's build.gradle calls kotlin { } / kotlin() but does not
    // apply the Kotlin plugin on AGP 9 -> apply it here for every Android module.
    pluginManager.withPlugin("com.android.library") {
        plugins.apply("org.jetbrains.kotlin.android")
    }
    pluginManager.withPlugin("com.android.application") {
        plugins.apply("org.jetbrains.kotlin.android")
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
