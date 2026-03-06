import { Router } from 'express';
import { patientController } from './patient.controller.js';

const router = Router();

/**
 * AfyaLink Patient Routes — ClinicConnect
 * ════════════════════════════════════════
 *
 * Typical workflow for a returning patient:
 *  1. GET  /api/patients/verify/question?nationalId=X&dob=Y
 *  2. POST /api/patients/verify/answer  { nationalId, dob, answer }
 *          → returns { token, nupi, facilitiesVisited, encounterIndex }
 *  3. GET  /api/patients/:nupi/federated   Authorization: Bearer <token>
 *  4. POST /api/patients/:nupi/visit       Authorization: Bearer <token>
 *
 * Registering a new patient:
 *  POST /api/patients  { nationalId, givenName, familyName, dob, gender,
 *                        securityQuestion, securityAnswer, pin }
 */

// ── Registration & lookup ─────────────────────────────────────────
router.post('/',          patientController.create.bind(patientController));
router.get('/id/:id',     patientController.getById.bind(patientController));
router.get('/search/nupi',patientController.searchNUPI.bind(patientController));

// ── Identity verification ─────────────────────────────────────────
router.get('/verify/question', patientController.getSecurityQuestion.bind(patientController));
router.post('/verify/answer',  patientController.verifyAnswer.bind(patientController));
router.post('/verify/pin',     patientController.verifyPin.bind(patientController));

// ── NUPI-based routes ─────────────────────────────────────────────
router.get('/nupi/:nupi',          patientController.getByNupi.bind(patientController));
router.post('/nupi/:nupi/checkin', patientController.checkIn.bind(patientController));

// ── Encounters ────────────────────────────────────────────────────
router.get('/:nupi/encounters',                      patientController.getLocalEncounters.bind(patientController));
router.get('/:nupi/encounters/facility/:facilityId', patientController.getEncountersFromFacility.bind(patientController));
router.get('/:nupi/federated',                       patientController.getFederatedData.bind(patientController));

// ── Blockchain data ───────────────────────────────────────────────
router.get('/:nupi/facilities', patientController.getFacilities.bind(patientController));
router.get('/:nupi/history',    patientController.getHistory.bind(patientController));

// ── Visit recording ───────────────────────────────────────────────
router.post('/:nupi/visit', patientController.registerVisit.bind(patientController));

export default router;
