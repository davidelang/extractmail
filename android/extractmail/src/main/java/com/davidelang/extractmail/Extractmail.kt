package com.davidelang.extractmail

/**
 * Android surface for extractmail (M2).
 * Full HTML extract: host CLI (`scripts/extractmail` / `python/extractmail_stdin.py`).
 * AAR ships stable types/constants for VE thin consumers — no on-device HTML parse.
 */
object Extractmail {
    const val VERSION = 2
    const val TYPE_SHELL = "shell-ereceipt"
    const val TYPE_SAMS_CLUB = "samsclub-fuel"
    const val TYPE_AUTO = "auto"

    val KNOWN_TYPES: List<String> = listOf(TYPE_SHELL, TYPE_SAMS_CLUB)

    fun hostCliHint(): String =
        "scripts/extractmail --type auto < body.html"

    fun hostCliForType(typeKey: String): String =
        "scripts/extractmail --type $typeKey < body.html"
}
