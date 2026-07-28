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
// AGP 8+ requires every module to declare a namespace. Some older plugin
// dependencies (e.g. image_gallery_saver, pulled in by stream_chat_flutter)
// predate this and only declare a manifest package, so fill it in for them.
// This must be registered before the evaluationDependsOn(":app") block below,
// which triggers early evaluation.
subprojects {
    afterEvaluate {
        val androidExt = extensions.findByName("android")
        if (androidExt is com.android.build.api.dsl.LibraryExtension && androidExt.namespace == null) {
            androidExt.namespace = project.group.toString()
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
