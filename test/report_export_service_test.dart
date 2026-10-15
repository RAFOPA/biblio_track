import 'package:excel/excel.dart';
import 'package:biblio_track/report_export_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final report = <String, dynamic>{
    'periodo': {
      'inicio': '2026-10-01T00:00:00.000Z',
      'fin': '2026-10-15T23:59:59.999Z',
    },
    'totales': {'usuarios': 8, 'recursos': 12, 'prestamos': 4, 'reservas': 5},
    'recursosMasSolicitados': [
      {'nombre': 'Libro A', 'tipo': 'Libro', 'solicitudes': 3},
    ],
    'prestamosPorDia': [
      {'_id': '2026-10-15', 'total': 2},
    ],
    'prestamosPorTipo': [
      {'tipo': 'Libro', 'prestamos': 3},
      {'tipo': 'Computadora', 'prestamos': 1},
    ],
    'usuariosConMasPrestamos': [
      {'nombre': 'Ana Pérez', 'carnet': 'A1', 'prestamos': 2},
    ],
  };

  test('creates a PDF report document', () async {
    final bytes = await ReportExportService.toPdf(report);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(500));
  });

  test('creates an XLSX workbook with the requested report sections', () {
    final bytes = ReportExportService.toExcel(report);
    expect(bytes.take(2), [0x50, 0x4b]);
    final workbook = Excel.decodeBytes(bytes);
    expect(workbook.sheets.keys, contains('Reporte'));
    expect(workbook['Reporte'].rows.length, greaterThan(10));
  });
}
