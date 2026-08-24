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
                val rankName = widgetData.getString("rank_name", "Pebble") ?: "Pebble"
                val streak = widgetData.getInt("active_streak", 0)
                val remaining = widgetData.getInt("remaining_count", 0)
                val total = widgetData.getInt("total_count", 0)
                val done = widgetData.getInt("done_count", 0)
                val stonesThisWeek = widgetData.getInt("stones_this_week", 0)
                val nextTitle = widgetData.getString("next_task_title", "") ?: ""
                val nextTime = widgetData.getString("next_task_due_time", "") ?: ""

                // 1. Top row: Big Altitude & Rank + Streak
                setTextViewText(R.id.widget_glance_altitude, "$altitude m")
                setTextViewText(R.id.widget_glance_rank, "🏔️ $rankName")
                setTextViewText(R.id.widget_glance_streak, "🔥 ${streak}d")

                // 2. Middle: Next habit or Status
                if (total == 0) {
                    setTextViewText(R.id.widget_glance_today_label, "START CLIMBING")
                    setTextViewText(R.id.widget_glance_next_preview, "No habits today")
                    setTextViewText(R.id.widget_glance_today_progress, "Tap to add your first habit")
                } else if (remaining == 0) {
                    setTextViewText(R.id.widget_glance_today_label, "TODAY COMPLETE")
                    setTextViewText(R.id.widget_glance_next_preview, "All stones placed! ✓")
                    setTextViewText(R.id.widget_glance_today_progress, "$done of $total habits proven")
                } else {
                    setTextViewText(R.id.widget_glance_today_label, "NEXT HABIT")
                    val habitWithTime = if (nextTime.isNotEmpty()) "$nextTitle ($nextTime)" else nextTitle
                    setTextViewText(R.id.widget_glance_next_preview, habitWithTime.ifEmpty { "Ready to prove" })
                    setTextViewText(R.id.widget_glance_today_progress, "$done of $total completed · $remaining left")
                }

                // 3. Bottom row: Weekly stones
                val weekText = if (stonesThisWeek == 1) "1 stone this week" else "$stonesThisWeek stones this week"
                setTextViewText(R.id.widget_glance_week_stones, weekText)

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
