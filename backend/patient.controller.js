import { patientService } from './patient.service.js';
import axios from 'axios';

export class PatientController {

  // ══════════════════════════════════════════════════════════════
  //  POST /patients
  //  Register a new patient → saves to Firestore + mints block
  // ══════════════════════════════════════════════════════════════

  async create(req, res) {
    try {
      const b = req.body;

      // ── Validate facility is configured ───────────────────────
      if (!process.env.FACILITY_ID || !process.env.FACILITY_API_KEY) {
        return res.status(500).json({
          success: false,
          error:   'Facility not configured. Set FACILITY_ID and FACILITY_API_KEY in .env. ' +
                   'These are issued by MoH when your facility is registered on AfyaLink.',
        });
      }

      // ── Map frontend body → service fields ────────────────────
      const mapped = {
        nationalId:       b.nationalId,
        firstName:        b.firstName   || b.givenName,
        lastName:         b.lastName    || b.familyName,
        middleName:       b.middleName  || b.middleNames || null,
        dateOfBirth:      b.dateOfBirth || b.dob,
        gender:           b.gender,
        phoneNumber:      b.phoneNumber || b.phone       || null,
        email:            b.email                        || null,
        address:          b.address ?? (
          b.county ? {
            county:    b.county,
            subCounty: b.subCounty  || null,
            ward:      b.ward       || null,
            village:   b.village    || null,
          } : null
        ),
        securityQuestion: b.securityQuestion,
        securityAnswer:   b.securityAnswer,
        pin:              b.pin,
      };

      // ── Validate required fields ───────────────────────────────
      const missing = ['nationalId','firstName','lastName','dateOfBirth','gender','securityQuestion','securityAnswer','pin']
        .filter(f => !mapped[f]);
      if (missing.length) {
        return res.status(400).json({
          success: false,
          error:   `Missing required fields: ${missing.join(', ')}`,
          note:    'firstName can also be sent as givenName, lastName as familyName, dateOfBirth as dob',
        });
      }

      const result = await patientService.create(mapped);

      return res.status(result.alreadyExists ? 200 : 201).json({
        success:       true,
        data:          result.patient,
        nupi:          result.nupi,
        blockIndex:    result.blockIndex ?? null,
        alreadyExists: result.alreadyExists,
        message:       result.alreadyExists
          ? 'Patient already registered on AfyaNet'
          : 'Patient registered — block minted on AfyaChain',
      });
    } catch (error) {
      // Log the full error so it appears in Render logs
      console.error('❌ Patient create error:', {
        message:       error.message,
        status:        error.response?.status,
        gatewayError:  error.response?.data,
        stack:         error.stack,
      });

      const status  = error.response?.status;
      const message = error.response?.data?.error || error.response?.data || error.message || 'Unknown error';

      if (status === 401) {
        return res.status(401).json({
          success: false,
          error:   'Gateway rejected this facility\'s credentials.',
          detail:  message,
          fix:     'Check that FACILITY_ID and FACILITY_API_KEY in .env match what MoH issued.',
        });
      }

      return res.status(status || 400).json({ success: false, error: message });
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  GET /patients/:id
  //  Get patient by local Firestore document ID
  // ══════════════════════════════════════════════════════════════

  async getById(req, res) {
    try {
      const patient = await patientService.getById(req.params.id);
      if (!patient) {
        return res.status(404).json({ success: false, error: 'Patient not found' });
      }
      return res.json({ success: true, data: patient });
    } catch (error) {
      return res.status(500).json({ success: false, error: error.message });
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  GET /patients/nupi/:nupi
  //  Get patient by NUPI — checks local DB first, then gateway.
  // ══════════════════════════════════════════════════════════════

  async getByNupi(req, res) {
    try {
      const { nupi }      = req.params;
      const accessToken   = req.headers['authorization']?.replace('Bearer ', '');

      const result = await patientService.getByNupi(nupi, accessToken);
      if (!result) {
        return res.status(404).json({ success: false, error: 'Patient not found' });
      }

      return res.json({
        success: true,
        data:    result.patient,
        source:  result.source,
      });
    } catch (error) {
      return res.status(500).json({ success: false, error: error.message });
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  GET /patients/search/nupi
  //  Search for patient by nationalId and dob via gateway
  //  Query params: nationalId, dob
  // ══════════════════════════════════════════════════════════════

  async searchNUPI(req, res) {
    try {
      const { nationalId, dob } = req.query;
      
      if (!nationalId || !dob) {
        return res.status(400).json({ 
          success: false, 
          error: 'nationalId and dob query parameters are required' 
        });
      }

      // First check local Firestore
      const localResults = await patientService.searchNUPI(nationalId || '');
      
      // Also try gateway search
      let gatewayResult = null;
      try {
        const gatewayRes = await axios.get(
          `${process.env.HIE_GATEWAY_URL}/api/patients/search/nupi`,
          { 
            params: { nationalId, dob },
            headers: {
              'X-Facility-Id': process.env.FACILITY_ID,
              'X-Api-Key': process.env.FACILITY_API_KEY
            }
          }
        );
        
        if (gatewayRes.data?.nupi) {
          gatewayResult = {
            nupi: gatewayRes.data.nupi,
            exists: true
          };
        }
      } catch (gatewayErr) {
        // Patient not found in gateway, that's ok
        console.log('Gateway search returned no results');
      }
      
      res.json({ 
        success: true, 
        results: localResults,
        gateway: gatewayResult,
        count: localResults.length 
      });
    } catch (error) {
      return res.status(500).json({ success: false, error: error.message });
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  IDENTITY VERIFICATION FLOW
  // ══════════════════════════════════════════════════════════════

  async getSecurityQuestion(req, res) {
    try {
      const { nationalId, dob } = req.query;
      if (!nationalId || !dob) {
        return res.status(400).json({ success: false, error: 'nationalId and dob query params required' });
      }
      const result = await patientService.getSecurityQuestion(nationalId, dob);
      return res.json({ success: true, data: result });
    } catch (error) {
      const status = error.response?.status || 500;
      return res.status(status).json({ success: false, error: error.response?.data?.error || error.message });
    }
  }

  async verifyAnswer(req, res) {
    try {
      const { nationalId, dob, answer } = req.body;
      if (!nationalId || !dob || !answer) {
        return res.status(400).json({ success: false, error: 'nationalId, dob and answer required' });
      }
      const result = await patientService.verifyIdentity({ nationalId, dob, answer });

      return res.json({
        success:           true,
        token:             result.token,
        nupi:              result.nupi,
        patient:           result.patient,
        facilitiesVisited: result.facilitiesVisited,
        encounterIndex:    result.encounterIndex,
        consentId:         result.consentId,
        blockIndex:        result.blockIndex,
        expiresIn:         result.expiresIn,
        message:           'Identity verified — access token issued',
      });
    } catch (error) {
      const status = error.response?.status === 401 ? 401 : 500;
      return res.status(status).json({ success: false, error: error.response?.data?.error || error.message });
    }
  }

  async verifyPin(req, res) {
    try {
      const { nationalId, dob, pin } = req.body;
      if (!nationalId || !dob || !pin) {
        return res.status(400).json({ success: false, error: 'nationalId, dob and pin required' });
      }
      const result = await patientService.verifyByPin({ nationalId, dob, pin });
      return res.json({
        success:           true,
        token:             result.token,
        nupi:              result.nupi,
        patient:           result.patient,
        facilitiesVisited: result.facilitiesVisited,
        encounterIndex:    result.encounterIndex,
        expiresIn:         result.expiresIn,
      });
    } catch (error) {
      const status = error.response?.status === 401 ? 401 : 500;
      return res.status(status).json({ success: false, error: error.response?.data?.error || error.message });
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  POST /patients/nupi/:nupi/checkin
  //  Check in a patient at this facility.
  // ══════════════════════════════════════════════════════════════

  async checkIn(req, res) {
    try {
      const { nupi }    = req.params;
      const accessToken = req.headers['authorization']?.replace('Bearer ', '');

      if (!accessToken) {
        return res.status(401).json({
          success: false,
          error:   'Authorization header required. Verify patient identity first via POST /patients/verify/answer',
        });
      }

      const result = await patientService.checkIn(nupi, {
        accessToken,
        practitionerName: req.body.practitionerName,
        chiefComplaint:   req.body.chiefComplaint,
      });

      return res.status(201).json({
        success:     true,
        data:        result.encounter,
        blockIndex:  result.blockIndex,
        message:     'Patient checked in — encounter recorded on AfyaChain',
      });
    } catch (error) {
      return res.status(500).json({ success: false, error: error.message });
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  POST /patients/:nupi/visit
  //  Record a full clinical encounter for a patient.
  // ══════════════════════════════════════════════════════════════

  async registerVisit(req, res) {
    try {
      const { nupi }    = req.params;
      const accessToken = req.headers['authorization']?.replace('Bearer ', '');

      const result = await patientService.registerVisit(nupi, {
        accessToken: accessToken || null,
        ...req.body,
      });

      return res.status(201).json({
        success:    true,
        data:       result.encounter,
        blockIndex: result.blockIndex,
        chainError: result.chainError ?? null,
        message:    result.blockIndex
          ? `Visit recorded — block #${result.blockIndex} minted on AfyaChain`
          : 'Visit saved locally (chain notification failed — will retry)',
      });
    } catch (error) {
      return res.status(500).json({ success: false, error: error.message });
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  GET /patients/:nupi/facilities
  //  Returns every facility the patient has ever visited
  // ══════════════════════════════════════════════════════════════

  async getFacilities(req, res) {
    try {
      const { nupi } = req.params;
      const facilities = await patientService.getPatientFacilities(nupi);
      return res.json({ success: true, data: facilities, count: facilities.length });
    } catch (error) {
      return res.status(500).json({ success: false, error: error.message });
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  GET /patients/:nupi/encounters
  //  Get this facility's encounters for a patient
  // ══════════════════════════════════════════════════════════════

  async getLocalEncounters(req, res) {
    try {
      const { nupi }     = req.params;
      const encounterList = await patientService.getLocalEncounters(nupi);
      return res.json({ success: true, data: encounterList, count: encounterList.length, source: 'local' });
    } catch (error) {
      return res.status(500).json({ success: false, error: error.message });
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  GET /patients/:nupi/encounters/facility/:facilityId
  //  Get encounters from a SPECIFIC facility via gateway.
  // ══════════════════════════════════════════════════════════════

  async getEncountersFromFacility(req, res) {
    try {
      const { nupi, facilityId } = req.params;
      const accessToken = req.headers['authorization']?.replace('Bearer ', '');

      if (!accessToken) {
        return res.status(401).json({ success: false, error: 'Authorization header required' });
      }

      const bundle = await patientService.getEncountersFromFacility(nupi, facilityId, accessToken);
      return res.json({ success: true, data: bundle, source: 'gateway', facilityId });
    } catch (error) {
      const status = error.response?.status || 500;
      return res.status(status).json({ success: false, error: error.response?.data || error.message });
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  GET /patients/:nupi/federated
  //  Full picture — local Firestore data + ALL facilities via gateway
  // ══════════════════════════════════════════════════════════════

  async getFederatedData(req, res) {
    try {
      const { nupi }    = req.params;
      const accessToken = req.headers['authorization']?.replace('Bearer ', '');

      if (!accessToken) {
        return res.status(401).json({
          success:         false,
          error:           'Authorization header required',
          howToGetToken:   'POST /patients/verify/answer with { nationalId, dob, answer }',
        });
      }

      const data = await patientService.getFederatedPatientData(nupi, accessToken);

      return res.json({
        success:           true,
        data,
        totalEncounters:   data.totalEncounters,
        facilitiesVisited: data.facilitiesVisited.length,
        message:           `Found ${data.totalEncounters} encounters across ${data.facilitiesVisited.length} facilities`,
      });
    } catch (error) {
      return res.status(500).json({ success: false, error: error.message });
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  GET /patients/:nupi/history
  //  Blockchain audit trail
  // ══════════════════════════════════════════════════════════════

  async getHistory(req, res) {
    try {
      const history = await patientService.getPatientHistory(req.params.nupi);
      return res.json({ success: true, data: history });
    } catch (error) {
      return res.status(500).json({ success: false, error: error.message });
    }
  }
}

export const patientController = new PatientController();