#![forbid(unsafe_code)]
use log::{debug, error, info, trace, warn};

fn main() {
    acap_logging::init_logger();
    trace!("Hello trace!");
    debug!("Hello debug!");
    info!("Hello info!");
    warn!("Hello warn!");
    error!("Hello error!");
}
