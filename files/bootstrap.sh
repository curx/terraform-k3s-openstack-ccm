#!/usr/bin/env bash

##    desc: bootstrap a kubernetes environment for openstack
## license: Apache-2.0

# setup aliases and environment
echo "# setup environment for $USER add .bash_aliases and .inputrc"
cat <<EOF > $HOME/.bash_aliases
# kubernetes-cli
alias k=kubectl
source <( kubectl completion bash | sed 's# kubectl\$# k kubectl\$#' )

# eof
EOF

# set inputrc set tab once
cat <<EOF > .inputrc
# set tab one
set show-all-if-ambiguous on
EOF

# eof
