package com.thnorty.cairn

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.net.Uri
import android.view.View
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
                val isAllCompleted = widgetData.getBoolean("is_all_completed", false)
                val nextTaskId = widgetData.getString("next_task_id", "") ?: ""
                val nextTaskTitle = widgetData.getString("next_task_title", "") ?: ""
                val nextTaskSlot = widgetData.getInt("next_task_slot", 0)
                val nextTime = widgetData.getString("next_task_due_time", "") ?: ""

                // 1. Top row: Big Altitude & Rank + Streak
                setTextViewText(R.id.widget_glance_altitude, "$altitude m")
                setTextViewText(R.id.widget_glance_rank, "🏔️ $rankName")
                setTextViewText(R.id.widget_glance_streak, "🔥 ${streak}d")

                // 2. Middle Section: Actionable or Status
                if (isAllCompleted || (total > 0 && remaining == 0)) {
                    // All completed
                    setViewVisibility(R.id.widget_glance_habit_content, View.GONE)
                    setViewVisibility(R.id.widget_glance_empty_content, View.GONE)
                    setViewVisibility(R.id.widget_glance_all_done_content, View.VISIBLE)
                    setTextViewText(
                        R.id.widget_glance_all_done_sub,
                        if (streak > 0) "🔥 ${streak}d streak safe · $done/$total done" else "All $total habits proven today"
                    )
                } else if (nextTaskId.isNotEmpty() && nextTaskTitle.isNotEmpty()) {
                    // Habit ready to prove
                    setViewVisibility(R.id.widget_glance_all_done_content, View.GONE)
                    setViewVisibility(R.id.widget_glance_empty_content, View.GONE)
                    setViewVisibility(R.id.widget_glance_habit_content, View.VISIBLE)

                    val habitWithTime = if (nextTime.isNotEmpty()) "$nextTaskTitle ($nextTime)" else nextTaskTitle
                    setTextViewText(R.id.widget_glance_next_preview, habitWithTime)
                    setTextViewText(R.id.widget_glance_today_progress, "$done of $total done · $remaining left")

                    val proveIntent = HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("cairn://prove?taskId=$nextTaskId&slot=$nextTaskSlot")
                    )
                    setOnClickPendingIntent(R.id.widget_glance_btn_prove, proveIntent)
                } else {
                    // Empty state
                    setViewVisibility(R.id.widget_glance_habit_content, View.GONE)
                    setViewVisibility(R.id.widget_glance_all_done_content, View.GONE)
                    setViewVisibility(R.id.widget_glance_empty_content, View.VISIBLE)

                    val addHabitIntent = HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("cairn://new_habit")
                    )
                    setOnClickPendingIntent(R.id.widget_glance_btn_add, addHabitIntent)
                }

                // 3. Bottom row: Weekly stones
                val weekText = if (stonesThisWeek == 1) "1 stone this week" else "$stonesThisWeek stones this week"
                setTextViewText(R.id.widget_glance_week_stones, weekText)

                // Launch App on card click
                val rootIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("cairn://today")
                )
                setOnClickPendingIntent(R.id.widget_glance_root, rootIntent)
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
