pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "fatwabot"

include(":app")
include(":core:common")
include(":core:designsystem")
include(":core:prayer")
include(":core:network")
include(":core:config")
include(":feature:home")
include(":feature:prayer")
include(":widget")
include(":feature:tasbeeh")
include(":core:content")
include(":feature:azkar")
