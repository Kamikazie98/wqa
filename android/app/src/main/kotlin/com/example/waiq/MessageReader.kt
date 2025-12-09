package com.example.waiq

import android.util.Log
import android.content.ContentResolver
import android.content.Context
import android.database.Cursor
import android.net.Uri
import android.provider.Telephony
import android.provider.ContactsContract
import java.text.SimpleDateFormat
import java.util.Locale

data class MessageData(
    val id: String,
    val sender: String,
    val senderName: String,
    val body: String,
    val timestamp: Long,
    val channel: String,
    val isRead: Boolean,
    val threadId: Long,
    val date: Long
)

data class MessageThreadData(
    val threadId: Long,
    val contact: String,
    val contactName: String,
    val lastMessage: String,
    val lastTimestamp: Long,
    val unreadCount: Int,
    val messageCount: Int
)

class MessageReader(private val context: Context) {
    private val contentResolver: ContentResolver = context.contentResolver

    // Helper to check for SMS permission
    private fun hasSmsPermission(): Boolean {
        return android.os.Build.VERSION.SDK_INT < android.os.Build.VERSION_CODES.M ||
            (context.checkSelfPermission(android.Manifest.permission.READ_SMS) ==
                android.content.pm.PackageManager.PERMISSION_GRANTED)
    }

    /**
     * دریافت پیام‌های نخوانده از SMS
     */
    fun getPendingMessages(limit: Int = 50): List<Map<String, Any?>> {
        if (!hasSmsPermission()) {
            Log.w("MessageReader", "READ_SMS permission denied. Cannot read pending messages.")
            return emptyList()
        }
        return try {
            val messages = mutableListOf<Map<String, Any?>>()
            val uri: Uri = Telephony.Sms.CONTENT_URI

            // فیلتر: صرف پیام‌های نخوانده (isRead = 0)
            val selection = "${Telephony.Sms.READ} = ?"
            val selectionArgs = arrayOf("0")

            val projection = arrayOf(
                Telephony.Sms._ID,
                Telephony.Sms.ADDRESS,
                Telephony.Sms.BODY,
                Telephony.Sms.DATE,
                Telephony.Sms.READ,
                Telephony.Sms.THREAD_ID,
                Telephony.Sms.TYPE
            )

            val cursor: Cursor? = contentResolver.query(
                uri,
                projection,
                selection,
                selectionArgs,
                "${Telephony.Sms.DATE} DESC LIMIT $limit"
            )

            cursor?.use { c ->
                val idIdx = c.getColumnIndex(Telephony.Sms._ID)
                val addressIdx = c.getColumnIndex(Telephony.Sms.ADDRESS)
                val bodyIdx = c.getColumnIndex(Telephony.Sms.BODY)
                val dateIdx = c.getColumnIndex(Telephony.Sms.DATE)
                val readIdx = c.getColumnIndex(Telephony.Sms.READ)
                val threadIdx = c.getColumnIndex(Telephony.Sms.THREAD_ID)
                val typeIdx = c.getColumnIndex(Telephony.Sms.TYPE)

                while (c.moveToNext()) {
                    try {
                        val id = if (idIdx >= 0) c.getString(idIdx) else ""
                        val address = if (addressIdx >= 0) c.getString(addressIdx) else ""
                        val body = if (bodyIdx >= 0) c.getString(bodyIdx) else ""
                        val date = if (dateIdx >= 0) c.getLong(dateIdx) else System.currentTimeMillis()
                        val isRead = if (readIdx >= 0) c.getInt(readIdx) != 0 else false
                        val threadId = if (threadIdx >= 0) c.getLong(threadIdx) else 0L
                        val type = if (typeIdx >= 0) c.getInt(typeIdx) else Telephony.Sms.MESSAGE_TYPE_INBOX

                        // تشخیص نوع پیام (دریافت شده = 1)
                        val isIncoming = type == Telephony.Sms.MESSAGE_TYPE_INBOX

                        if (isIncoming) {
                            val contactName = getContactName(address)
                            messages.add(
                                mapOf(
                                    "id" to id,
                                    "sender" to address,
                                    "senderName" to contactName,
                                    "body" to body,
                                    "timestamp" to date,
                                    "channel" to "sms",
                                    "isRead" to isRead,
                                    "threadId" to threadId,
                                    "date" to date
                                )
                            )
                        }
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                }
            }
            messages
        } catch (e: Exception) {
            e.printStackTrace()
            emptyList()
        }
    }

    /**
     * دریافت تمام پیام‌ها (خوانده‌شده و نخوانده)
     */
    fun getAllMessages(limit: Int = 100): List<Map<String, Any?>> {
        if (!hasSmsPermission()) {
            Log.w("MessageReader", "READ_SMS permission denied. Cannot read all messages.")
            return emptyList()
        }
        return try {
            val messages = mutableListOf<Map<String, Any?>>()
            val uri: Uri = Telephony.Sms.CONTENT_URI

            val projection = arrayOf(
                Telephony.Sms._ID,
                Telephony.Sms.ADDRESS,
                Telephony.Sms.BODY,
                Telephony.Sms.DATE,
                Telephony.Sms.READ,
                Telephony.Sms.THREAD_ID,
                Telephony.Sms.TYPE
            )

            val cursor: Cursor? = contentResolver.query(
                uri,
                projection,
                null,
                null,
                "${Telephony.Sms.DATE} DESC LIMIT $limit"
            )

            cursor?.use { c ->
                val idIdx = c.getColumnIndex(Telephony.Sms._ID)
                val addressIdx = c.getColumnIndex(Telephony.Sms.ADDRESS)
                val bodyIdx = c.getColumnIndex(Telephony.Sms.BODY)
                val dateIdx = c.getColumnIndex(Telephony.Sms.DATE)
                val readIdx = c.getColumnIndex(Telephony.Sms.READ)
                val threadIdx = c.getColumnIndex(Telephony.Sms.THREAD_ID)
                val typeIdx = c.getColumnIndex(Telephony.Sms.TYPE)

                while (c.moveToNext()) {
                    try {
                        val id = if (idIdx >= 0) c.getString(idIdx) else ""
                        val address = if (addressIdx >= 0) c.getString(addressIdx) else ""
                        val body = if (bodyIdx >= 0) c.getString(bodyIdx) else ""
                        val date = if (dateIdx >= 0) c.getLong(dateIdx) else System.currentTimeMillis()
                        val isRead = if (readIdx >= 0) c.getInt(readIdx) != 0 else false
                        val threadId = if (threadIdx >= 0) c.getLong(threadIdx) else 0L
                        val type = if (typeIdx >= 0) c.getInt(typeIdx) else Telephony.Sms.MESSAGE_TYPE_INBOX

                        val isIncoming = type == Telephony.Sms.MESSAGE_TYPE_INBOX

                        if (isIncoming) {
                            val contactName = getContactName(address)
                            messages.add(
                                mapOf(
                                    "id" to id,
                                    "sender" to address,
                                    "senderName" to contactName,
                                    "body" to body,
                                    "timestamp" to date,
                                    "channel" to "sms",
                                    "isRead" to isRead,
                                    "threadId" to threadId,
                                    "date" to date
                                )
                            )
                        }
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                }
            }
            messages
        } catch (e: Exception) {
            e.printStackTrace()
            emptyList()
        }
    }

    /**
     * دریافت تمام مکالمات (گروه‌بندی‌شده بر اساس تماس)
     */
    fun getMessageThreads(): List<Map<String, Any?>> {
        if (!hasSmsPermission()) {
            Log.w("MessageReader", "READ_SMS permission denied. Cannot read message threads.")
            return emptyList()
        }
        return try {
            val threads = mutableListOf<Map<String, Any?>>()
            val uri: Uri = Telephony.Sms.CONTENT_URI

            val projection = arrayOf(
                Telephony.Sms.THREAD_ID,
                Telephony.Sms.ADDRESS,
                Telephony.Sms.BODY,
                Telephony.Sms.DATE,
                Telephony.Sms.READ
            )

            // مرتب‌سازی بر اساس threadId و DATE برای گروه‌بندی
            val cursor: Cursor? = contentResolver.query(
                uri,
                projection,
                null,
                null,
                "${Telephony.Sms.THREAD_ID} ASC, ${Telephony.Sms.DATE} DESC"
            )

            val threadMap = mutableMapOf<Long, MutableMap<String, Any?>>()

            cursor?.use { c ->
                val threadIdx = c.getColumnIndex(Telephony.Sms.THREAD_ID)
                val addressIdx = c.getColumnIndex(Telephony.Sms.ADDRESS)
                val bodyIdx = c.getColumnIndex(Telephony.Sms.BODY)
                val dateIdx = c.getColumnIndex(Telephony.Sms.DATE)
                val readIdx = c.getColumnIndex(Telephony.Sms.READ)

                while (c.moveToNext()) {
                    try {
                        val threadId = if (threadIdx >= 0) c.getLong(threadIdx) else 0L
                        val address = if (addressIdx >= 0) c.getString(addressIdx) else ""
                        val body = if (bodyIdx >= 0) c.getString(bodyIdx) else ""
                        val date = if (dateIdx >= 0) c.getLong(dateIdx) else System.currentTimeMillis()
                        val isRead = if (readIdx >= 0) c.getInt(readIdx) != 0 else false

                        if (threadId > 0) {
                            if (!threadMap.containsKey(threadId)) {
                                val contactName = getContactName(address)
                                threadMap[threadId] = mutableMapOf(
                                    "threadId" to threadId,
                                    "contact" to address,
                                    "contactName" to contactName,
                                    "lastMessage" to body,
                                    "lastTimestamp" to date,
                                    "unreadCount" to if (isRead) 0 else 1,
                                    "messageCount" to 1
                                )
                            } else {
                                val thread = threadMap[threadId]!!
                                thread["messageCount"] = (thread["messageCount"] as? Int ?: 0) + 1
                                if (!isRead) {
                                    thread["unreadCount"] = (thread["unreadCount"] as? Int ?: 0) + 1
                                }
                            }
                        }
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                }
            }

            threads.addAll(threadMap.values)
            threads
        } catch (e: Exception) {
            e.printStackTrace()
            emptyList()
        }
    }

    /**
     * دریافت تمام پیام‌های از یک مخاطب مشخص
     */
    fun getMessagesFromContact(phoneNumber: String): List<Map<String, Any?>> {
        return try {
            val messages = mutableListOf<Map<String, Any?>>()
            val uri: Uri = Telephony.Sms.CONTENT_URI

            val selection = "${Telephony.Sms.ADDRESS} LIKE ?"
            val selectionArgs = arrayOf("%${phoneNumber.filter { it.isDigit() }}%")

            val projection = arrayOf(
                Telephony.Sms._ID,
                Telephony.Sms.ADDRESS,
                Telephony.Sms.BODY,
                Telephony.Sms.DATE,
                Telephony.Sms.READ,
                Telephony.Sms.THREAD_ID,
                Telephony.Sms.TYPE
            )

            val cursor: Cursor? = contentResolver.query(
                uri,
                projection,
                selection,
                selectionArgs,
                "${Telephony.Sms.DATE} DESC"
            )

            cursor?.use { c ->
                val idIdx = c.getColumnIndex(Telephony.Sms._ID)
                val addressIdx = c.getColumnIndex(Telephony.Sms.ADDRESS)
                val bodyIdx = c.getColumnIndex(Telephony.Sms.BODY)
                val dateIdx = c.getColumnIndex(Telephony.Sms.DATE)
                val readIdx = c.getColumnIndex(Telephony.Sms.READ)
                val threadIdx = c.getColumnIndex(Telephony.Sms.THREAD_ID)
                val typeIdx = c.getColumnIndex(Telephony.Sms.TYPE)

                while (c.moveToNext()) {
                    try {
                        val id = if (idIdx >= 0) c.getString(idIdx) else ""
                        val address = if (addressIdx >= 0) c.getString(addressIdx) else ""
                        val body = if (bodyIdx >= 0) c.getString(bodyIdx) else ""
                        val date = if (dateIdx >= 0) c.getLong(dateIdx) else System.currentTimeMillis()
                        val isRead = if (readIdx >= 0) c.getInt(readIdx) != 0 else false
                        val threadId = if (threadIdx >= 0) c.getLong(threadIdx) else 0L
                        val type = if (typeIdx >= 0) c.getInt(typeIdx) else Telephony.Sms.MESSAGE_TYPE_INBOX

                        val contactName = getContactName(address)
                        messages.add(
                            mapOf(
                                "id" to id,
                                "sender" to address,
                                "senderName" to contactName,
                                "body" to body,
                                "timestamp" to date,
                                "channel" to "sms",
                                "isRead" to isRead,
                                "threadId" to threadId,
                                "date" to date
                            )
                        )
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                }
            }
            messages
        } catch (e: Exception) {
            e.printStackTrace()
            emptyList()
        }
    }

    /**
     * علامت‌گذاری پیام به عنوان خوانده‌شده
     */
    fun markAsRead(messageId: String): Boolean {
        return try {
            val uri = Uri.parse("content://sms/$messageId")
            val values = android.content.ContentValues().apply {
                put(Telephony.Sms.READ, 1)
            }
            val rows = contentResolver.update(uri, values, null, null)
            rows > 0
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    /**
     * حذف پیام
     */
    fun deleteMessage(messageId: String): Boolean {
        return try {
            val uri = Uri.parse("content://sms/$messageId")
            val rows = contentResolver.delete(uri, null, null)
            rows > 0
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    /**
     * دریافت نام مخاطب از شماره تلفن
     */
    private fun getContactName(phoneNumber: String): String {
        return try {
            if (phoneNumber.isBlank()) return phoneNumber

            // چک کردن permission
            if (!hasContactPermission()) {
                return phoneNumber // اگر permission نداریم، شماره‌ی تلفن را برگردان
            }

            val uri = Uri.withAppendedPath(
                ContactsContract.PhoneLookup.CONTENT_FILTER_URI,
                Uri.encode(phoneNumber)
            )
            val projection = arrayOf(ContactsContract.PhoneLookup.DISPLAY_NAME)

            val cursor: Cursor? = contentResolver.query(
                uri,
                projection,
                null,
                null,
                null
            )

            var contactName = phoneNumber
            cursor?.use { c ->
                if (c.moveToFirst()) {
                    val nameIdx = c.getColumnIndex(ContactsContract.PhoneLookup.DISPLAY_NAME)
                    if (nameIdx >= 0) {
                        contactName = c.getString(nameIdx) ?: phoneNumber
                    }
                }
            }
            contactName
        } catch (e: Exception) {
            e.printStackTrace()
            phoneNumber
        }
    }

    /**
     * چک کردن داشتن READ_CONTACTS permission
     */
    private fun hasContactPermission(): Boolean {
        return android.os.Build.VERSION.SDK_INT < android.os.Build.VERSION_CODES.M ||
            (context.checkSelfPermission(android.Manifest.permission.READ_CONTACTS) == 
                android.content.pm.PackageManager.PERMISSION_GRANTED)
    }

    /**
     * دریافت تعداد پیام‌های نخوانده
     */
    fun getUnreadCount(): Int {
        return try {
            val uri: Uri = Telephony.Sms.CONTENT_URI
            val selection = "${Telephony.Sms.READ} = ?"
            val selectionArgs = arrayOf("0")

            val cursor: Cursor? = contentResolver.query(
                uri,
                arrayOf(Telephony.Sms._ID),
                selection,
                selectionArgs,
                null
            )

            var count = 0
            cursor?.use { c ->
                count = c.count
            }
            count
        } catch (e: Exception) {
            e.printStackTrace()
            0
        }
    }
}
