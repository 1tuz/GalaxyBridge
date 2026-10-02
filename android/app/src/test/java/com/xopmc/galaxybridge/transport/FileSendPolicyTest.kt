package com.xopmc.galaxybridge.transport

import com.xopmc.galaxybridge.BuildConfig
import com.xopmc.galaxybridge.protocol.v1.Envelope
import com.xopmc.galaxybridge.protocol.v1.TransferAck
import org.junit.Assert.*
import org.junit.Test

class FileSendPolicyTest {
    @Test fun onlyDirectAndInternalExposeSender() {
        assertTrue(FileSendPolicy.enabled("direct"))
        assertTrue(FileSendPolicy.enabled("internal"))
        assertFalse(FileSendPolicy.enabled("play"))
        assertFalse(FileSendPolicy.enabled("unknown"))
        assertEquals(BuildConfig.DISTRIBUTION != "play", AndroidOutgoingFiles.enabled)
    }
    @Test fun grantedContentUrisCanEnterSingleOrMultipleSharePreview() {
        assertTrue(FileSendPolicy.acceptsShare("android.intent.action.SEND", listOf("content"), 1, true))
        assertTrue(FileSendPolicy.acceptsShare(
            "android.intent.action.SEND_MULTIPLE",
            listOf("content", "content", "content"),
            3,
            true,
        ))
        assertFalse(FileSendPolicy.acceptsShare("android.intent.action.SEND", listOf("file"), 1, true))
        assertFalse(FileSendPolicy.acceptsShare("android.intent.action.SEND", listOf("content"), 1, false))
        assertFalse(FileSendPolicy.acceptsShare("android.intent.action.SEND", listOf("content", "content"), 2, true))
        assertFalse(FileSendPolicy.acceptsShare("android.intent.action.SEND_MULTIPLE", listOf("content", "file"), 2, true))
        assertFalse(FileSendPolicy.acceptsShare(null, emptyList(), 0, true))
        assertFalse(FileSendPolicy.acceptsShare("android.intent.action.SEND_MULTIPLE", List(101) { "content" }, 101, true))
    }
    @Test fun ackUsesExistingWireTagAndDedicatedFileRoute() {
        val wire = Envelope.newBuilder().setTransferAck(TransferAck.newBuilder()
            .setTransferId("fixture").setConfirmedOffset(17).setComplete(true).setPublishedName("copy (1).bin")).build()
        val decoded = Envelope.parseFrom(wire.toByteArray())
        assertEquals(21, decoded.payloadCase.number)
        assertEquals(CompanionControlPayloadKind.TRANSFER_ACK, CompanionControlPayloadPolicy.classify(decoded))
        assertEquals("copy (1).bin", decoded.transferAck.publishedName)
    }
}
