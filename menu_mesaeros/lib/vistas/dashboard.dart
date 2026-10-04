// vistas/dashboard.dart
import 'package:flutter/material.dart';
import 'menu.dart';
import 'mesas.dart';

class DashboardVista extends StatefulWidget {
  final Map<String, dynamic>? usuario;

  const DashboardVista({Key? key, this.usuario}) : super(key: key);

  @override
  State<DashboardVista> createState() => _DashboardVistaState();
}

class _DashboardVistaState extends State<DashboardVista> {
  // Clave para controlar el Drawer manualmente
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final String nombreMesero = widget.usuario?['nombre'] ?? 'Nancy López';
    final String rol = widget.usuario?['rol'] ?? 'Mesero / Comandero';

    const Color bgOrange = Color(0xFFFAF8F5);
    const Color bgCardLight = Color(0xFFFFF9EC);
    const Color tealColor = Color(0xFFD7C9B8);
    const Color redColor = Color(0xFFD8C8B5);
    const Color yellowColor = Color(0xFFF1C40F);
    const Color blueColor = Color(0xFF6488E4);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: bgCardLight,

      // -------------------------------------------------------------
      // DRAWER: MENÚ LATERAL DESLIZABLE (Tres líneas superiores)
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
                leading: const Icon(Icons.table_restaurant_rounded, color: Colors.white70),
                title: const Text('Mesas Disponibles', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MesasScreen(usuario: widget.usuario),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.restaurant_menu_rounded, color: Colors.white70),
                title: const Text('Menú / Catálogo', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MenuVista(usuario: widget.usuario),
                    ),
                  );
                },
              ),
              const Divider(color: Colors.white24),
              ListTile(
                leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                title: const Text('Cerrar Sesión', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pushReplacementNamed(context, '/login');
                },
              ),
            ],
          ),
        ),
      ),

      // -------------------------------------------------------------
      // CUERPO DEL DASHBOARD
      // -------------------------------------------------------------
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header Naranja Curvo con Info del Usuario
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
                    // Botones superiores (Menú 3 líneas y Búsqueda)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.menu_rounded, size: 28, color: Color(0xFF26201B)),
                          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                        ),
                        IconButton(
                          icon: const Icon(Icons.search_rounded, size: 28, color: Color(0xFF26201B)),
                          onPressed: () {},
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Foto y nombre del mesero
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
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF6B645C),
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Sección: Mis Comandas / Órdenes
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Estado de Órdenes',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF26201B),
                          ),
                        ),
                        CircleAvatar(
                          backgroundColor: tealColor,
                          radius: 20,
                          child: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Tarjetas de estado
                    _buildTaskStatusRow(
                      color: redColor,
                      icon: Icons.access_time_rounded,
                      title: 'Pendientes',
                      subtitle: '3 comandas sin enviar',
                    ),
                    const SizedBox(height: 12),
                    _buildTaskStatusRow(
                      color: yellowColor,
                      icon: Icons.soup_kitchen_rounded,
                      title: 'En Preparación',
                      subtitle: '2 mesas esperando platillos',
                    ),
                    const SizedBox(height: 12),
                    _buildTaskStatusRow(
                      color: blueColor,
                      icon: Icons.check_circle_rounded,
                      title: 'Listos para Entregar',
                      subtitle: '5 comandas completadas hoy',
                    ),

                    const SizedBox(height: 24),

                    // Sección de Accesos Rápidos
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Acceso Rápido',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF26201B),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: _buildProjectCard(
                            color: tealColor,
                            title: 'Mesas',
                            progress: '8 disponibles',
                            percentage: '12',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MesasScreen(usuario: widget.usuario),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildProjectCard(
                            color: redColor,
                            title: 'Menú POS',
                            progress: 'Tomar comanda',
                            percentage: '45',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MenuVista(usuario: widget.usuario),
                                ),
                              );
                            },
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
    );
  }

  // Widget para las filas de estado
  Widget _buildTaskStatusRow({
    required Color color,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: color,
          radius: 20,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF26201B)),
            ),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        )
      ],
    );
  }

  // Widget para tarjetas de acceso rápido
  Widget _buildProjectCard({
    required Color color,
    required String title,
    required String progress,
    required String percentage,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 160,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
        ),
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
                      value: 0.7,
                      color: Colors.white,
                      backgroundColor: Colors.white24,
                      strokeWidth: 3,
                    ),
                  ),
                  Text(
                    percentage,
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