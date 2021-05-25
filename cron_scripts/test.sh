#!/bin/bash

BACKUP_SOURCE_FN=backup-node_configs.sources

# BACKUP_SOURCES=( \
#   /etc/puppetlabs/puppet/ssl \
#   /etc/puppetlabs/puppet/puppet.conf \
#   /etc/krb5.keytab \
# )

BACKUP_SOURCES=( $( cat "${BACKUP_SOURCE_FN}" ) )

for i in "${!BACKUP_SOURCES[@]}"; do
  echo $i
  echo "${BACKUP_SOURCES[$i]}"
done
