package com.dialect.voice.shared.prompt

// Today's date, formatted like "2 September 2026" - fed into PromptBuilder.currentAffairsHint.
// expect/actual because date formatting is platform API (NSDateFormatter on iOS, java.time on
// the jvmMain verification target); there's no portable multiplatform clock/formatter
// dependency pulled in here to keep this module's dependency footprint minimal.
expect fun todayFormatted(): String
