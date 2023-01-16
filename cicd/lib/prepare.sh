#!/bin/bash -ex

# Fix some connectivity isues:
# apt update is hanging on security.ubuntu.com with IPv6, prefer IPv4 over IPv6
cat <<EOF > gai.conf
  precedence  ::1/128       50
  precedence  ::/0          40
  precedence  2002::/16     30
  precedence ::/96          20
  precedence ::ffff:0:0/96 100
EOF
if ! mv gai.conf /etc/gai.conf; then
    printf "/etc/gai.conf is not writable, ubuntu-core system? apt update won't be affected in that case\n"
    rm -f gai.conf
fi

# Copy external tools from the subtree to the "$TESTSLIB"/tools directory
# The idea is to have a single directory with all the testing tools
cp -f "$TESTSLIB"/external/snapd-testing-tools/tools/* "$TESTSTOOLS"
cp -f "$TESTSLIB"/external/snapd-testing-tools/remote/* "$TESTSTOOLS"
