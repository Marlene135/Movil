// vistas/dashboard.dart - Resumen en vivo (datos reales de la base de datos)
import 'dart:async';
import 'package:flutter/material.dart';
import '../modulos/conv.dart';
import '../modulos/usuario.dart';
import '../servicios/api_service.dart';
import '../servicios/db_service.dart';
import 'cocina.dart';
import 'menu.dart';
import 'mesas.dart';
import 'reservaciones.dart';

class DashboardVista extends StatefulWidget {
  final Map<String, dynamic>? usuario;

  const DashboardVista({Key? key, this.usuario}) : super(key: key);

  @override
  State<DashboardVista> createState() => _DashboardVistaState();
}

class _DashboardVistaState extends State<DashboardVista> {
  // Clave para controlar el Drawer manualmente
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  Map<String, dynamic>? _resumen;
  String? _error;
  bool _cargando = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _cargar();
    // Se actualiza solo cada 20 segundos
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _cargar(silencioso: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _cargar({bool silencioso = false}) async {
    if (!silencioso && mounted) setState(() => _cargando = true);
    try {
      final r = await DbService.obtenerResumen();
      if (!mounted) return;
      setState(() {
        _resumen = r;
        _error = null;
        _cargando = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.mensaje;
        _cargando = false;
      });
    }
  }

  /// Abre una pantalla y, al volver, refresca los números del dashboard.
  void _ir(Widget pantalla) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla)).then((_) => _cargar(silencioso: true));
  }

  void _cerrarSesion() {
    DbService.cerrarSesion();
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  int _n(String grupo, String campo) {
    final g = _resumen?[grupo];
    return g is Map ? toInt(g[campo]) : 0;
  }

  @override
  Widget build(BuildContext context) {
    final String nombreMesero = widget.usuario?['nombre'] ?? 'Usuario';
    final String rol = widget.usuario?['rol'] ?? 'Mesero / Comandero';

    const Color bgOrange = Color(0xFFFAF8F5);
    const Color bgCardLight = Color(0xFFFFF9EC);
    const Color tealColor = Color(0xFFD7C9B8);
    const Color redColor = Color(0xFFD8C8B5);
    const Color yellowColor = Color(0xFFF1C40F);
    const Color blueColor = Color(0xFF6488E4);

    final int mesasTotal = _n('mesas', 'total');
    final int mesasDisp = _n('mesas', 'disponibles');
    final int mesasOcup = _n('mesas', 'ocupadas');
    final int prodTotal = _n('productos', 'total');
    final int prodDisp = _n('productos', 'disponibles');
    final int reservasHoy = toInt(_resumen?['reservas_hoy']);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: bgCardLight,

      // -------------------------------------------------------------
      // DRAWER: MENÚ LATERAL DESLIZABLE
      // -------------------------------------------------------------
      drawer: Drawer(
        child: Container(
          color: const Color(0xFF26201B),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              UserAccountsDrawerHeader(
                decoration: const BoxDecoration(color: Color(0xFF1B1612)),
                accountName: Text(
                  nombreMesero,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                accountEmail: Text(
                  rol,
                  style: const TextStyle(color: Colors.white70),
                ),
                currentAccountPicture: const CircleAvatar(
                  backgroundColor: bgOrange,
                  child: Icon(Icons.person, size: 40, color: Colors.white),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.dashboard_rounded, color: bgOrange),
                title: const Text('Inicio / Dashboard', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.calendar_month_rounded, color: Colors.white70),
                title: const Text('Reservaciones / Calendario', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _ir(ReservacionesVista(usuario: widget.usuario));
                },
              ),
              ListTile(
                leading: const Icon(Icons.table_restaurant_rounded, color: Colors.white70),
                title: const Text('Mesas Disponibles', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _ir(MesasScreen(usuario: widget.usuario));
                },
              ),
              ListTile(
                leading: const Icon(Icons.restaurant_menu_rounded, color: Colors.white70),
                title: const Text('Menú / Catálogo', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _ir(MenuVista(usuario: widget.usuario));
                },
              ),
              ListTile(
                leading: const Icon(Icons.soup_kitchen_rounded, color: Colors.white70),
                title: const Text('Cocina / Barra (KDS)', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _ir(CocinaVista(usuario: widget.usuario));
                },
              ),
              const Divider(color: Colors.white24),
              ListTile(
                leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                title: const Text('Cerrar Sesión', style: TextStyle(color: Colors.redAccent)),
                onTap: _cerrarSesion,
              ),
            ],
          ),
        ),
      ),

      // -------------------------------------------------------------
      // CUERPO DEL DASHBOARD
      // -------------------------------------------------------------
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _cargar(silencioso: true),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                // Header Curvo con Info del Usuario
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  decoration: const BoxDecoration(
                    color: bgOrange,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(36),
                      bottomRight: Radius.circular(36),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.menu_rounded, size: 28, color: Color(0xFF26201B)),
                            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                          ),
                          IconButton(
                            tooltip: 'Actualizar',
                            icon: const Icon(Icons.refresh_rounded, size: 28, color: Color(0xFF26201B)),
                            onPressed: () => _cargar(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: redColor, width: 2.5),
                            ),
                            child: const CircleAvatar(
                              radius: 36,
                              backgroundColor: Color(0xFF6488E4),
                              child: Icon(Icons.person, size: 42, color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nombreMesero,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF26201B),
                                ),
                              ),
                              Text(
                                rol,
                                style: const TextStyle(fontSize: 14, color: Color(0xFF6B645C)),
                              ),
                            ],
                          )
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      if (_error != null)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDECEA),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.wifi_off_rounded, color: Color(0xFFC62828)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(_error!, style: const TextStyle(fontSize: 12, color: Color(0xFFC62828))),
                              ),
                              TextButton(onPressed: () => _cargar(), child: const Text('Reintentar')),
                            ],
                          ),
                        ),

                      // Sección: Estado de órdenes
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Estado de Órdenes',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF26201B)),
                          ),
                          InkWell(
                            onTap: () => _ir(ReservacionesVista(usuario: widget.usuario)),
                            borderRadius: BorderRadius.circular(20),
                            child: CircleAvatar(
                              backgroundColor: tealColor,
                              radius: 20,
                              child: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 20),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      if (_cargando && _resumen == null)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(color: Color(0xFF26201B)),
                        )
                      else ...[
                        _buildTaskStatusRow(
                          color: redColor,
                          icon: Icons.access_time_rounded,
                          title: 'Pendientes',
                          subtitle: '${_n('pendientes', 'platillos')} platillos en espera '
                              '(${_n('pendientes', 'comandas')} comandas)',
                          onTap: () => _ir(CocinaVista(usuario: widget.usuario)),
                        ),
                        const SizedBox(height: 12),
                        _buildTaskStatusRow(
                          color: yellowColor,
                          icon: Icons.soup_kitchen_rounded,
                          title: 'En Preparación',
                          subtitle: '${_n('preparacion', 'platillos')} platillos en '
                              '${_n('preparacion', 'comandas')} comandas',
                          onTap: () => _ir(CocinaVista(usuario: widget.usuario)),
                        ),
                        const SizedBox(height: 12),
                        _buildTaskStatusRow(
                          color: blueColor,
                          icon: Icons.check_circle_rounded,
                          title: 'Listos para Entregar',
                          subtitle: '${_n('listos', 'platillos')} platillos listos en '
                              '${_n('listos', 'comandas')} comandas',
                          onTap: () => _ir(CocinaVista(usuario: widget.usuario)),
                        ),
                        if (esCajaOAdmin(widget.usuario)) ...[
                          const SizedBox(height: 12),
                          _buildTaskStatusRow(
                            color: const Color(0xFF2E7D32),
                            icon: Icons.payments_rounded,
                            title: 'Ventas de hoy',
                            subtitle: '${dinero(toDouble(_resumen?['ventas_hoy']))} · '
                                '${toInt(_resumen?['ordenes_abiertas'])} cuentas abiertas',
                          ),
                        ],
                      ],

                      const SizedBox(height: 24),

                      // Accesos rápidos
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Acceso Rápido',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF26201B)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: _buildProjectCard(
                              color: tealColor,
                              title: 'Mesas',
                              progress: '$mesasDisp disponibles · $mesasOcup ocupadas',
                              value: mesasTotal == 0 ? 0 : mesasOcup / mesasTotal,
                              centro: '$mesasTotal',
                              onTap: () => _ir(MesasScreen(usuario: widget.usuario)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildProjectCard(
                              color: redColor,
                              title: 'Menú POS',
                              progress: 'Tomar comanda · $prodDisp de $prodTotal disponibles',
                              value: prodTotal == 0 ? 0 : prodDisp / prodTotal,
                              centro: '$prodTotal',
                              onTap: () => _ir(MenuVista(usuario: widget.usuario)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildProjectCard(
                              color: const Color(0xFFC9B79E),
                              title: 'Cocina / Barra',
                              progress: 'Pantalla KDS en vivo',
                              value: 1,
                              centro: '${_n('pendientes', 'platillos') + _n('preparacion', 'platillos')}',
                              onTap: () => _ir(CocinaVista(usuario: widget.usuario)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildProjectCard(
                              color: const Color(0xFFB8A58C),
                              title: 'Reservaciones',
                              progress: '$reservasHoy para hoy',
                              value: reservasHoy == 0 ? 0 : 1,
                              centro: '$reservasHoy',
                              onTap: () => _ir(ReservacionesVista(usuario: widget.usuario)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTaskStatusRow({
    required Color color,
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color,
            radius: 20,
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF26201B)),
                ),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectCard({
    required Color color,
    required String title,
    required String progress,
    required double value,
    required String centro,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 160,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(24)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 42,
                    height: 42,
                    child: CircularProgressIndicator(
                      value: value.clamp(0.0, 1.0).toDouble(),
                      color: Colors.white,
                      backgroundColor: Colors.white24,
                      strokeWidth: 3,
                    ),
                  ),
                  Text(
                    centro,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  progress,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
