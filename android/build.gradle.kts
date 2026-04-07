    buildscript {
        repositories {
            google()
            mavenCentral()
        }
        dependencies {
            classpath("com.android.tools.build:gradle:8.9.1") // match your AGP
        }
    }

    allprojects {
        repositories {
            google()
            mavenCentral()
        }
    }

    // Change build directory to root ../../build
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