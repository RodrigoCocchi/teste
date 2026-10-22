package br.pessoal.biblia_hinos_ccb

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/// Widget "Versículo do dia": o app grava os versículos dos próximos dias e
/// o widget mostra o da data de hoje (sem precisar abrir o app todo dia).
class VerseWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        var text = "Abra o app para preparar o versículo do dia."
        var ref = "Bíblia & Hinos"
        try {
            val all = JSONObject(widgetData.getString("verses", "{}") ?: "{}")
            val v = all.optJSONObject(today)
            if (v != null) {
                text = v.optString("t", text)
                ref = v.optString("r", ref)
            }
        } catch (_: Exception) {
        }
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.verse_widget).apply {
                setTextViewText(R.id.verse_text, text)
                setTextViewText(R.id.verse_ref, ref)
                setOnClickPendingIntent(
                    R.id.verse_root,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
                )
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
