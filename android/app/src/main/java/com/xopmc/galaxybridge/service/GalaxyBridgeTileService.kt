package com.xopmc.galaxybridge.service

import android.content.ComponentName
import android.content.Intent
import android.graphics.drawable.Icon
import android.service.quicksettings.TileService
import androidx.core.content.ContextCompat
import com.xopmc.galaxybridge.R

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
            label = getString(R.string.app_name)
            contentDescription = getString(
                if (enabled) R.string.qs_tile_on_content_description
                else R.string.qs_tile_off_content_description,
            )
            subtitle = getString(
                if (enabled) R.string.qs_tile_subtitle_on
                else R.string.qs_tile_subtitle_off,
            )
            icon = Icon.createWithResource(this@GalaxyBridgeTileService, R.drawable.ic_qs_galaxy_bridge)
            state = GalaxyBridgeTileState.tileState(enabled)
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
