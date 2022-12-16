use std::ffi::{OsStr, OsString};

use nix::sys::socket::{SockAddr, SockaddrLike, SockaddrStorage};

#[derive(Debug)]
pub enum RouteMessage<'a> {
    Interface(Interface<'a>),
    DeleteRoute(Route<'a>),
    AddRoute(Route<'a>),
    Other {
        header: &'a rt_msghdr_short,
        payload: &'a [u8],
    },
}

#[derive(Debug)]
pub enum Error {
    /// Payload buffer didn't match the reported message size in header
    InvalidBuffer(usize, usize),
    /// Buffer too small for specific message type
    BufferTooSmall(&'static str, usize),
    /// Unrecognized message
    UnknownMessageType(u8),
    /// Unrecognized address flag
    UnknownAddressFlag(AddressFlag),
}

type Result<T> = std::result::Result<T, Error>;

impl<'a> RouteMessage<'a> {
    pub fn parse_message(buffer: &'a [u8]) -> Result<Self> {
        match rt_msghdr_short::from_bytes(buffer) {
            Some(header) if header.is_type(libc::RTM_IFINFO) => Ok(RouteMessage::Interface(
                Interface::from_byte_buffer(buffer)?,
            )),
            Some(header) if header.is_one_of(&[libc::RTM_ADD, libc::RTM_DELETE]) => {
                let route = Route::from_byte_buffer(buffer)?;
                let msg = if route.is_add() {
                    Self::AddRoute(route)
                } else {
                    Self::DeleteRoute(route)
                };
                Ok(msg)
            }
            Some(header) => Ok(Self::Other {
                header,
                payload: buffer,
            }),
            None => Err(Error::BufferTooSmall("rt_msghdr_short", buffer.len())),
        }
    }
}

/// hush, this will come in later
fn align_to_nearest_u32(idx: usize) -> usize {
    if idx > 0 {
        1 + (((idx) - 1) | (std::mem::size_of::<u32>() - 1))
    } else {
        std::mem::size_of::<u32>()
    }
}

pub struct Interface<'a> {
    header: &'a libc::if_msghdr,
    payload: &'a [u8],
}

impl<'a> std::fmt::Debug for Interface<'a> {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let if_data = f
            .debug_struct("if_data")
            .field("ifi_type", &self.header.ifm_data.ifi_type)
            .field("ifi_typelen", &self.header.ifm_data.ifi_typelen)
            .field("ifi_physical", &self.header.ifm_data.ifi_physical)
            .field("ifi_addrlen", &self.header.ifm_data.ifi_addrlen)
            .field("ifi_hdrlen", &self.header.ifm_data.ifi_hdrlen)
            .field("ifi_recvquota", &self.header.ifm_data.ifi_recvquota)
            .field("ifi_xmitquota", &self.header.ifm_data.ifi_xmitquota)
            .field("ifi_unused1", &self.header.ifm_data.ifi_unused1)
            .field("ifi_mtu", &self.header.ifm_data.ifi_mtu)
            .field("ifi_metric", &self.header.ifm_data.ifi_metric)
            .field("ifi_baudrate", &self.header.ifm_data.ifi_baudrate)
            .field("ifi_ipackets", &self.header.ifm_data.ifi_ipackets)
            .field("ifi_ierrors", &self.header.ifm_data.ifi_ierrors)
            .field("ifi_opackets", &self.header.ifm_data.ifi_opackets)
            .field("ifi_oerrors", &self.header.ifm_data.ifi_oerrors)
            .field("ifi_collisions", &self.header.ifm_data.ifi_collisions)
            .field("ifi_ibytes", &self.header.ifm_data.ifi_ibytes)
            .field("ifi_obytes", &self.header.ifm_data.ifi_obytes)
            .field("ifi_imcasts", &self.header.ifm_data.ifi_imcasts)
            .field("ifi_omcasts", &self.header.ifm_data.ifi_omcasts)
            .field("ifi_iqdrops", &self.header.ifm_data.ifi_iqdrops)
            .field("ifi_noproto", &self.header.ifm_data.ifi_noproto)
            .field("ifi_recvtiming", &self.header.ifm_data.ifi_recvtiming)
            .field("ifi_xmittiming", &self.header.ifm_data.ifi_xmittiming)
            .field(
                "ifi_lastchange",
                &(
                    self.header.ifm_data.ifi_lastchange.tv_sec,
                    self.header.ifm_data.ifi_lastchange.tv_usec,
                ),
            )
            .field("ifi_unused2", &self.header.ifm_data.ifi_unused2)
            .field("ifi_hwassist", &self.header.ifm_data.ifi_hwassist)
            .field("ifi_reserved1", &self.header.ifm_data.ifi_reserved1)
            .field("ifi_reserved2", &self.header.ifm_data.ifi_reserved2)
            .finish();
        let header = f
            .debug_struct("if_msghdr")
            .field("ifm_msglen", &self.header.ifm_msglen)
            .field("ifm_version", &self.header.ifm_version)
            .field("ifm_type", &self.header.ifm_type)
            .field("ifm_addrs", &self.header.ifm_addrs)
            .field("ifm_flags", &self.header.ifm_flags)
            .field("ifm_index", &self.header.ifm_index)
            .field("ifm_data", &if_data)
            .finish()?;
        f.debug_struct("Interface")
            .field("header", &header)
            .field("payload", &self.payload)
            .finish()
    }
}

impl<'a> Interface<'a> {
    fn from_byte_buffer(buffer: &'a [u8]) -> Result<Self> {
        const header_size: usize = std::mem::size_of::<libc::if_msghdr>();
        if header_size > buffer.len() {
            return Err(Error::BufferTooSmall("if_msghdr", header_size));
        }
        let header = unsafe { &*(buffer.as_ptr() as *const libc::if_msghdr) };
        let payload = &buffer[header_size..header.ifm_msglen.into()];
        Ok(Self { header, payload })
    }
}

// #define RTA_DST         0x1     /* destination sockaddr present */
// #define RTA_GATEWAY     0x2     /* gateway sockaddr present */
// #define RTA_NETMASK     0x4     /* netmask sockaddr present */
// #define RTA_GENMASK     0x8     /* cloning mask sockaddr present */
// #define RTA_IFP         0x10    /* interface name sockaddr present */
// #define RTA_IFA         0x20    /* interface addr sockaddr present */
// #define RTA_AUTHOR      0x40    /* sockaddr for author of redirect */
// #define RTA_BRD         0x80    /* for NEWADDR, broadcast or p-p dest addr */
bitflags::bitflags! {
    /// All enum values of address flags can be iterated via `flag <<= 1`, starting from 1.
    pub struct AddressFlag: i32 {
        /// Destination socket address
        const RTA_DST = 0x1;
        /// Gateway socket address
        const RTA_GATEWAY = 0x2;
        /// Netmask socket address
        const RTA_NETMASK = 0x4;
        /// Cloning mask socket address
        const RTA_GENMASK = 0x8;
        /// Interface name socket address
        const RTA_IFP = 0x10;
        /// Interface address socket address
        const RTA_IFA = 0x20;
        /// Socket address for author of redirect
        const RTA_AUTHOR = 0x40;
        /// Socket address for `NEWADDR`, broadcast or point-to-point destination address
        const RTA_BRD = 0x80;
    }
}

pub enum RouteSockAddress {
    /// Corresponds to RTA_DST
    Destination(Option<SockaddrStorage>),
    /// RTA_GATEWAY
    Gateway(Option<SockaddrStorage>),
    /// RTA_NETMASK
    Netmask(Option<SockaddrStorage>),
    /// RTA_GENMASK
    CloningMask(Option<SockaddrStorage>),
    /// RTA_IFP
    IfName(Option<SockaddrStorage>),
    /// RTA_IFA
    IfSockaddr(Option<SockaddrStorage>),
    /// RTA_AUTHOR
    RedirectAuthor(Option<SockaddrStorage>),
    /// RTA_BRD
    Broadcast(Option<SockaddrStorage>),
}

#[repr(C)]
#[derive(Copy, Clone)]
struct sockaddr_hdr {
    sa_len: u8,
    sa_family: libc::sa_family_t,
    padding: u16,
}

impl RouteSockAddress {
    // TODO: resultify this function
    pub fn new(flag: AddressFlag, buf: &[u8]) -> Result<(Self, usize)> {
        // to get the length and type of
        if buf.len() < std::mem::size_of::<sockaddr_hdr>() {
            return Err(Error::BufferTooSmall(
                "sockaddr buffer too small",
                buf.len(),
            ));
        }

        let addr_header_ptr = buf.as_ptr() as *const sockaddr_hdr;
        // safety - since `buf` is at least as long as a `sockaddr_hdr`, it's perfectly valid to
        // read from.
        let addr_header = unsafe { *addr_header_ptr };
        let saddr_len = addr_header.sa_len;
        if saddr_len == 0 {
            return Ok((Self::with_sockaddr(flag, None)?, 4));
        }

        if Into::<usize>::into(saddr_len) > buf.len() {
            return Err(Error::InvalidBuffer(saddr_len.into(), buf.len()));
        }

        // SAFETY: the buffer is big enough for the sockaddr struct inside it, so accessing as a
        // `sockaddr` is valid.
        let saddr = unsafe {
            SockaddrStorage::from_raw(
                addr_header_ptr as *const nix::libc::sockaddr,
                Some(saddr_len.into()),
            )
        };

        return Ok((Self::with_sockaddr(flag, saddr)?, saddr_len.into()));
    }

    fn with_sockaddr(flag: AddressFlag, sockaddr: Option<SockaddrStorage>) -> Result<Self> {
        let constructor = match flag {
            AddressFlag::RTA_DST => Self::Destination,
            AddressFlag::RTA_GATEWAY => Self::Gateway,
            AddressFlag::RTA_NETMASK => Self::Netmask,
            AddressFlag::RTA_GENMASK => Self::CloningMask,
            AddressFlag::RTA_IFP => Self::IfName,
            AddressFlag::RTA_IFA => Self::IfSockaddr,
            AddressFlag::RTA_AUTHOR => Self::RedirectAuthor,
            AddressFlag::RTA_BRD => Self::Broadcast,
            unknown => return Err(Error::UnknownAddressFlag(unknown)),
        };

        Ok(constructor(sockaddr))
    }
}

#[derive(Debug)]
pub struct Route<'a> {
    header: &'a rt_msghdr,
    payload: &'a [u8],
}

impl<'a> Route<'a> {
    pub fn print_route(&self) {
        for (addr, flag) in self.route_addrs() {
            print!("\t {flag:?} - {:?} - {addr} ", addr.family());
            if let Some(ifaddr) = addr.as_link_addr() {
                if let Some(name) = ifaddr.interface_name() {
                    print!(" name - {}", name.to_string_lossy());
                }
                print!(" if-idx - {}", ifaddr.ifindex());
            }
            println!("");
        }
        let len = self.route_addrs().collect::<Vec<_>>().len();
        println!("LEN OF route_addrs() - {len}");
        if self.route_addrs().next().is_none() {
            println!("\titer empty - {:?}", self);
        }
    }
}

pub struct SockAddrIterator<'a> {
    buffer: &'a [u8],
    flags: AddressFlag,
    cursor: i32,
}

impl<'a> SockAddrIterator<'a> {
    fn new(buffer: &'a [u8], flags: AddressFlag) -> Self {
        Self {
            buffer,
            flags,
            cursor: 1i32,
        }
    }

    fn next_offset(&self, saddr_len: u8) -> usize {
        // SAFETY: it's ok to calculate an offset of a base pointer without
        // dereferencing it. Ultimately, it will be used to index into
        // self.buffer, but only if it's safe to do so.
        let padding = unsafe {
            self.buffer
                .as_ptr()
                .offset(saddr_len.into())
                .align_offset(std::mem::align_of::<u32>())
        };
        usize::from(saddr_len).wrapping_add(padding)
    }
}

impl<'a> Iterator for SockAddrIterator<'a> {
    type Item = (SockaddrStorage, AddressFlag);

    fn next(&mut self) -> Option<Self::Item> {
        loop {
            // If address flags don't contain the current one, try the next one.
            // Will return None if it runs out of valid flags.
            let current_flag = AddressFlag::from_bits(self.cursor)?;
            self.cursor <<= 1;

            if !self.flags.contains(current_flag) {
                continue;
            }

            if self.buffer.len() < std::mem::size_of::<libc::sockaddr>() {
                log::error!(
                    "Buffer of insufficient size for a sockaddr - {}",
                    self.buffer.len()
                );
                return None;
            }
            // Safety - it's safe to cast the pointer to a `libc::sockaddr` since it's big enough.
            let addr_header = self.buffer.as_ptr() as *const nix::libc::sockaddr;
            // Safety - since the buffer was big enough to fit a sockadr_len, it's OK to read the
            // `sa_len` field from it.
            let sockaddr_len = unsafe { (*addr_header).sa_len };
            let next_offset = self.next_offset(sockaddr_len);

            // it is safe to assume that the the addr_header is a valid sockaddr, but if it does
            // exist, it should be cloned to ensure that the `sockaddr` is unbound by the lifetime
            // of the underlying buffer.
            let sockaddr = unsafe {
                SockaddrStorage::from_raw(addr_header, Some(sockaddr_len as u32))
                    .map(|sa| sa.clone())
            };
            match sockaddr {
                Some(addr) => {
                    self.buffer = &self.buffer[std::cmp::min(self.buffer.len(), next_offset)..];

                    return Some((addr, current_flag));
                }
                None => {
                    log::error!(
                        "Failed to decode a sockaddr for flag {:?} with buffer {:x?}, next_offset - {next_offset}, sockaddr_len = {sockaddr_len}",
                        current_flag, &self.buffer
                    );
                    return None;
                }
            }
        }
    }
}

impl<'a> Route<'a> {
    fn from_byte_buffer(buffer: &'a [u8]) -> Result<Self> {
        const header_size: usize = std::mem::size_of::<rt_msghdr>();
        if header_size > buffer.len() {
            return Err(Error::BufferTooSmall("if_msghdr", header_size));
        }
        let header = unsafe { &*(buffer.as_ptr() as *const rt_msghdr) };
        let payload = &buffer[header_size..header.rtm_msglen.into()];
        assert!(header_size + payload.len() == buffer.len());
        Ok(Self { header, payload })
    }

    pub fn route_addrs(&self) -> SockAddrIterator<'a> {
        match AddressFlag::from_bits(self.header.rtm_addrs.into()) {
            Some(flags) => SockAddrIterator::new(self.payload, flags),
            None => SockAddrIterator::new(&[], AddressFlag::empty()),
        }
    }

    fn is_add(&self) -> bool {
        Into::<i32>::into(self.header.rtm_type) == libc::RTM_ADD
    }

    fn is_remove(&self) -> bool {
        Into::<i32>::into(self.header.rtm_type) == libc::RTM_DELETE
    }
}

// struct rt_msghdr {
// 	u_short rtm_msglen;     /* to skip over non-understood messages */
// 	u_char  rtm_version;    /* future binary compatibility */
// 	u_char  rtm_type;       /* message type */
// 	u_short rtm_index;      /* index for associated ifp */
// 	int     rtm_flags;      /* flags, incl. kern & message, e.g. DONE */
// 	int     rtm_addrs;      /* bitmask identifying sockaddrs in msg */
// 	pid_t   rtm_pid;        /* identify sender */
// 	int     rtm_seq;        /* for sender to identify action */
// 	int     rtm_errno;      /* why failed */
// 	int     rtm_use;        /* from rtentry */
// 	u_int32_t rtm_inits;    /* which metrics we are initializing */
// 	struct rt_metrics rtm_rmx; /* metrics themselves */
// };
#[derive(Debug)]
#[repr(C)]
pub struct rt_msghdr {
    pub rtm_msglen: libc::c_ushort,
    pub rtm_version: libc::c_uchar,
    pub rtm_type: libc::c_uchar,
    pub rtm_index: libc::c_ushort,
    pub rtm_flags: libc::c_int,
    pub rtm_addrs: libc::c_int,
    pub rtm_pid: libc::pid_t,
    pub rtm_seq: libc::c_int,
    pub rtm_errno: libc::c_int,
    pub rtm_use: libc::c_int,
    pub rtm_inits: u32,
    pub rtm_rmx: rt_metrics,
}

impl rt_msghdr {
    pub fn from_bytes<'a>(buf: &'a [u8]) -> Option<&'a Self> {
        if buf.len() >= std::mem::size_of::<rt_msghdr>() {
            let ptr = buf.as_ptr();
            Some(unsafe { &*(ptr as *const rt_msghdr) })
        } else {
            None
        }
    }
}

/// Shorter rt_msghdr version that matches all routing messages
#[derive(Debug)]
#[repr(C)]
pub struct rt_msghdr_short {
    pub rtm_msglen: libc::c_ushort,
    pub rtm_version: libc::c_uchar,
    pub rtm_type: libc::c_uchar,
}

impl rt_msghdr_short {
    fn is_one_of(&self, expected_types: &[i32]) -> bool {
        expected_types
            .iter()
            .any(|expected| self.is_type(*expected))
    }

    fn is_type(&self, expected_type: i32) -> bool {
        u8::try_from(expected_type)
            .map(|expected| self.rtm_type == expected)
            .unwrap_or(false)
    }

    pub fn from_bytes<'a>(buf: &'a [u8]) -> Option<&'a Self> {
        if buf.len() >= std::mem::size_of::<rt_msghdr_short>() {
            let ptr = buf.as_ptr();
            Some(unsafe { &*(ptr as *const rt_msghdr_short) })
        } else {
            None
        }
    }
}

// Struct containing metrics of various metrics for a specific route
// struct rt_metrics {
// 	u_int32_t       rmx_locks;      /* Kernel leaves these values alone */
// 	u_int32_t       rmx_mtu;        /* MTU for this path */
// 	u_int32_t       rmx_hopcount;   /* max hops expected */
// 	int32_t         rmx_expire;     /* lifetime for route, e.g. redirect */
// 	u_int32_t       rmx_recvpipe;   /* inbound delay-bandwidth product */
// 	u_int32_t       rmx_sendpipe;   /* outbound delay-bandwidth product */
// 	u_int32_t       rmx_ssthresh;   /* outbound gateway buffer limit */
// 	u_int32_t       rmx_rtt;        /* estimated round trip time */
// 	u_int32_t       rmx_rttvar;     /* estimated rtt variance */
// 	u_int32_t       rmx_pksent;     /* packets sent using this route */
// 	u_int32_t       rmx_state;      /* route state */
// 	u_int32_t       rmx_filler[3];  /* will be used for TCP's peer-MSS cache */
// };
#[derive(Debug)]
#[repr(C)]
pub struct rt_metrics {
    pub rmx_locks: u32,
    pub rmx_mtu: u32,
    pub rmx_hopcount: u32,
    pub rmx_expire: i32,
    pub rmx_recvpipe: u32,
    pub rmx_sendpipe: u32,
    pub rmx_ssthresh: u32,
    pub rmx_rtt: u32,
    pub rmx_rttvar: u32,
    pub rmx_pksent: u32,
    pub rmx_state: u32,
    pub rmx_filler: [u32; 3],
}
