package com.xopmc.galaxybridge.service

import android.service.quicksettings.Tile

/** Pure mapping for Quick Settings tile state. ACTIVE means bridge enabled. */
object GalaxyBridgeTileState {
    fun tileState(enabled: Boolean): Int =
        if (enabled) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
}
