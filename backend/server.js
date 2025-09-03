require('dotenv').config();
const express = require('express');
const { default: mongoose } = require('mongoose');
const cors = require('cors');
const path = require('path');

const port = process.env.PORT;
const Mongoose_URI = process.env.MONGO_URI;


const authRoutes = require('./routes/authRoutes');
const inventoryRoutes = require('./routes/inventoryRoutes');
const menuRoutes = require('./routes/menuRoutes');
const salesRoutes = require('./routes/salesRoutes');
const mobileOrderRoutes = require('./routes/mobileOrderRoutes');
const customerRoutes = require('./routes/customerRoutes');
const paymentMethodRoutes = require('./routes/paymentMethodRoutes');
const deliveryAddressRoutes = require('./routes/deliveryAddressRoutes');


const app = express();

// Socket.io setup
const http = require('http');
const server = http.createServer(app);
const { Server } = require('socket.io');
const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization']
  }
});
app.set('io', io); // Make io accessible in controllers

// CORS configuration
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));

app.use(express.json());

app.use(cors({
  origin: ['http://127.0.0.1:5501', 'http://localhost:5501'], // allow your frontend origins
  credentials: true // if you want to allow cookies/auth headers
}));

const mapper = '/api/v1/';


// Routes
app.use(mapper + 'auth', authRoutes);
app.use(mapper + 'inventory', inventoryRoutes);
app.use(mapper + 'menu', menuRoutes);
app.use(mapper + 'sales', salesRoutes);
app.use(mapper + 'mobile-orders', mobileOrderRoutes);
app.use(mapper + 'customers', customerRoutes);
app.use(mapper + 'payment-methods', paymentMethodRoutes);
app.use(mapper + 'delivery-addresses', deliveryAddressRoutes);
app.use('/uploads/menus', express.static(path.join(__dirname, 'uploads/menus')));

mongoose.connect(Mongoose_URI)
  .then(() => console.log('MongoDB Connected'))
  .catch(err => console.log(err));

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'OK', message: 'RamenXpress API is running' });
});

// Test sales endpoint without authentication
app.post('/api/v1/sales/test-order', async (req, res) => {
  try {
    console.log('Test order received:', req.body);
    
    // Simulate successful order processing
    const orderId = Date.now().toString();
    
    res.status(201).json({
      success: true,
      message: 'Test order processed successfully',
      orderDetails: {
        orderId: orderId,
        items: req.body.items || [],
        total: req.body.total || 0
      }
    });
  } catch (error) {
    console.error('Test order error:', error);
    res.status(500).json({
      success: false,
      message: 'Test order failed',
      error: error.message
    });
  }
});

server.listen(port, '0.0.0.0', () => {
    console.log(`Server is running on port ${port}`);
    console.log(`Health check available at http://localhost:${port}/health`);
    console.log(`Server accessible from Android emulator at http://10.0.2.2:${port}/health`);
});

