package com.thnorty.cairn

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin

class CairnNextHabitWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            val widgetData = HomeWidgetPlugin.getData(context)
            val views = RemoteViews(context.packageName, R.layout.cairn_next_habit_widget).apply {
                val isAllCompleted = widgetData.getBoolean("is_all_completed", false)
                val totalCount = widgetData.getInt("total_count", 0)
                val remainingCount = widgetData.getInt("remaining_count", 0)
                val nextTaskId = widgetData.getString("next_task_id", "") ?: ""
                val nextTaskTitle = widgetData.getString("next_task_title", "") ?: ""
                val nextTaskSlot = widgetData.getInt("next_task_slot", 0)
                val nextTaskDueTime = widgetData.getString("next_task_due_time", "") ?: ""
                val nextTaskCairnLabel = widgetData.getString("next_task_cairn_label", "") ?: ""
                val activeStreak = widgetData.getInt("active_streak", 0)

                if (isAllCompleted || (totalCount > 0 && remainingCount == 0)) {
                    // State 1: All habits completed today
                    setTextViewText(R.id.widget_header_label, "TODAY")
                    setTextViewText(R.id.widget_remaining_badge, "Done ✓")
                    setViewVisibility(R.id.widget_habit_content, View.GONE)
                    setViewVisibility(R.id.widget_empty_content, View.GONE)
                    setViewVisibility(R.id.widget_all_done_content, View.VISIBLE)
                    setTextViewText(
                        R.id.widget_all_done_streak,
                        if (activeStreak > 0) "🔥 ${activeStreak}d streak safe" else "Altitude climbing"
                    )
                } else if (nextTaskId.isNotEmpty() && nextTaskTitle.isNotEmpty()) {
                    // State 2: Active habit due for proof
                    setTextViewText(R.id.widget_header_label, "NEXT HABIT")
                    setTextViewText(
                        R.id.widget_remaining_badge,
                        if (remainingCount == 1) "1 left" else "$remainingCount left"
                    )
                    setViewVisibility(R.id.widget_all_done_content, View.GONE)
                    setViewVisibility(R.id.widget_empty_content, View.GONE)
                    setViewVisibility(R.id.widget_habit_content, View.VISIBLE)

                    setTextViewText(R.id.widget_habit_title, nextTaskTitle)

                    val metaText = buildString {
                        if (nextTaskDueTime.isNotEmpty()) {
                            append(nextTaskDueTime)
                            if (nextTaskCairnLabel.isNotEmpty()) append(" · ")
                        }
                        if (nextTaskCairnLabel.isNotEmpty()) {
                            append(nextTaskCairnLabel)
                        }
                    }
                    setTextViewText(R.id.widget_cairn_meta, metaText.ifEmpty { "Ready to prove" })

                    // Prove button click -> launches direct to camera for this taskId & slot
                    val proveIntent = HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("cairn://prove?taskId=$nextTaskId&slot=$nextTaskSlot")
                    )
                    setOnClickPendingIntent(R.id.widget_btn_prove, proveIntent)
                } else {
                    // State 3: Empty / No habits scheduled
                    setTextViewText(R.id.widget_header_label, "CAIRN")
                    setTextViewText(R.id.widget_remaining_badge, "0 scheduled")
                    setViewVisibility(R.id.widget_habit_content, View.GONE)
                    setViewVisibility(R.id.widget_all_done_content, View.GONE)
                    setViewVisibility(R.id.widget_empty_content, View.VISIBLE)

                    val addHabitIntent = HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("cairn://new_habit")
                    )
                    setOnClickPendingIntent(R.id.widget_btn_add_habit, addHabitIntent)
                }

                // Widget root click -> launches Today screen
                val rootIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("cairn://today")
                )
                setOnClickPendingIntent(R.id.widget_next_root, rootIntent)
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
