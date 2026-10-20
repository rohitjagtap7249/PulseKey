package com.rohitjagtap.pulsekey

import android.content.Context
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

object EventLog {
    private const val PREFS = "pulsekey_log"
    private const val KEY = "lines"

    @Synchronized
    fun add(ctx: Context, msg: String) {
        val fmt = SimpleDateFormat("HH:mm:ss", Locale.US)
        val p = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val old = p.getString(KEY, "") ?: ""
        val lines: ArrayList<String> =
            if (old.isEmpty()) ArrayList() else ArrayList(old.split("\n"))
        lines.add(fmt.format(Date()) + " " + msg.replace("\n", " "))
        while (lines.size > 40) lines.removeAt(0)
        p.edit().putString(KEY, lines.joinToString("\n")).commit()
    }

    @Synchronized
    fun read(ctx: Context): List<String> {
        val p = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val old = p.getString(KEY, "") ?: ""
        if (old.isEmpty()) return emptyList()
        return old.split("\n").reversed()
    }

    @Synchronized
    fun clear(ctx: Context) {
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putString(KEY, "").commit()
    }
}
