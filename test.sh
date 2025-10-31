#!/usr/bin/env bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== Evil Bit Kernel Module Test ===${NC}\n"

if lsmod | grep -q "evilbit"; then
    echo -e "${GREEN}✓${NC} Module is loaded"
else
    echo -e "${RED}✗${NC} Module is not loaded"
    echo "Run 'make install' first"
    exit 1
fi

echo -e "\n${YELLOW}Checking kernel logs:${NC}"
dmesg | grep -i evil | tail -n 5

echo -e "\n${YELLOW}Sending test packets:${NC}"
ping -c 3 8.8.8.8 > /dev/null 2>&1 || true
echo -e "${GREEN}✓${NC} Sent 3 ICMP packets to 8.8.8.8"

echo -e "\n${YELLOW}Capturing packets to verify evil bit:${NC}"
echo "Looking for packets with evil bit set..."

CAPTURE_FILE=$(mktemp)
timeout 5s sudo tcpdump -i any -w "$CAPTURE_FILE" ip 2>/dev/null || true

echo -e "${GREEN}✓${NC} Packet capture complete"

if command -v tshark &> /dev/null; then
    echo -e "\n${YELLOW}Analyzing packets with tshark:${NC}"
    tshark -r "$CAPTURE_FILE" -T fields -e ip.flags.rb 2>/dev/null | head -n 10
elif command -v tcpdump &> /dev/null; then
    echo -e "\n${YELLOW}Analyzing packets with tcpdump:${NC}"
    tcpdump -r "$CAPTURE_FILE" -vvv 2>/dev/null | head -n 20
fi

rm -f "$CAPTURE_FILE"

echo -e "\n${YELLOW}Test complete!${NC}"
echo "Note: The evil bit is the 'reserved bit' or first bit in the IP flags field"
echo "In tcpdump output, look for 'flags [evil]' or similar indicators"
echo ""
echo "To manually verify:"
echo "  1. sudo tcpdump -i any -vvv ip"
echo "  2. Generate traffic (ping, curl, etc.)"
echo "  3. Look for 'evil' or '0x8000' in the flags field"
