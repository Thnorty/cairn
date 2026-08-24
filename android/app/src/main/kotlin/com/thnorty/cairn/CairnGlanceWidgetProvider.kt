package com.thnorty.cairn

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin

class CairnGlanceWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            val widgetData = HomeWidgetPlugin.getData(context)
            val views = RemoteViews(context.packageName, R.layout.cairn_glance_widget).apply {
                val altitude = widgetData.getInt("altitude", 0)
                val streak = widgetData.getInt("active_streak", 0)
                val remaining = widgetData.getInt("remaining_count", 0)
                val total = widgetData.getInt("total_count", 0)

                setTextViewText(R.id.widget_glance_altitude, "$altitude m")
                setTextViewText(R.id.widget_glance_streak, "🔥 ${streak}d")

                val remainingText = when {
                    total == 0 -> "No habits today"
                    remaining == 0 -> "All done today!"
                    remaining == 1 -> "1 habit left today"
                    else -> "$remaining habits left today"
                }
                setTextViewText(R.id.widget_glance_remaining, remainingText)

                // Launch App on click
                val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("cairn://today")
                )
                setOnClickPendingIntent(R.id.widget_glance_root, pendingIntent)
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
