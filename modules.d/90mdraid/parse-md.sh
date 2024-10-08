#!/bin/bash

MD_UUID=$(getargs rd.md.uuid)
# normalize the uuid
MD_UUID=$(str_replace "$MD_UUID" "-" "")
MD_UUID=$(str_replace "$MD_UUID" ":" "")

if { [ -z "$MD_UUID" ] && ! getargbool 0 rd.auto; } || ! getargbool 1 rd.md; then
    info "rd.md=0: removing MD RAID activation"
    udevproperty rd_NO_MD=1
else
    # rewrite the md rules to only process the specified raid array
    if [ -n "$MD_UUID" ]; then
        for f in /etc/udev/rules.d/65-md-incremental*.rules; do
            [ -e "$f" ] || continue
            while read -r line || [ -n "$line" ]; do
                if [ "${line%%UUID CHECK}" != "$line" ]; then
                    for uuid in $MD_UUID; do
                        printf 'ENV{ID_FS_UUID}=="%s", GOTO="md_uuid_ok"\n' "${uuid:0:8}-${uuid:8:4}-${uuid:12:4}-${uuid:16:4}-${uuid:20:12}"
                    done
                    # shellcheck disable=SC2016
                    printf 'IMPORT{program}="/sbin/mdadm --examine --export $tempnode"\n'
                    for uuid in $MD_UUID; do
                        printf 'ENV{MD_UUID}=="%s", GOTO="md_uuid_ok"\n' "${uuid:0:8}:${uuid:8:8}:${uuid:16:8}:${uuid:24:8}"
                    done
                    printf 'GOTO="md_end"\n'
                    printf 'LABEL="md_uuid_ok"\n'
                else
                    echo "$line"
                fi
            done < "${f}" > "${f}.new"
            mv "${f}.new" "$f"
        done
        for uuid in $MD_UUID; do
            uuid="${uuid:0:8}:${uuid:8:8}:${uuid:16:8}:${uuid:24:8}"
            wait_for_dev "/dev/disk/by-id/md-uuid-${uuid}"
        done
    fi
fi

if [ -e /etc/mdadm.conf ] && getargbool 1 rd.md.conf; then
    udevproperty rd_MDADMCONF=1
    rm -f -- "$hookdir"/pre-pivot/*mdraid-cleanup.sh
fi

if ! getargbool 1 rd.md.conf; then
    rm -f -- /etc/mdadm/mdadm.conf /etc/mdadm.conf
    ln -s "$(command -v mdraid-cleanup)" "$hookdir"/pre-pivot/31-mdraid-cleanup.sh 2> /dev/null
fi

# noiswmd nodmraid for anaconda / rc.sysinit compatibility
# note nodmraid really means nobiosraid, so we don't want MDIMSM then either
if ! getargbool 1 rd.md.imsm; then
    info "no MD RAID for imsm/isw raids"
    udevproperty rd_NO_MDIMSM=1
fi

# same thing with ddf containers
if ! getargbool 1 rd.md.ddf; then
    info "no MD RAID for SNIA ddf raids"
    udevproperty rd_NO_MDDDF=1
fi
