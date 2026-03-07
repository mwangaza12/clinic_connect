/**
 * ClinicConnect — FHIR R4 Routes
 * ════════════════════════════════
 * Exposed to the HIE Gateway so NYH_001 and other facilities can
 * fetch this facility's patient data during cross-facility queries.
 *
 * Gateway calls these with header: X-Gateway-ID: HIE_GATEWAY
 * The gateway has already verified the patient access token before
 * routing here — we just trust the gateway header.
 *
 * Endpoints:
 *   GET /fhir/Patient/:nupi
 *   GET /fhir/Encounter?patient=:nupi
 *   GET /fhir/Patient/:nupi/Encounter
 *   GET /fhir/Patient/:nupi/$everything    ← main one the gateway uses
 */

import { Router } from 'express';
import admin      from 'firebase-admin';
import 'dotenv/config';

const router = Router();

const db  = admin.firestore();
const col = {
  patients:   db.collection('patients'),
  encounters: db.collection('encounters'),
};

const FACILITY_ID   = () => process.env.FACILITY_ID   || 'CLI_001';
const FACILITY_NAME = () => process.env.FACILITY_NAME || 'ClinicConnect';

// ── Gateway auth middleware ───────────────────────────────────────
function requireGateway(req, res, next) {
  if (req.headers['x-gateway-id'] !== 'HIE_GATEWAY') {
    return res.status(401).json({
      resourceType: 'OperationOutcome',
      issue: [{ severity: 'error', code: 'security',
        diagnostics: 'Only HIE Gateway may access FHIR endpoints. Include X-Gateway-ID: HIE_GATEWAY header.' }],
    });
  }
  next();
}

// ── FHIR builders ────────────────────────────────────────────────

function buildPatient(doc) {
  const p = doc;
  return {
    resourceType: 'Patient',
    id:     p.id || p.nupi,
    meta: {
      source:      FACILITY_ID(),
      sourceName:  FACILITY_NAME(),
      lastUpdated: p.updatedAt || new Date().toISOString(),
    },
    identifier: [{
      system: 'https://khis.uonbi.ac.ke/fhir/NamingSystem/nupi',
      value:  p.nupi,
    }],
    active: true,
    name: [{
      use:    'official',
      family: p.lastName    || p.last_name    || 'Unknown',
      given:  [
        p.firstName  || p.first_name  || 'Unknown',
        ...(p.middleName || p.middle_name ? [p.middleName || p.middle_name] : []),
      ],
    }],
    telecom: [
      ...(p.phoneNumber || p.phone_number
        ? [{ system: 'phone', value: p.phoneNumber || p.phone_number, use: 'mobile' }]
        : []),
      ...(p.email ? [{ system: 'email', value: p.email }] : []),
    ],
    gender:    p.gender     || 'unknown',
    birthDate: p.dateOfBirth || p.date_of_birth || null,
    address: p.address ? [{
      use:      'home',
      state:    p.address.county    || null,
      district: p.address.subCounty || null,
      city:     p.address.ward      || null,
      country:  'KE',
    }] : [],
    extension: [{
      url:         'https://khis.uonbi.ac.ke/fhir/StructureDefinition/managing-facility',
      valueString: FACILITY_ID(),
    }],
  };
}

function buildEncounter(doc, nupi) {
  const e = doc;
  const type = e.type || e.encounter_type || 'outpatient';
  const classCode = type === 'inpatient' ? 'IMP'
                  : type === 'emergency' ? 'EMER'
                  : 'AMB';
  return {
    resourceType: 'Encounter',
    id:     e.id,
    meta: {
      source:     FACILITY_ID(),
      sourceName: FACILITY_NAME(),
    },
    status: e.status || 'finished',
    class: {
      system:  'http://terminology.hl7.org/CodeSystem/v3-ActCode',
      code:    classCode,
      display: type,
    },
    subject: { reference: `Patient/${nupi}` },
    participant: (e.clinicianName || e.clinician_name) ? [{
      individual: { display: e.clinicianName || e.clinician_name },
    }] : [],
    period: {
      start: e.encounterDate || e.encounter_date || e.createdAt || e.created_at,
    },
    reasonCode: (e.chiefComplaint || e.chief_complaint)
      ? [{ text: e.chiefComplaint || e.chief_complaint }]
      : [],
    serviceProvider: {
      reference: `Organization/${FACILITY_ID()}`,
      display:   FACILITY_NAME(),
    },
  };
}

// ── GET /fhir/Patient/:nupi ───────────────────────────────────────

router.get('/Patient/:nupi', requireGateway, async (req, res) => {
  try {
    const { nupi } = req.params;
    const snap = await col.patients.where('nupi', '==', nupi).limit(1).get();

    if (snap.empty) {
      return res.status(404).json({
        resourceType: 'OperationOutcome',
        issue: [{ severity: 'error', code: 'not-found',
          diagnostics: `Patient ${nupi} not found at ${FACILITY_NAME()}` }],
      });
    }

    const data = { id: snap.docs[0].id, ...snap.docs[0].data() };
    res.set('Content-Type', 'application/fhir+json');
    res.json(buildPatient(data));
  } catch (err) {
    console.error('FHIR Patient error:', err.message);
    res.status(500).json({
      resourceType: 'OperationOutcome',
      issue: [{ severity: 'error', code: 'exception', diagnostics: err.message }],
    });
  }
});

// ── GET /fhir/Patient/:nupi/$everything ──────────────────────────
// Full bundle — Patient + all Encounters. Main endpoint the gateway uses.

router.get('/Patient/:nupi/\\$everything', requireGateway, async (req, res) => {
  try {
    const { nupi } = req.params;

    const [patientSnap, encounterSnap] = await Promise.all([
      col.patients.where('nupi', '==', nupi).limit(1).get(),
      col.encounters
        .where('patient_nupi', '==', nupi)
        .orderBy('encounter_date', 'desc')
        .get(),
    ]);

    if (patientSnap.empty) {
      return res.status(404).json({
        resourceType: 'OperationOutcome',
        issue: [{ severity: 'error', code: 'not-found',
          diagnostics: `Patient ${nupi} not found at ${FACILITY_NAME()}` }],
      });
    }

    const patientData = { id: patientSnap.docs[0].id, ...patientSnap.docs[0].data() };

    const entries = [
      { fullUrl: `Patient/${patientData.id}`, resource: buildPatient(patientData) },
    ];

    encounterSnap.docs.forEach(doc => {
      const data = { id: doc.id, ...doc.data() };
      entries.push({ fullUrl: `Encounter/${doc.id}`, resource: buildEncounter(data, nupi) });
    });

    const requestingFacility = req.headers['x-requesting-facility'] || 'unknown';
    console.log(`📤 FHIR $everything: ${nupi} → ${entries.length} resources → ${requestingFacility}`);

    res.set('Content-Type', 'application/fhir+json');
    res.json({
      resourceType: 'Bundle',
      type:         'collection',
      total:        entries.length,
      meta: {
        lastUpdated: new Date().toISOString(),
        source:      FACILITY_ID(),
        sourceName:  FACILITY_NAME(),
      },
      entry: entries,
    });
  } catch (err) {
    console.error('FHIR $everything error:', err.message);
    res.status(500).json({
      resourceType: 'OperationOutcome',
      issue: [{ severity: 'error', code: 'exception', diagnostics: err.message }],
    });
  }
});

// ── GET /fhir/Patient/:nupi/Encounter ────────────────────────────

router.get('/Patient/:nupi/Encounter', requireGateway, async (req, res) => {
  try {
    const { nupi } = req.params;
    const snap = await col.encounters
      .where('patient_nupi', '==', nupi)
      .orderBy('encounter_date', 'desc')
      .get();

    const entries = snap.docs.map(doc => {
      const data = { id: doc.id, ...doc.data() };
      return { fullUrl: `Encounter/${doc.id}`, resource: buildEncounter(data, nupi) };
    });

    res.set('Content-Type', 'application/fhir+json');
    res.json({
      resourceType: 'Bundle',
      type:  'searchset',
      total: entries.length,
      meta:  { source: FACILITY_ID(), sourceName: FACILITY_NAME() },
      entry: entries,
    });
  } catch (err) {
    res.status(500).json({
      resourceType: 'OperationOutcome',
      issue: [{ severity: 'error', code: 'exception', diagnostics: err.message }],
    });
  }
});

// ── GET /fhir/Encounter?patient=:nupi ────────────────────────────

router.get('/Encounter', requireGateway, async (req, res) => {
  try {
    const nupi = req.query.patient;
    if (!nupi) {
      return res.status(400).json({
        resourceType: 'OperationOutcome',
        issue: [{ severity: 'error', code: 'required',
          diagnostics: 'Query param ?patient=NUPI is required' }],
      });
    }

    const snap = await col.encounters
      .where('patient_nupi', '==', nupi)
      .orderBy('encounter_date', 'desc')
      .get();

    const entries = snap.docs.map(doc => {
      const data = { id: doc.id, ...doc.data() };
      return { fullUrl: `Encounter/${doc.id}`, resource: buildEncounter(data, nupi) };
    });

    res.set('Content-Type', 'application/fhir+json');
    res.json({
      resourceType: 'Bundle',
      type:  'searchset',
      total: entries.length,
      meta:  { source: FACILITY_ID(), sourceName: FACILITY_NAME() },
      entry: entries,
    });
  } catch (err) {
    res.status(500).json({
      resourceType: 'OperationOutcome',
      issue: [{ severity: 'error', code: 'exception', diagnostics: err.message }],
    });
  }
});

export default router;