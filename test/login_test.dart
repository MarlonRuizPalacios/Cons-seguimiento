import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import '../lib/screens/login_screen.dart'; 

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();


  testWidgets('Verifica la carga de los campos de email, contraseña y botón de login',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(),
      ),
    );

    expect(find.byKey(Key('emailField')), findsOneWidget);
    expect(find.byKey(Key('passwordField')), findsOneWidget);
    expect(find.byKey(Key('loginButton')), findsOneWidget);
  });
}
