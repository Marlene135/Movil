import 'package:flutter_test/flutter_test.dart';
import 'package:menu_mesaeros/main.dart';

void main() {
  testWidgets('Carga de pantalla inicial de PIN', (WidgetTester tester) async {
    await tester.pumpWidget(const SazonTrackApp());
    expect(find.text('SazónTrack'), findsOneWidget);
    expect(find.text('PIN'), findsOneWidget);
  });
}