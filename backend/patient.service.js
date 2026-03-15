/**
 * PatientService — ClinicConnect
 * ════════════════════════════════
 * Firestore-backed. Talks to HIE gateway for blockchain ops
 * and cross-facility FHIR queries.
 *
 * .env required:
 *   FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL, FIREBASE_PRIVATE_KEY
 *   HIE_GATEWAY_URL, FACILITY_ID, FACILITY_API_KEY, FACILITY_NAME
 */

import axios    from 'axios';
import admin    from 'firebase-admin';
import 'dotenv/config';

// ── Firebase init ─────────────────────────────────────────────────

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert({
      projectId:   process.env.FIREBASE_PROJECT_ID,
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
      privateKey:  process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
    }),
  });
}

const db = admin.firestore();

const col = {
  patients:   db.collection('patients'),
  encounters: db.collection('encounters'),
};

// ── Gateway client ────────────────────────────────────────────────

const gateway = axios.create({
  baseURL: process.env.HIE_GATEWAY_URL || 'https://hie-gateway.onrender.com',
  timeout: 60000,
  headers: {
    'X-Facility-Id': process.env.FACILITY_ID      || '',
    'X-Api-Key':     process.env.FACILITY_API_KEY  || '',
    'Content-Type':  'application/json',
  },
});

if (process.env.NODE_ENV === 'development') {
  gateway.interceptors.request.use(req => {
    console.log(`→ Gateway: ${req.method?.toUpperCase()} ${req.url}`);
    return req;
  });
}

// ─────────────────────────────────────────────────────────────────

class PatientService {

  // ══════════════════════════════════════════════════════════════
  //  PATIENT REGISTRATION
  // ══════════════════════════════════════════════════════════════

  async create(data) {
    // Step 1 — derive NUPI
    // Gateway exposes GET /api/patients/nupi?nationalId=X&dob=Y (not POST)
    const nupiRes = await gateway.get('/api/patients/nupi', {
      params: {
        nationalId: data.nationalId,
        dob:        data.dateOfBirth,
      },
    });
    const nupi = nupiRes.data.nupi;

    // Step 2 — check if already in Firestore
    const existing = await col.patients.where('nupi', '==', nupi).limit(1).get();
    if (!existing.empty) {
      return { patient: { id: existing.docs[0].id, ...existing.docs[0].data() }, alreadyExists: true, nupi };
    }

    // Step 3 — register on blockchain via gateway
    // FIX: send full demographics so they are stored on chain
    // and any facility can retrieve them via verify/answer or verify/pin
    const chainRes = await gateway.post('/api/patients/register', {
      nationalId:       data.nationalId,
      dob:              data.dateOfBirth,
      name:             [data.firstName, data.middleName, data.lastName].filter(Boolean).join(' '),
      securityQuestion: data.securityQuestion,
      securityAnswer:   data.securityAnswer,
      pin:              data.pin,
      gender:           data.gender           || '',
      phoneNumber:      data.phoneNumber      || '',
      email:            data.email            || '',
      county:           data.address?.county    || '',
      subCounty:        data.address?.subCounty || '',
      ward:             data.address?.ward      || '',
      village:          data.address?.village   || '',
    });
    const blockIndex = chainRes.data.blockIndex ?? null;

    // Step 4 — save to Firestore
    const patientDoc = {
      nupi,
      nationalId:        data.nationalId,
      firstName:         data.firstName,
      lastName:          data.lastName,
      middleName:        data.middleName  ?? null,
      dateOfBirth:       data.dateOfBirth,
      gender:            data.gender,
      phoneNumber:       data.phoneNumber ?? null,
      email:             data.email       ?? null,
      address:           data.address     ?? null,
      facilityId:        process.env.FACILITY_ID || '',
      isFederatedRecord: false,
      blockIndex:        blockIndex ?? null,
      createdAt:         admin.firestore.FieldValue.serverTimestamp(),
      updatedAt:         admin.firestore.FieldValue.serverTimestamp(),
    };

    const ref     = await col.patients.add(patientDoc);
    const patient = { id: ref.id, ...patientDoc };

    console.log(`✅ Patient registered: ${nupi} | Block #${blockIndex}`);
    return { patient, alreadyExists: false, nupi, blockIndex };
  }

  // ══════════════════════════════════════════════════════════════
  //  GET BY FIRESTORE DOC ID
  // ══════════════════════════════════════════════════════════════

  async getById(id) {
    const doc = await col.patients.doc(id).get();
    if (!doc.exists) return null;
    return { id: doc.id, ...doc.data() };
  }

  // ══════════════════════════════════════════════════════════════
  //  GET BY NUPI — Firestore first, then gateway fallback
  // ══════════════════════════════════════════════════════════════

  async getByNupi(nupi, accessToken) {
    const snap = await col.patients.where('nupi', '==', nupi).limit(1).get();
    if (!snap.empty) {
      return { patient: { id: snap.docs[0].id, ...snap.docs[0].data() }, source: 'local' };
    }

    if (!accessToken) return null;

    try {
      const res  = await gateway.get(`/api/fhir/Patient/${nupi}`, {
        headers: { Authorization: `Bearer ${accessToken}` },
      });
      const fhir = res.data;
      if (!fhir || fhir.resourceType !== 'Patient') return null;

      const name    = fhir.name?.[0];
      const telecom = fhir.telecom || [];
      const addr    = fhir.address?.[0];

      const patientDoc = {
        nupi,
        firstName:         name?.given?.[0]  || 'Unknown',
        lastName:          name?.family       || 'Unknown',
        middleName:        name?.given?.[1]   ?? null,
        dateOfBirth:       fhir.birthDate     || null,
        gender:            fhir.gender        || 'unknown',
        phoneNumber:       telecom.find(t => t.system === 'phone')?.value ?? null,
        email:             telecom.find(t => t.system === 'email')?.value ?? null,
        address:           addr ? { county: addr.state, subCounty: addr.district, ward: addr.city } : null,
        isFederatedRecord: true,
        createdAt:         admin.firestore.FieldValue.serverTimestamp(),
        updatedAt:         admin.firestore.FieldValue.serverTimestamp(),
      };

      const ref     = await col.patients.add(patientDoc);
      return { patient: { id: ref.id, ...patientDoc }, source: 'gateway' };
    } catch (err) {
      if (err.response?.status === 404) return null;
      throw err;
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  SEARCH — Firestore prefix matching
  // ══════════════════════════════════════════════════════════════

  async searchNUPI(query) {
    const end = query + '\uf8ff';
    const [byNupi, byFirst, byLast] = await Promise.all([
      col.patients.where('nupi',      '>=', query.toUpperCase()).where('nupi',      '<=', query.toUpperCase() + '\uf8ff').limit(10).get(),
      col.patients.where('firstName', '>=', query).where('firstName', '<=', end).limit(10).get(),
      col.patients.where('lastName',  '>=', query).where('lastName',  '<=', end).limit(10).get(),
    ]);

    const seen    = new Set();
    const results = [];
    [...byNupi.docs, ...byFirst.docs, ...byLast.docs].forEach(doc => {
      if (!seen.has(doc.id)) { seen.add(doc.id); results.push({ id: doc.id, ...doc.data() }); }
    });
    return results.slice(0, 20);
  }

  // ══════════════════════════════════════════════════════════════
  //  IDENTITY VERIFICATION
  // ══════════════════════════════════════════════════════════════

  async getSecurityQuestion(nationalId, dob) {
    const res = await gateway.post('/api/verify/question', { nationalId, dob });
    return res.data;
  }

  async verifyIdentity({ nationalId, dob, answer }) {
    const res = await gateway.post('/api/verify/answer', {
      nationalId, dob, answer,
      requestingFacility: process.env.FACILITY_ID,
    }, {
      headers: { 'X-Api-Key': process.env.FACILITY_API_KEY || '' },
    });
    return res.data;
  }

  async verifyByPin({ nationalId, dob, pin }) {
    const res = await gateway.post('/api/verify/pin', {
      nationalId, dob, pin,
      requestingFacility: process.env.FACILITY_ID,
    }, {
      headers: { 'X-Api-Key': process.env.FACILITY_API_KEY || '' },
    });
    return res.data;
  }

  // ══════════════════════════════════════════════════════════════
  //  BLOCKCHAIN HISTORY
  // ══════════════════════════════════════════════════════════════

  async getPatientHistory(nupi) {
    const res = await gateway.get(`/api/patients/${nupi}/history`);
    return res.data;
  }

  async getPatientFacilities(nupi) {
    const history = await this.getPatientHistory(nupi);
    return history.facilitiesVisited || [];
  }

  // ══════════════════════════════════════════════════════════════
  //  ENCOUNTERS
  // ══════════════════════════════════════════════════════════════

  async getLocalEncounters(nupi) {
    const snap = await col.encounters
      .where('patient_nupi', '==', nupi)
      .orderBy('encounter_date', 'desc')
      .get();
    return snap.docs.map(doc => ({
      id: doc.id, ...doc.data(),
      source:       'local',
      facilityName: process.env.FACILITY_NAME || 'ClinicConnect',
    }));
  }

  async getEncountersFromFacility(nupi, facilityId, accessToken) {
    const res = await gateway.get(`/api/fhir/Patient/${nupi}/Encounter`, {
      params:  { facility: facilityId },
      headers: { Authorization: `Bearer ${accessToken}` },
    });
    return res.data;
  }

  async getFederatedEncounters(nupi, accessToken) {
    const res    = await gateway.get(`/api/fhir/Patient/${nupi}/$everything`, {
      headers: { Authorization: `Bearer ${accessToken}` },
    });
    const bundle = res.data;
    const encounters = bundle.entry
      ?.map(e => e.resource)
      .filter(r => r?.resourceType === 'Encounter') || [];
    return { bundle, encounters };
  }

  // ══════════════════════════════════════════════════════════════
  //  FULL FEDERATED PATIENT DATA
  // ══════════════════════════════════════════════════════════════

  async getFederatedPatientData(nupi, accessToken) {
    const facilityId = process.env.FACILITY_ID || '';

    const [localSnap, localEncounters, federatedBundle, chainHistory] = await Promise.all([
      col.patients.where('nupi', '==', nupi).limit(1).get(),
      this.getLocalEncounters(nupi),
      this.getFederatedEncounters(nupi, accessToken).catch(() => ({ bundle: null, encounters: [] })),
      this.getPatientHistory(nupi).catch(() => null),
    ]);

    const localPatient = localSnap.empty
      ? null
      : { id: localSnap.docs[0].id, ...localSnap.docs[0].data() };

    const remoteEncounters = federatedBundle.encounters
      .filter(e => e.meta?.source !== facilityId)
      .map(e => ({
        id:             e.id,
        patientNupi:    nupi,
        encounterDate:  e.period?.start,
        encounterType:  e.class?.display,
        chiefComplaint: e.reasonCode?.[0]?.text || null,
        practitioner:   e.participant?.[0]?.individual?.display || null,
        facilityId:     e.meta?.source,
        facilityName:   e.meta?.sourceName || e.serviceProvider?.display,
        source:         'gateway',
        status:         e.status,
      }));

    const allEncounters = [...localEncounters, ...remoteEncounters]
      .sort((a, b) =>
        new Date(b.encounterDate || b.encounter_date).getTime() -
        new Date(a.encounterDate || a.encounter_date).getTime()
      );

    return {
      patient:           localPatient,
      encounters:        allEncounters,
      localEncounters,
      remoteEncounters,
      facilitiesVisited: chainHistory?.facilitiesVisited || [],
      encounterIndex:    chainHistory?.encounterIndex    || [],
      totalEncounters:   allEncounters.length,
      consentVerified:   true,
    };
  }

  // ══════════════════════════════════════════════════════════════
  //  RECORD ENCOUNTER
  //  1. Save to Firestore
  //  2. Mint ENCOUNTER_RECORDED block via gateway
  // ══════════════════════════════════════════════════════════════

  async recordEncounter(data) {
    const encounterDoc = {
      patient_nupi:      data.nupi,
      facility_id:       process.env.FACILITY_ID || '',
      encounter_type:    data.encounterType,
      encounter_date:    data.encounterDate   || new Date().toISOString(),
      chief_complaint:   data.chiefComplaint  ?? null,
      practitioner_name: data.practitionerName ?? 'Unknown',
      vital_signs:       data.vitalSigns      ?? null,
      diagnoses:         data.diagnoses       ?? [],
      medications:       data.medications     ?? null,
      notes:             data.notes           ?? null,
      status:            'active',
      source:            process.env.FACILITY_NAME || 'ClinicConnect',
      created_at:        admin.firestore.FieldValue.serverTimestamp(),
      updated_at:        admin.firestore.FieldValue.serverTimestamp(),
    };

    const ref       = await col.encounters.add(encounterDoc);
    const encounter = { id: ref.id, ...encounterDoc };

    try {
      const chainRes = await gateway.post('/api/patients/encounter', {
        nupi:             data.nupi,
        encounterId:      ref.id,
        encounterType:    data.encounterType,
        encounterDate:    data.encounterDate || new Date().toISOString(),
        chiefComplaint:   data.chiefComplaint  ?? null,
        practitionerName: data.practitionerName ?? null,
      });
      console.log(`⛓  Encounter on chain: Block #${chainRes.data.blockIndex}`);
      return { encounter, blockIndex: chainRes.data.blockIndex };
    } catch (err) {
      console.error('Chain notification failed (saved locally):', err.message);
      return { encounter, blockIndex: null, chainError: err.message };
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  CHECK-IN
  // ══════════════════════════════════════════════════════════════

  async checkIn(nupi, data) {
    const snap = await col.patients.where('nupi', '==', nupi).limit(1).get();
    if (snap.empty) {
      const result = await this.getByNupi(nupi, data.accessToken);
      if (!result) throw new Error('Patient not found on AfyaNet');
    }
    return this.recordEncounter({
      nupi,
      encounterType:    'check-in',
      chiefComplaint:   data.chiefComplaint   ?? undefined,
      practitionerName: data.practitionerName ?? undefined,
    });
  }

  // ══════════════════════════════════════════════════════════════
  //  REGISTER VISIT
  // ══════════════════════════════════════════════════════════════

  async registerVisit(nupi, data) {
    return this.recordEncounter({
      nupi,
      encounterType:    data.encounterType    ?? 'outpatient',
      chiefComplaint:   data.chiefComplaint   ?? undefined,
      practitionerName: data.practitionerName ?? undefined,
      vitalSigns:       data.vitalSigns       ?? undefined,
      diagnoses:        data.diagnoses        ?? undefined,
      medications:      data.medications      ?? undefined,
      notes:            data.notes            ?? undefined,
    });
  }
}

export const patientService = new PatientService();

// ── Keep-alive ping ───────────────────────────────────────────────
// Kept for backward compat — server.js now calls startSelfKeepAlive() instead
export function startGatewayKeepAlive() {
  // no-op: keep-alive is handled in server.js startSelfKeepAlive()
}