#!/bin/bash

nodels all,-switch | ssh-keyscan -f - -4 -H -t rsa 1>/root/.ssh/known_hosts
