import 'package:flutter/material.dart';

class PrivacyPolicyDialog extends StatelessWidget {
  const PrivacyPolicyDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (context) => const PrivacyPolicyDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1C1E24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.privacy_tip_outlined,
                    color: Color(0xFF0A84FF),
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    '隱私政策與條款',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    '1. 本應用程式（音流）為開源獨立音樂客戶端。\n\n'
                    '2. 本地儲存：您的伺服器位址、使用者名稱、密碼均僅儲存在您本機設備的加密/受保護資料庫中，絕不上傳至任何第三方伺服器。\n\n'
                    '3. 網路通訊：本應用僅直接與您所配置的自建音樂伺服器（如 Navidrome、Subsonic 等）進行通訊。\n\n'
                    '4. 音訊快取與下載：您選擇離線下載的歌曲將僅保留在您的本機磁碟中，隨時可手動管理與清除。',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                      height: 1.6,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0A84FF),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('我知道了'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
