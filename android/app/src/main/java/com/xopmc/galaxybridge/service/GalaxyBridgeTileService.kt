package com.xopmc.galaxybridge.service

import android.content.ComponentName
import android.content.Intent
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import androidx.core.content.ContextCompat

class GalaxyBridgeTileService : TileService() {
    override fun onStartListening() {
        super.onStartListening()
        publishState()
    }

    override fun onClick() {
        super.onClick()
        val enabled = !GalaxyBridgeForegroundService.isUserEnabled(this)
        GalaxyBridgeForegroundService.setUserEnabled(this, enabled)
        if (enabled) {
            ContextCompat.startForegroundService(
                this,
                Intent(this, GalaxyBridgeForegroundService::class.java),
            )
        } else {
            stopService(Intent(this, GalaxyBridgeForegroundService::class.java))
        }
        publishState(enabled)
    }

    private fun publishState(
        enabled: Boolean = GalaxyBridgeForegroundService.isUserEnabled(this),
    ) {
        qsTile?.apply {
            label = getString(com.xopmc.galaxybridge.R.string.app_name)
            state = if (enabled) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
            updateTile()
        }
    }

    companion object {
        fun requestRefresh(context: android.content.Context) {
            TileService.requestListeningState(
                context,
                ComponentName(context, GalaxyBridgeTileService::class.java),
            )
        }
    }
}
