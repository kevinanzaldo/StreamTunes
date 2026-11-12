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
    afterEvaluate {
        val androidExt = extensions.findByName("android") ?: return@afterEvaluate
        try {
            val method = androidExt.javaClass.getMethod("compileSdkVersion", Int::class.javaPrimitiveType)
            method.invoke(androidExt, 35)
        } catch (_: NoSuchMethodException) {
            try {
                val method = androidExt.javaClass.getMethod("setCompileSdk", Int::class.javaPrimitiveType)
                method.invoke(androidExt, 35)
            } catch (_: Exception) {}
        } catch (_: Exception) {}
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
