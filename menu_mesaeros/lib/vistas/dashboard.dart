// vistas/dashboard.dart - Resumen en vivo (datos reales de la base de datos)
import 'dart:async';
import 'package:flutter/material.dart';
import '../modulos/conv.dart';
import '../modulos/usuario.dart';
import '../servicios/api_service.dart';
import '../servicios/db_service.dart';
import '../widgets/ui.dart';
import 'cocina.dart';
import 'menu.dart';
import 'mesas.dart';
import 'reservaciones.dart';

class DashboardVista extends StatefulWidget {
  final Map<String, dynamic>? usuario;

  const DashboardVista({super.key, this.usuario});

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

    final int mesasTotal = _n('mesas', 'total');
    final int mesasDisp = _n('mesas', 'disponibles');
    final int mesasOcup = _n('mesas', 'ocupadas');
    final int prodTotal = _n('productos', 'total');
    final int prodDisp = _n('productos', 'disponibles');
    final int reservasHoy = toInt(_resumen?['reservas_hoy']);

    return TemaSazon(
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: kFondo,

        // -------------------------------------------------------------
        // DRAWER: BARRA LATERAL (mismo estilo que la barra de las capturas)
        // -------------------------------------------------------------
        drawer: Drawer(
          backgroundColor: kPanel,
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(color: kCafe, shape: BoxShape.circle),
                        child: const Icon(Icons.room_service_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const LogoSazon(tamano: 30),
                            Text('Panel de Control',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTexto.withValues(alpha: 0.8))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Divider(height: 1)),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    children: [
                      _itemMenu(Icons.pie_chart_rounded, 'Dashboard', activo: true, onTap: () => Navigator.pop(context)),
                      _itemMenu(Icons.calendar_month_rounded, 'Reservaciones', onTap: () {
                        Navigator.pop(context);
                        _ir(ReservacionesVista(usuario: widget.usuario));
                      }),
                      _itemMenu(Icons.restaurant_rounded, 'Mapa Mesas', onTap: () {
                        Navigator.pop(context);
                        _ir(MesasScreen(usuario: widget.usuario));
                      }),
                      _itemMenu(Icons.point_of_sale_rounded, 'Menú / Caja POS', onTap: () {
                        Navigator.pop(context);
                        _ir(MenuVista(usuario: widget.usuario));
                      }),
                      _itemMenu(Icons.soup_kitchen_rounded, 'KDS Cocina / Barra', onTap: () {
                        Navigator.pop(context);
                        _ir(CocinaVista(usuario: widget.usuario));
                      }),
                    ],
                  ),
                ),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Divider(height: 1)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 20,
                        backgroundColor: Color(0xFF6B645C),
                        child: Icon(Icons.person, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(nombreMesero,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: kTexto)),
                            Text(rol, style: const TextStyle(fontSize: 12, color: kTextoSuave)),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cerrar sesión',
                        icon: const Icon(Icons.logout_rounded, color: kEstadoOcupada, size: 20),
                        onPressed: _cerrarSesion,
                      ),
                    ],
                  ),
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
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Barra superior: menú, título y actualizar
                        Row(
                          children: [
                            Material(
                              color: kTexto,
                              shape: const CircleBorder(),
                              child: IconButton(
                                tooltip: 'Menú',
                                icon: const Icon(Icons.menu_rounded, size: 22, color: Colors.white),
                                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: TituloPagina('Dashboard', subtitulo: 'Resumen del restaurante en vivo'),
                            ),
                            BotonRedondo(
                              tooltip: 'Actualizar',
                              icono: Icons.refresh_rounded,
                              onPressed: () => _cargar(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Tarjeta del usuario
                        TarjetaSazon(
                          radio: 26,
                          padding: const EdgeInsets.all(18),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: kBorde, width: 2),
                                ),
                                child: const CircleAvatar(
                                  radius: 30,
                                  backgroundColor: kCafe,
                                  child: Icon(Icons.person, size: 34, color: Colors.white),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      nombreMesero,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kTexto),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(rol, style: const TextStyle(fontSize: 13, color: kTextoSuave)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        if (_error != null)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFDECEA),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: kRojo.withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.wifi_off_rounded, color: kRojo),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(_error!, style: const TextStyle(fontSize: 12, color: kRojo)),
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
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kTexto),
                            ),
                            GestureDetector(
                              onTap: () => _ir(ReservacionesVista(usuario: widget.usuario)),
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: kBorde),
                                ),
                                child: const Icon(Icons.calendar_month_rounded, color: kTexto, size: 20),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        if (_cargando && _resumen == null)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: CircularProgressIndicator(color: kCafe),
                            ),
                          )
                        else ...[
                          _buildTaskStatusRow(
                            color: kEstadoOcupada,
                            icon: Icons.access_time_rounded,
                            title: 'Pendientes',
                            subtitle: '${_n('pendientes', 'platillos')} platillos en espera '
                                '(${_n('pendientes', 'comandas')} comandas)',
                            onTap: () => _ir(CocinaVista(usuario: widget.usuario)),
                          ),
                          const SizedBox(height: 12),
                          _buildTaskStatusRow(
                            color: kAmbar,
                            icon: Icons.soup_kitchen_rounded,
                            title: 'En Preparación',
                            subtitle: '${_n('preparacion', 'platillos')} platillos en '
                                '${_n('preparacion', 'comandas')} comandas',
                            onTap: () => _ir(CocinaVista(usuario: widget.usuario)),
                          ),
                          const SizedBox(height: 12),
                          _buildTaskStatusRow(
                            color: kEstadoLimpiar,
                            icon: Icons.check_circle_rounded,
                            title: 'Listos para Entregar',
                            subtitle: '${_n('listos', 'platillos')} platillos listos en '
                                '${_n('listos', 'comandas')} comandas',
                            onTap: () => _ir(CocinaVista(usuario: widget.usuario)),
                          ),
                          if (esCajaOAdmin(widget.usuario)) ...[
                            const SizedBox(height: 12),
                            _buildTaskStatusRow(
                              color: kEstadoLibre,
                              icon: Icons.payments_rounded,
                              title: 'Ventas de hoy',
                              subtitle: '${dinero(toDouble(_resumen?['ventas_hoy']))} · '
                                  '${toInt(_resumen?['ordenes_abiertas'])} cuentas abiertas',
                            ),
                          ],
                        ],

                        const SizedBox(height: 26),

                        // Accesos rápidos
                        const Text(
                          'Acceso Rápido',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kTexto),
                        ),
                        const SizedBox(height: 14),

                        Row(
                          children: [
                            Expanded(
                              child: _buildProjectCard(
                                color: kEstadoLibre,
                                icon: Icons.restaurant_rounded,
                                title: 'Mapa de Mesas',
                                progress: '$mesasDisp disponibles · $mesasOcup ocupadas',
                                value: mesasTotal == 0 ? 0 : mesasOcup / mesasTotal,
                                centro: '$mesasTotal',
                                onTap: () => _ir(MesasScreen(usuario: widget.usuario)),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _buildProjectCard(
                                color: kAmbar,
                                icon: Icons.point_of_sale_rounded,
                                title: 'Menú POS',
                                progress: 'Tomar comanda · $prodDisp de $prodTotal disponibles',
                                value: prodTotal == 0 ? 0 : prodDisp / prodTotal,
                                centro: '$prodTotal',
                                onTap: () => _ir(MenuVista(usuario: widget.usuario)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _buildProjectCard(
                                color: kEstadoOcupada,
                                icon: Icons.soup_kitchen_rounded,
                                title: 'KDS Cocina / Barra',
                                progress: 'Pantalla de comandas en vivo',
                                value: 1,
                                centro: '${_n('pendientes', 'platillos') + _n('preparacion', 'platillos')}',
                                onTap: () => _ir(CocinaVista(usuario: widget.usuario)),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _buildProjectCard(
                                color: kEstadoLimpiar,
                                icon: Icons.calendar_month_rounded,
                                title: 'Reservaciones',
                                progress: '$reservasHoy para hoy',
                                value: reservasHoy == 0 ? 0 : 1,
                                centro: '$reservasHoy',
                                onTap: () => _ir(ReservacionesVista(usuario: widget.usuario)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Opción de la barra lateral: activa = píldora oscura.
  Widget _itemMenu(IconData icono, String texto, {bool activo = false, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: activo ? kTexto : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icono, size: 22, color: activo ? Colors.white : kTexto.withValues(alpha: 0.75)),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    texto,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
                      color: activo ? Colors.white : kTexto,
                    ),
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
    return GestureDetector(
      onTap: onTap,
      child: TarjetaSazon(
        radio: 20,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color,
              radius: 22,
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: kTexto),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: kTextoSuave)),
                ],
              ),
            ),
            if (onTap != null) const Icon(Icons.chevron_right_rounded, color: kTextoSuave),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectCard({
    required Color color,
    required IconData icon,
    required String title,
    required String progress,
    required double value,
    required String centro,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: 172,
        child: TarjetaSazon(
          radio: 24,
          colorSuperior: color,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, color: color, size: 26),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: CircularProgressIndicator(
                          value: value.clamp(0.0, 1.0).toDouble(),
                          color: color,
                          backgroundColor: color.withValues(alpha: 0.15),
                          strokeWidth: 4,
                        ),
                      ),
                      Text(
                        centro,
                        style: const TextStyle(color: kTexto, fontWeight: FontWeight.w800, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: kTexto, fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    progress,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: kTextoSuave, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
