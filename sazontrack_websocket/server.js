const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');

const app = express();
app.use(cors());

// Creamos el servidor HTTP y lo conectamos con Socket.io
const server = http.createServer(app);
const io = new Server(server, {
    cors: {
        origin: "*", // Permite conexiones desde tu Web (localhost) y tu App Flutter
        methods: ["GET", "POST"]
    }
});

io.on('connection', (socket) => {
    console.log('🟢 Nuevo dispositivo conectado:', socket.id);

    // 1. Escuchar cuando la App Móvil (Mesero) envía una nueva comanda
    socket.on('nueva_comanda', (data) => {
        console.log('📝 Nueva comanda recibida del mesero:', data);
        
        // Retransmitir al instante a la Web (KDS de Cocina y Caja POS)
        io.emit('renderizar_kds', data);
        io.emit('actualizar_mesas_caja', data);
    });

    // 2. Escuchar cuando Cocina (Web KDS) marca un platillo como "Listo"
    socket.on('platillo_preparado', (data) => {
        console.log('✅ Platillo listo en cocina:', data);
        
        // Avisar a la App Móvil del mesero para que lo recoja
        io.emit('notificar_mesero', data);
    });

    socket.on('disconnect', () => {
        console.log('🔴 Dispositivo desconectado:', socket.id);
    });
});

// El servidor WebSocket correrá en el puerto 3000 (independiente de Apache)
const PORT = 3000;
server.listen(PORT, () => {
    console.log(`🚀 Servidor WebSocket de SazónTrack corriendo en el puerto ${PORT}`);
});