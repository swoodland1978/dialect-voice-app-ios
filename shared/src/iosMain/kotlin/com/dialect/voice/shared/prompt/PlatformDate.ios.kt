package com.dialect.voice.shared.prompt

import platform.Foundation.NSDate
import platform.Foundation.NSDateFormatter

// Verified: `./gradlew :shared:compileKotlinIosSimulatorArm64` compiles this for real against
// Kotlin/Native's bundled Apple platform declarations (no Xcode needed for that step - see
// STATUS.md). Not yet linked/run - the final .framework link and any actual app run needs
// Xcode's own xcodebuild, which this dev machine doesn't have.
actual fun todayFormatted(): String {
    val formatter = NSDateFormatter()
    formatter.dateFormat = "d MMMM yyyy"
    return formatter.stringFromDate(NSDate())
}
