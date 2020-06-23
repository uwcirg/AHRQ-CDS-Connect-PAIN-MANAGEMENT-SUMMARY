import React, { Component } from 'react';
import PropTypes from 'prop-types';
import ChevronDownIcon from '../icons/ChevronDownIcon';
import IframeElement from '../elements/Iframe';


export default class Video extends Component {
  constructor(props) {
    super(props);
    this.state = {
      isToggleOn: false
    };
    // This binding is necessary to make `this` work in the callback
    this.handleClick = this.handleClick.bind(this);
    this.iframeRef = React.createRef();
  }

  handleClick(e) {
    e.preventDefault();
    /*
     * dynamically assigned src to iframe
     * only assign when it hasn't been assigned
     */
    if (!(this.iframeRef.current).src) {
      setTimeout(function() {
        (this.iframeRef.current).src = this.props.src;
      }.bind(this), 5);
    }
    this.setState(state => ({
      isToggleOn: !state.isToggleOn
    }));
  }

  render() {
    const {
      title, toggleable
    } = this.props;

    /*
     * responsive iframe style
     */
    const IframeStyle = {
      position: 'absolute',
      top: 0,
      left: 0,
      width: '100%',
      height: '100%'
    };

    const VideoContainerStyle = {
      position: 'relative',
      paddingBottom: '56.25%' /* 16:9 */,
      height: 0
    };

    if (!toggleable) {
      return (<IframeElement title={title} style={IframeStyle} ref={this.iframeRef} />);
    }
    const VideoElement = React.forwardRef((props, ref) => (
      <IframeElement {...props} forwardRef={ref}/>
    ));

    return (
      <div>
        {/* element for toggling the visibility of video */}
        <span title={title} onClick={this.handleClick} className='video-link'>{title}</span>
        <ChevronDownIcon
          className={`${this.state.isToggleOn?'open': ''} link-toggle`}
          onClick={this.handleClick}
          width='15'
          height='15'
        />
        <div className={`${this.state.isToggleOn?'show': 'hide'} video-container`}>
          <div
            className='video'
            style={VideoContainerStyle}
          >
          <span>loading...</span>
          <VideoElement ref={this.iframeRef} title={title} style={IframeStyle}  frameBorder="0"
          id="ifVideo" allowFullScreen></VideoElement>
          </div>
        </div>
      </div>
    );
  }
}
Video.propTypes = {
  title: PropTypes.string.isRequired,
  src: PropTypes.string.isRequired,
  toggleable: PropTypes.bool
};
