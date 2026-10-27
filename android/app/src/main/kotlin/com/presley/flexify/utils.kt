package com.presley.flexify

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.util.Log
import java.io.File
import java.util.Calendar

private const val BACKUP_LOCALIZATION_PREFERENCES = "backup_localizations"

fun setBackupLocalizations(context: Context, values: Map<String, String>) {
    context.getSharedPreferences(BACKUP_LOCALIZATION_PREFERENCES, Context.MODE_PRIVATE)
        .edit()
        .apply {
            values.forEach { (key, value) -> putString(key, value) }
        }
        .apply()
}

fun getBackupLocalization(context: Context, key: String): String {
    return context.getSharedPreferences(BACKUP_LOCALIZATION_PREFERENCES, Context.MODE_PRIVATE)
        .getString(key, "")
        .orEmpty()
}

fun hasBackupLocalizations(context: Context): Boolean {
    return getBackupLocalization(context, "backupCompletedTitle").isNotEmpty()
}

fun scheduleBackups(context: Context) {
    if (!hasBackupLocalizations(context)) return

    // Never schedule another run if the user has disabled automatic backups
    // or has removed the destination folder.
    val (automaticBackups, backupPath) = getSettings(context)
    if (!automaticBackups || backupPath.isNullOrBlank()) return

    val backupIntent =
        Intent(context, BackupReceiver::class.java).apply { setPackage(context.packageName) }
    val pendingIntent = PendingIntent.getBroadcast(
        context,
        0,
        backupIntent,
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
    )
    val now = System.currentTimeMillis()
    val nextRun = Calendar.getInstance().apply {
        set(Calendar.HOUR_OF_DAY, 2)
        set(Calendar.MINUTE, 0)
        set(Calendar.SECOND, 0)
        set(Calendar.MILLISECOND, 0)
        if (timeInMillis <= now) add(Calendar.DAY_OF_YEAR, 1)
    }
    val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    // A one-shot alarm is re-armed after every receiver attempt. This makes
    // the next run explicit instead of relying on a repeating alarm surviving
    // device idle and receiver failures.
    alarmManager.setAndAllowWhileIdle(
        AlarmManager.RTC_WAKEUP,
        nextRun.timeInMillis,
        pendingIntent
    )
}

fun getDatabaseFile(context: Context): File {
    val supported = File(context.filesDir, "flexify.sqlite")
    val migrationMarker = File(context.filesDir, ".flexify-storage-migrated")
    if (supported.exists() || migrationMarker.exists()) return supported
    val legacy = File(File(context.filesDir.parentFile, "app_flutter"), "flexify.sqlite")
    return if (legacy.exists()) legacy else supported
}

fun openDb(context: Context): SQLiteDatabase? {
    val dbFile = getDatabaseFile(context)
    if (!dbFile.exists()) return null
    return try {
        SQLiteDatabase.openDatabase(dbFile.absolutePath, null, 0)
    } catch (error: Exception) {
        Log.e("utils@openDb", error.toString())
        null
    }
}

fun getSettings(context: Context): Pair<Boolean, String?> {
    val db = openDb(context) ?: return Pair(false, null)
    return try {
        db.rawQuery("SELECT backup_path, automatic_backups FROM settings", null).use { cursor ->
            if (!cursor.moveToFirst()) return Pair(false, null)
            val backupPath = cursor.getString(cursor.getColumnIndexOrThrow("backup_path"))
            val automaticBackups =
                cursor.getInt(cursor.getColumnIndexOrThrow("automatic_backups")) == 1
            Pair(automaticBackups, backupPath)
        }
    } catch (error: Exception) {
        Log.e("utils@getSettings", error.toString())
        Pair(false, null)
    } finally {
        db.close()
    }
}

fun setAutomaticBackups(context: Context, enabled: Boolean) {
    val db = openDb(context) ?: return
    try {
        db.execSQL(
            "UPDATE settings SET automatic_backups = ?",
            arrayOf(if (enabled) 1 else 0)
        )
    } catch (error: Exception) {
        Log.e("utils@setAutomaticBackups", error.toString())
    } finally {
        db.close()
    }
}
