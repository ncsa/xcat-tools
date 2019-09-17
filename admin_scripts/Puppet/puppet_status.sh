#!/bin/bash

# Determine the status of Puppet on a node/list of nodes.

# Usage: ./puppet_status.sh <node|nodelist>

if [ "$#" -ne 1 ]; then
  echo "You must provide one argument: a node or nodelist!"
  exit 1
fi

xdsh $1 'puppet config print server --section agent; puppet resource service puppet; cat "/opt/puppetlabs/puppet/cache/state/agent_disabled.lock" 2>/dev/null' |xdshbak -c
