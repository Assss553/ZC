package com.rox.tv

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TvProtocolTest {
    @Test fun parsesMessages() {
        assertEquals(TvProtocol.Msg.Hello("123456", "Honor"), TvProtocol.parse("""{"type":"hello","code":"123456","device":"Honor"}"""))
        val s = TvProtocol.parse("""{"type":"subtitle","text":"مرحبا","speaker":"Elena","ttlMs":99999,"id":3}""") as TvProtocol.Msg.Subtitle
        assertEquals(30_000L, s.ttlMs) // clamped
        assertEquals("Elena: مرحبا", TvProtocol.display(s))
        assertEquals(TvProtocol.Msg.Clear, TvProtocol.parse("""{"type":"clear"}"""))
        assertTrue(TvProtocol.parse("garbage") is TvProtocol.Msg.Unknown)
    }

    @Test fun codeIsSixDigits() { repeat(50) { assertTrue(TvProtocol.newCode().matches(Regex("\\d{6}"))) } }

    @Test fun onlyPairedPhonesCanShowText() {
        val st = SubtitleState("111222")
        val phone = Any(); val stranger = Any()
        assertFalse(st.onHello(stranger, TvProtocol.Msg.Hello("000000", "x")))
        assertFalse(st.onSubtitle(stranger, TvProtocol.Msg.Subtitle("hack", "", "DIALOG", 4000, 1), 0))
        assertTrue(st.onHello(phone, TvProtocol.Msg.Hello("111222", "Honor")))
        assertTrue(st.onSubtitle(phone, TvProtocol.Msg.Subtitle("سطر", "", "DIALOG", 4000, 2), 0))
        assertEquals("سطر", st.text)
        assertFalse("same text must not re-render", st.onSubtitle(phone, TvProtocol.Msg.Subtitle("سطر", "", "DIALOG", 4000, 3), 100))
    }

    @Test fun subtitleDisappearsAfterTtlAndOnClear() {
        val st = SubtitleState("1"); val p = Any()
        st.onHello(p, TvProtocol.Msg.Hello("1", ""))
        st.onSubtitle(p, TvProtocol.Msg.Subtitle("a", "", "DIALOG", 1000, 1), 0)
        assertFalse(st.tick(500)); assertTrue(st.tick(1500)); assertEquals("", st.text)
        st.onSubtitle(p, TvProtocol.Msg.Subtitle("b", "", "DIALOG", 9000, 2), 2000)
        assertTrue(st.onClear(p)); assertEquals("", st.text)
    }
}
