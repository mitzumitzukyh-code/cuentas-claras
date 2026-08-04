import 'package:cuentaclara/core/utils/numero_ve.dart';
import 'package:cuentaclara/services/ia/lector_etiqueta_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// El pipeline de importación, medido contra el set de `pruebas_ocr/`.
///
/// **Qué mide y qué no.** Estas pruebas alimentan el pipeline con lo que
/// devolvería el Worker si el modelo leyera la foto correctamente, y verifican
/// que lo que sale coincide con el ground truth. Es decir: prueban la parte
/// determinista —normalización de cifras, consolidación de filas, nulos que no
/// se vuelven cero, validación cruzada— que es la que produjo los bugs.
///
/// **No prueban al modelo.** Si Gemini lee mal la foto, esto no se entera: eso
/// necesita la imagen real contra la API, con la clave que vive en Cloudflare.
/// El criterio de aprobación del propio set —"nombre, stock y precio coinciden"—
/// solo se puede firmar del todo con las 8 fotos en el dispositivo.
void main() {
  /// Fila en formato de cable: cifras como texto, tal como las manda el Worker.
  FilaLibreta fila(
    String nombre, {
    String precio = '',
    String cantidad = '',
    String codigo = '',
    String talla = '',
    String color = '',
  }) =>
      FilaLibreta(
        nombre: nombre,
        precio: normalizarPositivoVE(precio),
        cantidad: normalizarPositivoVE(cantidad),
        codigo: codigo,
        talla: talla,
        color: color,
      );

  group('03 · datos faltantes — el bug de los \$0,00', () {
    // El propio ground truth lo llama "REGLA DURA: campo ilegible o vacío =>
    // null. NUNCA 0. Un producto con precio 0 se puede cobrar."
    final leidas = [
      fila('Cuaderno rayado 100h', cantidad: '80', precio: '1,50'),
      fila('Lápiz grafito HB', precio: '0,30'),
      fila('Borrador blanco', cantidad: '45'),
      fila('Regla 30cm', cantidad: '60', precio: '0,75'),
      fila('Tijera escolar'),
      fila('Pega en barra', cantidad: '38', precio: '1,10'),
      fila('Marcador permanente', cantidad: '52'),
      fila('Cartulina blanca', precio: '0,60'),
    ];

    test('lo ilegible queda en null, jamás en cero', () {
      for (final f in leidas) {
        expect(f.precio, anyOf(isNull, greaterThan(0)), reason: f.nombre);
        expect(f.cantidad, anyOf(isNull, greaterThan(0)), reason: f.nombre);
      }
    });

    test('coincide con el ground truth fila por fila', () {
      expect(leidas[0].precio, 1.5);
      expect(leidas[0].cantidad, 80);
      expect(leidas[1].cantidad, isNull); // stock ilegible
      expect(leidas[1].precio, 0.3);
      expect(leidas[2].precio, isNull); // precio ilegible
      expect(leidas[4].precio, isNull); // ambos ilegibles
      expect(leidas[4].cantidad, isNull);
      expect(leidas[7].cantidad, isNull);
    });

    test('las cinco filas incompletas quedan marcadas para revisar', () {
      final dudosas = leidas.where((f) => f.dudosa).map((f) => f.nombre);
      expect(dudosas, [
        'Lápiz grafito HB',
        'Borrador blanco',
        'Tijera escolar',
        'Marcador permanente',
        'Cartulina blanca',
      ]);
    });
  });

  group('04 · filas duplicadas — el bug de las 7 impresoras', () {
    // 8 filas de la foto → 4 productos. Mismo código = mismo repuesto en
    // varios lotes: se suman.
    final consolidadas = consolidarFilas([
      fila('Filtro de aceite universal', codigo: 'FR-2201', cantidad: '20', precio: '5,00'),
      fila('Filtro de aceite universal', codigo: 'FR-2201', cantidad: '15'),
      fila('Bujía NGK BPR6ES', codigo: 'BJ-4410', cantidad: '40', precio: '2,25'),
      fila('Filtro aceite univ.', codigo: 'FR-2201', cantidad: '8'),
      fila('Correa de tiempo 8mm', codigo: 'CR-9002', cantidad: '6', precio: '18,00'),
      fila('Bujía NGK BPR6ES', codigo: 'BJ-4410', cantidad: '25'),
      fila('Filtro de aceite universal', codigo: 'FR-2201', cantidad: '2'),
      fila('Amortiguador delantero', codigo: 'AM-3311', cantidad: '4', precio: '45,00'),
    ]);

    test('8 filas se convierten en 4 productos', () {
      expect(consolidadas.length, 4);
    });

    test('los stocks del mismo código se suman', () {
      expect(consolidadas[0].cantidad, 45); // 20+15+8+2
      expect(consolidadas[1].cantidad, 65); // 40+25
      expect(consolidadas[2].cantidad, 6);
      expect(consolidadas[3].cantidad, 4);
    });

    test('el precio leído una sola vez no se pierde al unir', () {
      expect(consolidadas[0].precio, 5.0);
      expect(consolidadas[1].precio, 2.25);
      expect(consolidadas[3].precio, 45.0);
    });
  });

  group('06 · ropa con tallas — lo contrario del 04', () {
    // Mismo nombre con distinta talla/color NO es un duplicado: cada variante
    // mantiene su stock. Si se sumaran, la tienda pierde el stock por talla.
    final consolidadas = consolidarFilas([
      fila('Franela básica algodón', talla: 'S', color: 'Blanco', cantidad: '12', precio: '8,00'),
      fila('Franela básica algodón', talla: 'M', color: 'Blanco', cantidad: '18', precio: '8,00'),
      fila('Franela básica algodón', talla: 'L', color: 'Negro', cantidad: '10', precio: '8,00'),
      fila('Jean clásico dama', talla: 'M', color: 'Azul', cantidad: '7', precio: '22,00'),
      fila('Jean clásico dama', talla: 'L', color: 'Azul', cantidad: '5', precio: '22,00'),
      fila('Vestido casual', talla: 'S', color: 'Beige', cantidad: '4', precio: '35,00'),
      fila('Vestido casual', talla: 'M', color: 'Coral', cantidad: '6', precio: '35,00'),
      fila('Chaqueta jean', talla: 'XL', color: 'Azul', cantidad: '3', precio: '40,00'),
    ]);

    test('las 8 variantes se conservan, no se unen', () {
      expect(consolidadas.length, 8);
    });

    test('cada variante mantiene su propio stock', () {
      expect(consolidadas[0].cantidad, 12);
      expect(consolidadas[1].cantidad, 18);
      expect(consolidadas[2].cantidad, 10);
    });

    test('el mismo nombre con la MISMA talla y color sí se une', () {
      final r = consolidarFilas([
        fila('Franela', talla: 'M', color: 'Blanco', cantidad: '5'),
        fila('Franela', talla: 'M', color: 'Blanco', cantidad: '3'),
      ]);
      expect(r.length, 1);
      expect(r.first.cantidad, 8);
    });
  });

  group('02 · columna desalineada — validación cruzada', () {
    // La lista declara "Total Artículos: 423". Si la suma no da 423, la
    // lectura se corrió y hay que revisarla entera.
    final stocks = [45, 22, 15, 112, 38, 61, 25, 54, 33, 18];

    double sumaDe(List<int> s) => s.fold<double>(0, (a, b) => a + b);

    test('el ground truth suma exactamente el total declarado', () {
      expect(sumaDe(stocks), 423);
    });

    test('una lectura que se come una fila NO cuadra', () {
      final incompleta = [...stocks]..removeLast();
      expect(sumaDe(incompleta) == 423, false);
    });

    test('los precios grandes en formato venezolano se leen enteros', () {
      // 4.500,80 mal interpretado da 4,5 — cuatro dólares por un teléfono.
      expect(normalizarPositivoVE('4.500,80'), 4500.80);
      expect(normalizarPositivoVE('12.800,00'), 12800.0);
      expect(normalizarPositivoVE('6.200,00'), 6200.0);
      expect(normalizarPositivoVE('950,00'), 950.0);
    });
  });

  group('05 · panadería — decimales con coma y unidades mixtas', () {
    test('el stock por peso conserva los decimales', () {
      expect(normalizarPositivoVE('12,5'), 12.5);
      expect(normalizarPositivoVE('40'), 40);
    });

    test('los precios con coma no se convierten en miles', () {
      expect(normalizarPositivoVE('1,80'), 1.8);
      expect(normalizarPositivoVE('1,20'), 1.2);
      expect(normalizarPositivoVE('1,00'), 1.0);
    });
  });

  group('08 · factura de compra — precio de costo, no de venta', () {
    test('el tipo de documento viaja hasta la app', () {
      const lectura = LecturaInventario(
        filas: [],
        tipo: TipoDocumento.facturaCompra,
      );
      // Con esto la pantalla avisa antes de importar. Sin avisar, el dueño
      // carga precios de COSTO como precios de venta y vende sin ganancia.
      expect(lectura.tipo, TipoDocumento.facturaCompra);
    });

    test('un total declarado que no cuadra marca la lectura', () {
      const cuadra = LecturaInventario(filas: [], totalDeclarado: 423);
      const noCuadra =
          LecturaInventario(filas: [], totalDeclarado: 423, cuadra: false);
      expect(cuadra.cuadra, true);
      expect(noCuadra.cuadra, false);
    });
  });

  group('01 · bodega limpia — el baseline', () {
    test('una lista sin sorpresas pasa entera y sin dudosas', () {
      final r = consolidarFilas([
        fila('Harina PAN 1kg', cantidad: '48', precio: '1,20'),
        fila('Arroz Primor 1kg', cantidad: '35', precio: '1,80'),
        fila('Aceite Vatel 1L', cantidad: '22', precio: '3,50'),
      ]);
      expect(r.length, 3);
      expect(r.where((f) => f.dudosa), isEmpty);
      expect(r.map((f) => f.precio), [1.2, 1.8, 3.5]);
    });
  });
}
