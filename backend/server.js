import express from 'express';
import cors from 'cors';
import admin from 'firebase-admin';
import 'dotenv/config';

admin.initializeApp({
    credential: admin.credential.cert({
        projectId: process.env.FIREBASE_PROJECT_ID,
        clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
        privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, "\n"),
    }),
});

const db = admin.firestore();
const app = express();

app.use(cors());
app.use(express.json());


app.get('/api/patients/:nupi', async (req, res) => {
    try {
        const { nupi } = req.params;
        
        console.log(`📡 Fetching patient: ${nupi}`);
        
        const snapshot = await db
            .collection('patients')
            .where('nupi', '==', nupi)
            .limit(1)
            .get();
        
        if (snapshot.empty) {
            return res.status(404).json({
                success: false,
                error: 'Patient not found'
            });
        }
        
        const patientData = snapshot.docs[0].data();
        
        res.json({
            success: true,
            data: patientData
        });
        
    } catch (error) {
        console.error('Error:', error);
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

app.get('/api/encounters/:nupi', async (req, res) => {
    try {
        const { nupi } = req.params;
    
        console.log(`📋 Fetching encounters for: ${nupi}`);
    
        const snapshot = await db
            .collection('encounters')
            .where('patient_nupi', '==', nupi)
            .orderBy('encounter_date', 'desc')
            .get();
    
        const encounters = snapshot.docs.map(doc => ({
            id: doc.id,
            ...doc.data(),
            source: 'ClinicConnect'
        }));
    
        res.json({
            success: true,
            data: encounters,
            count: encounters.length
        });
    
    } catch (error) {
        console.error('Error:', error);
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
    });

// Health check
app.get('/health', (req, res) => {
    res.json({
        status: 'ok',
        service: 'ClinicConnect API'
    });
});

const PORT = process.env.PORT || 4000;
app.listen(PORT, () => {
    console.log(`CLINICCONNECT API 🚀 Running: http://localhost:${PORT}`);
});