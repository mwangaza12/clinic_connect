// backend/facility.routes.js
// Proxies facility directory requests to the HIE Gateway.
// The Flutter app calls this backend; the backend calls the gateway
// using the facility API key (which the app doesn't have access to).

import { Router } from 'express';
import axios      from 'axios';

const router  = Router();
const GATEWAY = process.env.HIE_GATEWAY_URL;
const HEADERS = {
  'X-Facility-Id': process.env.FACILITY_ID   || '',
  'X-Api-Key':     process.env.FACILITY_API_KEY || '',
};

// GET /api/facilities?q=nairobi&county=Nairobi&limit=100
router.get('/', async (req, res) => {
  try {
    const { q, county, limit } = req.query;
    const params = {};
    if (q)      params.q      = q;
    if (county) params.county = county;
    if (limit)  params.limit  = limit;

    const response = await axios.get(`${GATEWAY}/api/facilities`, {
      params,
      headers: HEADERS,
      timeout: 15000,
    });

    res.json(response.data);
  } catch (err) {
    console.error('Facility proxy error:', err.message);
    // Return empty list gracefully — don't crash the referral form
    const status = err.response?.status || 500;
    res.status(status).json({
      success:    false,
      facilities: [],
      error:      err.response?.data?.error || err.message,
    });
  }
});

// GET /api/facilities/:facilityId
router.get('/:facilityId', async (req, res) => {
  try {
    const response = await axios.get(
      `${GATEWAY}/api/facilities/${req.params.facilityId}`,
      { headers: HEADERS, timeout: 10000 }
    );
    res.json(response.data);
  } catch (err) {
    const status = err.response?.status || 500;
    res.status(status).json({ success: false, error: err.response?.data?.error || err.message });
  }
});

export default router;