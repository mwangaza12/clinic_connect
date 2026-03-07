import express from 'express';
import cors    from 'cors';
import helmet  from 'helmet';
import 'dotenv/config';

import patientRoutes              from './patient.routes.js';
import fhirRoutes                 from './fhir.routes.js';
import { startGatewayKeepAlive } from './patient.service.js';

const app = express();

app.use(helmet());
app.use(cors());
app.use(express.json({ limit: '10mb' }));

// ── Routes ─────────────────────────────────────────────────────────
app.use('/api/patients', patientRoutes);
app.use('/fhir',         fhirRoutes);   // ← FHIR R4 endpoints for HIE Gateway

// ── Health check ───────────────────────────────────────────────────
app.get('/health', (req, res) => {
  res.json({
    status:     'ok',
    service:    'ClinicConnect API',
    facilityId: process.env.FACILITY_ID    || 'NOT_SET',
    gateway:    process.env.HIE_GATEWAY_URL || 'NOT_SET',
    fhir:       'R4 (enabled)',
    timestamp:  new Date().toISOString(),
  });
});

// ── Start ──────────────────────────────────────────────────────────
const PORT = process.env.PORT || 4000;
app.listen(PORT, () => {
  console.log(`\n   ClinicConnect API  →  http://localhost:${PORT}`);
  console.log(`\n   Patient API:`);
  console.log(`     POST /api/patients                 register patient`);
  console.log(`     GET  /api/patients/verify/question  get security question`);
  console.log(`     POST /api/patients/verify/answer    verify + get token`);
  console.log(`     GET  /api/patients/:nupi/federated  full chart`);
  console.log(`     POST /api/patients/:nupi/visit      record encounter`);
  console.log(`\n   FHIR R4 (HIE Gateway only):`);
  console.log(`     GET  /fhir/Patient/:nupi`);
  console.log(`     GET  /fhir/Patient/:nupi/\\$everything`);
  console.log(`     GET  /fhir/Patient/:nupi/Encounter`);
  console.log(`     GET  /fhir/Encounter?patient=:nupi\n`);

  startGatewayKeepAlive();
});