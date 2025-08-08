// server.js
const express = require('express');
const tf = require('@tensorflow/tfjs-node');
const multer = require('multer');
const path = require('path');
const { createCanvas, loadImage } = require('canvas');
const fs = require('fs');

const app = express();
const port = 5000;

// Set up Multer for handling file uploads in memory
const upload = multer({
    storage: multer.memoryStorage()
});

// Define the path to the converted TensorFlow.js model
const MODEL_PATH = path.join(__dirname, 'tfjs_model');
let model;

// Define the image size and class names
const IMG_SIZE = [260, 260];

const CLASS_NAMES = ['COCONUT TREE', 'NOT COCONUT TREE'];

// Load the model asynchronously when the server starts
async function loadModel() {
    try {
        if (!fs.existsSync(MODEL_PATH)) {
            throw new Error(`Model directory not found at: ${MODEL_PATH}`);
        }
        model = await tf.loadLayersModel(`file://${MODEL_PATH}/model.json`);
        console.log('✅ Model loaded successfully!');
    } catch (e) {
        console.error('❌ Error loading model:', e);
        process.exit(1); // Exit if the model can't be loaded
    }
}

// Preprocessing function, replicating the Python version
async function preprocessImage(imageBuffer) {
    // Load the image from the buffer using canvas
    const img = await loadImage(imageBuffer);
    const canvas = createCanvas(img.width, img.height);
    const ctx = canvas.getContext('2d');
    ctx.drawImage(img, 0, 0, img.width, img.height);

    // Convert the canvas to a tensor
    const tensor = tf.browser.fromPixels(canvas)
        .resizeNearestNeighbor(IMG_SIZE)
        .toFloat();

    // The preprocessing for EfficientNetV2 is a specific function in Python.
    // In tf.js, the `preprocess_input` function is equivalent to scaling the values.
    // The exact scaling depends on the version, but the common practice is to normalize
    // to a range like [-1, 1] which is what is done below.
    const preprocessedTensor = tf.sub(
      tf.mul(tensor, 2 / 255),
      1
    );

    // Add a batch dimension
    return preprocessedTensor.expandDims(0);
}

// API endpoint for prediction
app.post('/predict', upload.single('file'), async (req, res) => {
    if (!req.file) {
        return res.status(400).json({ error: 'No image file uploaded.' });
    }

    try {
        const imageTensor = await preprocessImage(req.file.buffer);
        
        // Make a prediction
        const predictions = model.predict(imageTensor);
        const predictionData = await predictions.data();

        // Interpret the prediction
        // The output of the sigmoid activation is a single probability score
        const score = predictionData[0];
        const predictedClass = score > 0.5 ? CLASS_NAMES[1] : CLASS_NAMES[0];
        
        // Return the JSON response
        res.json({
            predicted_class: predictedClass,
            confidence: score
        });

    } catch (e) {
        console.error('Prediction failed:', e);
        res.status(500).json({ error: 'Prediction failed.' });
    }
});

// Start the server after the model is loaded
loadModel().then(() => {

    console.log('Starting server...');
    app.listen(port, () => {
        console.log(`Server is running on http://localhost:${port}`);
    });
});
