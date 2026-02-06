import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cruze_mobile/main.dart';
import 'package:cruze_mobile/screens/login_screen.dart';

void main() {
  testWidgets('CruzeApp loads LoginScreen', (WidgetTester tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
    const transparentImageBase64 =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8Xw8AAn8B9s8SgC0AAAAASUVORK5CYII=';
    final transparentImageBytes = base64Decode(transparentImageBase64);
    final emptyManifestBin = const StandardMessageCodec()
        .encodeMessage(<String, List<String>>{})!;
    TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
      final key = utf8.decode(message!.buffer.asUint8List());
      if (key == 'AssetManifest.json') {
        return ByteData.view(utf8.encode('{}').buffer);
      }
      if (key == 'AssetManifest.bin') {
        return emptyManifestBin;
      }
      if (key.startsWith('assets/images/')) {
        return ByteData.view(Uint8List.fromList(transparentImageBytes).buffer);
      }
      if (key == 'env/.env') {
        return ByteData.view(utf8.encode('').buffer);
      }
      return null;
    });

    // Build our app and trigger a frame.
    await tester.pumpWidget(const CruzeApp());

    // Verify that LoginScreen is present
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('CRUZE'), findsOneWidget);
  });
}
