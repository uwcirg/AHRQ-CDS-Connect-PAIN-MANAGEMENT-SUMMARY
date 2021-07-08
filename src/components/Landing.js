import React, { Component } from 'react';
import ReactTooltip from 'react-tooltip';
import tocbot from 'tocbot';
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome';

import executeElm from '../utils/executeELM';
import flagit from '../helpers/flagit';
import {datishFormat, dateFormat, dateNumberFormat, extractDateFromGMTDateString} from '../helpers/formatit';
import {dateCompare} from '../helpers/sortit';
import {getDiffDays} from '../helpers/utility';
import summaryMap from './summary.json';

import {getEnv, fetchEnvData} from '../utils/envConfig';
import Header from './Header';
import Summary from './Summary';
import {isInViewport} from './Utility';
import Spinner from '../elements/Spinner';

let uuid = 0;
let processIntervalId = 0;

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
      patientId: "",
      loadingMessage: "Resources are being loaded..."
    };
    this.errorCollection = [];
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
  pingProcessProgress() {
    processIntervalId = setInterval(() => {
     // console.log("collector status ", this.state.collector.length);
     // console.log("summary map ", summaryMap)
     let totalResources = Object.keys(summaryMap).length;
     let numResourcesLoaded = this.state.collector.length;
     let stillLoading = numResourcesLoaded <= totalResources;
      this.setState({
        loadingMessage: `<div>${totalResources} resources are being loaded.</div><div><span class='${stillLoading?"text-warning": "text-success"}'>${stillLoading ? (numResourcesLoaded > 0 ? numResourcesLoaded-1: 0) : totalResources} loaded ...</span></div>`
      });
    }, 30);
  }
  clearProcessInterval() {
    clearInterval(processIntervalId);
  }
  processCollectorErrors() {
    let collectorErrors = this.state.collector.filter(item => {
      return item.error;
    });
    collectorErrors.forEach(item => {
      this.setError(`[${item.type}] ${item.error}`);
    });
  }
  setError(message) {
    if (!message) return;
    this.errorCollection.push(message);
  }
  componentDidMount() {
    /*
     * fetch env data where necessary, i.e. env.json, to ensure REACT env variables are available
     */
    fetchEnvData();
    this.pingProcessProgress();
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
        setTimeout(function() {
          this.clearProcessInterval();
        }.bind(this), 0);
        this.processCollectorErrors();
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
          this.clearProcessInterval();
          this.setError(err);
        });
      }
    )
    .catch((err) => {
      console.error(err);
      this.setState({loading: false});
      this.clearProcessInterval();
      this.setError(err);
    });

  }

  componentDidUpdate() {
    const MIN_HEADER_HEIGHT = 120;
    if (!this.tocInitialized && !this.state.loading && this.state.result) {
      tocbot.init({
        tocSelector: '.summary__nav',           // where to render the table of contents
        contentSelector: '.summary__display',   // where to grab the headings to build the table of contents
        headingSelector: 'h2, h3',              // which headings to grab inside of the contentSelector element
        positionFixedSelector: '.summary__nav', // element to add the positionFixedClass to
        collapseDepth: 0,                       // how many heading levels should not be collpased
        includeHtml: true                       // include the HTML markup from the heading node, not just the text,
        ,headingsOffset: MIN_HEADER_HEIGHT,
        scrollSmoothOffset: -1 * MIN_HEADER_HEIGHT,
        throttleTimeout: 50,
      });

      this.tocInitialized = true;
    }
    //page title
    document.title = "COSRI";
    this.handleHeaderPos();

  }
  /*
   * fixed header when scrolling in the event that it is not within viewport
   */
  handleHeaderPos() {
    window.requestAnimationFrame(() => {
      document.addEventListener("scroll", function(e) {
        if (!isInViewport(document.querySelector("#anchorTop"))) {
          document.querySelector("body").classList.add("fixed");
          return;
        }
        document.querySelector("body").classList.remove("fixed");
      });
    });
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
        summaryMap[key].dataSource.forEach(item => {
          promiseResultSet.push(item);
        });
      }
    }

    if (!promiseResultSet.length) {
      return dataSet;
    }

    let results = await Promise.all(promiseResultSet.map(item => {
      return this.fetchData(this.processEndPoint(item.endpoint), item.dataKey, item.dataKey)
    })).catch(e => {
      console.log(`Error parsing external data response json: ${e.message}`);
      promiseResultSet.forEach(item => {
        dataSet[item.dataKeySource] = null;
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
      if (!dataSet[item.dataKeySource]) {
        dataSet[item.dataKeySource] = {}
      }
      dataSet[item.dataKeySource][item.dataKey] = result[item.dataKey] ? result[item.dataKey]: result;

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
                  //this prevents addition of duplicate alert text
                  let alertTextExist = alerts.filter(item => item.name === subitem.subSection.name && item.flagText === subitem.flagText);
                  if (!alertTextExist.length && subitem.flagText) {
                    alerts.push({
                      id: subitem.subSection.dataKey,
                      name: subitem.subSection.name,
                      flagText: subitem.flagText,
                      text: subitem.flagText + (subitem.flagDateText ? ` (${datishFormat('',subitem.flagDateText)})`: ""),
                      priority: subitem.priority || 100
                    });
                  }
                });
              } else {
                if (subsection[1].flagText) {
                  alerts.push({
                    id: subsection[1].subSection.dataKey,
                    name: subsection[1].subSection.name,
                    text: subsection[1].flagText,
                    priority: subsection[1].priority || 100
                  });
                }
              }
            }
          }
        }
      }
    }
    alerts.sort(function (a, b) {
      return a.priority - b.priority;
    });
     //process graph data
    let graphConfig = overviewSection.graphConfig;
    if (!(graphConfig && graphConfig.summaryDataSource)) {
      return;
    }
    //get the data from summary data
    let sections = graphConfig.summaryDataSource;
    let graph_data = [];
    if (getEnv(graphConfig.demoConfigKey)) {
      graph_data = graphConfig.demoData;
      summary[overviewSectionKey+"_graph"] = graph_data;
    } else {
      sections.forEach(item => {
        if (summary[item.section_key] && summary[item.section_key][item.subSection_key]) {
          graph_data = [...graph_data, ...summary[item.section_key][item.subSection_key]];
        }
      });
      const [startDateFieldName, endDateFieldName, MMEValueFieldName, graphDateFieldName] = [graphConfig.startDateField, graphConfig.endDateField, graphConfig.mmeField, graphConfig.graphDateField];
      const START_DELIMITER_FIELD_NAME = "start_delimiter";
      const END_DELIMITER_FIELD_NAME = "end_delimiter";
      const PLACEHOLDER_FIELD_NAME = "placeholder";

      //sort data by start date
      graph_data = graph_data.filter(function(item) {
        return item[startDateFieldName] && item[endDateFieldName];
      }).sort(function(a, b) {
        return dateCompare(a[startDateFieldName], b[startDateFieldName]);
      });

      let dataPoints = [];
      let prevObj = null, nextObj = null;
      graph_data.forEach(function(currentMedicationItem, index) {
        let dataPoint = {};
        let startDate = extractDateFromGMTDateString(currentMedicationItem[startDateFieldName]);
        let endDate = extractDateFromGMTDateString(currentMedicationItem[endDateFieldName]);
        let oStartDate = new Date(startDate);
        let diffDays = getDiffDays(startDate, endDate);
        nextObj = (index+1) <= graph_data.length-1 ? graph_data[index+1]: null;

        //add start date data point
        dataPoint = {};
        dataPoint[graphDateFieldName] = currentMedicationItem[startDateFieldName];
        dataPoint[MMEValueFieldName] = currentMedicationItem[MMEValueFieldName];
        dataPoint[START_DELIMITER_FIELD_NAME] = true;
        dataPoint = {...dataPoint, ...currentMedicationItem};
        dataPoints.push(dataPoint);

        //add intermediate data points between start and end dates
        if (diffDays >= 2) {
          for (let index = 2; index <= diffDays; index++) {
            let dataDate = new Date(oStartDate.valueOf());
            dataDate.setTime(dataDate.getTime() + (index * 24 * 60 * 60 * 1000));
            dataDate = dateFormat("", dataDate, "YYYY-MM-DD");
            dataPoint = {};
            dataPoint[graphDateFieldName] = dataDate;
            dataPoint[MMEValueFieldName] = currentMedicationItem[MMEValueFieldName];
            dataPoint[PLACEHOLDER_FIELD_NAME] = true;
            dataPoint[startDateFieldName] = dataDate;
            dataPoint = {...dataPoint, ...currentMedicationItem};
            dataPoints.push(dataPoint);
          }
        }

        //add end Date data point
        dataPoint = {};
        dataPoint[graphDateFieldName] = currentMedicationItem[endDateFieldName];
        dataPoint[MMEValueFieldName] = currentMedicationItem[MMEValueFieldName];
        dataPoint[END_DELIMITER_FIELD_NAME] = true;
        dataPoint[PLACEHOLDER_FIELD_NAME] = true;
        dataPoint = {...dataPoint, ...currentMedicationItem};
        dataPoints.push(dataPoint);
        prevObj = currentMedicationItem;

      });

      //sort data by date
      dataPoints = dataPoints.sort(function(a, b) {
        return dateCompare(a[graphDateFieldName], b[graphDateFieldName]);
      });

      //get all available dates
      let arrDates = (dataPoints.map(item => item.date));
      arrDates = arrDates.filter((d, index) => {
        return arrDates.indexOf(d) === index;
      });

      //loop through graph data to ADD MME values for the ones occurring on the same date
      let cumMMEValue = 0;
      arrDates.forEach(pointDate => {
        cumMMEValue = 0;
        let matchedItems = dataPoints.filter(d => {
          return d.date === pointDate;
        });
        if (matchedItems.length <= 1) return true;
        matchedItems.forEach(o => {
          cumMMEValue += o[MMEValueFieldName];
        });
        dataPoints.forEach((dataPoint) => {
          if (dataPoint.date === pointDate) {
            dataPoint[MMEValueFieldName] = cumMMEValue;
          }
        });
      });
      prevObj = null;
      let finalDataPoints = [];
      dataPoints.forEach(function(currentDataPoint, index) {
        let dataPoint = {};
        nextObj = dataPoints[index+1] ? dataPoints[index+1]: null;
        if (!prevObj) {
          //add starting graph point
          dataPoint = {};
          dataPoint[graphDateFieldName] = currentDataPoint[graphDateFieldName];
          dataPoint[MMEValueFieldName] = 0;
          dataPoint[START_DELIMITER_FIELD_NAME] = true;
          dataPoint[PLACEHOLDER_FIELD_NAME] = true;
          finalDataPoints.push(dataPoint);
        }
        //overlapping data points
        if (prevObj && (prevObj[MMEValueFieldName] !== currentDataPoint[MMEValueFieldName])) {
          //add data point with older value for the previous med
          dataPoint = {};
          dataPoint[graphDateFieldName] = currentDataPoint[graphDateFieldName];
          dataPoint[MMEValueFieldName] = prevObj[MMEValueFieldName];
          dataPoint[PLACEHOLDER_FIELD_NAME] = true;
          finalDataPoints.push(dataPoint);
          finalDataPoints.push(currentDataPoint);
        } else if (prevObj && currentDataPoint[START_DELIMITER_FIELD_NAME] && dateNumberFormat(currentDataPoint[startDateFieldName]) > dateNumberFormat(prevObj[endDateFieldName])) {
          if (getDiffDays(prevObj[endDateFieldName], currentDataPoint[startDateFieldName]) > 1) {
              dataPoint = {};
              dataPoint[graphDateFieldName] = currentDataPoint[graphDateFieldName];
              //add 0 value dummy data point to denote start of med where applicable
              dataPoint[MMEValueFieldName] = 0;
              dataPoint[START_DELIMITER_FIELD_NAME] = true;
              dataPoint[PLACEHOLDER_FIELD_NAME] = true;
              finalDataPoints.push(dataPoint);
          }
          //add current data point
          finalDataPoints.push(currentDataPoint);
        }
        else if (nextObj && currentDataPoint[END_DELIMITER_FIELD_NAME] && (dateNumberFormat(currentDataPoint[endDateFieldName]) < dateNumberFormat(nextObj[startDateFieldName])) && (dateNumberFormat(currentDataPoint[endDateFieldName]) < dateNumberFormat(nextObj[endDateFieldName]))) {
            //add current data point
            finalDataPoints.push(currentDataPoint);
            if (getDiffDays(currentDataPoint[endDateFieldName], nextObj[startDateFieldName]) > 1) {
              dataPoint = {};
              dataPoint[graphDateFieldName] = currentDataPoint[graphDateFieldName];
              //add 0 value dummy data point to denote end of med where applicable
              dataPoint[MMEValueFieldName] = 0;
              dataPoint[END_DELIMITER_FIELD_NAME] = true;
              dataPoint[PLACEHOLDER_FIELD_NAME] = true;
              finalDataPoints.push(dataPoint);
            }
        }
        else {
            finalDataPoints.push(currentDataPoint);
        }

        if (!nextObj) {
          //add ending graph point
          dataPoint = {};
          dataPoint[graphDateFieldName] = currentDataPoint[graphDateFieldName];
          dataPoint[MMEValueFieldName] = 0;
          dataPoint[END_DELIMITER_FIELD_NAME] = true;
          dataPoint[PLACEHOLDER_FIELD_NAME] = true;
          finalDataPoints.push(dataPoint);
        }
        prevObj = finalDataPoints[finalDataPoints.length-1];
      });
      console.log("graph data ", finalDataPoints);
      let formattedData = (JSON.parse(JSON.stringify(finalDataPoints))).map(point => {
        let o = {};
        o[graphDateFieldName] = point[graphDateFieldName];
        o[MMEValueFieldName] = parseFloat(point[MMEValueFieldName]).toFixed(2);
        if (point[PLACEHOLDER_FIELD_NAME]) {
          o[PLACEHOLDER_FIELD_NAME] = point[PLACEHOLDER_FIELD_NAME];
        }
        return o;
      });
      summary[overviewSectionKey+"_graph"] = formattedData;
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
        const alertMapping = subSection.alertMapping || {};

        if (entries.length > 0) {
          sectionFlags[sectionKey][subSection.dataKey] = entries.reduce((flaggedEntries, entry) => {
            if (entry._id == null) {
              entry._id = generateUuid();
            }
            const entryFlag = flagit(entry, subSection, summary);
            if (entryFlag) {
              flaggedCount += 1;
              let flagDateField = alertMapping.dateField ? alertMapping.dateField : null;

              flaggedEntries.push({
                'entryId': entry._id,
                'entry': entry, 'subSection': subSection,
                'flagText': entryFlag,
                'flagCount': flaggedCount,
                'flagDateText': entry && entry[flagDateField] ? entry[flagDateField]: "",
                'priority': alertMapping.priority? alertMapping.priority : 0});
            }

            return flaggedEntries;
          }, []);
        } else {

          const sectionFlagged = flagit(null, subSection, summary);
         // console.log("subSection? ", subSection, " flagged? ", sectionFlagged)
          if (sectionFlagged) {
            flaggedCount += 1;
            sectionFlags[sectionKey][subSection.dataKey] = [{
              'flagText': sectionFlagged,
              'flagCount': flaggedCount,
              'subSection': subSection,
              'priority': alertMapping.priority? alertMapping.priority : 0
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
      return <Spinner loadingMessage={this.state.loadingMessage}/>;
    }

    const PATIENT_SEARCH_URL = getEnv("REACT_APP_DASHBOARD_URL");

    if (this.state.result == null) {
      return (
        <div className="banner error">
          <div>
            <FontAwesomeIcon icon="exclamation-circle" title="error" /> Error: See console for details.
          </div>
          <div className="banner__linkContainer">
            <a href={PATIENT_SEARCH_URL}>Back to Patient Search</a>
          </div>
        </div>
      );
    }
    const patientResource = this.state.collector[0]['data'];
    const summary = this.state.result.Summary;
    const { sectionFlags } = this.state;

    return (
      <div className="landing">
        <div id="anchorTop"></div>
        <div id="skiptocontent"><a href="#maincontent">skip to main content</a></div>

        <Header
          patientName={summary.Patient.Name}
          patientDOB={datishFormat(this.state.result,patientResource.birthDate)}
          patientGender={summary.Patient.Gender}
          meetsInclusionCriteria={summary.Patient.MeetsInclusionCriteria}
          patientSearchURL={PATIENT_SEARCH_URL}
        />

        <Summary
          summary={summary}
          sectionFlags={sectionFlags}
          collector={this.state.collector}
          errorCollection={this.errorCollection}
          result={this.state.result}
          versionString={getEnv("REACT_APP_VERSION_STRING")}
        />
        <ReactTooltip className="summary-tooltip" id="summaryTooltip" />
      </div>
    );
  }
}
