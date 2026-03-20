// seed.js — ClinicConnect Demo Data Seeder
import axios from 'axios';
import 'dotenv/config';

const GATEWAY = process.env.HIE_GATEWAY_URL || 'https://hie-gateway.onrender.com';

const PATIENTS_A = [
  { nationalId:'11111111', firstName:'Amina',   lastName:'Mwangi',  dob:'1985-03-12', gender:'female', phone:'0712345001', county:'Kilifi',   subCounty:'Kilifi North', ward:'Kilifi Town',  secA:'Mombasa',   program:'hivArt'       },
  { nationalId:'11111112', firstName:'Juma',    lastName:'Karisa',  dob:'1978-07-22', gender:'male',   phone:'0712345002', county:'Kilifi',   subCounty:'Kilifi South', ward:'Mariakani',    secA:'Malindi',   program:'hypertension' },
  { nationalId:'11111113', firstName:'Fatuma',  lastName:'Charo',   dob:'1992-11-05', gender:'female', phone:'0712345003', county:'Kilifi',   subCounty:'Rabai',        ward:'Rabai',        secA:'Kilifi',    program:'mch'          },
  { nationalId:'11111114', firstName:'Hassan',  lastName:'Masha',   dob:'1965-01-18', gender:'male',   phone:'0712345004', county:'Kilifi',   subCounty:'Ganze',        ward:'Ganze',        secA:'Kaloleni',  program:'ncdDiabetes'  },
  { nationalId:'11111115', firstName:'Grace',   lastName:'Nganga',  dob:'1990-06-30', gender:'female', phone:'0712345005', county:'Kilifi',   subCounty:'Malindi',      ward:'Malindi Town', secA:'Malindi',   program:'tb'           },
  { nationalId:'11111116', firstName:'Peter',   lastName:'Mwenda',  dob:'1982-09-14', gender:'male',   phone:'0712345006', county:'Kilifi',   subCounty:'Magarini',     ward:'Magarini',     secA:'Watamu',    program:'malaria'      },
  { nationalId:'11111117', firstName:'Zawadi',  lastName:'Katana',  dob:'1975-04-08', gender:'female', phone:'0712345007', county:'Kilifi',   subCounty:'Kilifi North', ward:'Mtwapa',       secA:'Mtwapa',    program:'hivArt'       },
  { nationalId:'11111118', firstName:'David',   lastName:'Tsuma',   dob:'1988-12-25', gender:'male',   phone:'0712345008', county:'Kilifi',   subCounty:'Kilifi South', ward:'Kwale',        secA:'Voi',       program:'hypertension' },
  { nationalId:'11111119', firstName:'Rehema',  lastName:'Ngolo',   dob:'1995-08-17', gender:'female', phone:'0712345009', county:'Kilifi',   subCounty:'Rabai',        ward:'Kaloleni',     secA:'Mombasa',   program:'mch'          },
  { nationalId:'11111120', firstName:'Samson',  lastName:'Kazungu', dob:'1971-02-28', gender:'male',   phone:'0712345010', county:'Kilifi',   subCounty:'Ganze',        ward:'Bamba',        secA:'Kilifi',    program:'ncdDiabetes'  },
];

const PATIENTS_B = [
  { nationalId:'22222221', firstName:'Mary',     lastName:'Wanjiku',  dob:'1983-05-20', gender:'female', phone:'0722345001', county:'Laikipia', subCounty:'Laikipia North', ward:'Nyahururu',  secA:'Nyahururu', program:'hivArt'       },
  { nationalId:'22222222', firstName:'Joseph',   lastName:'Kamau',    dob:'1970-10-03', gender:'male',   phone:'0722345002', county:'Laikipia', subCounty:'Laikipia West',  ward:'Ol Kalou',   secA:'Nakuru',    program:'hypertension' },
  { nationalId:'22222223', firstName:'Esther',   lastName:'Njoroge',  dob:'1991-07-14', gender:'female', phone:'0722345003', county:'Laikipia', subCounty:'Laikipia East',  ward:'Nanyuki',    secA:'Nanyuki',   program:'mch'          },
  { nationalId:'22222224', firstName:'Michael',  lastName:'Gitau',    dob:'1967-03-09', gender:'male',   phone:'0722345004', county:'Laikipia', subCounty:'Laikipia North', ward:'Thomson',    secA:'Thomson',   program:'ncdDiabetes'  },
  { nationalId:'22222225', firstName:'Lucy',     lastName:'Wairimu',  dob:'1987-12-01', gender:'female', phone:'0722345005', county:'Laikipia', subCounty:'Laikipia West',  ward:'Ol Kalou',   secA:'Nyahururu', program:'tb'           },
  { nationalId:'22222226', firstName:'Samuel',   lastName:'Muthoni',  dob:'1993-04-22', gender:'male',   phone:'0722345006', county:'Laikipia', subCounty:'Laikipia East',  ward:'Rumuruti',   secA:'Rumuruti',  program:'malaria'      },
  { nationalId:'22222227', firstName:'Agnes',    lastName:'Kariuki',  dob:'1979-09-16', gender:'female', phone:'0722345007', county:'Laikipia', subCounty:'Laikipia North', ward:'Nyahururu',  secA:'Nanyuki',   program:'hivArt'       },
  { nationalId:'22222228', firstName:'Daniel',   lastName:'Mugo',     dob:'1986-11-30', gender:'male',   phone:'0722345008', county:'Laikipia', subCounty:'Laikipia West',  ward:'Ol Kalou',   secA:'Nakuru',    program:'hypertension' },
  { nationalId:'22222229', firstName:'Caroline', lastName:'Wambui',   dob:'1997-06-08', gender:'female', phone:'0722345009', county:'Laikipia', subCounty:'Laikipia East',  ward:'Nanyuki',    secA:'Nyahururu', program:'mch'          },
  { nationalId:'22222230', firstName:'George',   lastName:'Ndungu',   dob:'1962-08-25', gender:'male',   phone:'0722345010', county:'Laikipia', subCounty:'Laikipia North', ward:'Thomson',    secA:'Thomson',   program:'ncdDiabetes'  },
];

const FACILITIES = [
  { id:'FAC-KE-001', apiKey:'FAC-234BAFBBA0886028A26C87B7A6645507', apiUrl:'https://clinic-connect-sxct.onrender.com', label:'Kilifi County Hospital',      patients:PATIENTS_A },
  { id:'FAC-KE-002', apiKey:'FAC-958CF05B855EC2AD589D128ECB090E5D', apiUrl:'https://clinic-connect-1.onrender.com',    label:'Nyahururu Referral Hospital', patients:PATIENTS_B },
];

const ENC = {
  hivArt: [
    { type:'outpatient', daysAgo:90,  chief_complaint:'ART medication refill and routine review',            clinician_name:'Dr. Kamau Ochieng', vitals:{systolic_bp:118,diastolic_bp:76, temperature:36.8,weight:62,pulse_rate:74, oxygen_saturation:98},                 diagnoses:[{code:'B20',    description:'HIV disease - on ART, stable',                      is_primary:true}],                                                                      clinical_notes:'Patient adherent to TDF/3TC/DTG. Viral load suppressed <50 copies/ml. CD4 count 650.',  treatment_plan:'Continue TDF/3TC/DTG 1 tablet OD. Cotrimoxazole prophylaxis. Repeat viral load in 6 months.' },
    { type:'outpatient', daysAgo:55,  chief_complaint:'Routine HIV clinic - fever and mild cough',           clinician_name:'Dr. Amina Said',     vitals:{systolic_bp:120,diastolic_bp:78, temperature:37.4,weight:62,pulse_rate:82, oxygen_saturation:97},                 diagnoses:[{code:'B20',    description:'HIV disease',                                       is_primary:true},{code:'J06.9',description:'Upper respiratory tract infection',is_primary:false}], clinical_notes:'Mild URTI. TB screening negative.',                                                      treatment_plan:'Amoxicillin 500mg TDS for 5 days. Continue ART unchanged.' },
    { type:'outpatient', daysAgo:14,  chief_complaint:'Scheduled ART refill - no complaints',                clinician_name:'Dr. Kamau Ochieng', vitals:{systolic_bp:116,diastolic_bp:74, temperature:36.6,weight:63,pulse_rate:72, oxygen_saturation:99},                 diagnoses:[{code:'Z79.899',description:'HIV on ART - virologically suppressed',             is_primary:true}],                                                                      clinical_notes:'Excellent adherence. No side effects. Weight stable at 63kg.',                           treatment_plan:'Continue TDF/3TC/DTG. Next appointment 3 months.' },
  ],
  hypertension: [
    { type:'outpatient', daysAgo:90,  chief_complaint:'Elevated blood pressure - referred from pharmacy',    clinician_name:'Dr. Peter Njoroge', vitals:{systolic_bp:164,diastolic_bp:98, temperature:36.7,weight:82,pulse_rate:86, oxygen_saturation:97},                 diagnoses:[{code:'I10',    description:'Essential hypertension - Stage 2, newly diagnosed',  is_primary:true}],                                                                      clinical_notes:'BMI 28.4. No end-organ damage. Fundoscopy normal. ECG normal sinus rhythm.',            treatment_plan:'Amlodipine 5mg OD. Low-salt diet. Exercise 30min daily. Review in 4 weeks.' },
    { type:'outpatient', daysAgo:55,  chief_complaint:'BP review - morning headaches',                       clinician_name:'Dr. Faith Muthoni', vitals:{systolic_bp:148,diastolic_bp:92, temperature:36.5,weight:81,pulse_rate:80, oxygen_saturation:98},                 diagnoses:[{code:'I10',    description:'Essential hypertension - partially controlled',      is_primary:true}],                                                                      clinical_notes:'BP improving but not at target 130/80. Morning headache correlates with BP spikes.',     treatment_plan:'Amlodipine increased to 10mg OD. Added Lisinopril 5mg OD. Avoid NSAIDs.' },
    { type:'emergency',  daysAgo:7,   chief_complaint:'Severe headache, blurred vision, very high BP',       clinician_name:'Dr. Peter Njoroge', vitals:{systolic_bp:186,diastolic_bp:114,temperature:36.9,weight:82,pulse_rate:96, oxygen_saturation:96},                 diagnoses:[{code:'I10',    description:'Hypertensive urgency',                               is_primary:true},{code:'R51',description:'Severe headache',is_primary:false}],                   clinical_notes:'BP controlled to 154/94 over 2 hours with IV Labetalol. Admitted for 24hr observation.', treatment_plan:'IV Labetalol. Oral medications continued. Repeat BP q1h.' },
  ],
  mch: [
    { type:'outpatient', daysAgo:120, chief_complaint:'First ANC visit - 8 weeks pregnant',                  clinician_name:'Nurse Grace Auma',  vitals:{systolic_bp:108,diastolic_bp:68, temperature:36.8,weight:58,pulse_rate:76, oxygen_saturation:99},                 diagnoses:[{code:'Z34.0',  description:'Supervision of normal first trimester pregnancy',    is_primary:true}],                                                                      clinical_notes:'G2P1. Blood group O+, HIV negative, Syphilis negative. Fundal height 8cm.',             treatment_plan:'Folic acid 5mg OD. Ferrous sulphate 200mg BD. TT1 given. Next ANC at 20 weeks.' },
    { type:'outpatient', daysAgo:60,  chief_complaint:'ANC visit - 20 weeks, baby movements felt',           clinician_name:'Dr. Esther Wanjiku',vitals:{systolic_bp:112,diastolic_bp:70, temperature:36.7,weight:63,pulse_rate:80, oxygen_saturation:99},                 diagnoses:[{code:'Z34.1',  description:'Supervision of normal second trimester pregnancy',   is_primary:true}],                                                                      clinical_notes:'Fundal height 20cm. FHR 148bpm. Anomaly scan normal. GDM screening negative.',          treatment_plan:'Continue iron + folic acid. TT2 given. LLINS given. Next ANC at 28 weeks.' },
    { type:'outpatient', daysAgo:14,  chief_complaint:'ANC visit - 28 weeks, mild ankle swelling',           clinician_name:'Dr. Esther Wanjiku',vitals:{systolic_bp:116,diastolic_bp:72, temperature:36.6,weight:68,pulse_rate:82, oxygen_saturation:99},                 diagnoses:[{code:'Z34.2',  description:'Supervision of normal third trimester pregnancy',    is_primary:true}],                                                                      clinical_notes:'Mild physiological oedema. BP normal. Fundal height 28cm. Cephalic. No proteinuria.',   treatment_plan:'Elevate legs. Calcium 1g OD added. Next ANC at 32 weeks.' },
  ],
  ncdDiabetes: [
    { type:'outpatient', daysAgo:90,  chief_complaint:'Increased thirst, frequent urination, weight loss',   clinician_name:'Dr. Hassan Abdi',   vitals:{systolic_bp:132,diastolic_bp:84, temperature:36.8,weight:88,pulse_rate:80, oxygen_saturation:97,blood_glucose:14.2}, diagnoses:[{code:'E11',    description:'Type 2 diabetes mellitus - newly diagnosed',         is_primary:true}],                                                                      clinical_notes:'FBS 14.2mmol/L. HbA1c 9.8%. BMI 32. Foot exam normal.',                                treatment_plan:'Metformin 500mg BD. Diabetic diet education. Exercise 150min/week.' },
    { type:'outpatient', daysAgo:55,  chief_complaint:'Diabetes review - blood sugar still elevated',        clinician_name:'Dr. Hassan Abdi',   vitals:{systolic_bp:128,diastolic_bp:82, temperature:36.7,weight:86,pulse_rate:78, oxygen_saturation:97,blood_glucose:9.8},  diagnoses:[{code:'E11',    description:'T2DM - improving',                                   is_primary:true}],                                                                      clinical_notes:'FBS averaging 11.2mmol/L. HbA1c 8.4%. Weight down 2kg. Foot exam normal.',             treatment_plan:'Metformin increased to 1000mg BD. Glibenclamide 5mg OD added.' },
    { type:'outpatient', daysAgo:10,  chief_complaint:'Numbness and tingling in both feet',                  clinician_name:'Dr. James Omondi',  vitals:{systolic_bp:126,diastolic_bp:80, temperature:36.6,weight:85,pulse_rate:76, oxygen_saturation:98,blood_glucose:11.1}, diagnoses:[{code:'E11.40', description:'T2DM with diabetic peripheral neuropathy',           is_primary:true}],                                                                      clinical_notes:'Peripheral neuropathy confirmed by monofilament test. HbA1c 7.6% - improving.',         treatment_plan:'Amitriptyline 10mg nocte. Daily foot inspection education.' },
  ],
  tb: [
    { type:'outpatient', daysAgo:150, chief_complaint:'Persistent cough 3 weeks, night sweats, weight loss', clinician_name:'Dr. Charles Mwai',  vitals:{systolic_bp:106,diastolic_bp:66, temperature:38.2,weight:50,pulse_rate:98, oxygen_saturation:93},                 diagnoses:[{code:'A15.0',  description:'Pulmonary tuberculosis - bacteriologically confirmed',is_primary:true}],                                                                      clinical_notes:'GeneXpert positive MTB, RIF sensitive. CXR bilateral infiltrates. HIV negative.',       treatment_plan:'2RHZE daily. DOT arranged. Contact tracing initiated.' },
    { type:'outpatient', daysAgo:90,  chief_complaint:'TB treatment review - 2 month milestone',             clinician_name:'Nurse Ruth Kamau',  vitals:{systolic_bp:112,diastolic_bp:70, temperature:36.9,weight:54,pulse_rate:82, oxygen_saturation:96},                 diagnoses:[{code:'A15.0',  description:'Pulmonary TB - intensive phase completing',            is_primary:true}],                                                                      clinical_notes:'Sputum conversion confirmed. Weight gain 4kg. 100% DOT adherence.',                     treatment_plan:'Transition to 4RH continuation phase. DOT continue.' },
    { type:'outpatient', daysAgo:7,   chief_complaint:'TB treatment final review - 6 month check',           clinician_name:'Dr. Charles Mwai',  vitals:{systolic_bp:118,diastolic_bp:74, temperature:36.7,weight:60,pulse_rate:74, oxygen_saturation:98},                 diagnoses:[{code:'A15.0',  description:'Pulmonary TB - treatment completed',                   is_primary:true}],                                                                      clinical_notes:'End-of-treatment sputum smear negative. Weight restored 60kg. Outcome: Cured.',          treatment_plan:'Treatment completed. Discharge from TB register.' },
  ],
  malaria: [
    { type:'outpatient', daysAgo:45,  chief_complaint:'Fever, chills, headache and body aches for 2 days',  clinician_name:'Dr. Mercy Njeri',  vitals:{systolic_bp:102,diastolic_bp:64, temperature:39.1,weight:68,pulse_rate:108,oxygen_saturation:95},                 diagnoses:[{code:'B54',    description:'Malaria - P. falciparum uncomplicated',               is_primary:true}],                                                                      clinical_notes:'RDT positive P.falciparum. No danger signs. Not pregnant.',                             treatment_plan:'AL 4 tablets at 0,8,24,36,48,60h. Paracetamol 1g TDS. ORS for hydration.' },
    { type:'outpatient', daysAgo:38,  chief_complaint:'Follow-up after malaria treatment - feeling better',  clinician_name:'Nurse John Ouko',  vitals:{systolic_bp:114,diastolic_bp:72, temperature:36.7,weight:68,pulse_rate:76, oxygen_saturation:98},                 diagnoses:[{code:'B54',    description:'Malaria - resolved',                                  is_primary:true}],                                                                      clinical_notes:'Treatment completed. Symptoms fully resolved. RDT negative.',                           treatment_plan:'Discharged. ITN provided. Preventive education given.' },
    { type:'outpatient', daysAgo:10,  chief_complaint:'Routine checkup - fully recovered',                   clinician_name:'Dr. Mercy Njeri',  vitals:{systolic_bp:116,diastolic_bp:74, temperature:36.6,weight:69,pulse_rate:72, oxygen_saturation:99},                 diagnoses:[{code:'Z09',    description:'Follow-up after completed malaria treatment',          is_primary:true}],                                                                      clinical_notes:'Fully recovered. Hb 13.2g/dl normal. RDT negative.',                                   treatment_plan:'No further treatment. Malaria prevention education reinforced.' },
  ],
};

// camelCase — matches ProgramEnrollmentModel.toFirestore() exactly
function makeEnrollment(nupi, patientName, facilityId, program) {
  const now = new Date();
  const enr = new Date(now.getTime() - 85 * 86400000);
  const id  = `enr_${nupi}_${program}_${Date.now()}`;
  const iso = d => d.toISOString();

  const specificData = {
    hivArt:       { hivDiagnosisDate:iso(new Date(enr.getTime()-180*86400000)), whoStage:'Stage 2', baselineCd4Count:380, currentCd4Count:650, arvRegimen:'TDF/3TC/DTG', arvStartDate:iso(enr), viralLoadStatus:'Suppressed', lastViralLoad:45, onTbProphylaxis:false, onCotrimoxazole:true, nextAppointmentDate:iso(new Date(now.getTime()+60*86400000)) },
    hypertension: { diagnosisDate:iso(enr), baselineSystolic:164, baselineDiastolic:98, medication:'Amlodipine 10mg OD + Lisinopril 5mg OD', stage:'Stage 2', riskFactors:'Obesity, high salt intake', nextAppointmentDate:iso(new Date(now.getTime()+30*86400000)) },
    mch:          { programType:'ANC', lmp:iso(new Date(now.getTime()-196*86400000)), edd:iso(new Date(now.getTime()+84*86400000)), gravida:2, parity:1, ancVisitNumber:3, hivStatus:'Negative', onPmtct:false, nextImmunizationDate:iso(new Date(now.getTime()+14*86400000)) },
    ncdDiabetes:  { diabetesType:'Type 2', diagnosisDate:iso(enr), hba1c:7.6, fastingBloodSugar:9.2, medication:'Metformin 1000mg BD + Glibenclamide 5mg OD', onInsulin:false, complications:'Peripheral neuropathy', nextAppointmentDate:iso(new Date(now.getTime()+60*86400000)) },
    tb:           { diagnosisDate:iso(new Date(now.getTime()-150*86400000)), tbType:'Pulmonary', tbCategory:'New', testType:'GeneXpert', testResult:'MTB detected, RIF sensitive', treatmentRegimen:'2RHZE/4RH', treatmentStartDate:iso(new Date(now.getTime()-150*86400000)), treatmentPhase:2, nextAppointmentDate:iso(new Date(now.getTime()+7*86400000)) },
    malaria:      { symptomsStartDate:iso(new Date(now.getTime()-45*86400000)), testType:'RDT', testResult:'P. falciparum', severity:'Uncomplicated', treatment:'Artemether-Lumefantrine (AL)', treatmentDays:3, outcome:'Cured' },
  };

  return {
    id,
    patientNupi:         nupi,
    patientName,
    facilityId,
    program,
    status:              program === 'malaria' ? 'completed' : 'active',
    enrollmentDate:      iso(enr),
    completionDate:      program === 'malaria' ? iso(new Date(now.getTime()-35*86400000)) : null,
    outcomeNotes:        program === 'malaria' ? 'Treatment completed. Cured.' : null,
    programSpecificData: specificData[program] ?? null,
    createdAt:           iso(enr),
    updatedAt:           iso(now),
  };
}

// Firestore REST — ISO date strings auto-detected and converted to timestampValue
function toFirestoreValue(val) {
  if (val === null || val === undefined) return { nullValue: null };
  if (typeof val === 'boolean') return { booleanValue: val };
  if (typeof val === 'number')  return Number.isInteger(val) ? { integerValue: String(val) } : { doubleValue: val };
  if (typeof val === 'string') {
    if (/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/.test(val)) return { timestampValue: val };
    return { stringValue: val };
  }
  if (Array.isArray(val)) return { arrayValue: { values: val.map(toFirestoreValue) } };
  if (typeof val === 'object') return { mapValue: { fields: toFirestoreFields(val) } };
  return { stringValue: String(val) };
}

function toFirestoreFields(obj) {
  const fields = {};
  for (const [k, v] of Object.entries(obj)) {
    if (v !== undefined && v !== null) fields[k] = toFirestoreValue(v);
  }
  return fields;
}

const sleep = ms => new Promise(r => setTimeout(r, ms));
const ago   = n  => new Date(Date.now() - n * 86400000).toISOString();

async function wakeService(url, label, isFacilityBackend = false) {
  const client = axios.create({ baseURL: url, timeout: 30000 });
  process.stdout.write(`  ⏳ Waking ${label}`);

  let healthData = null;
  for (let i = 0; i < 15; i++) {
    try {
      const r = await client.get('/health');
      if (r.data?.status === 'ok') { healthData = r.data; break; }
    } catch (_) {}
    process.stdout.write('.');
    await sleep(8000);
  }
  if (!healthData) { console.log(' ❌ unreachable'); return false; }

  // For facility backends: keep polling /api/patients until Express returns JSON not HTML
  if (isFacilityBackend) {
    for (let i = 0; i < 10; i++) {
      try {
        const r = await client.get('/api/patients/search/nupi?nationalId=test&dob=2000-01-01');
        if (typeof r.data === 'object') break;
      } catch (err) {
        if (err.response && typeof err.response.data === 'object') break;
      }
      process.stdout.write('.');
      await sleep(5000);
    }
    console.log(' ✅ ready');
    const fid = healthData.facilityId || '';
    if (fid) console.log(`     ℹ️  facilityId: ${fid}  gateway: ${healthData.gateway || ''}`);
    else     console.log('     ⚠️  FACILITY_ID not set in Render env vars!');
  } else {
    console.log(' ✅ ready');
  }
  return true;
}

async function getFirebaseConfig(facilityId, apiKey) {
  const res = await axios.get(`${GATEWAY}/api/facilities/${facilityId}/firebase-config`, { 
    headers: { 'X-Api-Key': apiKey } 
  });
  if (!res.data.success) throw new Error(res.data.error);
  return res.data.firebaseConfig;
}

async function getFirebaseIdToken(fbApiKey) {
  const res = await axios.post(`https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${fbApiKey}`, 
    { returnSecureToken: true }
  );
  return res.data.idToken;
}

async function writeFirestoreDoc(projectId, collection, docId, data, idToken) {
  const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/${collection}/${docId}`;
  await axios.patch(url, { fields: toFirestoreFields(data) }, {
    headers: { Authorization: `Bearer ${idToken}` },
    params:  { 'updateMask.fieldPaths': Object.keys(data) },
  });
}

async function seedFacility(fac) {
  console.log(`\n${'═'.repeat(60)}\n  ${fac.label}  (${fac.id})\n${'═'.repeat(60)}\n`);

  let firebaseConfig, idToken;
  process.stdout.write('  ⏳ Fetching Firebase config from gateway...');
  try {
    firebaseConfig = await getFirebaseConfig(fac.id, fac.apiKey);
    console.log(` ✅ project: ${firebaseConfig.projectId}`);
  } catch (err) {
    console.log(` ❌ ${err.response?.data?.error || err.message}\n     Program enrollments will be SKIPPED.`);
  }

  if (firebaseConfig) {
    process.stdout.write('  ⏳ Signing in anonymously to Firebase...');
    try {
      idToken = await getFirebaseIdToken(firebaseConfig.apiKey);
      console.log(' ✅ ID token obtained');
    } catch (err) {
      const msg = err.response?.data?.error?.message || err.message;
      console.log(` ❌ ${msg}`);
      console.log('     → Enable: Firebase Console → Authentication → Sign-in providers → Anonymous → Enable');
      console.log('     Program enrollments will be SKIPPED.');
    }
  }

  const api   = axios.create({ baseURL: fac.apiUrl, timeout: 90000, headers: { 'Content-Type': 'application/json' } });
  const ready = await wakeService(fac.apiUrl, `${fac.label} backend`, true);
  if (!ready) return;
  console.log();

  for (const p of fac.patients) {
    const fullName = `${p.firstName} ${p.lastName}`;
    console.log(`  ── ${fullName} (${p.nationalId}) ──────────────`);

    // 1. First check if patient exists via search endpoint
    let nupi;
    try {
      const searchRes = await api.get('/api/patients/search/nupi', { 
        params: { nationalId: p.nationalId, dob: p.dob } 
      });
      nupi = searchRes.data?.nupi;
      console.log(`     ✅ Found existing patient — NUPI: ${nupi}`);
    } catch (searchErr) {
      // Patient doesn't exist, register new one
      try {
        const regRes = await api.post('/api/patients', {
          nationalId: p.nationalId, 
          firstName: p.firstName, 
          lastName: p.lastName,
          dateOfBirth: p.dob, 
          gender: p.gender, 
          phoneNumber: p.phone,
          securityQuestion: 'What city were you born in?', 
          securityAnswer: p.secA, 
          pin: '1234',
          address: { 
            county: p.county, 
            subCounty: p.subCounty, 
            ward: p.ward, 
            village: '' 
          },
        });
        nupi = regRes.data?.nupi ?? regRes.data?.patient?.nupi;
        console.log(`     ✅ Registered new patient — NUPI: ${nupi} Block#${regRes.data?.blockIndex ?? '?'}`);
      } catch (regErr) {
        const msg = regErr.response?.data?.error || regErr.message;
        console.log(`     ❌ Registration failed: ${msg}`);
        continue;
      }
    }

    if (!nupi) { console.log('     ❌ No NUPI, skipping\n'); continue; }
    await sleep(800);

    // 2. Encounters
    const encList = ENC[p.program] ?? ENC.malaria;
    for (let i = 0; i < encList.length; i++) {
      const e = encList[i];
      try {
        await api.post(`/api/patients/${nupi}/visit`, {
          encounterType: e.type, 
          encounterDate: ago(e.daysAgo),
          chiefComplaint: e.chief_complaint, 
          practitionerName: e.clinician_name,
          vitalSigns: e.vitals, 
          diagnoses: e.diagnoses,
          notes: e.clinical_notes, 
          treatmentPlan: e.treatment_plan,
        });
        console.log(`     ✅ Encounter ${i+1}: [${e.type}] ${e.chief_complaint.slice(0,45)}...`);
      } catch (err) {
        console.log(`     ⚠️  Encounter ${i+1}: ${err.response?.data?.error || err.message}`);
      }
      await sleep(600);
    }

    // 3. Program enrollment → Firestore REST
    if (firebaseConfig && idToken) {
      try {
        const enrollment = makeEnrollment(nupi, fullName, fac.id, p.program);
        await writeFirestoreDoc(firebaseConfig.projectId, 'program_enrollments', enrollment.id, enrollment, idToken);
        console.log(`     ✅ Enrollment: ${p.program} → Firestore`);
      } catch (err) {
        const msg = err.response?.data?.error?.message || err.message;
        if (msg?.includes('UNAUTHENTICATED') || msg?.includes('expired')) {
          try {
            idToken = await getFirebaseIdToken(firebaseConfig.apiKey);
            const enrollment = makeEnrollment(nupi, fullName, fac.id, p.program);
            await writeFirestoreDoc(firebaseConfig.projectId, 'program_enrollments', enrollment.id, enrollment, idToken);
            console.log(`     ✅ Enrollment: ${p.program} → Firestore (token refreshed)`);
          } catch (e2) { console.log(`     ⚠️  Enrollment: ${e2.response?.data?.error?.message || e2.message}`); }
        } else {
          console.log(`     ⚠️  Enrollment: ${msg}`);
        }
      }
    } else {
      console.log('     ⚠️  Enrollment skipped (enable Anonymous auth in Firebase Console)');
    }

    console.log();
    await sleep(400);
  }
}

async function main() {
  console.log('\n╔══════════════════════════════════════════════════╗');
  console.log('║  ClinicConnect Seed — 2 facilities × 10 patients  ║');
  console.log('╚══════════════════════════════════════════════════╝');

  const gatewayUp = await wakeService(GATEWAY, 'HIE Gateway');
  if (!gatewayUp) { console.log('\n❌ Gateway unreachable.'); process.exit(1); }

  for (const fac of FACILITIES) { await seedFacility(fac); await sleep(2000); }

  console.log('\n╔══════════════════════════════════════════════════╗');
  console.log('║  Done!                                            ║');
  console.log('╚══════════════════════════════════════════════════╝\n');
  console.log('🔑 Security question: "What city were you born in?" | PIN: 1234\n');
  console.log('Facility A (Kilifi):');
  PATIENTS_A.forEach(p => console.log(`  ${p.nationalId}  ${(p.firstName+' '+p.lastName).padEnd(18)}  DOB:${p.dob}  ans:"${p.secA}"  prog:${p.program}`));
  console.log('\nFacility B (Nyahururu):');
  PATIENTS_B.forEach(p => console.log(`  ${p.nationalId}  ${(p.firstName+' '+p.lastName).padEnd(18)}  DOB:${p.dob}  ans:"${p.secA}"  prog:${p.program}`));
}

main().catch(err => { console.error('Fatal:', err.message); process.exit(1); });