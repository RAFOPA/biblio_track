import 'package:excel/excel.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ReportExportService {
  static Future<Uint8List> toTablePdf(Map<String, dynamic> report) async {
    final pdf = pw.Document();
    final font = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Inter-Variable.ttf'),
    );
    final columns = _stringList(report['columns']);
    final rows = _stringRows(report['rows']);
    final period = _map(report['period']);
    pdf.addPage(
      pw.MultiPage(
        pageFormat: columns.length > 6
            ? PdfPageFormat.a4.landscape
            : PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(
          base: font,
          bold: font,
          italic: font,
          boldItalic: font,
        ),
        build: (_) => [
          pw.Text(
            'BiblioTrack',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            'Reporte de ${report['title'] ?? 'datos'}',
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
          ),
          if (period.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4, bottom: 12),
              child: pw.Text(
                'Desde ${_date(period['start'])} hasta ${_date(period['end'])}',
              ),
            )
          else
            pw.SizedBox(height: 12),
          _table(columns, rows),
        ],
      ),
    );
    return Uint8List.fromList(await pdf.save());
  }

  static Uint8List toTableExcel(Map<String, dynamic> report) {
    final workbook = Excel.createExcel();
    workbook.rename('Sheet1', 'Reporte');
    final sheet = workbook['Reporte'];
    final columns = _stringList(report['columns']);
    final rows = _stringRows(report['rows']);
    final period = _map(report['period']);
    sheet.appendRow([TextCellValue('BiblioTrack')]);
    sheet.appendRow([
      TextCellValue('Reporte de ${report['title'] ?? 'datos'}'),
    ]);
    if (period.isNotEmpty) {
      sheet.appendRow([
        TextCellValue(
          'Desde ${_date(period['start'])} hasta ${_date(period['end'])}',
        ),
      ]);
    }
    sheet.appendRow([TextCellValue('')]);
    final headerRow = sheet.maxRows;
    sheet.appendRow(columns.map(TextCellValue.new).toList());
    for (final row in rows) {
      sheet.appendRow(row.map(TextCellValue.new).toList());
    }

    final titleStyle = CellStyle(
      bold: true,
      fontSize: 16,
      fontColorHex: ExcelColor.fromHexString('#09144D'),
    );
    final headerStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      backgroundColorHex: ExcelColor.fromHexString('#09144D'),
      textWrapping: TextWrapping.WrapText,
    );
    sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
            .cellStyle =
        titleStyle;
    sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1))
            .cellStyle =
        titleStyle;
    for (var column = 0; column < columns.length; column++) {
      sheet
              .cell(
                CellIndex.indexByColumnRow(
                  columnIndex: column,
                  rowIndex: headerRow,
                ),
              )
              .cellStyle =
          headerStyle;
      sheet.setColumnWidth(column, 22);
    }
    final bytes = workbook.encode();
    if (bytes == null) throw StateError('No se pudo crear el archivo Excel.');
    return Uint8List.fromList(bytes);
  }

  static Future<Uint8List> toPdf(Map<String, dynamic> report) async {
    final pdf = pw.Document();
    final font = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Inter-Variable.ttf'),
    );
    final totals = _map(report['totales']);
    final period = _map(report['periodo']);
    pdf.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(
          base: font,
          bold: font,
          italic: font,
          boldItalic: font,
        ),
        build: (_) => [
          pw.Text(
            'BiblioTrack - Reporte de uso',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Período: ${_date(period['inicio'])} al ${_date(period['fin'])}',
          ),
          pw.SizedBox(height: 14),
          pw.Text(
            'Totales',
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
          ),
          _table(
            ['Indicador', 'Total'],
            [
              ['Usuarios', _value(totals['usuarios'])],
              ['Recursos', _value(totals['recursos'])],
              ['Préstamos', _value(totals['prestamos'])],
              ['Reservas', _value(totals['reservas'])],
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Text(
            'Préstamos por tipo de recurso',
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
          ),
          _table(
            ['Tipo', 'Préstamos'],
            _rows(
              report['prestamosPorTipo'],
              (row) => [_value(row['tipo']), _value(row['prestamos'])],
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Text(
            'Usuarios con más préstamos',
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
          ),
          _table(
            ['Usuario', 'Carnet', 'Préstamos'],
            _rows(
              report['usuariosConMasPrestamos'],
              (row) => [
                _value(row['nombre']),
                _value(row['carnet']),
                _value(row['prestamos']),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Text(
            'Recursos más solicitados',
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
          ),
          _table(
            ['Recurso', 'Tipo', 'Solicitudes'],
            _rows(
              report['recursosMasSolicitados'],
              (row) => [
                _value(row['nombre']),
                _value(row['tipo']),
                _value(row['solicitudes']),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Text(
            'Préstamos por día',
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
          ),
          _table(
            ['Fecha', 'Préstamos'],
            _rows(
              report['prestamosPorDia'],
              (row) => [_value(row['_id']), _value(row['total'])],
            ),
          ),
        ],
      ),
    );
    return Uint8List.fromList(await pdf.save());
  }

  static Uint8List toExcel(Map<String, dynamic> report) {
    final workbook = Excel.createExcel();
    workbook.rename('Sheet1', 'Reporte');
    final sheet = workbook['Reporte'];
    final totals = _map(report['totales']);
    final period = _map(report['periodo']);
    void row(List<Object?> cells) => sheet.appendRow(cells.map(_cell).toList());
    row(['BiblioTrack - Reporte de uso']);
    row(['Período', '${_date(period['inicio'])} al ${_date(period['fin'])}']);
    row([]);
    row(['Totales']);
    row(['Indicador', 'Total']);
    for (final entry in [
      ['Usuarios', totals['usuarios']],
      ['Recursos', totals['recursos']],
      ['Préstamos', totals['prestamos']],
      ['Reservas', totals['reservas']],
    ]) {
      row(entry);
    }
    _appendSection(
      sheet,
      'Préstamos por tipo de recurso',
      ['Tipo', 'Préstamos'],
      report['prestamosPorTipo'],
      (item) => [item['tipo'], item['prestamos']],
    );
    _appendSection(
      sheet,
      'Usuarios con más préstamos',
      ['Usuario', 'Carnet', 'Préstamos'],
      report['usuariosConMasPrestamos'],
      (item) => [item['nombre'], item['carnet'], item['prestamos']],
    );
    _appendSection(
      sheet,
      'Recursos más solicitados',
      ['Recurso', 'Tipo', 'Solicitudes'],
      report['recursosMasSolicitados'],
      (item) => [item['nombre'], item['tipo'], item['solicitudes']],
    );
    _appendSection(
      sheet,
      'Préstamos por día',
      ['Fecha', 'Préstamos'],
      report['prestamosPorDia'],
      (item) => [item['_id'], item['total']],
    );
    final bytes = workbook.encode();
    if (bytes == null) throw StateError('No se pudo crear el archivo Excel.');
    return Uint8List.fromList(bytes);
  }

  static void _appendSection(
    Sheet sheet,
    String title,
    List<String> headers,
    dynamic source,
    List<Object?> Function(Map<String, dynamic>) values,
  ) {
    sheet.appendRow([TextCellValue('')]);
    sheet.appendRow([TextCellValue(title)]);
    sheet.appendRow(headers.map((value) => TextCellValue(value)).toList());
    for (final item in source is List ? source : const []) {
      sheet.appendRow(values(_map(item)).map(_cell).toList());
    }
  }

  static List<List<String>> _rows(
    dynamic source,
    List<String> Function(Map<String, dynamic>) values,
  ) {
    if (source is! List) return [];
    return source.map((item) => values(_map(item))).toList();
  }

  static List<String> _stringList(dynamic source) =>
      source is List ? source.map(_value).toList() : <String>[];

  static List<List<String>> _stringRows(dynamic source) => source is List
      ? source.map((row) => _stringList(row)).toList()
      : <List<String>>[];

  static pw.Widget _table(List<String> headers, List<List<String>> rows) =>
      pw.TableHelper.fromTextArray(
        headers: headers,
        data: rows,
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        headerDecoration: pw.BoxDecoration(color: PdfColor(0.91, 0.93, 0.96)),
        cellPadding: const pw.EdgeInsets.all(5),
      );

  static CellValue _cell(Object? value) => switch (value) {
    num number => IntCellValue(number.toInt()),
    bool boolean => BoolCellValue(boolean),
    _ => TextCellValue(_value(value)),
  };

  static Map<String, dynamic> _map(dynamic value) =>
      value is Map<String, dynamic> ? value : <String, dynamic>{};

  static String _value(dynamic value) => value?.toString() ?? '—';

  static String _date(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return '—';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
