package com.example.enobet.auto

import android.content.Intent
import android.content.pm.ApplicationInfo
import androidx.car.app.CarAppService
import androidx.car.app.Session
import androidx.car.app.SessionInfo
import androidx.car.app.Screen
import androidx.car.app.validation.HostValidator

class EnobetCarAppService : CarAppService() {
    override fun createHostValidator(): HostValidator {
        val debug = (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
        return if (debug) {
            HostValidator.ALLOW_ALL_HOSTS_VALIDATOR
        } else {
            HostValidator.Builder(this)
                .addAllowedHosts(androidx.car.app.R.array.hosts_allowlist_sample)
                .build()
        }
    }

    override fun onCreateSession(sessionInfo: SessionInfo): Session = EnobetCarSession()
}

private class EnobetCarSession : Session() {
    override fun onCreateScreen(intent: Intent): Screen = EnobetCarHomeScreen(carContext)
}
