import React, { Component } from 'react';
import PropTypes from 'prop-types';
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome';

export default class Header extends Component {

  constructor() {
    super(...arguments);
    this.state = {
      patientSearchURL: ""
    };
  }
  componentDidMount() {
    this.setState({
      patientSearchURL: this.props["patientSearchURL"]
    });
  }
  handleSearchClick(e) {
    //clear current frontend session
    sessionStorage.clear();
    let url = e.target.getAttribute("data-url");
    setTimeout(() => {
      window.location = url;
    }, 0);
  }
  render() {
    const {
      patientName, patientDOB, patientGender, patientSearchURL
    } = this.props;

    return (
      <header className="header">
        <div className="header__logo">
          <img className="header__logo-img primary" src={process.env.PUBLIC_URL + "/assets/images/logo_horizontal.png"} alt="cds connect logo" />
          <div className="header__tagline-text">
            <div className="entry">
              <span className="header__logo-text--light">built with </span>
            </div>
            <div className="entry">
              <a href="https://cds.ahrq.gov" target="_blank" rel="noopener noreferrer"><img className="header__logo-img secondary" src={process.env.PUBLIC_URL + "/assets/images/cds_connect_logo.png"} alt="cds connect logo" /></a> <span className="header__logo-text">CDS Connect</span>
              <a href="https://www.ahrq.gov/" target="_blank" rel="noopener noreferrer"><img className="header__logo-img terciary" src={process.env.PUBLIC_URL + "/assets/images/AHRQ_logo.png"} alt="ahrq connect logo" /></a>
            </div>
          </div>
        </div>
        <div className="header__summary">
          <div className="header__summary-patient">
            <FontAwesomeIcon className="patient-icon" icon="user-circle" title="patient" />
            <div className="patient-info">
              <h1 className="patient-name">{patientName}</h1>

              <div className="patient-demographics">
                <span className="patient-dob" aria-label="Date of birth">DOB: {patientDOB}</span>
                <span className="patient-gender">{patientGender}</span>
              </div>
            </div>
            <div className="header__search">
                <button className={`button-primary ${!this.state.patientSearchURL?"disabled":""}`} onClick={this.handleSearchClick} data-url={patientSearchURL}disabled={this.state.patientSearchURL?false:true}>New Patient Search</button>
            </div>
          </div>
			    <div className="header__summary-dashboard">
            <div className="entries">
              <img src={process.env.PUBLIC_URL + "/assets/images/doh_logo.png"} alt="doh logo" />
            </div>
          </div>
        </div>
      </header>
    );
  }
}

Header.propTypes = {
  patientName: PropTypes.string.isRequired,
  patientDOB: PropTypes.string.isRequired,
  patientGender: PropTypes.string.isRequired,
  patientSearchURL: PropTypes.string
};
