import React, { Component } from 'react';
import PropTypes from 'prop-types';
import { scaleLinear, scaleTime } from 'd3-scale';
import { line } from 'd3-shape';
import XYAxis from './xy-axis';
import Line from './line';

const defaultFields = {
  x: "date",
  y: "MMEValue"
};
const xFieldName = defaultFields.x;
const yFieldName = defaultFields.y;
export default class MMEGraph extends Component {

  getDefaultDataValueSet(value, minDate, maxDate, total, xFieldName, yFieldName) {
    let data = [];
    value = value || 0;
    total = total || 8;
    xFieldName = xFieldName || defaultFields.x;
    yFieldName = yFieldName || defaultFields.y;

    if (!maxDate) {
      maxDate = new Date();
    }
    if (!minDate) {
      minDate = new Date();
      minDate.setDate(maxDate.getDate() - total * 30);
    }
    let index = 0;
    let increment = Math.ceil((maxDate.getTime() - minDate.getTime()) / total);

    while(index <= total) {
      let addTime = minDate.getTime() + increment*index;
      let item = {};
      item[xFieldName] = new Date(addTime);
      item[yFieldName] = value;
      data.push(item);
      index++;
    }
    return data;
  }
  compareDate(a, b) {
    let calcA = (new Date(a[xFieldName])).getTime();
    let calcB = (new Date(b[xFieldName])).getTime();
    if (calcA > calcB) return 1;
    if (calcB > calcA) return -1;
    return 0;
  }

  getMaxMMEValue(data) {
    let maxValue =  0;
    //let CAP_MAX_VALUE = 1500;
    data.forEach(item => {
     // if (item["MMEValue"] > CAP_MAX_VALUE) return true;
      maxValue = Math.max(maxValue, item["MMEValue"]);
    });
    return maxValue;
  }

  render() {
    /*
     *  example data format: [{"dateWritten":"2019-04-15","MMEValue":40}, {"dateWritten":"2019-04-15","MMEValue":40}]
     */
    let maxDate = new Date();
    let minDate = new Date();
    let baseLineDate = new Date();
    minDate.setDate(maxDate.getDate() - 365);
    const parentWidth = 500;
    const WA_MAX_VALUE = 120;
    const CDC_SECONDARY_MAX_VALUE = 50;
    const CDC_MAX_VALUE = 90;
    const xIntervals = 8;
    let lineParamsSet = [xIntervals, xFieldName, yFieldName];
    //make a copy of the data so as not to accidentally mutate it
    //need to make sure the dates are sorted for line to draw correctly
    let computedData = this.props.data? (this.props.data).map(item => {
      return {
        ...item
      }
    }): null;
    //let data = computedData? (computedData).sort(this.compareDate): [];
    //let data  = computedData || this.getDefaultDataValueSet(0, minDate, maxDate, ...lineParamsSet);
    let data = computedData || [];
    let noEntry = !data || !data.length;
    data = data.filter(d => d[xFieldName]);
    data = data.map(d => {
      let dObj = new Date(d[xFieldName]);
      let tzOffset = dObj.getTimezoneOffset() * 60000;
      dObj.setTime(dObj.getTime() + tzOffset);
      d[xFieldName] = dObj;
      return d;
    });
    let arrayDates = data.map(d => {
      return d[xFieldName];
    });
    if (arrayDates.length) {
      maxDate = new Date(Math.max.apply(null, arrayDates))
      minDate = new Date(Math.min.apply(null, arrayDates));
    }
    //console.log("maxDate: ", maxDate, " minDate ", minDate)
    const diffTime = Math.abs(maxDate - minDate);
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
   // if (arrayDates.length < (xIntervals - 2)) {
    if (diffDays <= 60 && arrayDates.length < (xIntervals - 2)) {
      /*
       * make sure graph has appropiate end points on the graph if the total count of data points is less than the initial set number of intervals
       */
      let calcMinDate = new Date(minDate.valueOf());
      let calcMaxDate = new Date(maxDate.valueOf());
      minDate = calcMinDate.setDate(calcMinDate.getDate() - (30 * ((xIntervals-arrayDates.length)/2-1)));
      maxDate = calcMaxDate.setDate(calcMaxDate.getDate() + (30 * ((xIntervals-arrayDates.length)/2-1)));
      maxDate = new Date(maxDate);
      minDate = new Date(minDate);
      //console.log("min date ", minDate, " max date ", maxDate)
    }
    /*
     * set up baseline data point starting at 0
     */
    if (arrayDates.length) {
      baseLineDate.setTime(new Date(minDate.valueOf()).getTime() - (30 * 24 * 60 * 60 * 1000));
      let baselineItem = {};
      baselineItem[xFieldName] = baseLineDate;
      baselineItem[yFieldName] = 0;
      baselineItem["baseline"] = true;
      baselineItem["placeholder"] = true;
      data.unshift(baselineItem);
    }

    let WAData = this.getDefaultDataValueSet(WA_MAX_VALUE, baseLineDate, maxDate, ...lineParamsSet);
    let CDCSecondaryData = this.getDefaultDataValueSet(CDC_SECONDARY_MAX_VALUE, baseLineDate, maxDate, ...lineParamsSet);
    let CDCData = this.getDefaultDataValueSet(CDC_MAX_VALUE, baseLineDate, maxDate, ...lineParamsSet);

    const margins = {
      top: 20,
      right: 48,
      bottom: 48,
      left: 52,
    };

    const width = parentWidth - margins.left - margins.right;
    const height = 300 - margins.top - margins.bottom;
    const xScale = scaleTime().domain([baseLineDate, maxDate]).rangeRound([0, width]);
    const yMaxValue = Math.max(140, this.getMaxMMEValue(data));
    const yScale = scaleLinear()
      .domain([0, yMaxValue])
      .range([height, 0])
      .nice();

    const lineGenerator = line()
      .x(d => xScale(d[xFieldName]))
      .y(d => yScale(d[yFieldName]));


    const defaultProps = {
        xScale: xScale,
        yScale: yScale,
        lineGenerator: lineGenerator,
        width: width,
        height: height,
        xName: xFieldName,
        yName: yFieldName
    };
    const dataStrokeColor = "#168698";
    const additionalProps = {
      "strokeColor": dataStrokeColor,
      "strokeFill": dataStrokeColor,
      "strokeWidth": "2.25"
    };
    additionalProps["dataPoints"] = {
        ...additionalProps,
        ...{
          "dataStrokeWidth": "2.5",
          "dataStrokeFill": dataStrokeColor
        }
    };

    const xSettings = {
      scale: xScale,
      orient: 'bottom',
      transform: `translate(0, ${height})`,
      tickFormat: "%b %Y",
      tickType: "date",
      tickInterval: diffDays <= 360 ? 1 : 2,
      ticks: xIntervals
    };
    const ySettings = {
      scale: yScale,
      orient: 'left',
      transform: 'translate(0, 0)',
      ticks: 10
    };

    const defaultLegendSettings = {
      "fontFamily": "sans-serif",
      "fontSize": yMaxValue >= 600 ? "8px": "12px",
      "fontWeight": "600",
      "letterSpacing": "0.02rem",
      "x": xScale(baseLineDate) + 8
    };

    const WA_COLOR = "#a75454";
    const CDC_COLOR = "#c57829";
    const textMargin = 4;
    const WALegendSettings = {
      "y": yScale(120 + textMargin),
      "fill": WA_COLOR,
      ...defaultLegendSettings
    };
    const CDCLegendSettings = {
      "fill": CDC_COLOR,
      ...defaultLegendSettings
    }

    const dataLineProps = {...defaultProps, ...additionalProps};
    const graphWidth = width + margins.left + margins.right;
    const graphHeight = height + margins.top + margins.bottom;
    if (noEntry) {
      return  (<div className="MMEgraph no-entry">
                <div className="title">Morphine Equivalent Dose (MED)</div>
                <div className="no-entry">No graph data available</div>
              </div>);
    }
    return (
      <div className="MMEgraph">
        <div className="title">Morphine Equivalent Dose (MED)</div>
        <div className="MME-svg-container">
          <svg
            className="MMEChartSvg"
            // width={width + margins.left + margins.right}
            // height={height + margins.top + margins.bottom}
            //preserveAspectRatio="xMinYMin meet"
            width="100%"
            height="100%"
            viewBox = {`0 0 ${graphWidth} ${graphHeight}`}
          >
            <g transform={`translate(${margins.left}, ${margins.top})`}>
              <XYAxis {...{xSettings, ySettings}} />
              <Line lineID="dataLine" data={data} {...dataLineProps} />
              <Line lineID="WALine" strokeColor={WA_COLOR} dotted="true" dotSpacing="3, 3" data={WAData} {...defaultProps} />
              <Line lineID="CDCSecondaryLine" strokeColor={CDC_COLOR} dotted="true" dotSpacing="3, 3" data={CDCSecondaryData} {...defaultProps} />
              <Line lineID="CDCLine" strokeColor={CDC_COLOR} dotted="true" dotSpacing="3, 3" data={CDCData} {...defaultProps} />
              <text {...WALegendSettings}>Washington State consultation threshold</text>
              <text {...CDCLegendSettings} y={yScale(50 + textMargin)}>CDC extra precautions threshold</text>
              <text {...CDCLegendSettings} y={yScale(90 + textMargin)}>CDC avoid/justify threshold</text>
            </g>
          </svg>
        </div>
      </div>
    );
  }
}

MMEGraph.propTypes = {
  data: PropTypes.array
};
