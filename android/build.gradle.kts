plugins {
    id("com.android.application") version "8.6.0" apply false
    id("com.android.library") version "8.6.0" apply false
    id("org.jetbrains.kotlin.android") version "1.9.24" apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }

    // Prevent Jetify from processing incompatible byte-buddy classes (caused "Unsupported class file major version 68").
    // Exclude byte-buddy from all configurations and also force a safe version if any plugin brings it in.
    // This avoids Jetifier/ASM parse errors on newer class file versions.
    configurations.all {
        // Exclude any transitive incoming byte-buddy jars from being processed
        exclude(group = "net.bytebuddy", module = "byte-buddy")
        // Force a safe, compatible byte-buddy version if it is requested transitively
        resolutionStrategy.force("net.bytebuddy:byte-buddy:1.18.4")
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}