package com.example.enobet.auto

import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.constraints.ConstraintManager
import androidx.car.app.model.Action
import androidx.car.app.model.ItemList
import androidx.car.app.model.ListTemplate
import androidx.car.app.model.MessageTemplate
import androidx.car.app.model.Row
import androidx.car.app.model.Template
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.math.max

class EnobetCarHomeScreen(
    carContext: CarContext,
) : Screen(carContext) {
    companion object {
        private const val PREFS_NAME = "enobet_auto"
        private const val NAV_STATE_KEY = "navigation_state"
        private const val STALE_AFTER_MS = 120_000L
        private const val REFRESH_MS = 2_500L
    }

    private val handler = Handler(Looper.getMainLooper())
    private val refreshTask = object : Runnable {
        override fun run() {
            invalidate()
            handler.postDelayed(this, REFRESH_MS)
        }
    }

    init {
        lifecycle.addObserver(object : DefaultLifecycleObserver {
            override fun onStart(owner: LifecycleOwner) {
                handler.removeCallbacks(refreshTask)
                handler.post(refreshTask)
            }

            override fun onStop(owner: LifecycleOwner) {
                handler.removeCallbacks(refreshTask)
            }

            override fun onDestroy(owner: LifecycleOwner) {
                handler.removeCallbacks(refreshTask)
            }
        })
    }

    override fun onGetTemplate(): Template {
        val state = readState()
        if (state == null || !state.active) {
            return MessageTemplate.Builder(
                "Telefonda ENöbet → Yol Asistanı'nı açın, hedefi seçin ve GİT'e basın. " +
                    "Yolculuk başladığında hedef, kalan mesafe ve sıradaki yol üstü işletmeler burada görünecek.",
            )
                .setTitle("ENöbet • Android Auto")
                .setHeaderAction(Action.APP_ICON)
                .build()
        }

        val manager = carContext.getCarService(ConstraintManager::class.java)
        val contentLimit = try {
            manager.getContentLimit(ConstraintManager.CONTENT_LIMIT_TYPE_LIST)
        } catch (_: Exception) {
            6
        }
        val maxBusinesses = max(1, contentLimit - 2).coerceAtMost(5)

        val list = ItemList.Builder()
        list.addItem(
            Row.Builder()
                .setTitle(state.target.ifBlank { "Hedef" })
                .addText("${formatDistance(state.remainingMeters)} • ${formatDuration(state.remainingSeconds)} • Varış ${formatClock(state.arrivalEpochMs)}")
                .build(),
        )

        if (state.maneuver.isNotBlank()) {
            list.addItem(
                Row.Builder()
                    .setTitle(state.maneuver)
                    .addText("${formatDistance(state.maneuverMeters)} sonra")
                    .build(),
            )
        }

        state.businesses.take(maxBusinesses).forEachIndexed { index, business ->
            val typeLabel = when (business.type.lowercase(Locale.ROOT)) {
                "akaryakit" -> "Akaryakıt"
                "sarj" -> "Şarj"
                "dinlenme" -> "Dinlenme"
                else -> "Yol üstü"
            }
            list.addItem(
                Row.Builder()
                    .setTitle("${index + 1}. ${business.name}")
                    .addText("$typeLabel • ${formatDistance(business.remainingMeters)}")
                    .build(),
            )
        }

        if (state.businesses.isEmpty()) {
            list.addItem(
                Row.Builder()
                    .setTitle("Yol üstü işletme")
                    .addText("İleride doğrulanmış işletme bulunmuyor")
                    .build(),
            )
        }

        return ListTemplate.Builder()
            .setTitle("ENöbet • Yol Asistanı")
            .setHeaderAction(Action.APP_ICON)
            .setSingleList(list.build())
            .build()
    }

    private fun readState(): NavigationState? {
        val prefs = carContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val raw = prefs.getString(NAV_STATE_KEY, null) ?: return null
        return try {
            val root = JSONObject(raw)
            val updatedAt = root.optLong("updatedAtMs", 0L)
            if (updatedAt <= 0L || System.currentTimeMillis() - updatedAt > STALE_AFTER_MS) {
                return null
            }

            val businessesJson = root.optJSONArray("businesses") ?: JSONArray()
            val businesses = buildList {
                for (i in 0 until businessesJson.length()) {
                    val item = businessesJson.optJSONObject(i) ?: continue
                    add(
                        BusinessState(
                            name = item.optString("name", "İşletme"),
                            type = item.optString("type", ""),
                            remainingMeters = item.optDouble("remainingMeters", 0.0),
                        ),
                    )
                }
            }

            NavigationState(
                active = root.optBoolean("active", false),
                target = root.optString("target", "Hedef"),
                remainingMeters = root.optDouble("remainingMeters", 0.0),
                remainingSeconds = root.optDouble("remainingSeconds", 0.0),
                arrivalEpochMs = root.optLong("arrivalEpochMs", 0L),
                maneuver = root.optString("maneuver", ""),
                maneuverMeters = root.optDouble("maneuverMeters", 0.0),
                businesses = businesses,
            )
        } catch (_: Exception) {
            null
        }
    }

    private fun formatDistance(meters: Double): String {
        val safe = meters.coerceAtLeast(0.0)
        return if (safe < 1000) {
            "${safe.toInt()} m"
        } else {
            String.format(Locale("tr", "TR"), "%.1f km", safe / 1000.0)
        }
    }

    private fun formatDuration(seconds: Double): String {
        val minutes = (seconds.coerceAtLeast(0.0) / 60.0).toInt()
        return if (minutes < 60) {
            "$minutes dk"
        } else {
            val hours = minutes / 60
            val remainder = minutes % 60
            if (remainder == 0) "$hours sa" else "$hours sa $remainder dk"
        }
    }

    private fun formatClock(epochMs: Long): String {
        if (epochMs <= 0L) return "--:--"
        return SimpleDateFormat("HH:mm", Locale("tr", "TR")).format(Date(epochMs))
    }
}

private data class NavigationState(
    val active: Boolean,
    val target: String,
    val remainingMeters: Double,
    val remainingSeconds: Double,
    val arrivalEpochMs: Long,
    val maneuver: String,
    val maneuverMeters: Double,
    val businesses: List<BusinessState>,
)

private data class BusinessState(
    val name: String,
    val type: String,
    val remainingMeters: Double,
)
