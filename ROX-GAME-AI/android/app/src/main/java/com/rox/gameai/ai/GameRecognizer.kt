package com.rox.gameai.ai

import com.rox.gameai.core.GameProfile
import com.rox.gameai.core.RoxLog
import com.rox.gameai.core.Store
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/**
 * ROX GAME RECOGNITION.
 *  1. Title reported by the console itself over LAN discovery (most reliable, PS4/PS5 send running-app-name).
 *  2. Otherwise OCR text on screen matched against the saved game library.
 *  3. Otherwise "unknown" → the UI shows the manual picker.
 * The language is identified from accumulated OCR text and saved in the game's profile.
 */
class GameRecognizer(private val store: Store) {
    data class State(val profile: GameProfile? = null, val source: String = "", val needsManualPick: Boolean = false)
    private val _state = MutableStateFlow(State())
    val state: StateFlow<State> = _state
    private val textSample = StringBuilder()
    private var attempts = 0

    fun reset() { _state.value = State(); textSample.clear(); attempts = 0 }

    private fun idFor(name: String) = GameMatcher.normalize(name).replace(" ", "_").ifEmpty { "game_${System.currentTimeMillis()}" }

    fun fromConsole(appName: String?, titleId: String?) {
        if (appName.isNullOrBlank()) return
        if (_state.value.profile?.name == appName) return
        val existing = store.games.value.firstOrNull { (titleId != null && it.titleId == titleId) || GameMatcher.similarity(it.name, appName) > 0.95f }
        select(existing ?: GameProfile(idFor(appName), appName, titleId ?: ""), "console")
    }

    fun fromScreenText(text: String) {
        if (_state.value.profile != null) return
        textSample.append(' ').append(text)
        if (textSample.length > 4000) textSample.delete(0, textSample.length - 4000)
        attempts++
        val match = GameMatcher.bestMatch(textSample.toString(), store.games.value.map { it.name })
        if (match != null) {
            select(store.games.value.first { it.name == match }, "screen")
        } else if (attempts >= 6 && !_state.value.needsManualPick) {
            _state.value = _state.value.copy(needsManualPick = true)
            RoxLog.w("Recognition", "Game not recognised automatically — manual selection requested")
        }
    }

    fun select(p: GameProfile, source: String) {
        val updated = p.copy(lastPlayed = System.currentTimeMillis(), timesPlayed = p.timesPlayed + 1)
        store.upsertGame(updated)
        _state.value = State(updated, source, false)
        RoxLog.i("Recognition", "Game: ${p.name} (via $source)")
    }

    fun manual(name: String) {
        val existing = store.games.value.firstOrNull { it.name.equals(name, true) }
        select(existing ?: GameProfile(idFor(name), name), "manual")
    }

    fun setLanguage(lang: String) {
        val p = _state.value.profile ?: return
        if (p.language == lang || lang == "und") return
        val u = p.copy(language = lang)
        store.upsertGame(u)
        _state.value = _state.value.copy(profile = u)
        RoxLog.i("Recognition", "Game language: $lang")
    }

    fun updateProfile(p: GameProfile) {
        store.upsertGame(p)
        if (_state.value.profile?.id == p.id) _state.value = _state.value.copy(profile = p)
    }
}
