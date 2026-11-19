package com.rox.gameai

import com.rox.gameai.connection.DdpProtocol
import com.rox.gameai.core.ConsoleType
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class DdpProtocolTest {
    @Test fun searchRequestFormat() {
        val ps5 = String(DdpProtocol.searchRequest(true))
        assertTrue(ps5.startsWith("SRCH * HTTP/1.1\n"))
        assertTrue(ps5.contains("device-discovery-protocol-version:00030010"))
        assertTrue(String(DdpProtocol.searchRequest(false)).contains("00020020"))
    }

    @Test fun parsesPs5OnWithRunningGame() {
        val txt = "HTTP/1.1 200 Ok\r\nhost-id:ABCDEF123456\r\nhost-type:PS5\r\nhost-name:Living Room\r\nhost-request-port:997\r\nrunning-app-name:Ghost of Tsushima\r\nrunning-app-titleid:PPSA01234\r\nsystem-version:07000000\r\n"
        val r = DdpProtocol.parse(txt, "192.168.1.20")!!
        assertEquals(ConsoleType.PS5, r.type)
        assertEquals(DdpProtocol.PowerState.ON, r.state)
        assertEquals("Living Room", r.hostName)
        assertEquals("Ghost of Tsushima", r.runningAppName)
        assertEquals("PPSA01234", r.runningAppTitleId)
        assertEquals(997, r.requestPort)
        assertEquals("192.168.1.20", r.ip)
    }

    @Test fun parsesPs4Standby() {
        val r = DdpProtocol.parse("HTTP/1.1 620 Server Standby\nhost-id:111\nhost-type:PS4\nhost-name:PS4-Bedroom\n", "10.0.0.5")!!
        assertEquals(ConsoleType.PS4, r.type)
        assertEquals(DdpProtocol.PowerState.STANDBY, r.state)
        assertNull(r.runningAppName)
    }

    @Test fun rejectsGarbage() {
        assertNull(DdpProtocol.parse("hello world", "1.2.3.4"))
        assertNull(DdpProtocol.parse("HTTP/1.1 200 Ok\nhost-name:x\n", "1.2.3.4")) // no host-id
    }
}
