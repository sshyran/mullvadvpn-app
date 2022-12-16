use nix::sys::socket::{socket, AddressFamily, SockFlag, SockType, SockaddrLike};
use std::io::Result;

mod data;

/// Watch routes
pub fn watch_routes() -> Result<()> {
    // let sock = socket(AddressFamily::Route, SockType::Raw, SockFlag::empty(), None)?;

    // // let fd = AsyncFd::new(sock)?;
    // let mut buf = [0u8; 2048];

    // loop {
    // let bytes_read = nix::unistd::read(sock, &mut buf)?;
    // let msg_buf = &buf[0..bytes_read];
    // println!("Received a message {} bytes long", msg_buf.len());
    parse_msg(REMOVE_ROUTE_MSG);
    Ok(())
    // }
}

fn parse_msg(buf: &[u8]) {
    test_remove_route_inner();
    let msg = data::RouteMessage::parse_message(buf);
    match &msg {
        Ok(data::RouteMessage::AddRoute(route)) => {
            println!(
                "================================================================================"
            );
            println!("add route");
            route.print_route();
            println!("");
        }
        Ok(data::RouteMessage::DeleteRoute(route)) => {
            println!(
                "================================================================================"
            );
            println!("msg {:?}", buf);
            println!("delete route");
            let addrs = route.route_addrs().collect::<Vec<_>>();
            println!("route-addrs = {}", addrs.len());
            route.print_route();
            println!("");
        }
        Err(err) => {
            println!("err - {:?}", err);
        }
        // ignoring other kinds of route messages
        _ => {
            return;
        }
    };
}

const REMOVE_ROUTE_MSG: &[u8] = &[
    164, 0, 5, 2, 11, 0, 0, 0, 66, 8, 1, 67, 55, 0, 0, 0, 64, 1, 0, 0, 71, 8, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 220, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    16, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 16, 2, 0, 0, 192, 168, 185, 1, 11, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 20, 18, 11, 0, 6, 3, 6, 0, 101, 110, 48, 60, 6, 48, 3, 54, 249, 0, 0, 0,
    16, 2, 0, 0, 192, 168, 185, 116, 0, 0, 0, 0, 0, 0, 0, 0,
];

#[test]
fn test_remove_route() {
    test_remove_route_inner()
}

/// the source of insanity
pub fn test_remove_route_inner() {
    match data::RouteMessage::parse_message(REMOVE_ROUTE_MSG).unwrap() {
        data::RouteMessage::DeleteRoute(route) => {
            let addrs = route.route_addrs().collect::<Vec<_>>();
            assert_eq!(addrs.len(), 2);
        }
        unexpected => {
            panic!("unexpected type of route message {:?}", unexpected);
        }
    }
}
