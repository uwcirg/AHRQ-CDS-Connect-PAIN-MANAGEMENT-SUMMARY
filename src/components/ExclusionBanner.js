import React, { Component } from 'react';
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome';
import ChevronDownIcon from '../icons/ChevronDownIcon';

export default class ExclusionBanner extends Component {
  constructor() {
    super(...arguments);
    this.state = {
      displayed: true
    };
    this.handleCloseToggle= this.handleCloseToggle.bind(this);
  }

  handleClose = () => {
    this.setState({ displayed: false });
  }

  handleCloseToggle(e) {
    e.preventDefault();
    this.setState(state => ({
      displayed: !state.displayed
    }));
  }

  render() {
    const conditionalClass = this.state.displayed ? '': 'close';
    return (
      <div
        className={`exclusion-banner banner ${conditionalClass}`}
        role="banner"
        onClick={this.handleCloseToggle}>
        <ChevronDownIcon className="close-button" icon="times" title="close"  width="25" height="25" />

        <div className="exclusion-banner__description">
          <strong className="title"><FontAwesomeIcon icon="exclamation-circle" title="notice" /> LIMITATIONS</strong> <span className="content">Guidance <b><u>not intended</u></b> for <b>palliative</b>, <b>inpatient</b>, or <b>active cancer care</b>.</span>
        </div>
      </div>
    );
  }
}
