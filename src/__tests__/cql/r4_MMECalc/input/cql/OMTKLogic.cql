library OMTKLogic version '3.0.0'

/*
This library provides functionality for calculating Milligram Morphine
Equivalents (MME) for opioid medications, as described in the CDC Opioid
Prescribing Guideline.
The functionality in this library was developed based on the Java-based
implementation described [here](http://build.fhir.org/ig/cqframework/opioid-cds-r4/service-documentation.html#solution-component-3-core-logic-processing-java-class),
as well as the MME conversion calculation published as part of the CDC Opioid
Prescribing Guideline.
This version of the OMTKLogic library uses the OMTKData library as the
source for drug ingredient and strength information, rather than the
OMTK data source. This library has no external dependencies and so
can run in an environment that supports pure CQL.
NOTE: For performance, all terminology comparisons in this library use
direct integer comparison of the RxNorm codes.
This product uses publicly available data courtesy of the U.S. National Library of Medicine (NLM),
National Institutes of Health, Department of Health and Human Services; NLM is not responsible for
the product and does not endorse or recommend this or any other product.
Nelson SJ, Zeng K, Kilbourne J, Powell T, Moore R. Normalized names for clinical drugs: RxNorm at 6 years.
J Am Med Inform Assoc. 2011 Jul-Aug;18(4)441-8. doi: 10.1136/amiajnl-2011-000116.
Epub 2011 Apr 21. PubMed PMID: 21515544; PubMed Central PMCID: PMC3128404.
[Full text](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3128404/)
*/

include OMTKData version '3.0.0' called OMTKData

codesystem "RXNORM": 'http://www.nlm.nih.gov/research/umls/rxnorm'

parameter ErrorLevel String default 'Warning'






/*
// subset of ingredients from OMTKData to make it easier to test functions
define DrugIngredients:
{
  { drugCode: 197696, drugName: '72 HR Fentanyl 0.075 MG/HR Transdermal System', doseFormCode: 316987, doseFormName: 'Transdermal System', ingredientCode: 4337, ingredientName: 'Fentanyl', strength: '0.075 MG/HR', strengthValue: 0.075, strengthUnit: 'MG/HR' },
  { drugCode: 197873, drugName: 'Levorphanol 2 MG Oral Tablet', doseFormCode: 317541, doseFormName: 'Oral Tablet', ingredientCode: 6378, ingredientName: 'Levorphanol', strength: '2 MG', strengthValue: 2.0, strengthUnit: 'MG' },
  { drugCode: 205533, drugName: '1 ML Buprenorphine 0.3 MG/ML Injection [Buprenex]', doseFormCode: 1649574, doseFormName: 'Injection', ingredientCode: 1819, ingredientName: 'Buprenorphine', strength: '0.3 MG/ML', strengthValue: 0.3, strengthUnit: 'MG/ML' },
  { drugCode: 238129, drugName: '1 ML Buprenorphine 0.3 MG/ML Injection', doseFormCode: 1649574, doseFormName: 'Injection', ingredientCode: 1819, ingredientName: 'Buprenorphine', strength: '0.3 MG/ML', strengthValue: 0.3, strengthUnit: 'MG/ML' },
  { drugCode: 238133, drugName: 'Pentazocine 30 MG/ML Injectable Solution', doseFormCode: 316949, doseFormName: 'Injectable Solution', ingredientCode: 8001, ingredientName: 'Pentazocine', strength: '30 MG/ML', strengthValue: 30.0, strengthUnit: 'MG/ML' },
  { drugCode: 245134, drugName: '72 HR Fentanyl 0.025 MG/HR Transdermal System', doseFormCode: 316987, doseFormName: 'Transdermal System', ingredientCode: 4337, ingredientName: 'Fentanyl', strength: '0.025 MG/HR', strengthValue: 0.025, strengthUnit: 'MG/HR' },
  { drugCode: 245135, drugName: '72 HR Fentanyl 0.05 MG/HR Transdermal System', doseFormCode: 316987, doseFormName: 'Transdermal System', ingredientCode: 4337, ingredientName: 'Fentanyl', strength: '0.05 MG/HR', strengthValue: 0.05, strengthUnit: 'MG/HR' },
  { drugCode: 245136, drugName: '72 HR Fentanyl 0.1 MG/HR Transdermal System', doseFormCode: 316987, doseFormName: 'Transdermal System', ingredientCode: 4337, ingredientName: 'Fentanyl', strength: '0.1 MG/HR', strengthValue: 0.1, strengthUnit: 'MG/HR' },
  { drugCode: 261106, drugName: 'Fentanyl 0.2 MG Oral Lozenge [Actiq]', doseFormCode: 316992, doseFormName: 'Oral Lozenge', ingredientCode: 4337, ingredientName: 'Fentanyl', strength: '0.2 MG', strengthValue: 0.2, strengthUnit: 'MG' },
  { drugCode: 261107, drugName: 'Fentanyl 0.6 MG Oral Lozenge [Actiq]', doseFormCode: 316992, doseFormName: 'Oral Lozenge', ingredientCode: 4337, ingredientName: 'Fentanyl', strength: '0.6 MG', strengthValue: 0.6, strengthUnit: 'MG' },
  { drugCode: 261108, drugName: 'Fentanyl 0.8 MG Oral Lozenge [Actiq]', doseFormCode: 316992, doseFormName: 'Oral Lozenge', ingredientCode: 4337, ingredientName: 'Fentanyl', strength: '0.8 MG', strengthValue: 0.8, strengthUnit: 'MG' },
  { drugCode: 261109, drugName: 'Fentanyl 1.2 MG Oral Lozenge [Actiq]', doseFormCode: 316992, doseFormName: 'Oral Lozenge', ingredientCode: 4337, ingredientName: 'Fentanyl', strength: '1.2 MG', strengthValue: 1.2, strengthUnit: 'MG' },
  { drugCode: 261110, drugName: 'Fentanyl 1.6 MG Oral Lozenge [Actiq]', doseFormCode: 316992, doseFormName: 'Oral Lozenge', ingredientCode: 4337, ingredientName: 'Fentanyl', strength: '1.6 MG', strengthValue: 1.6, strengthUnit: 'MG' },
  { drugCode: 261184, drugName: '72 HR Fentanyl 0.025 MG/HR Transdermal System [Duragesic]', doseFormCode: 316987, doseFormName: 'Transdermal System', ingredientCode: 4337, ingredientName: 'Fentanyl', strength: '0.025 MG/HR', strengthValue: 0.025, strengthUnit: 'MG/HR' },
  { drugCode: 261185, drugName: '72 HR Fentanyl 0.05 MG/HR Transdermal System [Duragesic]', doseFormCode: 316987, doseFormName: 'Transdermal System', ingredientCode: 4337, ingredientName: 'Fentanyl', strength: '0.05 MG/HR', strengthValue: 0.05, strengthUnit: 'MG/HR' },
  { drugCode: 261186, drugName: '72 HR Fentanyl 0.075 MG/HR Transdermal System [Duragesic]', doseFormCode: 316987, doseFormName: 'Transdermal System', ingredientCode: 4337, ingredientName: 'Fentanyl', strength: '0.075 MG/HR', strengthValue: 0.075, strengthUnit: 'MG/HR' },
  { drugCode: 262071, drugName: '72 HR Fentanyl 0.1 MG/HR Transdermal System [Duragesic]', doseFormCode: 316987, doseFormName: 'Transdermal System', ingredientCode: 4337, ingredientName: 'Fentanyl', strength: '0.1 MG/HR', strengthValue: 0.1, strengthUnit: 'MG/HR' },
  { drugCode: 262219, drugName: 'Fentanyl 0.4 MG Oral Lozenge [Actiq]', doseFormCode: 316992, doseFormName: 'Oral Lozenge', ingredientCode: 4337, ingredientName: 'Fentanyl', strength: '0.4 MG', strengthValue: 0.4, strengthUnit: 'MG' },
  { drugCode: 310293, drugName: 'Fentanyl 1.2 MG Oral Lozenge', doseFormCode: 316992, doseFormName: 'Oral Lozenge', ingredientCode: 4337, ingredientName: 'Fentanyl', strength: '1.2 MG', strengthValue: 1.2, strengthUnit: 'MG' },
  { drugCode: 310294, drugName: 'Fentanyl 1.6 MG Oral Lozenge', doseFormCode: 316992, doseFormName: 'Oral Lozenge', ingredientCode: 4337, ingredientName: 'Fentanyl', strength: '1.6 MG', strengthValue: 1.6, strengthUnit: 'MG' },
  { drugCode: 310295, drugName: 'Fentanyl 0.2 MG Oral Lozenge', doseFormCode: 316992, doseFormName: 'Oral Lozenge', ingredientCode: 4337, ingredientName: 'Fentanyl', strength: '0.2 MG', strengthValue: 0.2, strengthUnit: 'MG' },
  { drugCode: 310297, drugName: 'Fentanyl 0.4 MG Oral Lozenge', doseFormCode: 316992, doseFormName: 'Oral Lozenge', ingredientCode: 4337, ingredientName: 'Fentanyl', strength: '0.4 MG', strengthValue: 0.4, strengthUnit: 'MG' },
  { drugCode: 312104, drugName: 'Belladonna Alkaloids 16.2 MG / Opium 30 MG Rectal Suppository', doseFormCode: 316978, doseFormName: 'Rectal Suppository', ingredientCode: 7676, ingredientName: 'Opium', strength: '30 MG', strengthValue: 30.0, strengthUnit: 'MG' },
  { drugCode: 312107, drugName: 'Belladonna Alkaloids 16.2 MG / Opium 60 MG Rectal Suppository', doseFormCode: 316978, doseFormName: 'Rectal Suppository', ingredientCode: 7676, ingredientName: 'Opium', strength: '60 MG', strengthValue: 60.0, strengthUnit: 'MG' },
  { drugCode: 312289, drugName: 'Naloxone 0.5 MG / Pentazocine 50 MG Oral Tablet', doseFormCode: 317541, doseFormName: 'Oral Tablet', ingredientCode: 8001, ingredientName: 'Pentazocine', strength: '50 MG', strengthValue: 50.0, strengthUnit: 'MG' },
  { drugCode: 313992, drugName: 'Fentanyl 0.6 MG Oral Lozenge', doseFormCode: 316992, doseFormName: 'Oral Lozenge', ingredientCode: 4337, ingredientName: 'Fentanyl', strength: '0.6 MG', strengthValue: 0.6, strengthUnit: 'MG' },
  { drugCode: 313993, drugName: 'Fentanyl 0.8 MG Oral Lozenge', doseFormCode: 316992, doseFormName: 'Oral Lozenge', ingredientCode: 4337, ingredientName: 'Fentanyl', strength: '0.8 MG', strengthValue: 0.8, strengthUnit: 'MG' },
  { drugCode: 351264, drugName: 'Buprenorphine 2 MG Sublingual Tablet', doseFormCode: 317007, doseFormName: 'Sublingual Tablet', ingredientCode: 1819, ingredientName: 'Buprenorphine', strength: '2 MG', strengthValue: 2.0, strengthUnit: 'MG' },
  { drugCode: 351265, drugName: 'Buprenorphine 8 MG Sublingual Tablet', doseFormCode: 317007, doseFormName: 'Sublingual Tablet', ingredientCode: 1819, ingredientName: 'Buprenorphine', strength: '8 MG', strengthValue: 8.0, strengthUnit: 'MG' },
  { drugCode: 351266, drugName: 'Buprenorphine 2 MG / Naloxone 0.5 MG Sublingual Tablet', doseFormCode: 317007, doseFormName: 'Sublingual Tablet', ingredientCode: 1819, ingredientName: 'Buprenorphine', strength: '2 MG', strengthValue: 2.0, strengthUnit: 'MG' },
  { drugCode: 351267, drugName: 'Buprenorphine 8 MG / Naloxone 2 MG Sublingual Tablet', doseFormCode: 317007, doseFormName: 'Sublingual Tablet', ingredientCode: 1819, ingredientName: 'Buprenorphine', strength: '8 MG', strengthValue: 8.0, strengthUnit: 'MG' },
  { drugCode: 577057, drugName: '72 HR Fentanyl 0.012 MG/HR Transdermal System', doseFormCode: 316987, doseFormName: 'Transdermal System', ingredientCode: 4337, ingredientName: 'Fentanyl', strength: '0.012 MG/HR', strengthValue: 0.012, strengthUnit: 'MG/HR' },
  { drugCode: 583490, drugName: '72 HR Fentanyl 0.012 MG/HR Transdermal System [Duragesic]', doseFormCode: 316987, doseFormName: 'Transdermal System', ingredientCode: 4337, ingredientName: 'Fentanyl', strength: '0.012 MG/HR', strengthValue: 0.012, strengthUnit: 'MG/HR' },
  { drugCode: 637540, drugName: 'Aspirin 325 MG / Oxycodone Hydrochloride 4.5 MG / oxycodone terephthalate 0.38 MG Oral Tablet', doseFormCode: 317541, doseFormName: 'Oral Tablet', ingredientCode: 7804, ingredientName: 'Oxycodone', strength: '4.5 MG', strengthValue: 4.5, strengthUnit: 'MG' },
  { drugCode: 637540, drugName: 'Aspirin 325 MG / Oxycodone Hydrochloride 4.5 MG / oxycodone terephthalate 0.38 MG Oral Tablet', doseFormCode: 317541, doseFormName: 'Oral Tablet', ingredientCode: 7804, ingredientName: 'Oxycodone', strength: '0.38 MG', strengthValue: 0.38, strengthUnit: 'MG' },
  { drugCode: 668363, drugName: 'Fentanyl 0.1 MG Buccal Tablet', doseFormCode: 970789, doseFormName: 'Buccal Tablet', ingredientCode: 4337, ingredientName: 'Fentanyl', strength: '0.1 MG', strengthValue: 0.1, strengthUnit: 'MG' },
  { drugCode: 668364, drugName: 'Fentanyl 0.2 MG Buccal Tablet', doseFormCode: 970789, doseFormName: 'Buccal Tablet', ingredientCode: 4337, ingredientName: 'Fentanyl', strength: '0.2 MG', strengthValue: 0.2, strengthUnit: 'MG' }
}
*/















/*
  Normalizes the input units to UCUM units
  The values listed here are the only ones currently present in the OMTK data
  Based on the HL7 UCUM subset here:
  http://download.hl7.de/documents/ucum/ucumdata.html
*/
define function ToUCUM(unit String):
  case unit
    when 'MG' then 'mg'
    when 'MG/ACTUAT' then 'mg/{actuat}'
    when 'MG/HR' then 'mg/h'
    when 'MG/ML' then 'mg/mL'
    else Message(null, true, 'OMTKLogic.ToUCUM.UnknownUnit', ErrorLevel, 'Unknown unit ' & unit)
  end

/*
  Calculates daily frequency given frequency within a period
*/
define function ToDaily(frequency Integer, period Quantity):
  case period.unit
    when 'h' then frequency * (24.0 / period.value)
    when 'min' then frequency * (24.0 / period.value) * 60
    when 's' then frequency * (24.0 / period.value) * 60 * 60
    when 'd' then frequency * (24.0 / period.value) / 24
    when 'wk' then frequency * (24.0 / period.value) / (24 * 7)
    when 'mo' then frequency * (24.0 / period.value) / (24 * 30) /* assuming 30 days in month */
    when 'a' then frequency * (24.0 / period.value) / (24 * 365) /* assuming 365 days in year */
    when 'hour' then frequency * (24.0 / period.value)
    when 'minute' then frequency * (24.0 / period.value) * 60
    when 'second' then frequency * (24.0 / period.value) * 60 * 60
    when 'day' then frequency * (24.0 / period.value) / 24
    when 'week' then frequency * (24.0 / period.value) / (24 * 7)
    when 'month' then frequency * (24.0 / period.value) / (24 * 30) /* assuming 30 days in month */
    when 'year' then frequency * (24.0 / period.value) / (24 * 365) /* assuming 365 days in year */
    when 'hours' then frequency * (24.0 / period.value)
    when 'minutes' then frequency * (24.0 / period.value) * 60
    when 'seconds' then frequency * (24.0 / period.value) * 60 * 60
    when 'days' then frequency * (24.0 / period.value) / 24
    when 'weeks' then frequency * (24.0 / period.value) / (24 * 7)
    when 'months' then frequency * (24.0 / period.value) / (24 * 30) /* assuming 30 days in month */
    when 'years' then frequency * (24.0 / period.value) / (24 * 365) /* assuming 365 days in year */
    else Message(null, true, 'OMTKLogic.ToDaily.UnknownUnit', ErrorLevel, 'Unknown unit ' & period.unit)
  end

/*
  Returns the conversion factor for the given ingredient
CDC Guidance:
https://www.cdc.gov/drugoverdose/pdf/calculating_total_daily_dose-a.pdf
https://www.cdc.gov/drugoverdose/modules/data-files.html
CMS Guidance:
https://www.cms.gov/Medicare/Prescription-Drug-Coverage/PrescriptionDrugCovContra/Downloads/Oral-MME-CFs-vFeb-2018.pdf
Opioid (strength in mg except where noted)	MME Conversion Factor*
Buprenorphine, transdermal patch (MCG/HR)	12.6
Buprenorphine, tablet or film	30
Buprenorphine, film (MCG)	0.03
Butorphanol	7
Codeine	0.15
Dihydrocodeine	0.25
Fentanyl, buccal/SL tabet or lozenge/troche (MCG)	0.13
Fentanyl, film or oral spray (MCG)	0.18
Fentanyl, nasal spray (MCG)	0.16
Fentanyl, transdermal patch (MCG/HR)	2.4
Hydrocodone	1
Hydromorphone	4
Levomethadyl acetate	8
Levorphanol tartrate	11
Meperidine 	0.1
Methadone	3
  1-20 mg/d 4
  21-40 mg/d 8
  41-60 mg/d 10
  61-80 mg/d 12
Morphine	1
Opium	1 // NOTE: Not present as an ingredient in the RxNorm data
Oxycodone	1.5
Oxymorphone	3
Pentazocine	0.37
Tapentadol	0.4
Tramadol	0.1
*/
define function GetConversionFactor(ingredientCode Code, dailyDose Quantity, doseFormCode Code):
  case ToInteger(ingredientCode.code)
    when 161 then 0  /*	Acetaminophen */
    when 1191 then 0 /*	Aspirin */
    when 1223 then 0 /*	Atropine */
    when 1767 then 0 /*	Brompheniramine */
    when 1819 then ( /*	Buprenorphine */
      case
        when ToInteger(doseFormCode.code) = 316987 then 12.6 /* Transdermal system */
        else 30 /* Tablet or Film (or Film in MCG) */
      end
    )
    when 1841 then 7 /*	Butorphanol */
    when 1886 then 0 /*	Caffeine */
    when 2101 then 0 /*	Carisoprodol */
    when 2354 then 0 /*	chlorcyclizine */
    when 2400 then 0 /*	Chlorpheniramine */
    when 2670 then 0.15 /*	Codeine */
    when 3423 then 4 /*	Hydromorphone */
    when 3498 then 0 /*	Diphenhydramine */
    when 4337 then ( /*	Fentanyl */
      case
        when ToInteger(doseFormCode.code) in { 970789, 317007, 316992 } then 0.13 /* Buccal Tablet, Sublingual Tablet, Oral Lozenge */
        when ToInteger(doseFormCode.code) = 858080 then 0.18 /* Buccal Film */
        when ToInteger(doseFormCode.code) in { 126542, 346163, 1797831 } then 0.16 /* Nasal Spray, Mucosal Spray, Metered Dose Nasal Spray */
        when ToInteger(doseFormCode.code) = 316987 then 2.4 /* Transdermal system */
        else Message(null, true, 'OMTKLogic.GetConversionFactor.UnknownDoseForm', ErrorLevel, 'Unknown dose form code ' & doseFormCode.code)
      end
    )
    when 5032 then 0 /*	Guaifenesin */
    when 5489 then 1 /*	Hydrocodone */
    when 5640 then 0 /*	Ibuprofen */
    when 6102 then 0 /*	Kaolin */
    when 6378 then 11 /*	Levorphanol (NOTE: Given as Levorphanol tartrate in the CDC conversion table) */
    when 6754 then 0.1 /*	Meperidine */
    when 6813 then ( /*	Methadone */
      case
        when dailyDose.value between 1 and 20 then 4
        when dailyDose.value between 21 and 40 then 8
        when dailyDose.value between 41 and 60 then 10
        when dailyDose.value >= 61 then 12
        else Message(null, dailyDose.value < 1, 'OMTKLogic.GetConversionFactor.DailyDoseLessThanOne', ErrorLevel, 'Daily dose less than 1')
      end
    )
    when 7052 then 1 /*	Morphine */
    when 7242 then 0 /*	Naloxone */
    when 7243 then 0 /*	Naltrexone */
    when 7804 then 1.5 /*	Oxycodone */
    when 7814 then 3 /*	Oxymorphone */
    when 8001 then 0.37 /*	Pentazocine */
    when 8163 then 0 /*	Phenylephrine */
    when 8175 then 0 /*	Phenylpropanolamine */
    when 8745 then 0 /*	Promethazine */
    when 8896 then 0 /*	Pseudoephedrine */
    when 9009 then 0 /*	Pyrilamine */
    when 10689 then 0.1 /*	Tramadol */
    when 10849 then 0 /*	Triprolidine */
    when 19759 then 0 /*	bromodiphenhydramine */
    when 19860 then 0 /*	butalbital */
    when 22696 then 0 /*	dexbrompheniramine */
    when 22697 then 0 /*	dexchlorpheniramine */
    when 23088 then 0.25 /*	dihydrocodeine */
    when 27084 then 0 /*	homatropine */
    when 35780 then 0 /*	ropivacaine */
    when 237005 then 8 /*	Levomethadyl (NOTE: given as Levomethadyl acetate in the CDC conversion table) */
    when 636827 then 0 /*	guaiacolsulfonate */
    when 787390 then 0.4 /*	tapentadol */
    else Message(null, true, 'OMTKLogic.GetConversionFactor.UnknownIngredientCode', ErrorLevel, 'Unknown ingredient code: ' & ingredientCode.code)
  end

// Test function
//define TestConversionFactor:
//  GetConversionFactor(Code '1819' from RXNORM, Quantity {value: 2.0}, Code '317007' from RXNORM)
//(ingredientCode Code, dailyDose Quantity, doseFormCode Code)
//I don't think dailyDose is used in this calculation




define function EnsureMicrogramQuantity(strength Quantity):
  // TODO: This should be possible with just quantity arithmetic
  if strength.value < 0.1 and (PositionOf('mg', strength.unit) = 0) then
    Quantity {
      value: strength.value * 1000,
      unit: 'ug' & Substring(strength.unit, 2)
    }
  else
    strength

/*
  Returns the opioid ingredients and their strengths that
  make up the drug identified by the given rxNormCode as a list of tuples:
  List<Tuple {
    rxNormCode Code,
    doseFormCode Code,
    doseFormName String,
    ingredientCode Code,
    ingredientName String,
    strength Quantity
  }>
*/

/*
GetIngredients:
  List<{
    rxNormCode Code,
    doseFormCode Code,
    ingredientCode code,
    strength Quantity
  }>
*/
define function GetIngredients(rxNormCode Code):
  OMTKData.DrugIngredients DI
    where DI.drugCode = ToInteger(rxNormCode.code)
    return {
      rxNormCode: Code { code: ToString(DI.drugCode), system: 'http://www.nlm.nih.gov/research/umls/rxnorm', display: DI.drugName },
      doseFormCode: Code { code: ToString(DI.doseFormCode), system: 'http://www.nlm.nih.gov/research/umls/rxnorm', display: DI.doseFormName },
      ingredientCode: Code { code: ToString(DI.ingredientCode), system: 'http://www.nlm.nih.gov/research/umls/rxnorm', display: DI.ingredientName },
      strength: EnsureMicrogramQuantity(
          Quantity {
            value: DI.strengthValue,
            unit: ToUCUM(DI.strengthUnit)
          }
        )
    }

// Test function
define TestGetIngredients:
  GetIngredients(Code '351267' from RXNORM)




/*
Returns the first RxNorm code in the given concept that matches a drug code
specified in OMTKData.
*/
define function GetMedicationCode(concept Concept):
  First(
    (concept.codes) C
      where C.system = 'http://www.nlm.nih.gov/research/umls/rxnorm'
        return singleton from (
          OMTKData.DrugIngredients DI
            where DI.drugCode = ToInteger(C.code)
            return Code {
              code: ToString(DI.drugCode),
              system: 'http://www.nlm.nih.gov/research/umls/rxnorm',
              display: DI.drugName
            }
        )
  )

/*
Returns the display of the given concept, if present, otherwise, looks up medication
names for any RxNormCodes within the concept using the GetMedicationName function
*/
define function GetMedicationConceptName(concept Concept):
  if concept.display is null then
    First(
      (concept.codes) C
        where C.system = 'http://www.nlm.nih.gov/research/umls/rxnorm'
        return GetMedicationName(C)
    )
  else
    concept.display

/*
Returns the display of the given code, if present, otherwise looks it up from the OMTK data
*/
define function GetMedicationName(rxNormCode Code):
  if rxNormCode.display is null then
    singleton from (
      OMTKData.DrugIngredients DI
        where DI.drugCode = ToInteger(rxNormCode.code)
        return DI.drugName
    )
    else rxNormCode.display

/*
Returns the display of the given ingredient, if present, otherwise looks it up from the OMTK data
*/
define function GetIngredientName(ingredientCode Code):
  if ingredientCode.display is null then
    singleton from (
      OMTKData.DrugIngredients DI
        where DI.ingredientCode = ToInteger(ingredientCode.code)
        return DI.ingredientName
    )
    else ingredientCode.display

/*
Returns the display of the given dose form, if present, otherwise looks it up from the OMTK data
*/
define function GetDoseFormName(doseFormCode Code):
  if doseFormCode.display is null then
    singleton from (
      OMTKData.DrugIngredients DI
        where DI.doseFormCode = ToInteger(doseFormCode.code)
        return DI.doseFormName
    )
    else doseFormCode.display

/*
  Removes the last per argument from a unit
*/
define function StripPer(unit String):
  if LastPositionOf('/', unit) >= 0
    then Substring(unit, 0, LastPositionOf('/', unit))
    else unit

/*
  Calculates daily dose for a specific ingredient based on the ingredient strength, dose form, dose quantity, and daily frequency
*/
define function GetDailyDose(ingredientCode Code, strength Quantity, doseFormCode Code, doseQuantity Quantity, dosesPerDay Decimal):
  case
    when dosesPerDay is null or doseQuantity is null or strength is null then
      null as Quantity
	  /* if patch --> daily dose = dose value (e.g, number patches with doseQuantity unit = "patch") * per-hour strength */
    when ToInteger(doseFormCode.code) = 316987 then
      /* buprenorphine or fentanyl patch */
      if ToInteger(ingredientCode.code) in { 1819, 4337 } then
        Quantity { value: dosesPerDay * doseQuantity.value * strength.value, unit: strength.unit }
      else
        Message(null, true, 'OMTKLogic.GetDailyDoseDescription.UnknownPatchIngredient', ErrorLevel, 'Unknown patch ingredient: ' & ingredientCode.code & ':' & ingredientCode.display)

    /* if dose unit in actual mass units (mg or ug -- when it's a single med) --> daily dose = numTimesPerDay * dose */
    when doseQuantity.unit in { 'mg', 'ug' } then
      Quantity { value: dosesPerDay * doseQuantity.value, unit: doseQuantity.unit }

    /* if doseQuantity is in actual volume units (mL) --> daily dose = numTimesPerDay * dose * strength */
    when doseQuantity.unit = 'mL' and (PositionOf('/mL', strength.unit) = Length(strength.unit) - 3) then
      Quantity { value: dosesPerDay * doseQuantity.value * strength.value, unit: StripPer(strength.unit) }

		/* if doseQuantity is not in actual units (e.g., 1 tab, 1 spray -- when it's a combo med with a unit of tablet, or it's mg/actuat) -->  daily dose = numTimesPerDay * dose value * strength value */
    else
      Quantity { value: dosesPerDay * doseQuantity.value * strength.value, unit: StripPer(strength.unit) }
  end

//Test function
define TestDailyDose:
  GetDailyDose(Code '1819' from RXNORM, Quantity {value: 8.0}, Code '317007' from RXNORM, Quantity {value: 1, unit:'tab'}, 2.00)




/*
  Builds a description for the daily dose for an ingredient
*/
define function GetDailyDoseDescription(ingredientCode Code, strength Quantity, doseFormCode Code, doseQuantity Quantity, dosesPerDay Decimal, dailyDose Quantity):
  case
    /* if patch */
    when ToInteger(doseFormCode.code) = 316987 then
      /* buprenorphine or fentanyl patch */
      if ToInteger(ingredientCode.code) in { 1819, 4337 } then
        GetIngredientName(ingredientCode) & ' patch: ' & ToString(doseQuantity.value) & ' * ' & ToString(dosesPerDay) & '/d * '& ToString(strength) & ' = ' + ToString(dailyDose)
      else
        Message(null, true, 'OMTKLogic.GetDailyDoseDescription.UnknownPatchIngredient', ErrorLevel, 'Unknown patch ingredient: ' & ingredientCode.code & ':' & ingredientCode.display)

    /* if dose unit in actual mass units (mg or ug -- when it's a single med) */
    when doseQuantity.unit in { 'mg', 'ug' } then
      GetIngredientName(ingredientCode) + ' ' + GetDoseFormName(doseFormCode) + ': ' + ToString(dosesPerDay) + '/d * ' + ToString(doseQuantity) + ' = ' + ToString(dailyDose)

    /* if doseQuantity in actual volume units (mL) or not in actual units (e.g. 1 tab, 1 spray) */
    else
      GetIngredientName(ingredientCode) + ' ' + GetDoseFormName(doseFormCode) + ': ' + ToString(dosesPerDay) + '/d * ' + ToString(doseQuantity) + ' * ' + ToString(strength) + ' = ' + ToString(dailyDose)
  end

/*
  Calculates MMEs for the given input prescription information and returns it
  as a list of tuples:
  List<Tuple {
    rxNormCode Code,
    doseFormCode Code,
    doseQuantity Quantity,
    dosesPerDay Decimal,
    ingredientCode Code,
    strength Quantity,
    dailyDose Quantity,
    dailyDoseDescription String,
    conversionFactor Decimal,
    mme Quantity
  }>
*/
define function CalculateMMEs(medications List<Tuple { rxNormCode Code, doseQuantity Quantity, dosesPerDay Decimal }>):
  Flatten(
    medications M
      let Ingredients: GetIngredients(M.rxNormCode)
      return
        Ingredients I
          let
            adjustedDoseQuantity: EnsureMicrogramQuantity(M.doseQuantity),
            dailyDose: GetDailyDose(I.ingredientCode, I.strength, I.doseFormCode, adjustedDoseQuantity, M.dosesPerDay),
            dailyDoseDescription: GetDailyDoseDescription(I.ingredientCode, I.strength, I.doseFormCode, adjustedDoseQuantity, M.dosesPerDay, dailyDose),
            factor: GetConversionFactor(I.ingredientCode, dailyDose, I.doseFormCode)
          return {
            rxNormCode: M.rxNormCode,
            doseFormCode: I.doseFormCode,
            doseQuantity: adjustedDoseQuantity,
            dosesPerDay: M.dosesPerDay,
            ingredientCode: I.ingredientCode,
            strength: I.strength,
            dailyDose: dailyDose,
            dailyDoseDescription: dailyDoseDescription & (' * factor: ' + ToString(factor)),
            conversionFactor: factor,
            mme: Quantity(
              dailyDose.value * factor,
              '{MME}/d'
            )
          }
  )

// Test function
define TestCalculateMMEs:
  CalculateMMEs({ { rxNormCode: Code '351267' from RXNORM, doseQuantity: Quantity { value: 1, unit: 'tab' }, dosesPerDay: 2.00 } })


define function Quantity(value Decimal, unit String):
  if value is not null then
    Quantity { value: value, unit: unit }
  else
    null
