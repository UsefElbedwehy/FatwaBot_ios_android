plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
    alias(libs.plugins.ksp)
    alias(libs.plugins.hilt)
    alias(libs.plugins.google.services)
    alias(libs.plugins.crashlytics)
}

android {
    namespace = "com.fatwabot.app"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.fatwabot.app"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "0.1.0"
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
    buildFeatures {
        compose = true
        buildConfig = true
    }
}

dependencies {
    implementation(project(":core:common"))
    implementation(project(":core:designsystem"))
    implementation(project(":core:prayer"))
    implementation(project(":feature:prayer"))
    implementation(project(":core:config"))
    implementation(project(":core:network"))
    implementation(project(":widget"))
    implementation(project(":feature:tasbeeh"))
    implementation(project(":core:content"))
    implementation(project(":feature:azkar"))
    implementation(project(":feature:dua"))
    implementation(project(":feature:awrad"))
    implementation(project(":feature:hadith"))
    implementation(project(":feature:gamification"))
    implementation(project(":feature:leaderboard"))
    implementation(project(":feature:searchhistory"))
    implementation(project(":feature:onboarding"))
    implementation(project(":feature:fatwasearch"))

    val composeBom = platform(libs.compose.bom)
    implementation(composeBom)
    implementation(libs.androidx.core.ktx)
    // Per-app language selection: AppCompatDelegate.setApplicationLocales is
    // the only route that works below API 33, where the platform LocaleManager
    // does not exist. minSdk is 26, so the framework API alone would leave most
    // of the supported range with no way to switch language in-app.
    implementation(libs.androidx.appcompat)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.navigation.compose)
    implementation(libs.compose.ui)
    implementation(libs.compose.material3)
    implementation(libs.compose.material.icons.extended)
    implementation(libs.hilt.android)
    implementation(libs.hilt.navigation.compose)
    implementation(libs.kotlinx.serialization.json)
    implementation(libs.kotlinx.datetime)
    implementation(libs.glance.appwidget)
    implementation(platform(libs.firebase.bom))
    implementation(libs.firebase.messaging)
    implementation(libs.firebase.analytics)
    implementation(libs.firebase.crashlytics)
    // Google Sign-In via Credential Manager (returns a Google ID token that the
    // backend verifies against Google's JWKS).
    implementation(libs.androidx.credentials)
    implementation(libs.androidx.credentials.play.services)
    implementation(libs.googleid)
    ksp(libs.hilt.compiler)

    testImplementation(libs.junit)
}
