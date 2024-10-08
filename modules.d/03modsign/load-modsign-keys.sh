#!/bin/bash
#
# Licensed under the GPLv2
#
# Copyright 2013 Red Hat, Inc.
# Peter Jones <pjones@redhat.com>

for x in /lib/modules/keys/*; do
    [ "${x}" = "/lib/modules/keys/*" ] && break
    keyctl padd asymmetric "" %:.secondary_trusted_keys < "${x}"
done
