// backend/referral.routes.js
// Proxies all referral operations to the HIE Gateway.
// The Flutter app calls THIS backend; this backend calls the gateway
// using the facility credentials stored in env vars.
// This keeps the API key off the mobile device.

import { Router } from 'express';
import axios      from 'axios';

const router  = Router();
const GATEWAY = process.env.HIE_GATEWAY_URL;

// Build headers — facility credentials live only on the backend server
const facilityHeaders = () => ({
  'Content-Type':  'application/json',
  'X-Facility-Id': process.env.FACILITY_ID      || '',
  'X-Api-Key':     process.env.FACILITY_API_KEY  || '',
});

// ── POST /api/referrals ───────────────────────────────────────────
// Create a referral — logs on blockchain via gateway
router.post('/', async (req, res) => {
  try {
    const response = await axios.post(
      `${GATEWAY}/api/referrals`,
      req.body,
      { headers: facilityHeaders(), timeout: 30000 }
    );
    res.status(response.status).json(response.data);
  } catch (err) {
    console.error('Referral create proxy error:', err.message);
    const status = err.response?.status || 500;
    res.status(status).json({
      success: false,
      error:   err.response?.data?.error || err.message,
    });
  }
});

// ── GET /api/referrals/incoming/:facilityId ───────────────────────
// Returns referrals TO this facility
router.get('/incoming/:facilityId', async (req, res) => {
  try {
    const response = await axios.get(
      `${GATEWAY}/api/referrals/incoming/${req.params.facilityId}`,
      { headers: facilityHeaders(), timeout: 20000 }
    );
    res.status(response.status).json(response.data);
  } catch (err) {
    console.error('Referral incoming proxy error:', err.message);
    const status = err.response?.status || 500;
    res.status(status).json({
      success:   false,
      referrals: [],
      count:     0,
      error:     err.response?.data?.error || err.message,
    });
  }
});

// ── GET /api/referrals/outgoing/:facilityId ───────────────────────
// Returns referrals FROM this facility
router.get('/outgoing/:facilityId', async (req, res) => {
  try {
    const response = await axios.get(
      `${GATEWAY}/api/referrals/outgoing/${req.params.facilityId}`,
      { headers: facilityHeaders(), timeout: 20000 }
    );
    res.status(response.status).json(response.data);
  } catch (err) {
    console.error('Referral outgoing proxy error:', err.message);
    const status = err.response?.status || 500;
    res.status(status).json({
      success:   false,
      referrals: [],
      count:     0,
      error:     err.response?.data?.error || err.message,
    });
  }
});

// ── GET /api/referrals/patient/:nupi ─────────────────────────────
// All referrals for a specific patient visible to this facility
router.get('/patient/:nupi', async (req, res) => {
  try {
    const response = await axios.get(
      `${GATEWAY}/api/referrals/patient/${req.params.nupi}`,
      { headers: facilityHeaders(), timeout: 20000 }
    );
    res.status(response.status).json(response.data);
  } catch (err) {
    const status = err.response?.status || 500;
    res.status(status).json({
      success:   false,
      referrals: [],
      error:     err.response?.data?.error || err.message,
    });
  }
});

// ── GET /api/referrals/:referralId ────────────────────────────────
// Look up a specific referral by ID
router.get('/:referralId', async (req, res) => {
  try {
    const response = await axios.get(
      `${GATEWAY}/api/referrals/${req.params.referralId}`,
      { headers: facilityHeaders(), timeout: 15000 }
    );
    res.status(response.status).json(response.data);
  } catch (err) {
    const status = err.response?.status || 500;
    res.status(status).json({
      success: false,
      error:   err.response?.data?.error || err.message,
    });
  }
});

// ── PATCH /api/referrals/:referralId/status ───────────────────────
// Update referral status — logged on blockchain
router.patch('/:referralId/status', async (req, res) => {
  try {
    const response = await axios.patch(
      `${GATEWAY}/api/referrals/${req.params.referralId}/status`,
      req.body,
      { headers: facilityHeaders(), timeout: 20000 }
    );
    res.status(response.status).json(response.data);
  } catch (err) {
    console.error('Referral status proxy error:', err.message);
    const status = err.response?.status || 500;
    res.status(status).json({
      success: false,
      error:   err.response?.data?.error || err.message,
    });
  }
});

export default router;