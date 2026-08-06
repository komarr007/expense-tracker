// Taruh file ini di:
// android/app/src/main/kotlin/<path sesuai applicationId lu>/LifeCountdownWidgetProvider.kt
//
// Misal applicationId lu "com.rigaqi.themoneylogger", taruh di:
// android/app/src/main/kotlin/com/rigaqi/themoneylogger/LifeCountdownWidgetProvider.kt
// dan ganti "package" line di bawah biar match.
//
// CATATAN: API dari package `home_widget` (nama class HomeWidgetProvider,
// HomeWidgetLaunchIntent, dll) bisa berubah antar versi. Cek versi yang
// lu install di pubspec.lock terus samain sama contoh terbaru di:
// https://pub.dev/packages/home_widget

package com.example.the_money_logger // TODO: ganti sesuai package/applicationId lu

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class LifeCountdownWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val days = widgetData.getInt("remaining_days", -1)
            val years = widgetData.getInt("remaining_years", -1)

            val views = RemoteViews(context.packageName, R.layout.life_countdown_widget).apply {
                setTextViewText(
                    R.id.widget_days_value,
                    if (days >= 0) "%,d".format(days) else "—"
                )
                setTextViewText(
                    R.id.widget_years_value,
                    if (years >= 0) "≈ $years tahun lagi" else ""
                )

                // Tap widget -> buka app
                val pendingIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                setOnClickPendingIntent(R.id.widget_days_value, pendingIntent)
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
