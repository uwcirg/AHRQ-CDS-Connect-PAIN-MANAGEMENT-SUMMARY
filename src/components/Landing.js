import React, { Component } from 'react';
import ReactTooltip from 'react-tooltip';
import tocbot from 'tocbot';
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome';

import executeElm from '../utils/executeELM';
import flagit from '../helpers/flagit';
import {dateFormat, datishFormat} from '../helpers/formatit';
import {dateTimeCompare} from '../helpers/sortit';
import summaryMap from './summary.json';

import {getEnv, fetchEnvData} from '../utils/envConfig';
import Header from './Header';
import Summary from './Summary';
import Spinner from '../elements/Spinner';

let uuid = 0;

function generateUuid() {
  return ++uuid; // eslint-disable-line no-plusplus
}

export default class Landing extends Component {
  constructor() {
    super(...arguments);
    this.state = {
      result: null,
      loading: true,
      collector: [],
      externals: {},
      patientId: ""
    };

    this.tocInitialized = false;
  }

  setPatientId() {
    if (!this.state.collector) return;
    /*
     * passed down via fhir.js
     */
    let patientBundle = (this.state.collector).filter(item => item.data && item.data.resourceType && item.data.resourceType.toLowerCase() === "patient");
    if (patientBundle.length) {
      this.setState({
        patientId: patientBundle[0].data.id
      });
    }
  }
  getPatientId() {
    return this.state.patientId;
  }

  componentDidMount() {
    /*
     * fetch env data where necessary, i.e. env.json, to ensure REACT env variables are available
     */
    fetchEnvData();
    let result = {};
    Promise.all([executeElm(this.state.collector)])
    .then(
      response => {
        //set result from data from EPIC
        let EPICData = response[0];
        result['Summary'] = EPICData ? {...EPICData['Summary']} : {};
        const { sectionFlags, flaggedCount } = this.processSummary(result.Summary);
        this.setState({ result, sectionFlags, flaggedCount });
        this.setPatientId();
        //add data from other sources, e.g. PDMP
        Promise.all([this.getExternalData()]).then(
          externalData => {
            result['Summary'] = {...result['Summary'], ...externalData[0]};
            const { sectionFlags, flaggedCount } = this.processSummary(result.Summary);
            this.processOverviewData(result['Summary'], sectionFlags);
            this.setState({ result, sectionFlags, flaggedCount });
            this.setState({ loading: false});
        }).catch((err) => {
          console.log(err);
          this.setState({ loading: false});
        });
      }
    )
    .catch((err) => {
      console.error(err);
      this.setState({ loading: false});
    });
    
  }

  componentDidUpdate() {
    if (!this.tocInitialized && !this.state.loading && this.state.result) {
      tocbot.init({
        tocSelector: '.summary__nav',           // where to render the table of contents
        contentSelector: '.summary__display',   // where to grab the headings to build the table of contents
        headingSelector: 'h2, h3',              // which headings to grab inside of the contentSelector element
        positionFixedSelector: '.summary__nav', // element to add the positionFixedClass to
        collapseDepth: 0,                       // how many heading levels should not be collpased
        includeHtml: true                       // include the HTML markup from the heading node, not just the text
      });

      this.tocInitialized = true;
    }

    if (this.state.result && this.state.result.Summary.Patient.Name) {
      const patientName = this.state.result.Summary.Patient.Name;
      document.title = `Pain Management Summary - ${patientName}`;
    }
  }
  /*
   * function for retrieving data from other sources e.g. PDMP
   */
  async getExternalData() {
    let dataSet = {};
    const promiseResultSet = [];

    /*
     * retrieve entries from Summary map, i.e. summary.json that requires fetching data via external API
     */
    for (let key in summaryMap) {
      if (summaryMap[key].dataSource) {
        promiseResultSet.push(summaryMap[key].dataSource);
      }
    }

    if (!promiseResultSet.length) {
      return dataSet;
    }

    let results = await Promise.all(promiseResultSet.map(item => {
      return this.fetchData(this.processEndPoint(item.endpoint), item.dataKey, item.dataKeySource)
    })).catch(e => {
      console.log(`Error parsing external data response json: ${e.message}`);
      promiseResultSet.forEach(item => {
        dataSet[item.dataKey] = null;
      });
      return dataSet;
    });

    promiseResultSet.forEach((item, index) => {
      let result = results[index];
      //require additional processing of result data
      if (item.processFunction && this[item.processFunction]) {
        try {
          result = this[item.processFunction](results[index] ? results[index][item.dataKey] : null, item.dataKey);
        } catch(e) {
          console.log(`Error processing data result via processing function ${item.processFunction}: ${e}`);
        }
      }
      dataSet[item.dataKey] = result ? result: null;

    });
    return dataSet;
  }

  processOverviewData(summary, sectionFlags) {
    const overviewSectionKey = "PatientRiskOverview";
    let overviewSection = summaryMap[overviewSectionKey];
    if (!overviewSection) {
      return false;
    }
    let stats = [];
    let config = overviewSection.statsConfig;
    if (config) {
      let dataSource = summary[config.dataKeySource] ? summary[config.dataKeySource][config.dataKey]: null;
      let statsSource = dataSource ? dataSource : [];
      if (config.data) {
        config.data.forEach(item => {
          let o = statsSource;
          if (item.keyMatch) {
            o = statsSource.filter(element => element[item.keyMatch]);
            o = Array.from(new Set(o.map(subitem => subitem[item.keyMatch])));
          }
          let statItem = {};
          statItem[item.title] = o.length;
          stats.push(statItem);
        });
      }
    }
    let alerts = [];
    if (sectionFlags) {
      for (let section in sectionFlags) {
        for (let subsection of Object.entries(sectionFlags[section])) {
          if (subsection[1]) {
            if (typeof subsection[1] === "string") {
              alerts.push(subsection[1]);
            }
            if (typeof subsection[1] === "object") {
              if (Array.isArray(subsection[1])) {
                subsection[1].forEach(subitem => {
                  if (subitem.flagText) {
                    alerts.push({
                      id: subitem.subSection.dataKey,
                      name: subitem.subSection.name,
                      text: subitem.flagText,
                      priority: subitem.priority || 0
                    });
                  }
                });
              } else {
                if (subsection[1].flagText) {
                  alerts.push({
                    id: subsection[1].subSection.dataKey,
                    name: subsection[1].subSection.name,
                    text: subsection[1].flagText,
                    priority: subsection[1].priority || 0
                  });
                }
              }
            }
          }
        }
      }
    }
    alerts.sort(function (a, b) {
      return b.priority - a.priority;
    });

    //process graph data
    if (overviewSection.graphConfig && overviewSection.graphConfig.summaryDataSource) {
      //get the data from summary data
      let sections = overviewSection.graphConfig.summaryDataSource;
      let graph_data = [];
      const MME_VALUE_FIELD_NAME = "MMEValue";
      const END_DATE_FIELD_NAME = "End";
    
      sections.forEach(item => {
        if (summary[item.section_key] && summary[item.section_key][item.subSection_key]) {
          //console.log("section data? ", summary[item.section_key][item.subSection_key])
          graph_data = [...graph_data, ...summary[item.section_key][item.subSection_key]];

          /*
           * safe-guard, make sure all the graph item has the required fields
           */
          graph_data = graph_data.filter(item => item[END_DATE_FIELD_NAME] && !isNaN(item[MME_VALUE_FIELD_NAME]));
          
          /*
           * re-format dates so they can be compared reliably
           */
          graph_data = graph_data.map(item => {
            item[END_DATE_FIELD_NAME] = dateFormat("", item[END_DATE_FIELD_NAME], "YYYY-MM-DD");
            return item;
          });
        
          /*
           * add MME Values for those that fall on the same date
           */
          graph_data = graph_data.reduce((o, current) => {
            /*
            * find existing item with the same date
            */
            const existingIndex = o.findIndex(item => {
              return (
                item[END_DATE_FIELD_NAME] === current[END_DATE_FIELD_NAME]
              );
            });
              /*
              * add MM value if existing item with same date found
              */
              if (existingIndex !== -1) {
                o[existingIndex][MME_VALUE_FIELD_NAME] = o[existingIndex][MME_VALUE_FIELD_NAME] + current[MME_VALUE_FIELD_NAME];
                return o;
              }
              return o.concat([current]);
          }, []);
        }
      });

      summary[overviewSectionKey+"_graph"] = graph_data;
      //console.log("graph data?? ", graph_data)
    }

    
    summary[overviewSectionKey+"_stats"] = stats;
    summary[overviewSectionKey+"_alerts"] = alerts.filter((item,index,thisRef)=>thisRef.findIndex(t=>(t.text === item.text))===index);

  }

  processEndPoint(endpoint) {
    if (!endpoint) return "";
    return (endpoint)
    .replace('{process.env.REACT_APP_CONF_API_URL}', getEnv("REACT_APP_CONF_API_URL"))
    .replace('{process.env.PUBLIC_URL}', getEnv("PUBLIC_URL"))
    .replace('{patientId}', this.getPatientId());
  }

  processMedicationOrder(result, dataKey) {

    if (!result || !result.length) {
      return false;
    }
    let dataSet = {};
    /*
     * dealing with deeply nested FHIR response data, reformat for ease of rendering
     */
    let getValue = (obj, prop) => {
      return obj && obj[prop] ? obj[prop] : "";
    }
    result.forEach(item => {
      //prescriber
      item["_prescriber"] = getValue(item["prescriber"], "display");
      let dispenseRequest = item.dispenseRequest;
      if (!dispenseRequest) {
        return true;
      }
      //quantity
      item["_quantity"] = getValue(dispenseRequest["quantity"], "value"); 
      let extensionObj = dispenseRequest["extension"];
      if (!extensionObj.length) {
        return true;
      }
      //date dispensed
      let dObj = extensionObj.filter(o => o.valueDate);
      if (dObj.length) {
        item["_dateDispensed"] = dObj[0].valueDate;
      }
      // pharmacy
      let pObj = extensionObj.filter(o => o.valueString);
      if (pObj.length) {
        item["_pharmacy"] = pObj[0].valueString;
      }
    });
    /*
     * a hack, until figure out why react table is not sorting the date correctly by default
     */
    result = result.sort(function(a, b) {
      return dateTimeCompare(a._dateDispensed, b._dateDispensed);
    });
    /*
     * TODO: add MME converted value for each opioid med here?
     * so we can use these values to draw graph??
     */
    dataSet[dataKey] = result;
    return dataSet;
  }

  async getDemoData(section) {
    if (!section || !section["demoData"]) return null;
    if (!section["demoData"]["endpoint"]) {
      return null;
    }
    return fetch(this.processEndPoint(section["demoData"]["endpoint"]));
  }

  setDemoDataFlag(datasetKey) {
    if (summaryMap[datasetKey]) {
      summaryMap[datasetKey].usedemoflag = true;
    }
  }

  setDataError(datasetKey, message) {
    if (!summaryMap[datasetKey] || !message) {
      return;
    }
    console.log(message); //display error in console
    summaryMap[datasetKey]["errorMessage"] = message;
  }

  async fetchData (url, datasetKey, rootElement) {
    let dataSet = {};
    dataSet[datasetKey] = {};
    const MAX_WAIT_TIME = 15000;
    // Create a promise that rejects in maximum wait time in milliseconds
    let timeoutPromise = new Promise((resolve, reject) => {
      let id = setTimeout(() => {
        clearTimeout(id);
        reject(`Timed out in ${MAX_WAIT_TIME} ms.`)
      }, MAX_WAIT_TIME);
    });

    // let response = await fetch(url)
    // .catch(e => console.log(`Error fetching ${datasetKey} data: ${e.message}`));

    /*
     * if for some reason fetching the request data doesn't resolve or reject withing the maximum waittime,
     * then the timeout promise will kick in
     */
    let results = await Promise.race([
      fetch(url),
      timeoutPromise
    ]).catch(e => {
      this.setDataError(datasetKey, `There was error fetching data: ${e}`);
    });

    let json = null;
    if (results) {
      try {
        //read response stream
        json = await (results.json()).catch(e => {
          this.setDataError(datasetKey, `There was error parsing data: ${e.message}`);
        });
      } catch(e) {
        this.setDataError(datasetKey, `There was error parsing data: ${e}`);
        json = null;
      }
    }

    if (!json) {
      let demoResult = await this.getDemoData(summaryMap[datasetKey]).catch(e => {
        this.setDataError(datasetKey, `There was error fetching demo data: ${e}`);
      });
      //if unable to fetch data, set data to demo data if any
      json = await(demoResult.json()).catch(e => {
        this.setDataError(datasetKey, `There was error parsing demo data: ${e.message}`);
      });
      if (json && json[rootElement]) {
        this.setDemoDataFlag(datasetKey);
      }
    }
    let responseDataSet = null;
    try {
      responseDataSet = json[rootElement];
    } catch(e) {
      this.setDataError(datasetKey, `Data does not contained the required root element ${rootElement}: ${e}`);
      responseDataSet  = null;
    }
    dataSet[datasetKey] = responseDataSet;
    return dataSet;
  }

  getAnalyticsData(endpoint, apikey, summary) {
    const meetsInclusionCriteria = summary.Patient.MeetsInclusionCriteria;
    const applicationAnalytics = {
      meetsInclusionCriteria
    };

    if (meetsInclusionCriteria) {
      let totalCount = 0;
      applicationAnalytics.sections = [];

      const cloneSections = JSON.parse(JSON.stringify(summary));
      delete cloneSections.Patient;

      // Build total number of entries for each subsection of the summary.
      Object.keys(cloneSections).forEach((sectionKey, i) => {
        applicationAnalytics.sections.push({ section: sectionKey, subSections: [] });
        Object.keys(cloneSections[sectionKey]).forEach(subSectionKey => {
          let SectionElement = cloneSections[sectionKey];
          if (!SectionElement) return true;
          const subSection = SectionElement[subSectionKey];
          if (!subSectionKey) return true;
          let count;
          if (subSection instanceof Array) count = subSection.length;
          else if (subSection instanceof Object) count = 1;
          else count = 0;
          totalCount += count;
          applicationAnalytics.sections[i].subSections.push({
            subSection: subSectionKey, numEntries: count
          });
        });
      });

      applicationAnalytics.totalNumEntries = totalCount;
    }

    let jsonBody = JSON.stringify(applicationAnalytics);

    const requestOptions = {
      body: jsonBody,
      headers: {
        'x-api-key': `${apikey}`,
        'Content-Type': 'application/json',
        'Content-Length': jsonBody.length
      },
      method: 'POST'
    };

    fetch(`${endpoint}`, requestOptions)
      .catch(err => { console.log(err) });
  }

  processSummary(summary) {
    /*
     * TODO: certain sections we have chosen not to display so need to exclude those when tallying up flag counts
     * suppressed section: "PertinentMedicalHistory", "PainAssessments", "RiskConsiderations"
     */
    const sectionFlags = {};
    const sectionKeys = Object.keys(summaryMap);
    let flaggedCount = 0;

    sectionKeys.forEach((sectionKey, i) => { // for each section
      sectionFlags[sectionKey] = {};
      summaryMap[sectionKey]["sections"].forEach((subSection) => { // for each sub section
        const keySource = summary[subSection.dataKeySource];
        if (!keySource) {
          return true;
        }
        const data = keySource[subSection.dataKey];
        const entries = (Array.isArray(data) ? data : [data]).filter(r => r != null);

        if (entries.length > 0) {
          sectionFlags[sectionKey][subSection.dataKey] = entries.reduce((flaggedEntries, entry) => {
            if (entry._id == null) {
              entry._id = generateUuid();
            }
            const entryFlag = flagit(entry, subSection, summary);

            if (entryFlag) {
              flaggedCount += 1;
              flaggedEntries.push({'entryId': entry._id, 'subSection': subSection, 'flagText': entryFlag, 'flagCount': flaggedCount, 'priority': subSection.alertPriority || 0});
            }

            return flaggedEntries;
          }, []);
        } else {
          const sectionFlagged = flagit(null, subSection, summary);
          if (sectionFlagged) {
            flaggedCount += 1;
            sectionFlags[sectionKey][subSection.dataKey] = [{
              'flagText': sectionFlagged,
              'flagCount': flaggedCount,
              'subSection': subSection,
              'priority': subSection.alertPriority || 0
            }];
          }
        }
      });
    });


    //console.log("sectionFlags ", sectionFlags);
    // Get the configured endpoint to use for POST for app analytics
    fetch(`${getEnv("PUBLIC_URL")}/config.json`)
      .then(response => response.json())
      .then(config => {
        // Only provide analytics if the endpoint has been set
        if (config.analytics_endpoint) {
          this.getAnalyticsData(config.analytics_endpoint, config.x_api_key, summary);
        }
      })
      .catch(err => { console.log(err) });

      
    return { sectionFlags, flaggedCount };
  }

  render() {
    if (this.state.loading) {
      return <Spinner />;
    }

    if (this.state.result == null) {
      return (
        <div className="banner error">
          <FontAwesomeIcon icon="exclamation-circle" title="error" /> Error: See console for details.
        </div>
      );
    }
    const patientResource = this.state.collector[0]['data'];
    const summary = this.state.result.Summary;
    const { sectionFlags } = this.state;

    return (
      <div className="landing">
        <div id="skiptocontent"><a href="#maincontent">skip to main content</a></div>

        <Header
          patientName={summary.Patient.Name}
          patientDOB={datishFormat(this.state.result,patientResource.birthDate)}
          patientGender={summary.Patient.Gender}
          meetsInclusionCriteria={summary.Patient.MeetsInclusionCriteria}
        />

        <Summary
          summary={summary}
          sectionFlags={sectionFlags}
          collector={this.state.collector}
          result={this.state.result}
        />

        <ReactTooltip className="summary-tooltip" id="summaryTooltip" />    
      </div>
    );
  }
}
