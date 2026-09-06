package com.dialect.voice.shared.prompt

// Builds the actual system prompt sent to the backend: the dialect's persona (Dialects.kt)
// plus three fixed hints shared across every dialect, ported from the Android app's
// ChatViewModel.sendMessage(). `todayFormatted` is supplied by the caller (e.g. "2 September
// 2026") rather than computed here, since date formatting is platform-specific
// (NSDateFormatter on iOS, java.time on the Android/JVM sides) and this module has no
// platform date dependency of its own - see PlatformDate.kt's expect declaration.
object PromptBuilder {

    // Used to hard-cap every reply at ~40 words regardless of what was asked, which gutted
    // real questions (e.g. "how do I do trigonometry?" got a one-liner). Now it only
    // discourages padding for genuinely simple chat, while explicitly telling the model to
    // give a real, complete, detailed answer - still in accent - when the question calls for one.
    private const val LENGTH_HINT = "Match your reply's length to what's actually being asked: keep " +
        "simple chat and banter short and punchy (1-2 sentences), but when someone asks a real " +
        "question that needs explaining - how something works, how to do something, instructions, " +
        "a proper opinion - give a complete, clear, properly detailed answer, still fully in " +
        "character and accent. Never pad for the sake of length, and never cut a real answer " +
        "short just to keep it brief."

    // Shared across every dialect (unlike the dialect-specific personality/slang in
    // Dialects.kt) since it's a fixed bit, not something that needs rewriting per accent - the
    // model naturally renders it in whatever voice is already active.
    private const val SPARETIME_HINT = "If someone asks what you do in your spare time / free time, " +
        "say something like: \"I am writing a book about different farts people do. " +
        "I'm currently working on a chapter about why my farts smell much better than " +
        "other people's.\" - reword it naturally in your own voice/accent rather than " +
        "reciting it verbatim."

    // The model's training data has a fixed cutoff and gets no live/web data here, so left to
    // itself it'll confidently state whatever was true as of that cutoff (e.g. a stale head
    // of state) as if it's current fact. Telling it today's actual date plus to hedge on
    // anything that might have changed since turns that into an honest "I'm not sure that's
    // still current" in-voice, rather than a confidently wrong answer.
    //
    // A hard-coded specific correction (spelling out who currently holds some office) was
    // tried on the Android side and deliberately removed - it's a maintenance trap that goes
    // stale at the next election exactly like the problem it was patching. The real fix is
    // picking a backend model with a materially recent knowledge cutoff; this hedge is the
    // general-purpose safety net for whatever's still after that cutoff.
    private fun currentAffairsHint(todayFormatted: String): String =
        "Today's date is $todayFormatted. Your training data has a cutoff " +
            "date before this, so you won't know about anything that changed after it - " +
            "who currently holds a given office or role, recent news, this year's " +
            "events, and so on. If you're asked about something like that and you're not " +
            "confident your information is still current, say so honestly in your own " +
            "voice/accent instead of confidently stating something that might now be out " +
            "of date."

    fun buildFullSystemPrompt(dialectSystemPrompt: String, todayFormatted: String): String =
        "$dialectSystemPrompt\n\n$LENGTH_HINT\n\n$SPARETIME_HINT\n\n${currentAffairsHint(todayFormatted)}"
}
