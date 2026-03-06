import express from 'express';
import cors    from 'cors';
import helmet  from 'helmet';
import 'dotenv/config';

import patientRoutes              from './patient.routes.js';
import { startGatewayKeepAlive } from './patient.service.js';

const app = express();

app.use(helmet());
app.use(cors());
app.use(express.json({ limit: '10mb' }));

// ── Routes ────────────────────────────────────────────────────────
app.use('/api/patients', patientRoutes);

// ── Health check ──────────────────────────────────────────────────
app.get('/health', (req, res) => {
  res.json({
    status:     'ok',
    service:    'ClinicConnect API',
    facilityId: process.env.FACILITY_ID   || 'NOT_SET',
    gateway:    process.env.HIE_GATEWAY_URL || 'NOT_SET',
    timestamp:  new Date().toISOString(),
  });
});

// ── Start ─────────────────────────────────────────────────────────
const PORT = process.env.PORT || 4000;
app.listen(PORT, () => {
  console.log(`\n🏥 ClinicConnect API`);
  console.log(`   http://localhost:${PORT}`);
  console.log(`\n   Register patient:  POST /api/patients`);
  console.log(`   Get question:      GET  /api/patients/verify/question?nationalId=X&dob=Y`);
  console.log(`   Verify + token:    POST /api/patients/verify/answer`);
  console.log(`   Federated chart:   GET  /api/patients/:nupi/federated`);
  console.log(`   Record visit:      POST /api/patients/:nupi/visit\n`);

  startGatewayKeepAlive();
});
