package com.dialect.voice.shared.prompt

import java.time.LocalDate
import java.time.format.DateTimeFormatter

// jvmMain exists only so commonMain has a target this dev machine (no Xcode/iOS SDK) can
// actually compile and unit-test - see shared/build.gradle.kts header. This implementation
// is never shipped in the iOS app.
actual fun todayFormatted(): String =
    LocalDate.now().format(DateTimeFormatter.ofPattern("d MMMM yyyy"))
