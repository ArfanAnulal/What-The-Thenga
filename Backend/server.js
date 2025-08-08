const express = require('express');
const tf = require('@tensorflow/tfjs');
require('@tensorflow/tfjs-backend-cpu');
const multer = require('multer');
const sharp = require('sharp');
const cors = require('cors');
const path = require('path');
const fs = require('fs');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Serve model files statically
app.use('/models', express.static(__dirname, {
  setHeaders: (res, filePath) => {
    if (filePath.endsWith('.json')) {
      res.set('Content-Type', 'application/json');
    } else if (filePath.endsWith('.bin')) {
      res.set('Content-Type', 'application/octet-stream');
    }
  }
}));

// Configure multer for file uploads
const upload = multer({
  dest: 'uploads/',
  limits: {
    fileSize: 10 * 1024 * 1024 // 10MB limit
  },
  fileFilter: (req, file, cb) => {
    if (file.mimetype.startsWith('image/')) {
      cb(null, true);
    } else {
      cb(new Error('Only image files are allowed'), false);
    }
  }
});

// Global variable to store the loaded model
let model = null;

// Load the TensorFlow.js model
async function loadModel() {
  try {
    console.log('Loading model...');
    
    // Load model via HTTP after server starts
    model = await tf.loadGraphModel(`http://localhost:${PORT}/models/model.json`);
    console.log('Model loaded successfully');
    console.log('Input shape:', model.inputs[0].shape);
    console.log('Output shape:', model.outputs[0].shape);
  } catch (error) {
    console.error('Error loading model:', error);
    process.exit(1);
  }
}

// Preprocess image for the model
async function preprocessImage(imagePath) {
  try {
    // Read and resize image to 260x260 (as expected by the model)
    const imageBuffer = await sharp(imagePath)
      .resize(260, 260)
      .raw()
      .toBuffer();

    // Convert to tensor
    const tensor = tf.tensor3d(new Uint8Array(imageBuffer), [260, 260, 3]);
    
    // Normalize pixel values to [0, 1] and add batch dimension
    const normalized = tensor.cast('float32').div(255.0).expandDims(0);
    
    // Clean up
    tensor.dispose();
    
    return normalized;
  } catch (error) {
    console.error('Error preprocessing image:', error);
    throw error;
  }
}

// Prediction endpoint
app.post('/predict', upload.single('picture'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({
        success: false,
        error: 'No image file provided'
      });
    }

    if (!model) {
      return res.status(500).json({
        success: false,
        error: 'Model not loaded'
      });
    }

    console.log('Processing prediction for:', req.file.filename);

    // Preprocess the uploaded image
    const inputTensor = await preprocessImage(req.file.path);

    // Make prediction
    const prediction = model.predict(inputTensor);
    const predictionValue = await prediction.data();

    // Clean up tensors
    inputTensor.dispose();
    prediction.dispose();

    // Clean up uploaded file


    // Convert prediction to probability (assuming sigmoid output)
    const probability = predictionValue[0];
    const isCoconutTree = probability > 0.5;
    const confidence = isCoconutTree ? probability : 1 - probability;

    console.log(`Prediction: ${probability}, Is Coconut: ${isCoconutTree}, Confidence: ${confidence}`);

    res.json({
      success: true,
      prediction: {
        isCoconutTree: isCoconutTree,
        confidence: parseFloat((confidence * 100).toFixed(2)), // Convert to percentage
        rawScore: parseFloat(probability.toFixed(4)),
        classification: isCoconutTree ? 'Not a Coconut Tree' : 'Coconut Tree'
      }
    });

  } catch (error) {
    console.error('Error during prediction:', error);
    
    // Clean up uploaded file if it exists
    if (req.file && req.file.path) {
      try {
        fs.unlinkSync(req.file.path);
      } catch (cleanupError) {
        console.error('Error cleaning up file:', cleanupError);
      }
    }

    res.status(500).json({
      success: false,
      error: 'Internal server error during prediction'
    });
  }
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    success: true,
    status: 'Server is running',
    modelLoaded: model !== null
  });
});

// Test endpoint for basic functionality
app.get('/', (req, res) => {
  res.json({
    message: 'Coconut Tree Classification API',
    endpoints: {
      predict: 'POST /predict - Upload an image to classify',
      health: 'GET /health - Check server status'
    }
  });
});

// Error handling middleware
app.use((error, req, res, next) => {
  if (error instanceof multer.MulterError) {
    if (error.code === 'LIMIT_FILE_SIZE') {
      return res.status(400).json({
        success: false,
        error: 'File too large. Maximum size is 10MB.'
      });
    }
  }
  
  res.status(500).json({
    success: false,
    error: error.message || 'Internal server error'
  });
});

// Start server
async function startServer() {
  // Create uploads directory if it doesn't exist
  if (!fs.existsSync('uploads')) {
    fs.mkdirSync('uploads');
  }
  
  const server = app.listen(PORT, async () => {
    console.log(`Server is running on port ${PORT}`);
    console.log(`Health check: http://localhost:${PORT}/health`);
    console.log(`Prediction endpoint: http://localhost:${PORT}/predict`);
    
    // Load the model after server starts (important!)
    setTimeout(async () => {
      await loadModel();
    }, 1000); // Wait 1 second for server to fully start
  });
}

// Handle graceful shutdown
process.on('SIGINT', () => {
  console.log('Shutting down server...');
  if (model) {
    model.dispose();
  }
  process.exit(0);
});

// Start the server
startServer().catch(error => {
  console.error('Failed to start server:', error);
  process.exit(1);
});
