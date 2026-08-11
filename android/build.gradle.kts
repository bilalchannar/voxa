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
    afterEvaluate {
        if (project.extensions.findByName("android") != null) {
            val android = project.extensions.getByName("android") as com.android.build.gradle.BaseExtension
            android.compileSdkVersion(36)
        }
    }
}


subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    tasks.matching { it.name.startsWith("process") && it.name.endsWith("Manifest") }.configureEach {
        doFirst {
            val gradleCache = file("D:/GradleCache/caches")
            val userCache = file("${System.getProperty("user.home")}/.gradle/caches")
            listOf(gradleCache, userCache).forEach { cacheDir ->
                if (cacheDir.exists()) {
                    cacheDir.walkTopDown().filter { file -> file.name == "AndroidManifest.xml" && file.path.contains("iris-rtc") }.forEach { xmlFile ->
                        try {
                            val content = xmlFile.readText()
                            if (content.contains("package=\"io.agora.rtc\"")) {
                                xmlFile.writeText(content.replace("package=\"io.agora.rtc\"", "package=\"io.agora.rtc.iris\""))
                                println("Patched iris-rtc AndroidManifest.xml package namespace successfully!")
                            }
                        } catch (_: Exception) {
                        }
                    }
                }
            }
        }
    }
}


tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
