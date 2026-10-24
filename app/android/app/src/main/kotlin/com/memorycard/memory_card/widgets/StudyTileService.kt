package com.memorycard.memory_card.widgets

import android.content.Intent
import android.graphics.drawable.Icon
import android.net.Uri
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import com.memorycard.memory_card.MainActivity
import com.memorycard.memory_card.R
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * The Quick Settings tile: "Memory Card · 8 to go · tap to study". It reads the same snapshot as the widgets each
 * time the panel opens, and a tap opens the last deck straight into study.
 */
class StudyTileService : TileService() {
    override fun onStartListening() {
        val tile = qsTile ?: return
        val st = WidgetState.from(HomeWidgetPlugin.getData(this))
        tile.label = "Memory Card"
        tile.icon = Icon.createWithResource(this, R.drawable.wg_tile_icon)
        val line = when {
            !st.ready -> "Open once to start"
            st.goalHit -> "Goal met · tap for more"
            else -> "${st.left} to go · tap to study"
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) tile.subtitle = line
        tile.state = if (st.ready && st.goalHit) Tile.STATE_INACTIVE else Tile.STATE_ACTIVE
        tile.updateTile()
    }

    @Suppress("DEPRECATION")
    override fun onClick() {
        val uri = Uri.parse("memorycard://study")
        if (Build.VERSION.SDK_INT >= 34) {
            startActivityAndCollapse(HomeWidgetLaunchIntent.getActivity(this, MainActivity::class.java, uri))
        } else {
            val intent = Intent(this, MainActivity::class.java)
                .setAction(HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION)
                .setData(uri)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivityAndCollapse(intent)
        }
    }
}
