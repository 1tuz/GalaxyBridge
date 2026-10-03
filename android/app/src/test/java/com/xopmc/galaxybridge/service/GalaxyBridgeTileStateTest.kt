package com.xopmc.galaxybridge.service

import android.service.quicksettings.Tile
import org.junit.Assert.assertEquals
import org.junit.Test

class GalaxyBridgeTileStateTest {
    @Test
    fun enabledMapsToActive() {
        assertEquals(Tile.STATE_ACTIVE, GalaxyBridgeTileState.tileState(true))
    }

    @Test
    fun disabledMapsToInactive() {
        assertEquals(Tile.STATE_INACTIVE, GalaxyBridgeTileState.tileState(false))
    }
}
