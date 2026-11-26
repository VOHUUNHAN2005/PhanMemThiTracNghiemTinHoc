import 'package:flutter/material.dart';
import 'package:user/core/constants/api_constants.dart';

class QuestionImageBox extends StatelessWidget {
  final dynamic rawImageUrl;
  final double maxHeight;

  const QuestionImageBox({
    super.key,
    required this.rawImageUrl,
    this.maxHeight = 220,
  });

  static String resolveUrl(dynamic raw) {
    String url = (raw ?? '').toString().trim();
    if (url.isEmpty || url.toLowerCase() == 'null') return '';

    final baseUri = Uri.parse(ApiConstants.baseUrl);
    final serverOrigin =
        '${baseUri.scheme}://${baseUri.host}${baseUri.hasPort ? ':${baseUri.port}' : ''}';

    if (url.startsWith('http://') || url.startsWith('https://')) {
      final parsed = Uri.tryParse(url);
      if (parsed != null &&
          (parsed.host == 'localhost' || parsed.host == '127.0.0.1')) {
        final query = parsed.hasQuery ? '?${parsed.query}' : '';
        return '$serverOrigin${parsed.path}$query';
      }
      return url;
    }

    return url.startsWith('/') ? '$serverOrigin$url' : '$serverOrigin/$url';
  }

  void _openFullScreen(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.0,
              child: Center(
                child: Image.network(imageUrl, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = resolveUrl(rawImageUrl);
    if (imageUrl.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: GestureDetector(
        onTap: () => _openFullScreen(context, imageUrl),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: Center(
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.broken_image_outlined,
                                      color: Colors.grey),
                                  SizedBox(width: 8),
                                  Text(
                                    'Không tải được hình ảnh minh họa',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                imageUrl,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.zoom_in_rounded, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Phóng to',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}