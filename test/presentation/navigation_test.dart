import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:parcial2/app.dart';
import 'package:parcial2/core/di/app_dependencies.dart';
import 'package:parcial2/domain/entities/diary_entry.dart';
import 'package:parcial2/domain/entities/mood.dart';

import '../helpers/fakes.dart';

/// Pruebas de widgets de la navegación principal con dependencias falsas.
void main() {
  setUpAll(() => initializeDateFormatting('es'));

  DiaryEntry entry(int id, String title) => DiaryEntry(
    id: id,
    title: title,
    content: 'Contenido $id',
    mood: Mood.good,
    createdAt: DateTime(2026, 11, id),
    updatedAt: DateTime(2026, 11, id),
  );

  Future<InMemoryDiaryRepository> pumpApp(WidgetTester tester) async {
    final repository = InMemoryDiaryRepository([
      entry(1, 'Primera entrada'),
      entry(2, 'Segunda entrada'),
    ]);
    await tester.pumpWidget(
      AppScope(
        dependencies: buildFakeDependencies(repository: repository),
        child: const HuellasApp(),
      ),
    );
    await tester.pumpAndSettle();
    return repository;
  }

  testWidgets('la lista carga los diarios con FutureBuilder', (tester) async {
    await pumpApp(tester);

    expect(find.text('Mis diarios'), findsOneWidget);
    expect(find.text('Primera entrada'), findsOneWidget);
    expect(find.text('Segunda entrada'), findsOneWidget);
  });

  testWidgets('lista -> detalle -> atrás recarga la lista', (tester) async {
    final repository = await pumpApp(tester);
    final callsBefore = repository.getAllCalls;

    await tester.tap(find.text('Segunda entrada'));
    await tester.pumpAndSettle();
    expect(find.text('¿Dónde estaba?'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Mis diarios'), findsOneWidget);
    expect(repository.getAllCalls, greaterThan(callsBefore));
    expect(tester.takeException(), isNull);
  });

  // Regresión: un setState que devolvía un Future dentro de didPopNext
  // dejaba el Navigator bloqueado y el detalle no se cerraba al borrar.
  testWidgets('eliminar desde el detalle regresa a la lista', (tester) async {
    final repository = await pumpApp(tester);

    await tester.tap(find.text('Segunda entrada'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Eliminar'));
    await tester.pumpAndSettle();
    expect(find.text('¿Eliminar entrada?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Mis diarios'), findsOneWidget);
    expect(find.text('Segunda entrada'), findsNothing);
    expect(find.text('Primera entrada'), findsOneWidget);
    expect(await repository.count(), 1);
  });

  testWidgets('el Drawer navega a Ajustes y atrás vuelve a la lista', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    expect(find.text('Mapa de recuerdos'), findsOneWidget);

    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    expect(find.text('Bloqueo biométrico'), findsOneWidget);

    // "Atrás" desde una sección siempre vuelve a la lista principal.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Mis diarios'), findsOneWidget);
  });
}
