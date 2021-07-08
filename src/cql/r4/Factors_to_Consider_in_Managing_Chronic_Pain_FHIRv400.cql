// # Introduction

// The Pain Management Summary artifact provides relevant information to consider when managing a patient’s pain.
// This CDS logic was informed by the Centers for Disease Control and Prevention (CDC) Guideline for Opioid Prescribing
// for Chronic Pain. The CDS is not a direct representation of any one recommendation statement within the guideline.
// Instead, the CDS compiles clinical concepts mentioned throughout the guideline in one consolidated summary for
// clinician review.
//
// In the process of authoring the logic, certain assumptions were made and details developed when the guideline did
// not provide enough specificity.  These decisions were made in the context of the CDS Connect Workgroup and CDC
// stakeholders, and are documented in the logic and/or in the CDS Connect artifact metadata.
//
// NOTE: This is a FHIR R4 port of the original FHIR DSTU2 CQL piloted for CDS Connect.  In addition to the changes
// to support FHIR R4, it contains the following additional changes from the artifact that was piloted:
// - Added the following value sets for identifying Risk Factors for Opiod-Related Harms (in addition to existing ones)
//   - Depression Diagnosis ICD9 (2.16.840.1.113883.3.600.143)
//   - Anxiety Disorders ICD9 (2.16.840.1.113883.3.1240.2017.3.2.1015)
//   - Substance Abuse (2.16.840.1.113883.3.464.1003.106.11.1010)
//   - Pregnancy (New ICD10 codes published in 2018 and 2019)": '2.16.840.1.113762.1.4.1032.80'
// - Changed the Suicide Attempt value set to 2.16.840.1.113762.1.4.1032.102
// - Removed specific inclusion of SNOMED-CT 86849004 since it is now in the Suicide Attempt value set
// - Updated QuantityText logic to not include '{score}' units (since scalar number is enough in those cases)
//
// ##Source guideline 1: [CDC Guideline for Opioid Prescribing for Chronic Pain](https://www.cdc.gov/drugoverdose/prescribing/guideline.html)
// ##Source guideline 2: [Washington State Prescribing Rules](

// Update 20200224
//    Removed inclusion criteria excepting age 18
//    Added opioid overdose for ICD-10 and SNOMED
//    Changed lookback for opioids, non-opioids, and benzos from 2 to 100 years
// Update 20200227
//    Added carisoprodol as another risk factor for co-prescribing with opioids
//    Also removed an old superfluous function
// Update 20200819
//    Updated to include MME Calculation
// Update 20200904
//    Code cleaning
// Update 20210628
//    use Last Fill date as the Start Date for MME value calculation, it was using authored date

library Factors_to_Consider_in_Managing_Chronic_Pain_FHIRv400 version '1.0.0'



// # Data model #

// FHIR Version
using FHIR version '4.0.0'



// # Referenced libraries #

// The CDS Connect Commons for FHIRv400 library provides functions representing commonly used CDS logic and patterns.
include CDS_Connect_Commons_for_FHIRv400 version '1.0.1' called C3F
// The FHIRHelpers library provides common functions for simplifying interaction w/ the FHIR R4 data model.
include FHIRHelpers version '4.0.0' called FHIRHelpers
// The MMECalculator library is used to compute the patient's MME/MED
include MMECalculator version '3.0.0' called MMECalculator



// # Value sets and codes #

// ## Code Systems ##
codesystem "LOINC": 'http://loinc.org'
codesystem "SNOMED-CT": 'http://snomed.info/sct'


// ## Value sets ##
// List value sets used by the artifact. The links to the Value Set Authority Center (VSAC) point to the latest
// expansion of each value set available.

// [See value set in VSAC](https://vsac.nlm.nih.gov/valueset/2.16.840.1.113762.1.4.1032.37/expansion)
valueset "Conditions associated with chronic pain": '2.16.840.1.113762.1.4.1032.37'

// [See value set in VSAC](https://vsac.nlm.nih.gov/valueset/2.16.840.1.113762.1.4.1032.34/expansion)
valueset "Opioid Pain Medications": '2.16.840.1.113762.1.4.1032.34'

// [See value set in VSAC](https://vsac.nlm.nih.gov/valueset/2.16.840.1.113762.1.4.1032.54/expansion)
valueset "Adjuvant Analgesic Medications": '2.16.840.1.113762.1.4.1032.54'

// [See value set in VSAC](https://vsac.nlm.nih.gov/valueset/2.16.840.1.113883.3.464.1003.105.12.1007/expansion)
valueset "Major Depression": '2.16.840.1.113883.3.464.1003.105.12.1007'

// [See value set in VSAC](https://vsac.nlm.nih.gov/valueset/2.16.840.1.113883.3.600.143/expansion)
valueset "Depression Diagnosis ICD9": '2.16.840.1.113883.3.600.143'

// [See value set in VSAC](https://vsac.nlm.nih.gov/valueset/2.16.840.1.113762.1.4.1032.52/expansion)
valueset "Anxiety": '2.16.840.1.113762.1.4.1032.52'

// [See value set in VSAC](https://vsac.nlm.nih.gov/valueset/2.16.840.1.113883.3.1240.2017.3.2.1015/expansion)
valueset "Anxiety Disorders ICD9": '2.16.840.1.113883.3.1240.2017.3.2.1015'

// [See value set in VSAC](https://vsac.nlm.nih.gov/valueset/2.16.840.1.113883.3.464.1003.106.12.1004/expansion)
valueset "Substance use disorder": '2.16.840.1.113883.3.464.1003.106.12.1004'

// [See value set in VSAC](https://vsac.nlm.nih.gov/valueset/2.16.840.1.113883.3.464.1003.106.11.1010/expansion)
valueset "Substance Abuse": '2.16.840.1.113883.3.464.1003.106.11.1010'

// [See value set in VSAC](https://vsac.nlm.nih.gov/valueset/2.16.840.1.113762.1.4.1146.1008/expansion)
valueset "Opioid overdose and poisoning (ICD10CM)": '2.16.840.1.113762.1.4.1146.1008'

// [See value set in VSAC](https://vsac.nlm.nih.gov/valueset/2.16.840.1.113762.1.4.1146.1063/expansion)
valueset "Opioid overdose and poisoning (SNOMED)": '2.16.840.1.113762.1.4.1146.1063'

// [See value set in VSAC](https://vsac.nlm.nih.gov/valueset/2.16.840.1.113762.1.4.1032.102/expansion)
valueset "Suicide Attempt": '2.16.840.1.113762.1.4.1032.102'

// [See value set in VSAC](https://vsac.nlm.nih.gov/valueset/2.16.840.1.113762.1.4.1032.53/expansion)
valueset "Sleep-disordered breathing": '2.16.840.1.113762.1.4.1032.53'

// [See value set in VSAC](https://vsac.nlm.nih.gov/valueset/2.16.840.1.113883.3.464.1003.109.12.1028/expansion)
valueset "Kidney Failure": '2.16.840.1.113883.3.464.1003.109.12.1028'

// [See value set in VSAC](https://vsac.nlm.nih.gov/valueset/2.16.840.1.113883.3.464.1003.199.12.1035/expansion)
valueset "Chronic Liver Disease": '2.16.840.1.113883.3.464.1003.199.12.1035'

// [See value set in VSAC](https://vsac.nlm.nih.gov/valueset/2.16.840.1.113762.1.4.1047.42/expansion)
valueset "Liver Disease": '2.16.840.1.113762.1.4.1047.42'

// [See value set in VSAC](https://vsac.nlm.nih.gov/valueset/2.16.840.1.113883.3.526.3.378/expansion)
valueset "Pregnancy": '2.16.840.1.113883.3.526.3.378'

// [See value set in VSAC](https://vsac.nlm.nih.gov/valueset/2.16.840.1.113762.1.4.1032.80/expansion)
valueset "Pregnancy (New ICD10 codes published in 2018 and 2019)": '2.16.840.1.113762.1.4.1032.80'

// [See value set in VSAC](https://vsac.nlm.nih.gov/valueset/2.16.840.1.113762.1.4.1032.26/expansion)
valueset "Non opiod pain medications": '2.16.840.1.113762.1.4.1032.26'

// [See value set in VSAC](https://vsac.nlm.nih.gov/valueset/2.16.840.1.113762.1.4.1032.36/expansion)
valueset "Non pharmacologic treatments for chronic pain": '2.16.840.1.113762.1.4.1032.36'

// [See value set in VSAC](https://vsac.nlm.nih.gov/valueset/2.16.840.1.113762.1.4.1032.55/expansion)
valueset "Risk assessments relevant to pain management": '2.16.840.1.113762.1.4.1032.55'

// [See value set in VSAC](https://vsac.nlm.nih.gov/valueset/2.16.840.1.113762.1.4.1032.43/expansion)
valueset "Benzodiazepine medications": '2.16.840.1.113762.1.4.1032.43'

// [See value set in VSAC](https://vsac.nlm.nih.gov/valueset/2.16.840.1.113883.3.464.1003.196.11.1152/expansion)
valueset "Carisoprodol": '2.16.840.1.113883.3.464.1003.196.11.1152'

// [See value set in VSAC](https://vsac.nlm.nih.gov/valueset/2.16.840.1.113883.3.464.1003.196.11.1314/expansion)
valueset "Aspirin / Carisoprodol": '2.16.840.1.113883.3.464.1003.196.11.1314'

// [See value set in VSAC](https://vsac.nlm.nih.gov/valueset/2.16.840.1.113762.1.4.1032.42/expansion)
valueset "Naloxone medications": '2.16.840.1.113762.1.4.1032.42'

// [See value set in VSAC](https://vsac.nlm.nih.gov/valueset/2.16.840.1.113762.1.4.1032.28/expansion)
valueset "Urine drug screen for pain management": '2.16.840.1.113762.1.4.1032.28'

// [See value set in VSAC](https://vsac.nlm.nih.gov/valueset/2.16.840.1.113762.1.4.1032.44/expansion)
valueset "Stool softeners and laxatives": '2.16.840.1.113762.1.4.1032.44'


// ## Individual codes ##
// List of individual codes from code systems used directly in the CQL logic. Individual codes are used when there is
// a single code from a particular vocabulary standard used to represent a clinical concept. It is considered
// best-practice not to create value sets containing a single code.
code "Pregnancy status code": '82810-3' from "LOINC" display 'Pregnancy status'
code "Pregnant code": '77386006' from "SNOMED-CT" display 'Patient currently pregnant (finding)'


// CQL currently requires concept declarations to contain references to code declarations.
concept "Pregnancy status": { "Pregnancy status code" } display 'Pregnancy status'
concept "Pregnant": { "Pregnant code" } display 'Patient currently pregnant (finding)'



// # Parameters #

// The InclusionMedicationsLookbackPeriod allows CDS implementors to specify how far the inclusion logic should look
// back for qualifying active medications. By default, the inclusion logic will look back 180 days.
parameter InclusionMedicationsLookbackPeriod default 180 days //DO WE NEED THIS?

//system url from PDMP identifier
define PDMP_SYSTEM_VALUE: 'https://github.com/uwcirg/script-fhir-facade/'



// # CDS logic #
context Patient


// ## Re-usable functions ##

// The summary logic contains many constructs that are needed throughout the logic. Where possible, these constructs
// have been developed as re-usable functions that can be invoked wherever they are needed.

// Returns the first-found display text for a CodeableConcept, looking first at the `text` attribute, then the
// `display` on each `coding` until it finds a non-null value.  Some PEG codes are normalized due to length.
// @param c - a FHIR CodeableConcept to get text from
// @returns {System.String} the display text or null if none is found
define function ConceptText(c FHIR.CodeableConcept):
    Coalesce(c.text.value, Coalesce((c.coding) c2 return c2.display.value))

// Returns a text representation of a date using the CQL `ToString` function.
// @param d - a FHIR date to get text for
// @returns {System.String} the text representation of the date
define function DateText(d FHIR.date):
  ToString(d.value)

// Returns a text representation of a dateTime using the CQL `ToString` function.
// @param d - a FHIR dateTime to get text for
// @returns {System.String} the text representation of the dateTime
define function DateTimeText(d FHIR.dateTime):
  ToString(d.value)

// Returns a text representation of an instant using the CQL `ToString` function.
// @param i - a FHIR instant to get text for
// @returns {System.String} the text representation of the instant
define function InstantText(i FHIR.instant):
  ToString(i.value)

// Returns a text representation of a Quantity with the Quantity's value and unit.
// If the unit is {score}, then omit it (as it is not useful to display)
// @param q - a FHIR Quantity to get text for
// @returns {System.String} the text representation of the Quantity
define function QuantityText(q FHIR.Quantity):
  if (q is null) then null
  else if (q.unit is not null and q.unit.value != '{score}') then ToString(q.value.value) + ' ' + q.unit.value
  else if (q.code is not null and q.code.value != '{score}') then ToString(q.value.value) + ' ' + q.code.value
  else ToString(q.value.value)

// Returns a tuple containing a Period's start and end as text representations.
// @param p - a FHIR Period to get a tuple for
// @returns {Tuple<Start System.String, End System.String>} the tuple representation of the Period
define function PeriodObject(p FHIR.Period):
  if p is null then null
  else
    {
      Start: DateTimeText(p."start"),
      End: DateTimeText(p."end")
    }

// Returns a tuple containing a Range's low and high as text representations.
// @param r - a FHIR Range to get a tuple for
// @returns {Tuple<Low System.String, High System.String>} the tuple representation of the Range
define function RangeObject(r FHIR.Range):
  if r is null then null
  else
    {
      Low: QuantityText(r.low),
      High: QuantityText(r.high)
    }

// Returns a text representation of a date associated with an Observation, preferring `effectiveDateTime`, then
// `effectivePeriod.start`, then `issued`.
// @param o - a FHIR Observation to get the text date from
// @returns {System.String} the text representation of a relevant date from the Observation
define function ObservationDate(o FHIR.Observation):
  Coalesce(
    DateTimeText(o.effective as FHIR.dateTime),
    InstantText(o.effective as FHIR.instant),
    DateTimeText((o.effective as FHIR.Period)."start"),
    InstantText(o.issued)
  )

// Returns a text representation of a date associated with a MedicationStatement, preferring `effectiveDateTime`, then
// `.start`.
// @param s - a FHIR MedicationStatement to get the text date from
// @returns {System.String} the text representation of a relevant date from the MedicationStatement
define function MedicationStatementDate(s FHIR.MedicationStatement):
  Coalesce(
    DateTimeText(s.effective as FHIR.dateTime),
    DateTimeText((s.effective as FHIR.Period)."start")
  )

// Returns a text representation of a Condition's onset, whether represented as a dateTime, Period, Quantity (Age),
// Range (Age), or string.
// @param c - a FHIR Condition to get the text representation of the onset from
// @returns {System.String} the text representation of the Condition's onset
define function Onset(c FHIR.Condition):
  Coalesce( List{
    DateTimeText(c.onset as FHIR.dateTime),
    QuantityText(c.onset as FHIR.Age),
    PeriodObject(c.onset as FHIR.Period),
    RangeObject(c.onset as FHIR.Range),
    (c.onset as FHIR.string).value
  })

// Returns a text representation of a Condition's abatement, whether represented as a dateTime, Period, Quantity (Age),
// Range (Age), string, or boolean.
// @param c - a FHIR Condition to get the text representation of the abatement from
// @returns {System.String} the text representation of the Condition's abatement
define function Abatement(c FHIR.Condition):
  Coalesce( List{
    DateTimeText(c.abatement as FHIR.dateTime),
    QuantityText(c.abatement as FHIR.Age),
    PeriodObject(c.abatement as FHIR.Period),
    RangeObject(c.abatement as FHIR.Range),
    (c.abatement as FHIR.string).value
  })


// Return dispensed quantity
// @param MedicationRequest FHIR object
define function GetMedicationRequestDispensedQuantity(medRequest MedicationRequest):
  (medRequest) O
  let
    dispenseRequest: O.dispenseRequest,
    dispensedQuantity: if dispenseRequest is not null then dispenseRequest.quantity.value.value else null
    return dispensedQuantity


// Return pharmacy name
// @param MedicationRequest FHIR object
define function GetMedicationRequestPharmacy(medRequest MedicationRequest):
  (medRequest) O
  let
    //pharmacy is from extension
    pharmacyExtension: O.dispenseRequest.extension[0],
    pharmacy: if pharmacyExtension is not null then (pharmacyExtension.value as FHIR.string).value else null
    return pharmacy

// Returns the predicted last date for the prescription, based on the supply duration and quantity
// @param MedicationRequest FHIR object
define function GetMedicationRequestEndDate(medRequest MedicationRequest):
  (medRequest) O
   let
    CalculatedDuration:
      if O.dispenseRequest.expectedSupplyDuration is not null
      then  O.dispenseRequest.expectedSupplyDuration.value.value
      else 0,
    CalculatedDurationUnit:
      if O.dispenseRequest.expectedSupplyDuration is not null
      then  O.dispenseRequest.expectedSupplyDuration.unit.value
      else 'days',
    Start: GetMedicationRequestStartDate(O),
    CalculatedStart: if Start is not null then Start else O.authoredOn
    return date from ToDate(CalculatedStart + System.Quantity {value: CalculatedDuration, unit: CalculatedDurationUnit})

// Return dispensed date or last fill date for a medication
// @param MedicationRequest FHIR object
define function GetMedicationRequestDispensedDate(medRequest MedicationRequest):
  (medRequest) O
  let
    //last fill date is from extension
    LastFillExtension: O.dispenseRequest.extension[1],
    Start: if LastFillExtension is not null then (LastFillExtension.value as FHIR.dateTime) else null
    return Start


// Returns the start date for a medication
// @param MedicationRequest FHIR object
define function GetMedicationRequestStartDate(medRequest MedicationRequest):
  (medRequest) O
  let
    LastFillDate: GetMedicationRequestDispensedDate(O),
    Start: if LastFillDate is not null then LastFillDate else O.authoredOn
    return Start


// ## Target population ##

// INCLUSIONS
// Determines if patient's age, in years, at the time CQL is run, is at least 18 years old
define Is18orOlder:
  AgeInYears() >= 18

// Determines if the patient meets the inclusion criteria for the CDS. Inclusion criteria is:
// - Age >=18 years
define MeetsInclusionCriteria:
  Is18orOlder


// EXCLUSIONS
// TAKE NOTICE: This CDS is not intended for patients who meet any of the following criteria:
// 1. Younger than 18 years of age
// 2. Undergoing end-of-life care (hospice or palliative)
// 3. Undergoing active cancer treatment

// The first exclusion is explicitly accounted for under INCLUSIONS.
// The second and third exclusions cannot be realiably detected for all patients using just EHR data. For that reason
// they are not implemented in this CDS. Care providers should use their judgement when applying this CDS to their
// patients.



// # Intervention(s) #
// DISPLAY and POPULATE a Pain Management Summary of the following items:


// PERTINENT MEDICAL HISTORY

// Conditions associated with chronic pain
define ConditionsAssociatedWithChronicPain:
  C3F.Confirmed(C3F.ActiveOrRecurring([Condition: "Conditions associated with chronic pain"]))

// Conditions associated with chronic pain and their dates of onset
define ReportConditionsAssociatedWithChronicPain:
  (ConditionsAssociatedWithChronicPain) C
  return {
    Name:   ConceptText(C.code),
    Status: C.clinicalStatus.coding[0].code.value,
    Onset:  Onset(C),
    DateRecorded: DateTimeText(C.recordedDate)
  }
  sort by (Onset as String) desc


// Conditions that are risk factors for opioid-related harms and their dates of onset
// This is a union of nine value sets (w/ different filtering criteria)
define DepressionConditions:
  C3F.Confirmed(C3F.ActiveOrRecurring([Condition: "Major Depression"]))
  union C3F.Confirmed(C3F.ActiveOrRecurring([Condition: "Depression Diagnosis ICD9"]))

define AnxietyConditions:
  C3F.Confirmed(C3F.ActiveOrRecurring([Condition: "Anxiety"]))
  union C3F.Confirmed(C3F.ActiveOrRecurring([Condition: "Anxiety Disorders ICD9"]))

define SubstanceUseDisorderConditions:
  C3F.Confirmed([Condition: "Substance use disorder"])
  union C3F.Confirmed([Condition: "Substance Abuse"])

define OpioidOverdoseAndPoisoningConditions:
  C3F.Confirmed([Condition: "Opioid overdose and poisoning (ICD10CM)"])
  union C3F.Confirmed([Condition: "Opioid overdose and poisoning (SNOMED)"])

define SuicideAttemptConditions:
  C3F.Confirmed([Condition: "Suicide Attempt"])

define SleepDisorderedBreathingConditions:
  C3F.Confirmed(C3F.ActiveOrRecurring([Condition: "Sleep-disordered breathing"]))

define RenalDysfunctionConditions:
  C3F.Confirmed(C3F.ActiveOrRecurring([Condition: "Kidney Failure"]))

define HepaticDysfunctionConditions:
  C3F.Confirmed(C3F.ActiveOrRecurring([Condition: "Chronic Liver Disease"]))
  union C3F.Confirmed(C3F.ActiveOrRecurring([Condition: "Liver Disease"]))

define PregnancyConditions:
  C3F.Confirmed(C3F.ConditionLookBack(C3F.ActiveOrRecurring(
    [Condition: "Pregnancy"])
      union [Condition: "Pregnancy (New ICD10 codes published in 2018 and 2019)"],
    42 weeks
  ))

define PregnancyObservations:
  C3F.Verified(C3F.ObservationLookBack([Observation: "Pregnancy status"], 42 weeks))

define MostRecentPregnancyObservation:
  C3F.MostRecent(PregnancyObservations)

define MostRecentPregnancyObservationIsPositive:
  C3F.ConceptValue(MostRecentPregnancyObservation) ~ "Pregnant"

define Is65orOlder:
  AgeInYears() >= 65

define ConditionRiskFactorsForOpioidRelatedHarms:
  DepressionConditions
  union AnxietyConditions
  union SubstanceUseDisorderConditions
  union OpioidOverdoseAndPoisoningConditions
  union SuicideAttemptConditions
  union SleepDisorderedBreathingConditions
  union RenalDysfunctionConditions
  union HepaticDysfunctionConditions
  union PregnancyConditions


// Encounter diagnoses that are risk factors for opioid-related harms and their dates of onset. Some risk factors may
// not exist on the problem list, and therefore may not be represented as Conditions (depending on EHR implementation).
// For this, the logic also looks at the patient's encounters, trying to find risk factors recorded as encounter
// diagnosis codes. We do not look at the reasonReference field because the Conditions referred to would already be
// reflected in the expression that queries over Conditions.
define EncounterRiskFactorsForOpioidRelatedHarms:
  [Encounter] E where exists(
    E.reasonCode R where
      FHIRHelpers.ToConcept(R) in "Major Depression"
      or FHIRHelpers.ToConcept(R) in "Depression Diagnosis ICD9"
      or FHIRHelpers.ToConcept(R) in "Anxiety"
      or FHIRHelpers.ToConcept(R) in "Anxiety Disorders ICD9"
      or FHIRHelpers.ToConcept(R) in "Substance use disorder"
      or FHIRHelpers.ToConcept(R) in "Substance Abuse"
      or FHIRHelpers.ToConcept(R) in "Opioid overdose and poisoning (ICD10CM)"
      or FHIRHelpers.ToConcept(R) in "Opioid overdose and poisoning (SNOMED)"
      or FHIRHelpers.ToConcept(R) in "Suicide Attempt"
      or FHIRHelpers.ToConcept(R) in "Sleep-disordered breathing"
      or FHIRHelpers.ToConcept(R) in "Kidney Failure"
      or FHIRHelpers.ToConcept(R) in "Chronic Liver Disease"
      or FHIRHelpers.ToConcept(R) in "Liver Disease"
      // Pregnancy not considered in Encounter diagnoses because this is an unrestricted lookback.
  )


// NOTE: As a convention, if an expression's name starts with "Report", its purpose is to format data for the purpose
// of building the final summary object.

// Format the risk factors in a uniform way despite the different sources of the data (conditions, encounter diagnoses,
// etc.). Note that conditions do not have a "Visit" date and encounter diagnoses do not have a status, onset date,
// recorded date, or abatement date.

define ReportConditionRiskFactorsForOpioidRelatedHarms:
  (ConditionRiskFactorsForOpioidRelatedHarms) C
  return {
    Name:      ConceptText(C.code),
    Status:    C.clinicalStatus.coding[0].code.value,
    Onset:     Onset(C),
    DateRecorded: DateTimeText(C.recordedDate),
    Abatement: Abatement(C),
    Visit:     null as Tuple{ Start String, End String }
  }
  sort by (Onset as String) desc, (Abatement as String) desc

define function GetEncounterDiagnosesRiskFactorsForOpioidRelatedHarms(enc Encounter):
  (enc.reasonCode) R
    where FHIRHelpers.ToConcept(R) in "Major Depression"
      or FHIRHelpers.ToConcept(R) in "Depression Diagnosis ICD9"
      or FHIRHelpers.ToConcept(R) in "Anxiety"
      or FHIRHelpers.ToConcept(R) in "Anxiety Disorders ICD9"
      or FHIRHelpers.ToConcept(R) in "Substance use disorder"
      or FHIRHelpers.ToConcept(R) in "Substance Abuse"
      or FHIRHelpers.ToConcept(R) in "Opioid overdose and poisoning (ICD10CM)"
      or FHIRHelpers.ToConcept(R) in "Opioid overdose and poisoning (SNOMED)"
      or FHIRHelpers.ToConcept(R) in "Suicide Attempt"
      or FHIRHelpers.ToConcept(R) in "Sleep-disordered breathing"
      or FHIRHelpers.ToConcept(R) in "Kidney Failure"
      or FHIRHelpers.ToConcept(R) in "Chronic Liver Disease"
      or FHIRHelpers.ToConcept(R) in "Liver Disease"
      // Pregnancy not considered in Encounter diagnoses because this is an unrestricted lookback.
    return {
      Name:      ConceptText(R),
      Status:    null as String,
      Onset:     null as String,
      DateRecorded: null as String,
      Abatement: null as String,
      Visit:     PeriodObject(enc.period)
    }

define ReportEncounterRiskFactorsForOpioidRelatedHarms:
  (flatten((EncounterRiskFactorsForOpioidRelatedHarms) E
  return GetEncounterDiagnosesRiskFactorsForOpioidRelatedHarms(E))) D
  sort by Visit.Start desc, Visit.End desc

// Shape the pregnancy Observation as a Condition, since this is the backup approach for detecting a pregnancy in case
// there are no active Conditions found.
define ReportMostRecentPositivePregnancyObservation:
{
  if MostRecentPregnancyObservationIsPositive then
    {
      Name: ConceptText(MostRecentPregnancyObservation.code),
      Status: ConceptText(MostRecentPregnancyObservation.value as FHIR.CodeableConcept),
      Onset: ToString(Coalesce(
        (MostRecentPregnancyObservation.effective as FHIR.dateTime).value,
        (MostRecentPregnancyObservation.effective as FHIR.instant).value,
        (MostRecentPregnancyObservation.effective as FHIR.Period)."start".value
      )),
      DateRecorded: ToString(MostRecentPregnancyObservation.issued.value),
      Abatement: null as String,
      Visit: null as Tuple{ Start String, End String }
    }
  else
    null
}

// Shape the case of being 65 or older as a Condition for the purposes of building the summary.
define ReportOlderThan65:
{
  if Is65orOlder then
    {
      Name: '65 years or older',
      Status: 'active',
      Onset: null as String,
      DateRecorded: null as String,
      Abatement: null as String,
      Visit: null as Tuple{ Start String, End String }
    }
  else
    null
}

define ReportRiskFactorsForOpioidRelatedHarms:
  // If a pregnancy Condition is present, use that.
  if Exists(PregnancyConditions) then
    (ReportConditionRiskFactorsForOpioidRelatedHarms
      union ReportEncounterRiskFactorsForOpioidRelatedHarms
      union ReportOlderThan65) C
  // Otherwise, try to find a positive pregnancy status in an Observation.
  else
    (ReportConditionRiskFactorsForOpioidRelatedHarms
      union ReportEncounterRiskFactorsForOpioidRelatedHarms
      union ReportOlderThan65
      union ReportMostRecentPositivePregnancyObservation) C
  sort by (if Onset is not null then Onset as String else Visit.Start) desc, Visit.End desc, (Abatement as String) desc





// HISTORICAL TREATMENTS

// Opioid medication orders and statements with dates
define OpioidMedicationRequests:
  C3F.MedicationRequestLookBack(
    [MedicationRequest: "Opioid Pain Medications"], //remove consideration for the status field
    100 years
  )

define OpioidMedicationStatements:
  C3F.MedicationStatementLookBack(
    [MedicationStatement: "Opioid Pain Medications"],
    100 years
  )

define ReportOpioidMedicationRequests:
  ( OpioidMedicationRequests M
    where not(M.identifier is not null and M.identifier[0].system ~ PDMP_SYSTEM_VALUE)
  ) O
  let CalculatedEnd: GetMedicationRequestEndDate(O)
  return {
    Type:  'Request',
    Name:  ConceptText(O.medication as FHIR.CodeableConcept),
    Start: DateTimeText(O.authoredOn),
    DispensedDate: DateTimeText(GetMedicationRequestDispensedDate(O)),
    //provided by the extension dateValue, may not always be there
    CalculatedEnd: CalculatedEnd, //of type datetime
    End: ToString(CalculatedEnd), //of type string
    Quantity: GetMedicationRequestDispensedQuantity(O),
    Prescriber: O.requester.display.value,
    Pharmacy: GetMedicationRequestPharmacy(O),
    Status: O.status.value,
    dispenseExtension: O.dispenseRequest.extension
  }
  sort by Start desc, End desc

define ReportOpioidMedicationStatements:
  (OpioidMedicationStatements) S
  return {
    Type:  'Statement',
    Name:  ConceptText(S.medication as FHIR.CodeableConcept),
    Start: MedicationStatementDate(S),
    End:   DateTimeText((S.effective as FHIR.Period)."end"),
    Status: S.status.value
  }
  sort by Start desc, End desc

define ReportOpioidMedications:
  (ReportOpioidMedicationRequests union ReportOpioidMedicationStatements) M
  sort by Start desc, End desc


// medication requests from PDMP
// using relevant system identifier for filtering
define PDMPMedicationRequests:
  [MedicationRequest] M
  where M.identifier is not null and M.identifier[0].system ~ PDMP_SYSTEM_VALUE

define ReportPDMPMedicationRequests:
  (PDMPMedicationRequests) O
  let
    CalculatedEnd: GetMedicationRequestEndDate(O),
    dispenseRequest:  O.dispenseRequest,
    MME_Object: MMECalculator.MME(O)
    return {
      Type:  'Request',
      Name:  ConceptText(O.medication as FHIR.CodeableConcept),
      Start: DateTimeText(O.authoredOn),
      DispensedDate: DateTimeText(GetMedicationRequestDispensedDate(O)),
      CalculatedEnd: CalculatedEnd, //of datetime type
      End: ToString(CalculatedEnd), //of string type
      Quantity: GetMedicationRequestDispensedQuantity(O),
      Duration: if dispenseRequest.expectedSupplyDuration is not null then dispenseRequest.expectedSupplyDuration.value.value else null,
      MME: MME_Object[0].mme.value,
      Prescriber: O.requester.display.value,
      Pharmacy: GetMedicationRequestPharmacy(O),
      Status: O.status.value
    }
    sort by DispensedDate desc, End desc


// Non-opioid medication orders and statements with dates (lookback 2 years)
define NonOpioidMedicationRequests:
  C3F.MedicationRequestLookBack(
    [MedicationRequest: "Non opiod pain medications"], //remove consideration for the status field
    100 years
  )

define NonOpioidMedicationStatements:
  C3F.MedicationStatementLookBack(
    [MedicationStatement: "Non opiod pain medications"], //remove consideration for the status field
    100 years
  )

define ReportNonOpioidMedicationRequests:
  (NonOpioidMedicationRequests) O
  let CalculatedEnd: GetMedicationRequestEndDate(O)
  return {
    Type:  'Request',
    Name:  ConceptText(O.medication as FHIR.CodeableConcept),
    Start: DateTimeText(O.authoredOn),
    DispensedDate: DateTimeText(GetMedicationRequestDispensedDate(O)),
    CalculatedEnd: CalculatedEnd,
    End: ToString(CalculatedEnd),
    Quantity: GetMedicationRequestDispensedQuantity(O),
    Prescriber: O.requester.display.value,
    Pharmacy: GetMedicationRequestPharmacy(O),
    Status: O.status.value
  }
  sort by Start desc, End desc

define ReportNonOpioidMedicationStatements:
  (NonOpioidMedicationStatements) S
  return {
    Type:  'Statement',
    Name:  ConceptText(S.medication as FHIR.CodeableConcept),
    Start: MedicationStatementDate(S),
    End:   DateTimeText((S.effective as FHIR.Period)."end"),
    //Quantity: QuantityText(S.value as FHIR.Quantity),
    Status: S.status.value
  }
  sort by Start desc, End desc

define ReportNonOpioidMedications:
  (ReportNonOpioidMedicationRequests union ReportNonOpioidMedicationStatements) M
  sort by Start desc, End desc


// Non-pharmacologic treatments, orders, and referrals with dates (lookback 2 years)
define NonPharmacologicTreatmentProcedures:
  C3F.ProcedurePerformance(C3F.ProcedureLookBack([Procedure: "Non pharmacologic treatments for chronic pain"], 2 years))

define ReportNonPharmacologicTreatmentProcedures:
  (NonPharmacologicTreatmentProcedures) P
  return {
    Type: 'Procedure',
    Name: ConceptText(P.code),
    Date: Coalesce(
      DateTimeText(P.performed as FHIR.dateTime),
      DateTimeText((P.performed as FHIR.Period)."start")
    )
  }
  sort by Date desc

define NonPharmacologicTreatmentServiceRequests:
  C3F.ServiceRequestActiveOrCompleted(
    C3F.ServiceRequestLookBack([ServiceRequest: "Non pharmacologic treatments for chronic pain"], 2 years)
  )

define ReportNonPharmacologicTreatmentServiceRequests:
  (NonPharmacologicTreatmentServiceRequests) P
  return {
    Type: 'ServiceRequest',
    Name: ConceptText(P.code),
    Date: DateTimeText(P.authoredOn)
  }
  sort by Date desc

define ReportNonPharmacologicTreatments:
  (ReportNonPharmacologicTreatmentProcedures
    union ReportNonPharmacologicTreatmentServiceRequests) M
  sort by Date desc


// Stool softeners and laxatives - orders and statements with dates (lookback 6 months)
define StoolSoftenersAndLaxativesRequests:
  C3F.MedicationRequestLookBack(
    [MedicationRequest: "Stool softeners and laxatives"], //remove consideration for status field
    6 months
  )

define StoolSoftenersAndLaxativesStatements:
  C3F.MedicationStatementLookBack(
    [MedicationStatement: "Stool softeners and laxatives"], //remove consideration for status field
    6 months
  )

define ReportStoolSoftenersAndLaxativesRequests:
  (StoolSoftenersAndLaxativesRequests) O
  return {
    Type:  'Request',
    Name:  ConceptText(O.medication as FHIR.CodeableConcept),
    Start: DateTimeText(O.authoredOn),
    DispensedDate: DateTimeText(GetMedicationRequestDispensedDate(O)),
    End:   null as String, // MedicationRequest end date not supported in R4,
    Status: O.status.value
  }
  sort by Start desc, End desc

define ReportStoolSoftenersAndLaxativesStatements:
  (StoolSoftenersAndLaxativesStatements) S
  return {
    Type:  'Statement',
    Name:  ConceptText(S.medication as FHIR.CodeableConcept),
    Start: MedicationStatementDate(S),
    End:   DateTimeText((S.effective as FHIR.Period)."end"),
    Status: S.status.value
  }
  sort by Start desc, End desc

define ReportStoolSoftenersAndLaxatives:
  (ReportStoolSoftenersAndLaxativesRequests union ReportStoolSoftenersAndLaxativesStatements) M
  sort by Start desc, End desc



// RISK CONSIDERATIONS

// Helps calculate active medications based on end date rather than 'active' status
define ActiveOpioidMedicationRequestsByEndDate:
  [MedicationRequest: "Opioid Pain Medications"] O
    let CalculatedEnd: GetMedicationRequestEndDate(O)
    where CalculatedEnd same or after Today()

define CurrentMME:
  MMECalculator.TotalMME(ActiveOpioidMedicationRequestsByEndDate)


define ReportCurrentMME:
{
  if CurrentMME is null then
    null
  else
    (CurrentMME) M
    return {
      Name: 'Current Milligram Morephine Equivalent',
      Result: M.value,
      Date: ToString(Today())
    }
}

define ReportMME:
  [MedicationRequest: "Opioid Pain Medications"] O
  let
    MME_Object: MMECalculator.MME(O),
    CalculatedEnd: GetMedicationRequestEndDate(O),
    CalculatedStatus:
      if CalculatedEnd same or after Today() then 'active' else null
  return {
    Type:  'Request',
    Name:  ConceptText(O.medication as FHIR.CodeableConcept),
    CalculatedEnd: CalculatedEnd,
    Written: DateTimeText(O.authoredOn),
    Start: DateTimeText(GetMedicationRequestStartDate(O)),
    End: ToString(CalculatedEnd),
    Status: CalculatedStatus,
    doseQuantity: MME_Object[0].doseQuantity,
    dosesPerDay: MME_Object[0].dosesPerDay,
    strength: MME_Object[0].strength,
    supplyQuantity: MME_Object[0].supplyQuantity,
    supplyDuration: MME_Object[0].supplyDuration,
    factor: MME_Object[0].conversionFactor,
    MMEValue: MME_Object[0].mme.value
  }
  sort by End desc

define MMEDateList:
  (ReportMME) R
  where
    R.End is not null and R.MMEValue is not null and (year from Today() - year from R.CalculatedEnd <= 2)
  return {
    Start: R.Start,
    End: R.End
  }

define ReportMMEByDates:
  MMEDateList R
  return {
    Start: R.Start,
    End: R.End,
    MMEValue: First(ReportMME M where M.Start ~ R.Start return M.MMEValue)
  }
  sort by End

define ReportPrescriptions:
  (OpioidMedicationRequests) M
  return MMECalculator.Prescriptions(M)


// Urine drug screen - dates and results (all screens w/ lookback of 1 year)
define UrineDrugScreens:
  C3F.Verified(C3F.ObservationLookBack([Observation: "Urine drug screen for pain management"], 1 year))

define ReportUrineDrugScreens:
  (UrineDrugScreens) S
  return {
    Name:           ConceptText(S.code),
    Result:         Coalesce(
      QuantityText(S.value as FHIR.Quantity),
      (S.value as FHIR.string).value,
      ConceptText(S.value as FHIR.CodeableConcept)
    ),
    Interpretation: ConceptText(First(S.interpretation)),
    Date:           ObservationDate(S)
  }
  sort by Date desc


// Benzodiazepine Medications (lookback of 2 years)-  orders and statements with dates
define BenzodiazepineMedicationRequests:
  C3F.MedicationRequestLookBack(
    [MedicationRequest: "Benzodiazepine medications"], //remove consideration for status field
    100 years
  )

define BenzodiazepineMedicationStatements:
  C3F.MedicationStatementLookBack(
    [MedicationStatement: "Benzodiazepine medications"], //remove consideration for status field
    100 years
  )

define ReportBenzodiazepineMedicationRequests:
  (BenzodiazepineMedicationRequests) O
  return {
    Type:  'Request',
    Name:  ConceptText(O.medication as FHIR.CodeableConcept),
    Start: DateTimeText(O.authoredOn),
    DispensedDate: DateTimeText(GetMedicationRequestDispensedDate(O)),
    End:   null as String, // MedicationRequest end date not supported in R4,
    Status: O.status.value
  }
  sort by Start desc, End desc

define ReportBenzodiazepineMedicationStatements:
  (BenzodiazepineMedicationStatements) S
  return {
    Type:  'Statement',
    Name:  ConceptText(S.medication as FHIR.CodeableConcept),
    Start: MedicationStatementDate(S),
    End:   DateTimeText((S.effective as FHIR.Period)."end"),
    Status: S.status.value
  }
  sort by Start desc, End desc

define ReportBenzodiazepineMedications:
  (ReportBenzodiazepineMedicationRequests union ReportBenzodiazepineMedicationStatements) M
  sort by Start desc, End desc


// Carisoprodol Medications -  orders and statements with dates
define CarisoprodolMedicationRequests:
  //remove consideration for status field
  C3F.MedicationRequestLookBack(
    [MedicationRequest: "Carisoprodol"]
    union [MedicationRequest: "Aspirin / Carisoprodol"]
  , 100 years)

define CarisoprodolMedicationStatements:
  //remove consideration for status field
  C3F.MedicationStatementLookBack(
    [MedicationStatement: "Carisoprodol"]
    union [MedicationStatement: "Aspirin / Carisoprodol"]
  , 100 years)


define ReportCarisoprodolMedicationRequests:
  (CarisoprodolMedicationRequests) O
  return {
    Type:  'Request',
    Name:  ConceptText(O.medication as FHIR.CodeableConcept),
    Start: DateTimeText(O.authoredOn),
    DispensedDate: DateTimeText(GetMedicationRequestDispensedDate(O)),
    End:   null as String, // MedicationRequest end date not supported in R4,
    Status: O.status.value
  }
  sort by Start desc, End desc

define ReportCarisoprodolMedicationStatements:
  (CarisoprodolMedicationStatements) S
  return {
    Type:  'Statement',
    Name:  ConceptText(S.medication as FHIR.CodeableConcept),
    Start: MedicationStatementDate(S),
    End:   DateTimeText((S.effective as FHIR.Period)."end"),
    Status: S.status.value
  }
  sort by Start desc, End desc

define ReportCarisoprodolMedications:
  (ReportCarisoprodolMedicationRequests union ReportCarisoprodolMedicationStatements) M
  sort by Start desc, End desc


// Naloxone Medications (unrestricted lookback) - orders and statements with dates
define NaloxoneMedicationRequests:
  //remove consideration for status
  [MedicationRequest: "Naloxone medications"]

define NaloxoneMedicationStatements:
  //remove consideration for status
  [MedicationStatement: "Naloxone medications"]

define ReportNaloxoneMedicationRequests:
  (NaloxoneMedicationRequests) O
  return {
    Type:  'Request',
    Name:  ConceptText(O.medication as FHIR.CodeableConcept),
    DispensedDate: DateTimeText(GetMedicationRequestDispensedDate(O)),
    Start: DateTimeText(O.authoredOn),
    End:   null as String, // MedicationRequest end date not supported in R4,
    Status: O.status.value
  }
  sort by Start desc, End desc

define ReportNaloxoneMedicationStatements:
  (NaloxoneMedicationStatements) S
  return {
    Type:  'Statement',
    Name:  ConceptText(S.medication as FHIR.CodeableConcept),
    Start: MedicationStatementDate(S),
    End:   DateTimeText((S.effective as FHIR.Period)."end"),
    Status: S.status.value
  }
  sort by Start desc, End desc

define ReportNaloxoneMedications:
  (ReportNaloxoneMedicationRequests union ReportNaloxoneMedicationStatements) M
  sort by Start desc, End desc




// SUMMARY

// The Summary object represents the full Pain Management Summary to be displayed to the clinician.  All values are
// returned as user-friendly text representations, but a robust user interface (UI) should be implemented to
// display the data to the user in a friendly manner.  See the Pain Management Summary SMART on FHIR application as
// an example of how to integrate this summary into an EHR using modern web UI technologies.

define Summary: {
  Patient: {
    Name: Combine(Patient.name.given G return G.value, ' ') + ' ' + Combine(Patient.name.family F return F.value, ' '),
    Gender: Patient.gender.value,
    Age: AgeInYears(),
    MeetsInclusionCriteria: MeetsInclusionCriteria
  },
  PertinentMedicalHistory: {
    ConditionsAssociatedWithChronicPain: ReportConditionsAssociatedWithChronicPain,
    RiskFactorsForOpioidRelatedHarms: ReportRiskFactorsForOpioidRelatedHarms
  },
  HistoricalTreatments: {
    OpioidMedications: ReportOpioidMedications,
    NonOpioidMedications: ReportNonOpioidMedications,
    NonPharmacologicTreatments: ReportNonPharmacologicTreatments,
    StoolSoftenersAndLaxatives: ReportStoolSoftenersAndLaxatives
  },
  RiskConsiderations: {
    CurrentMME: ReportCurrentMME,
    ReportMME: ReportMME,
    ReportMMEByDates: ReportMMEByDates,
    //for debugging, uncomment to test
    //ReportPrescriptions: ReportPrescriptions,
    UrineDrugScreens: ReportUrineDrugScreens,
    BenzodiazepineMedications: ReportBenzodiazepineMedications,
    CarisoprodolMedications: ReportCarisoprodolMedications,
    NaloxoneMedications: ReportNaloxoneMedications
  },
  PDMPMedications: {
    PDMPMedications: ReportPDMPMedicationRequests
  }
}
