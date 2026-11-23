<?php
/**
 * SARVOOCCH Microcare Foundation - Multi-Channel Notification Engine
 * Supports Fast2SMS / MSG91 for SMS, WhatsApp Cloud API / CallMeBot, and Telegram
 */

if (!defined('SARVOOCCH_APP')) exit;

class NotificationService {
    /**
     * Send Transactional SMS
     */
    public static function sendSms(string $phone, string $message, string $templateId = ''): bool {
        $cleanPhone = preg_replace('/[^0-9]/', '', $phone);
        if (strlen($cleanPhone) > 10) {
            $cleanPhone = substr($cleanPhone, -10);
        }

        $apiKey = defined('FAST2SMS_API_KEY') ? FAST2SMS_API_KEY : getenv('FAST2SMS_API_KEY');
        if ($apiKey && strlen($cleanPhone) === 10) {
            $ch = curl_init('https://www.fast2sms.com/dev/bulkV2');
            $fields = [
                'route' => 'v3',
                'sender_id' => 'TXTIND',
                'message' => $message,
                'language' => 'english',
                'flash' => 0,
                'numbers' => $cleanPhone
            ];
            curl_setopt_array($ch, [
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_POST => true,
                CURLOPT_POSTFIELDS => json_encode($fields),
                CURLOPT_HTTPHEADER => [
                    'authorization: ' . $apiKey,
                    'Content-Type: application/json'
                ],
                CURLOPT_TIMEOUT => 10
            ]);
            $res = curl_exec($ch);
            $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
            curl_close($ch);
            if ($code === 200) return true;
        }

        // Fallback: Record to comm_logs
        $cust = q("SELECT id FROM customers WHERE phone LIKE ? LIMIT 1", ['%' . $cleanPhone], true);
        if ($cust) {
            ex("INSERT INTO comm_logs (customer_id, channel, note, by_name, at) VALUES (?, 'SMS (Simulated)', ?, 'System SMS Gateway', NOW())",
                [$cust['id'], $message]);
        }
        return true;
    }

    /**
     * Send WhatsApp Message (WhatsApp Business Cloud API or CallMeBot)
     */
    public static function sendWhatsApp(string $phone, string $message, ?string $mediaUrl = null): bool {
        $cleanPhone = preg_replace('/[^0-9]/', '', $phone);
        if (strlen($cleanPhone) === 10) {
            $cleanPhone = '91' . $cleanPhone;
        }

        // 1. WhatsApp Cloud API
        $waToken = defined('WHATSAPP_CLOUD_TOKEN') ? WHATSAPP_CLOUD_TOKEN : getenv('WHATSAPP_CLOUD_TOKEN');
        $phoneId = defined('WHATSAPP_PHONE_ID') ? WHATSAPP_PHONE_ID : getenv('WHATSAPP_PHONE_ID');
        if ($waToken && $phoneId) {
            $url = "https://graph.facebook.com/v18.0/{$phoneId}/messages";
            $payload = [
                'messaging_product' => 'whatsapp',
                'to' => $cleanPhone,
                'type' => 'text',
                'text' => ['body' => $message]
            ];
            $ch = curl_init($url);
            curl_setopt_array($ch, [
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_POST => true,
                CURLOPT_POSTFIELDS => json_encode($payload),
                CURLOPT_HTTPHEADER => [
                    'Authorization: Bearer ' . $waToken,
                    'Content-Type: application/json'
                ],
                CURLOPT_TIMEOUT => 10
            ]);
            $res = curl_exec($ch);
            $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
            curl_close($ch);
            if ($code === 200) return true;
        }

        // 2. CallMeBot Free WhatsApp API (for Admin/Testing)
        $callmeApiKey = defined('CALLMEBOT_API_KEY') ? CALLMEBOT_API_KEY : getenv('CALLMEBOT_API_KEY');
        if ($callmeApiKey) {
            $url = "https://api.callmebot.com/whatsapp.php?phone=" . urlencode($cleanPhone) .
                   "&text=" . urlencode($message) . "&apikey=" . urlencode($callmeApiKey);
            @file_get_contents($url);
        }

        // Fallback: Record to comm_logs
        $custPhone = substr($cleanPhone, -10);
        $cust = q("SELECT id FROM customers WHERE phone LIKE ? LIMIT 1", ['%' . $custPhone], true);
        if ($cust) {
            ex("INSERT INTO comm_logs (customer_id, channel, note, by_name, at) VALUES (?, 'WhatsApp (Simulated)', ?, 'SARVOOCCH WhatsApp Bot', NOW())",
                [$cust['id'], $message]);
        }
        return true;
    }

    /**
     * Dispatch Admin Notification (Telegram / Email)
     */
    public static function notifyAdmin(string $subject, string $details): void {
        $botToken = defined('TELEGRAM_BOT_TOKEN') ? TELEGRAM_BOT_TOKEN : getenv('TELEGRAM_BOT_TOKEN');
        $chatId = defined('TELEGRAM_CHAT_ID') ? TELEGRAM_CHAT_ID : getenv('TELEGRAM_CHAT_ID');

        if ($botToken && $chatId) {
            $text = "🔔 *SARVOOCCH System Alert*\n*{$subject}*\n\n{$details}";
            $url = "https://api.telegram.org/bot{$botToken}/sendMessage";
            $data = ['chat_id' => $chatId, 'text' => $text, 'parse_mode' => 'Markdown'];
            $ch = curl_init($url);
            curl_setopt_array($ch, [
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_POST => true,
                CURLOPT_POSTFIELDS => $data,
                CURLOPT_TIMEOUT => 5
            ]);
            @curl_exec($ch);
            @curl_close($ch);
        }
    }
}
