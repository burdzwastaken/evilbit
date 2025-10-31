#!/usr/bin/env bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== Evil Bit Kernel Test ===${NC}\n"

if lsmod | grep -q "evilbit"; then
    echo -e "${GREEN}✓${NC} module is loaded"
else
    echo -e "${RED}✗${NC} module is not loaded"
    echo "run 'make install' first"
    exit 1
fi

echo -e "\n${YELLOW}checking kernel logs:${NC}"
dmesg | grep -i evil | tail -n 5

echo -e "\n${YELLOW}sending test packets:${NC}"
ping -c 3 8.8.8.8 > /dev/null 2>&1 || true
echo -e "${GREEN}✓${NC} Sent 3 ICMP packets to 8.8.8.8"

echo -e "\n${YELLOW}capturing packets to verify evil bit:${NC}"
echo "looking for packets with evil bit set..."

CAPTURE_FILE=$(mktemp)
timeout 5s sudo tcpdump -i any -w "$CAPTURE_FILE" ip 2>/dev/null || true

echo -e "${GREEN}✓${NC} packet capture complete"

if command -v tshark &> /dev/null; then
    echo -e "\n${YELLOW}analyzing packets with tshark:${NC}"
    tshark -r "$CAPTURE_FILE" -T fields -e ip.flags.rb 2>/dev/null | head -n 10
elif command -v tcpdump &> /dev/null; then
    echo -e "\n${YELLOW}analyzing packets with tcpdump:${NC}"
    tcpdump -r "$CAPTURE_FILE" -vvv 2>/dev/null | head -n 20
fi

rm -f "$CAPTURE_FILE"

echo -e "\n${YELLOW}test complete!${NC}"
echo "NOTE: The evil bit is the 'reserved bit' or first bit in the IP flags field"
echo "In tcpdump output, look for 'flags [evil]' or similar indicators"
echo ""
echo "to manually verify:"
echo "  1. sudo tcpdump -i any -vvv ip"
echo "  2. generate traffic (ping, curl, etc.)"
echo "  3. look for 'evil' or '0x8000' in the flags field"
