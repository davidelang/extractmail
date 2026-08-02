package com.davidelang.extractmail

/**
 * Android surface for extractmail M1.
 * Full HTML extractors: reference-js / stdin CLI on host.
 * AAR ships stable package surface for VE thin consumers.
 */
object Extractmail {
    const val VERSION = 1
    fun hostCliHint(): String =
        "python3 python/extractmail_stdin.py --type auto < body.html"
}
