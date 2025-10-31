// SPDX-License-Identifier: GPL-2.0

//! evilbit - Evil Bit Kernel Module (RFC 3514)
//!
//! This module sets the "evil bit" on all outgoing IPv4 packets
//! The evil bit is bit 0 of the IP flags field (the reserved bit)
//!
//! Reference: https://datatracker.ietf.org/doc/html/rfc3514

use kernel::net::filter as netfilter;
use kernel::net::{self, SkBuff};
use kernel::prelude::*;

module! {
    type: EvilBitModule,
    name: "evilbit",
    authors: ["burdz <burdz@burdz.net>"],
    description: "Sets the evil bit on all IPv4 packets (RFC 3514)",
    license: "GPL",
}

const EVIL_BIT: u16 = 0x8000; // network byte order (bit 0 of flags)

struct EvilBitModule {
    _reg: Pin<Box<netfilter::Registration<EvilBitFilter>>>,
}

struct EvilBitFilter;

impl netfilter::Filter for EvilBitFilter {
    type Data = ();

    fn filter(_data: Self::Data, skb: &SkBuff) -> netfilter::Disposition {
        // attempt t get and modify the IP header
        if let Err(_) = set_evil_bit(skb) {
            // if we can't set the evil bit, just accept the packet anyway?
            return netfilter::Disposition::Accept;
        }

        netfilter::Disposition::Accept
    }
}

/// Sets the evil bit on an IPv4 packet
fn set_evil_bit(skb: &SkBuff) -> Result {
    let data = skb.head_data();
    
    // least 20 bytes for an IPv4 header
    if data.len() < 20 {
        return Ok(());
    }

    // IP header structure:
    // 0: version_ihl, 1: tos, 2-3: tot_len, 4-5: id, 
    // 6-7: frag_off (FLAGS + FRAGMENT OFFSET), ...
    // safety: we've checked the length, only reading/writing within bounds
    unsafe {
        let ip_header = data.as_ptr() as *mut u8;
        
        // check if it is IPv4
        let version = (*ip_header) >> 4;
        if version != 4 {
            return Ok(());
        }

        // get pointer to frag_off field (bytes 6-7 of IP header)
        let frag_off_ptr = ip_header.add(6) as *mut u16;
        
        // read current flags/fragment offset in network byte order
        let old_frag_off = core::ptr::read_unaligned(frag_off_ptr);
        let old_flags = u16::from_be(old_frag_off);
        
        // set the evil bit (bi5 15)
        let new_flags = old_flags | EVIL_BIT;
        
        if old_flags != new_flags {
            core::ptr::write_unaligned(frag_off_ptr, new_flags.to_be());
            
            recalculate_ip_checksum(ip_header);
        }
    }

    Ok(())
}

/// Recalculates the IP header checksum
unsafe fn recalculate_ip_checksum(ip_header: *mut u8) {
    // get IHL Internet Header Length number
    let ihl = ((*ip_header) & 0x0F) as usize;
    let header_len = ihl * 4;
    
    // zero out the checksum field (bytes 10-11)
    let checksum_ptr = ip_header.add(10) as *mut u16;
    core::ptr::write_unaligned(checksum_ptr, 0);
    
    let mut sum: u32 = 0;
    let header_ptr = ip_header as *const u16;
    
    for i in 0..(header_len / 2) {
        let word = u16::from_be(core::ptr::read_unaligned(header_ptr.add(i)));
        sum += word as u32;
    }
    
    // can be odd?
    if header_len % 2 != 0 {
        let last_byte = *ip_header.add(header_len - 1) as u32;
        sum += last_byte << 8;
    }
    
    while (sum >> 16) != 0 {
        sum = (sum & 0xFFFF) + (sum >> 16);
    }
    
    let checksum = (!sum) as u16;
    
    // checksum back in network byte order?
    core::ptr::write_unaligned(checksum_ptr, checksum.to_be());
}

impl kernel::Module for EvilBitModule {
    fn init(_module: &'static ThisModule) -> Result<Self> {
        pr_info!("evilbit: Evil Bit Module loading...\n");
        pr_info!("evilbit: Setting evil bit on all IPv4 packets (RFC 3514)\n");

        let ns = net::init_ns();

        // netfilter hook at POST_ROUTING for IPv4
        let reg = netfilter::Registration::new_pinned(
            netfilter::Family::Ipv4(netfilter::ipv4::Hook::PostRouting),
            0,
            ns.into(),
            None,
            (),
        )?;

        pr_info!("evilbit: Netfilter hook registered successfully\n");
        pr_info!("evilbit: Evil Bit Module loaded successfully!\n");

        Ok(EvilBitModule { _reg: reg })
    }
}

impl Drop for EvilBitModule {
    fn drop(&mut self) {
        pr_info!("evilbit: Evil Bit Module unloading...\n");
    }
}
