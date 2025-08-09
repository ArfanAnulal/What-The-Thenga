const express = require('express');
const tf = require('@tensorflow/tfjs');
require('@tensorflow/tfjs-backend-cpu'); // Using CPU backend
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

// Serve model files statically from the root directory
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
        console.log('Model loaded successfully.');
        console.log('Input shape:', model.inputs[0].shape);
    } catch (error) {
        console.error('Error loading model:', error);
        process.exit(1);
    }
}

// Preprocess image for the EfficientNetV2 model
async function preprocessImage(imagePath) {
    try {
        // Read and resize image to 260x260
        const imageBuffer = await sharp(imagePath)
            .resize(260, 260)
            .raw()
            .toBuffer();

        const tensor = tf.tensor3d(new Uint8Array(imageBuffer), [260, 260, 3]);

        // ## FIX 1: Correct Preprocessing for EfficientNetV2 ##
        // EfficientNetV2 expects pixel values in the [0, 255] range and type float32.
        // DO NOT normalize by dividing by 255.0.
        const preprocessedTensor = tensor.cast('float32').expandDims(0);

        tensor.dispose(); // Clean up the original tensor

        return preprocessedTensor;
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
                error: 'Model is not loaded yet'
            });
        }

        console.log('Processing prediction for:', req.file.filename);

        const inputTensor = await preprocessImage(req.file.path);

        // Make prediction
        const prediction = model.predict(inputTensor);
        const predictionValue = await prediction.data();

        // Clean up tensors
        inputTensor.dispose();
        prediction.dispose();

        const probability = predictionValue[0];
        
        // ## FINAL FIX: Invert the logic based on class indices ##
        // A high score means class 1 ('NOT COCONUT TREE').
        // Therefore, it's a coconut tree if the score is LOW.
        const isCoconutTree = probability < 0.5;

        // The confidence is the model's certainty in its chosen class.
        const confidence = isCoconutTree ? (1 - probability) : probability;

        console.log(`Prediction Score (for 'Not Coconut Tree'): ${probability}, Is Coconut: ${isCoconutTree}, Confidence: ${confidence}`);
        
        // Clean up uploaded file on success
        // fs.unlinkSync(req.file.path);

        res.json({
            success: true,
            prediction: {
                isCoconutTree: isCoconutTree,
                confidence: parseFloat((confidence * 100).toFixed(2)),
                rawScore: parseFloat(probability.toFixed(4)),
                classification: isCoconutTree ? 'Coconut Tree' : 'Not a Coconut Tree'
            }
        });

    } catch (error) {
        console.error('Error during prediction:', error);

        // Clean up uploaded file if it exists on error
        if (req.file && req.file.path) {
            try {
                // fs.unlinkSync(req.file.path);
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

// Root endpoint
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

// Start server function
async function startServer() {
    // Create uploads directory if it doesn't exist
    if (!fs.existsSync('uploads')) {
        fs.mkdirSync('uploads');
    }

    app.listen(PORT, async () => {
        console.log(`Server is running on port ${PORT}`);
        console.log(`Health check: http://localhost:${PORT}/health`);
        console.log(`Prediction endpoint: http://localhost:${PORT}/predict`);

        // Load the model after the server has started
        // A small delay ensures the server is fully ready to accept HTTP requests
        setTimeout(loadModel, 1000);
    });
}

// Handle graceful shutdown
process.on('SIGINT', () => {
    console.log('Shutting down server...');
    if (model) {
        tf.dispose(model);
        console.log('Model disposed.');
    }
    process.exit(0);
});

// Start the server
startServer().catch(error => {
    console.error('Failed to start server:', error);
    process.exit(1);
});