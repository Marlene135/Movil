// Acceso a datos de la app. Todo pasa por los endpoints PHP de /KDS/api,
// que son los que hablan con PostgreSQL (sazontrack_db2).
import 'api_service.dart';
import '../modulos/orden.dart';
import '../modulos/producto.dart';
import '../modulos/reserva.dart';

List<Map<String, dynamic>> _lista(dynamic data) =>
    ((data as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

Map<String, dynamic> _mapa(dynamic data) => Map<String, dynamic>.from(data as Map);

class DbService {
  // ------------------------------------------------------------------ Sesión
  /// Valida el PIN. Devuelve el usuario (y guarda el token) o null si el PIN es incorrecto.
  static Future<Map<String, dynamic>?> validarPin(String pin) async {
    try {
      final r = await ApiService.post('login.php', body: {'pin': pin});
      final usuario = r['usuario'];
      final token = r['token'];
      if (usuario is Map && token != null) {
        ApiService.token = token.toString();
        return Map<String, dynamic>.from(usuario);
      }
      return null;
    } on ApiException catch (e) {
      if (e.codigo == 401) return null; // PIN incorrecto
      rethrow;
    }
  }

  static void cerrarSesion() => ApiService.token = null;

  // --------------------------------------------------------------- Dashboard
  static Future<Map<String, dynamic>> obtenerResumen() async =>
      _mapa((await ApiService.get('api/dashboard.php'))['data']);

  // ------------------------------------------------------------------ Áreas
  static Future<List<Area>> obtenerAreas() async =>
      _lista((await ApiService.get('api/areas.php'))['data']).map(Area.fromMap).toList();

  static Future<Area> crearArea(String nombre) async => Area.fromMap(
      _mapa((await ApiService.post('api/areas.php', body: {'nombre': nombre}))['data']));

  static Future<void> renombrarArea(int id, String nombre) async {
    await ApiService.put('api/areas.php', query: {'id': id}, body: {'nombre': nombre});
  }

  static Future<void> eliminarArea(int id) async {
    await ApiService.delete('api/areas.php', query: {'id': id});
  }

  // ------------------------------------------------------------------ Mesas
  static Future<List<Mesa>> obtenerMesas() async =>
      _lista((await ApiService.get('api/mesas.php'))['data']).map(Mesa.fromMap).toList();

  static Future<Mesa> crearMesa({required String numero, required int capacidad, int? idArea}) async =>
      Mesa.fromMap(_mapa((await ApiService.post('api/mesas.php',
          body: {'numero': numero, 'capacidad': capacidad, 'id_area': idArea}))['data']));

  static Future<void> actualizarMesa(int id, Map<String, dynamic> campos) async {
    await ApiService.put('api/mesas.php', query: {'id': id}, body: campos);
  }

  static Future<void> eliminarMesa(int id) async {
    await ApiService.delete('api/mesas.php', query: {'id': id});
  }

  /// Guarda posición y unión de varias mesas a la vez.
  static Future<void> guardarLayout(List<Mesa> mesas) async {
    await ApiService.post('api/mesas.php',
      query: {'accion': 'layout'},
      body: {
        'mesas': mesas
            .map((m) => {'id': m.id, 'pos_x': m.x.round(), 'pos_y': m.y.round(), 'grupo_union': m.grupo})
            .toList()
      });
  }

  // -------------------------------------------------------------- Categorías
  static Future<List<Categoria>> obtenerCategorias({bool todas = false}) async => _lista(
          (await ApiService.get('api/categorias.php', query: {'todas': todas ? 1 : 0}))['data'])
      .map(Categoria.fromMap)
      .toList();

  static Future<void> crearCategoria(String nombre, String estacion) async {
    await ApiService.post('api/categorias.php', body: {'nombre': nombre, 'estacion': estacion});
  }

  static Future<void> actualizarCategoria(int id, Map<String, dynamic> campos) async {
    await ApiService.put('api/categorias.php', query: {'id': id}, body: campos);
  }

  // --------------------------------------------------------------- Productos
  static Future<List<Producto>> obtenerProductos({bool todos = false}) async => _lista(
          (await ApiService.get('api/productos.php', query: {'todos': todos ? 1 : 0}))['data'])
      .map(Producto.fromMap)
      .toList();

  static Future<void> crearProducto(Map<String, dynamic> campos) async {
    await ApiService.post('api/productos.php', body: campos);
  }

  static Future<void> actualizarProducto(int id, Map<String, dynamic> campos) async {
    await ApiService.put('api/productos.php', query: {'id': id}, body: campos);
  }

  static Future<void> desactivarProducto(int id) async {
    await ApiService.delete('api/productos.php', query: {'id': id});
  }

  // ----------------------------------------------------------------- Órdenes
  /// Cuenta abierta de la mesa (null si no tiene).
  static Future<Orden?> obtenerOrdenMesa(int idMesa) async {
    final data = (await ApiService.get('api/ordenes.php', query: {'id_mesa': idMesa}))['data'];
    return data == null ? null : Orden.fromMap(_mapa(data));
  }

  static Future<Orden> abrirMesa(int idMesa, int comensales) async => Orden.fromMap(_mapa(
      (await ApiService.post('api/ordenes.php',
          query: {'accion': 'abrir'}, body: {'id_mesa': idMesa, 'comensales': comensales}))['data']));

  /// Envía la comanda a cocina/barra. [items] = [{id_producto, cantidad, notas}]
  static Future<Orden> enviarComanda(int idMesa, List<Map<String, dynamic>> items,
          {int? comensales}) async =>
      Orden.fromMap(_mapa((await ApiService.post('api/ordenes.php',
          query: {'accion': 'enviar'},
          body: {'id_mesa': idMesa, 'items': items, 'comensales': comensales ?? 1}))['data']));

  static Future<Orden> cancelarItem(int idDetalle) async => Orden.fromMap(_mapa(
      (await ApiService.post('api/ordenes.php',
          query: {'accion': 'cancelar_item'}, body: {'id_detalle': idDetalle}))['data']));

  static Future<void> cancelarOrden(int idOrden) async {
    await ApiService.post('api/ordenes.php',
      query: {'accion': 'cancelar_orden'}, body: {'id_orden': idOrden});
  }

  /// Cobra una o varias cuentas (mesas unidas). Devuelve {total, cambio, propina, folios}.
  static Future<Map<String, dynamic>> pagar({
    required List<int> idsOrden,
    required String metodoPago,
    required double montoRecibido,
    double propina = 0,
  }) async =>
      _mapa((await ApiService.post('api/ordenes.php', query: {
        'accion': 'pagar'
      }, body: {
        'ids_orden': idsOrden,
        'metodo_pago': metodoPago,
        'monto_recibido': montoRecibido,
        'propina': propina,
      }))['data']);

  // --------------------------------------------------------------------- KDS
  static Future<List<KdsItem>> obtenerKds({String? estacion}) async => _lista(
          (await ApiService.get('api/kds.php', query: {'estacion': estacion}))['data'])
      .map(KdsItem.fromMap)
      .toList();

  static Future<void> cambiarEstadoItems(List<int> ids, String estado) async {
    await ApiService.post('api/kds.php', query: {'accion': 'estado'}, body: {'ids': ids, 'estado': estado});
  }

  // ---------------------------------------------------------------- Reservas
  /// Reservas de un mes (mes = 1..12).
  static Future<List<Reserva>> obtenerReservasMes(int anio, int mes) async {
    final m = '$anio-${mes.toString().padLeft(2, '0')}';
    return _lista((await ApiService.get('api/reservas.php', query: {'mes': m}))['data'])
        .map(Reserva.fromMap)
        .toList();
  }

  static Future<void> crearReserva(Map<String, dynamic> campos) async {
    await ApiService.post('api/reservas.php', body: campos);
  }

  static Future<void> actualizarReserva(int id, Map<String, dynamic> campos) async {
    await ApiService.put('api/reservas.php', query: {'id': id}, body: campos);
  }

  static Future<void> eliminarReserva(int id) async {
    await ApiService.delete('api/reservas.php', query: {'id': id});
  }
}
