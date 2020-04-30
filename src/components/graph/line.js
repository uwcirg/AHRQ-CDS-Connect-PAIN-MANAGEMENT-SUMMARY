import React from 'react';
import { select } from 'd3-selection';
import { transition } from 'd3-transition';

class Line extends React.Component {
  constructor() {
    super();
    this.ref = React.createRef();
    this.state = {
      xName: "",
      yName: ""
    }
  }
  componentDidMount() {
    const node = this.ref.current;
    const { data, lineGenerator, xName, yName } = this.props;
    
    this.setState({
      xName: xName,
      yName: yName
    });

    let currentNode = select(node)
      .append('path')
      .datum(data)
      .attr('id', this.props.lineID)
      .attr('stroke', this.props.strokeColor || "#217684")
      .attr('stroke-width', this.props.strokeWidth || 2)
      .attr('fill', 'none')
      .attr('d', lineGenerator);
    if (this.props.dotted) {
      currentNode.style("stroke-dasharray", (this.props.dotSpacing || "3, 3"))  // <== This line here!!
    }

    this.updateChart()
  }
  componentDidUpdate() {
    this.updateChart();
  }
  updateChart() {
    const {
          lineGenerator, data,
        } = this.props;

    const t = transition().duration(1000);

    const line = select('#line');

    line
      .datum(data)
      .transition(t)
      .attr('d', lineGenerator);

  }
  render() {
    return <g className={this.props.className} ref={this.ref} />;
  }
}

export default Line;