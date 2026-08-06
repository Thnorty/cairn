import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing is configured from android/key.properties (see
// android/key.properties.example for the shape). That file and the keystore it
// points to hold secrets and are gitignored, so this loads them only when the
// file is present and otherwise falls back to debug signing below, keeping
// local and CI debug builds working without the (secret) upload keystore.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.thnorty.cairn"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Required by flutter_local_notifications 10+ (Phase 6's habit
        // reminders): it uses java.time to schedule notifications with
        // backwards compatibility on older Android versions, and the plugin's
        // AAR metadata fails the build outright without this - even for an
        // app that schedules nothing. See the plugin's own "Gradle setup"
        // README section.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.thnorty.cairn"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Desugaring pushes the method count up; multidex is what the plugin's
        // README pairs with it, and it is a no-op on the API 21+ devices this
        // app targets (they support multidex natively).
        multiDexEnabled = true
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Use the real upload keystore when android/key.properties exists,
            // otherwise fall back to debug so `flutter run --release` and CI
            // still work without the secret keystore.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

dependencies {
    // The desugaring runtime enabled by `isCoreLibraryDesugaringEnabled`
    // above. Version pinned to what flutter_local_notifications 20.x's README
    // specifies; it has to be bumped alongside that plugin, not
    // independently.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
