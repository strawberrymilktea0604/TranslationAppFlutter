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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
subprojects {
    val configureNamespace = {
        if (extensions.findByName("android") != null) {
            val android = extensions.getByName("android") as com.android.build.gradle.BaseExtension
            if (android.namespace.isNullOrEmpty()) {
                android.namespace = project.group.toString()
            }
        }
    }

    // Kiểm tra xem project đã evaluate xong chưa
    if (state.executed) {
        configureNamespace() // Nếu xong rồi thì chạy luôn
    } else {
        afterEvaluate { configureNamespace() } // Nếu chưa thì đặt lịch chờ
    }
}