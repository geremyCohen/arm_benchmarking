#!/bin/bash
# detect-crypto.sh - Detection method for Crypto Extensions (AES, SHA1, SHA2)

grep -E "aes|sha1|sha2" /proc/cpuinfo
