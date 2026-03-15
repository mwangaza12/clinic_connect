import express from 'express';
import axios   from 'axios';
import cors    from 'cors';
import helmet  from 'helmet';
import 'dotenv/config';

import patientRoutes    from './patient.routes.js';
import facilityRoutes   from './facility.routes.js';
import fhirRoutes       from './fhir.routes.js';
import referralRoutes   from './referral.routes.js';   // ← NEW
import { startGatewayKeepAlive } from './patient.service.js';

const app = express();

app.use(helmet());
app.use(cors());
app.use(express.json({ limit: '10mb' }));

// ── Routes ─────────────────────────────────────────────────────────
app.use('/api/patients',  patientRoutes);
app.use('/api/facilities', facilityRoutes);
app.use('/api/referrals', referralRoutes);  // ← NEW
app.use('/fhir',         fhirRoutes);

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
const server = app.listen(PORT, '0.0.0.0', () => {
  console.log(`\n  ClinicConnect API  →  http://0.0.0.0:${PORT}`);
  console.log(`\n  Patient API:`);
  console.log(`    POST /api/patients                 register patient`);
  console.log(`    GET  /api/patients/verify/question  get security question`);
  console.log(`    POST /api/patients/verify/answer    verify + get token`);
  console.log(`    GET  /api/patients/:nupi/federated  full chart`);
  console.log(`    POST /api/patients/:nupi/visit      record encounter`);
  console.log(`\n  Referral API:`);
  console.log(`    POST /api/referrals                      create referral`);
  console.log(`    GET  /api/referrals/incoming/:facilityId incoming referrals`);
  console.log(`    GET  /api/referrals/outgoing/:facilityId outgoing referrals`);
  console.log(`    GET  /api/referrals/:referralId          get referral`);
  console.log(`    PATCH /api/referrals/:referralId/status  update status`);
  console.log(`\n  FHIR R4 (HIE Gateway only):`);
  console.log(`    GET  /fhir/Patient/:nupi`);
  console.log(`    GET  /fhir/Patient/:nupi/\\$everything`);
  console.log(`    GET  /fhir/Patient/:nupi/Encounter`);
  console.log(`    GET  /fhir/Encounter?patient=:nupi\n`);

  startGatewayKeepAlive();
  startSelfKeepAlive(PORT);
});

// ── Self keep-alive ────────────────────────────────────────────────
function startSelfKeepAlive(port) {
  if (process.env.NODE_ENV !== 'production') return;

  const selfUrl    = process.env.RENDER_EXTERNAL_URL
    ? `${process.env.RENDER_EXTERNAL_URL}/health`
    : `http://localhost:${port}/health`;

  const gatewayUrl = process.env.HIE_GATEWAY_URL
    ? `${process.env.HIE_GATEWAY_URL}/health`
    : null;

  setInterval(async () => {
    try {
      await axios.get(selfUrl, { timeout: 10000 });
      console.log(`Self keep-alive OK → ${selfUrl}`);
    } catch (e) {
      console.warn(`Self keep-alive failed: ${e.message}`);
    }

    if (gatewayUrl) {
      try {
        await axios.get(gatewayUrl, { timeout: 10000 });
        console.log(`Gateway keep-alive OK → ${gatewayUrl}`);
      } catch (e) {
        console.warn(`Gateway keep-alive failed: ${e.message}`);
      }
    }
  }, 10 * 60 * 1000);

  console.log(`Self keep-alive active → ${selfUrl}`);
}