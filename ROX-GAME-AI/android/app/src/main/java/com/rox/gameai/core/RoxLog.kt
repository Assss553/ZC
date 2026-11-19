package com.rox.gameai.core

import android.content.Context
import android.util.Log
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.Executors

/** App-wide log: in memory (for the Logs screen) + rotating file in app storage. Errors are never hidden. */
object RoxLog {
    data class Entry(val time: Long, val level: Char, val tag: String, val message: String)

    private val _entries = MutableStateFlow<List<Entry>>(emptyList())
    val entries: StateFlow<List<Entry>> = _entries
    private var file: File? = null
    private val io = Executors.newSingleThreadExecutor()
    private val fmt = SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", Locale.US)

    fun init(context: Context) {
        file = File(context.filesDir, "rox.log").also { if (it.length() > 2_000_000) it.delete() }
    }

    fun i(tag: String, msg: String) = add('I', tag, msg, null)
    fun w(tag: String, msg: String) = add('W', tag, msg, null)
    fun e(tag: String, msg: String, t: Throwable? = null) = add('E', tag, msg, t)

    @Synchronized
    private fun add(level: Char, tag: String, msg: String, t: Throwable?) {
        val text = if (t != null) "$msg: ${t.javaClass.simpleName}: ${t.message}" else msg
        when (level) { 'E' -> Log.e("ROX/$tag", text, t); 'W' -> Log.w("ROX/$tag", text); else -> Log.i("ROX/$tag", text) }
        val e = Entry(System.currentTimeMillis(), level, tag, text)
        _entries.value = (_entries.value + e).takeLast(800)
        val f = file ?: return
        io.execute { runCatching { f.appendText("${fmt.format(Date(e.time))} $level/$tag: $text\n") } }
    }

    fun clear() { _entries.value = emptyList(); file?.let { f -> io.execute { runCatching { f.writeText("") } } } }

    fun exportText(): String = _entries.value.joinToString("\n") { "${fmt.format(Date(it.time))} ${it.level}/${it.tag}: ${it.message}" }
}
