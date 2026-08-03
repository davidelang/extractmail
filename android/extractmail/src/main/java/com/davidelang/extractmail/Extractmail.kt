package com.davidelang.extractmail

/**
 * Android surface for extractmail.
 *
 * Full HTML extract on host: `scripts/extractmail` / `python/extractmail_stdin.py`.
 * AAR ships **type keys, detect heuristics, and fuel contract constants** so the
 * VehicleExpenses app can stay a thin consumer (live Kotlin parsers may remain
 * until a pure-Kotlin port; detect + types SoT is this library).
 */
object Extractmail {
    const val VERSION = 3

    const val TYPE_SHELL = "shell-ereceipt"
    const val TYPE_SAMS_CLUB = "samsclub-fuel"
    const val TYPE_AUTO = "auto"

    val KNOWN_TYPES: List<String> = listOf(TYPE_SHELL, TYPE_SAMS_CLUB)

    /** Fuel row contract (loyalty / email fills). */
    const val FUEL_VEHICLE_ID_UNASSIGNED = 0
    const val FUEL_ODOMETER = 0
    const val FUEL_PARTIAL_FILL = false
    const val FUEL_ECONOMY_IGNORED = false

    fun hostCliHint(): String =
        "scripts/extractmail --type auto < body.html"

    fun hostCliForType(typeKey: String): String =
        "scripts/extractmail --type $typeKey < body.html"

    /**
     * Detect builtin receipt type from HTML + headers (case-insensitive).
     * Order matches host CLI / YAML detect: Shell exclusive markers → Sam's → null.
     * @return [TYPE_SHELL], [TYPE_SAMS_CLUB], or null
     */
    fun detectType(
        html: String?,
        fromHeader: String? = null,
        subject: String? = null,
    ): String? {
        if (html.isNullOrBlank()) return null
        val blob = listOf(html, fromHeader.orEmpty(), subject.orEmpty())
            .joinToString("\n")
            .lowercase()

        if (looksShell(blob)) return TYPE_SHELL
        if (looksSamsClub(blob)) return TYPE_SAMS_CLUB
        return null
    }

    fun looksShell(blobLowercase: String): Boolean {
        val b = blobLowercase.lowercase()
        return b.contains("ereceiptshell") ||
            b.contains("mail.ereceiptshell.com") ||
            b.contains("shell e-receipt") ||
            (b.contains("welcome to shell") && b.contains("amount paid"))
    }

    fun looksSamsClub(blobLowercase: String): Boolean {
        val b = blobLowercase.lowercase()
        if (b.contains("ereceiptshell")) return false
        return b.contains("samsclub.com") ||
            b.contains("sam's club fuel") ||
            b.contains("fuel station receipt") ||
            (b.contains("sam's club") && b.contains("total paid"))
    }

    /** True if [typeKey] is a known builtin (not auto). */
    fun isKnownType(typeKey: String): Boolean =
        typeKey in KNOWN_TYPES
}
