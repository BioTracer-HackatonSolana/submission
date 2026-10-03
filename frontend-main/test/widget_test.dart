import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:biotracer/app.dart';

Future<void> _selectRole(WidgetTester tester, String label) async {
  await tester.tap(find.byTooltip('Trocar papel da demo'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('dashboard abre com lote real do cenário', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: BioTracerApp()));

    expect(find.text('Visão geral'), findsOneWidget);
    expect(find.text('Cada etapa, um registro.'), findsWidgets);
    expect(find.text('BT-2048'), findsOneWidget);
    expect(find.text('Equipo de infusão'), findsOneWidget);
    expect(find.text('1,024'), findsNothing);
  });

  testWidgets('fabricante vê o formulário de registro', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: BioTracerApp()));
    await _openTab(tester, 'Registrar');

    expect(find.text('Registrar novo produto'), findsOneWidget);
    expect(find.text('Registrar e Emitir Lote'), findsOneWidget);
  });

  testWidgets('identificação simulada libera o envio', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: BioTracerApp()));
    await _selectRole(tester, 'Distribuidor');
    await _openTab(tester, 'Receber');

    await tester.ensureVisible(find.text('Usar lote demo'));
    await tester.tap(find.text('Usar lote demo'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Enviar lote'), findsOneWidget);
    expect(
      find.text('Lote BT-2048 identificado. Confira os dados antes de enviar.'),
      findsOneWidget,
    );
  });

  testWidgets('histórico lista eventos reais do lote', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: BioTracerApp()));
    await _openTab(tester, 'Histórico');

    expect(find.text('Histórico do produto'), findsOneWidget);
    expect(find.text('Lote registrado'), findsOneWidget);
    expect(find.text('Custódia recebida'), findsOneWidget);
  });

  testWidgets('layout não lança exceção em larguras móveis', (
    WidgetTester tester,
  ) async {
    for (final width in [320.0, 375.0, 414.0, 768.0]) {
      tester.view
        ..physicalSize = Size(width, 900)
        ..devicePixelRatio = 1;
      await tester.pumpWidget(const ProviderScope(child: BioTracerApp()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'largura $width');
    }
    addTearDown(tester.view.resetPhysicalSize);
  });
}
