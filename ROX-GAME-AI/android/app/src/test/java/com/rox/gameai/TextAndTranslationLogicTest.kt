package com.rox.gameai

import com.rox.gameai.ai.GameMatcher
import com.rox.gameai.ai.TextClassifier
import com.rox.gameai.core.IRect
import com.rox.gameai.core.TextKind
import com.rox.gameai.translation.DialogContext
import com.rox.gameai.translation.TranslationCache
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class TextAndTranslationLogicTest {
    private val W = 1280; private val H = 720

    @Test fun dialogueWithSpeaker() {
        val r = TextClassifier.classify("Elena: We must find the ancient key before nightfall.", IRect(150, 610, 1100, 660), W, H)
        assertEquals(TextKind.DIALOG, r.kind); assertEquals("Elena", r.speaker); assertEquals("We must find the ancient key before nightfall.", r.body)
    }

    @Test fun missionMenuNotification() {
        assertEquals(TextKind.MISSION, TextClassifier.classify("Mission: Reach the old lighthouse", IRect(40, 40, 600, 80), W, H).kind)
        assertEquals(TextKind.MENU, TextClassifier.classify("Inventory", IRect(40, 480, 200, 510), W, H).kind)
        assertEquals(TextKind.NOTIFICATION, TextClassifier.classify("Trophy unlocked", IRect(980, 30, 1250, 70), W, H).kind)
        assertEquals(TextKind.ITEM, TextClassifier.classify("Rifle ammo 30/120", IRect(1000, 600, 1250, 640), W, H).kind)
        assertEquals(TextKind.DIALOG, TextClassifier.classify("I will not leave you behind again", IRect(200, 600, 1080, 650), W, H).kind)
    }

    @Test fun cacheNormalisesAndPreventsRepeats() {
        val c = TranslationCache(repeatWindowMs = 1000)
        c.put("Hello   World", "مرحبا بالعالم")
        assertEquals("مرحبا بالعالم", c.get("hello world"))
        assertNull(c.get("other"))
        assertFalse(c.seenRecently("Hello World", 0))
        assertTrue(c.seenRecently("hello  world", 500))
        assertFalse(c.seenRecently("hello world", 5000))
    }

    @Test fun cacheIsBounded() {
        val c = TranslationCache(capacity = 10)
        repeat(50) { c.put("t$it", "x") }
        assertEquals(10, c.size())
        assertNull(c.get("t0")); assertEquals("x", c.get("t49"))
    }

    @Test fun dialogContextSpeakerAttribution() {
        val d = DialogContext()
        d.add(DialogContext.Line(1000, "Marcus", "Go", "اذهب"))
        assertEquals("Marcus", d.lastSpeaker(3000))
        assertEquals("", d.lastSpeaker(10_000))
    }

    @Test fun gameMatching() {
        assertTrue(GameMatcher.similarity("Ghost of Tsushima™", "ghost of tsushima") > 0.95f)
        val lib = listOf("Elden Ring", "Ghost of Tsushima", "Gran Turismo 7")
        assertEquals("Elden Ring", GameMatcher.bestMatch("PRESS ANY BUTTON  ELDEN RING  ©2022", lib))
        assertNull(GameMatcher.bestMatch("Continue Inventory Map", lib))
    }
}
