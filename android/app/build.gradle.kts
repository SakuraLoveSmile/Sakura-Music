import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.sakuramusic.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    // Stable release signing so APKs share one key and can overlay-install older
    // builds. CI decodes the keystore into android/app/keystore.jks and writes
    // android/app/key.properties; locally the same keystore is reused. Without
    // key.properties it falls back to the debug key so `flutter run --release` works.
    val keystoreProperties =
        if (file("key.properties").exists()) {
            Properties().apply {
                file("key.properties").inputStream().use { load(it) }
            }
        } else {
            null
        }

    signingConfigs {
        create("release") {
            val props = keystoreProperties
            if (props != null) {
                storeFile = file(props.getProperty("storeFile")!!)
                storePassword = props.getProperty("storePassword")
                keyAlias = props.getProperty("keyAlias")
                keyPassword = props.getProperty("keyPassword")
            } else {
                initWith(signingConfigs.getByName("debug"))
            }
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.sakuramusic.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

dependencies {
    // Lyricon status-bar lyrics provider SDK (resolved from mavenCentral,
    // already present in the root allprojects repositories).
    implementation("io.github.proify.lyricon:provider:0.1.70")
}

flutter {
    source = "../.."
}
