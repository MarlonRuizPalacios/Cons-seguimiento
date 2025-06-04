import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import '../lib/screens/register_screen.dart';


void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Carga todos los campos de registro y botón', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: RegisterScreen()),
    );

    expect(find.byKey(Key('usernameField')), findsOneWidget);
    expect(find.byKey(Key('emailField')), findsOneWidget);
    expect(find.byKey(Key('passwordField')), findsOneWidget);
    expect(find.byKey(Key('confirmPasswordField')), findsOneWidget);
    expect(find.byKey(Key('registerButton')), findsOneWidget);
    expect(find.byKey(Key('toLoginButton')), findsOneWidget);
  });
}
