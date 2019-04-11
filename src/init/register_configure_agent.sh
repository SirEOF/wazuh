#!/bin/bash

# Copyright (C) 2015-2019, Wazuh Inc.
# March 6, 2019.
#
# This program is a free software; you can redistribute it
# and/or modify it under the terms of the GNU General Public
# License (version 2) as published by the FSF - Free Software
# Foundation.

. /etc/ossec-init.conf

sed="sed -ri"

edit_value_tag() {
    if [ "$#" == "2" ] && [ ! -z "$2" ]; then
        ${sed} "s#<$1>.*</$1>#<$1>$2</$1>#g" "${DIRECTORY}/etc/ossec.conf"
    fi

    if [ "$?" != "0" ]; then
        echo "$(date '+%Y/%m/%d %H:%M:%S') agent-auth: Error updating $2 with variable $1." >> ${DIRECTORY}/logs/ossec.log
    fi
}

add_adress_block() {

    SET_ADDRESSES=("$@")
    LAST=$((${#SET_ADDRESSES[@]}-1))

    for i in "${SET_ADDRESSES[@]}";
    do
        if [ "$i" == "${SET_ADDRESSES[${LAST}]}" ]; then
            NEW="<address>$i</address>      "
        else
            NEW="<address>$i</address>\n      "
        fi
        BLOCK=${BLOCK}${NEW}
    done
    ${sed} "s#<address>MANAGER_IP</address>#${BLOCK}#g" "${DIRECTORY}/etc/ossec.conf"
}

add_parameter () {
    if [ ! -z "$3" ]; then
        OPTIONS="$1 $2 $3"
    fi
    echo ${OPTIONS}
}

set_vars () {
    export WAZUH_MANAGER_IP=$(launchctl getenv WAZUH_MANAGER_IP)
    export WAZUH_PROTOCOL=$(launchctl getenv WAZUH_PROTOCOL)
    export WAZUH_SERVER_PORT=$(launchctl getenv WAZUH_SERVER_PORT)
    export WAZUH_NOTIFY_TIME=$(launchctl getenv WAZUH_NOTIFY_TIME)
    export WAZUH_TIME_RECONNECT=$(launchctl getenv WAZUH_TIME_RECONNECT)
    export WAZUH_AUTHD_SERVER=$(launchctl getenv WAZUH_AUTHD_SERVER)
    export WAZUH_AUTHD_PORT=$(launchctl getenv WAZUH_AUTHD_PORT)
    export WAZUH_PASSWORD=$(launchctl getenv WAZUH_PASSWORD)
    export WAZUH_AGENT_NAME=$(launchctl getenv WAZUH_AGENT_NAME)
    export WAZUH_GROUP=$(launchctl getenv WAZUH_GROUP)
    export WAZUH_CERTIFICATE=$(launchctl getenv WAZUH_CERTIFICATE)
    export WAZUH_KEY=$(launchctl getenv WAZUH_KEY)
    export WAZUH_PEM=$(launchctl getenv WAZUH_PEM)
}

main () {

    uname_s=$(uname -s)

    if [ "${uname_s}" = "Darwin" ]; then
        sed="sed -ire"
        set_vars
    fi

    if [ ! -s ${DIRECTORY}/etc/client.keys ] && [ ! -z ${WAZUH_MANAGER_IP} ]; then

        if [ ! -f ${DIRECTORY}/logs/ossec.log ]; then
            touch -f ${DIRECTORY}/logs/ossec.log
            chmod 660 ${DIRECTORY}/logs/ossec.log
            chown root:ossec ${DIRECTORY}/logs/ossec.log
        fi

        # Check if multiples IPs are defined in variable WAZUH_MANAGER_IP
        ADDRESSES=(${WAZUH_MANAGER_IP//,/ })
        if [ ${#ADDRESSES[@]} -gt 1 ]; then
            # Get uniques values
            ADDRESSES=($(echo "${ADDRESSES[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
            add_adress_block "${ADDRESSES[@]}"
        else
            # Single address
            edit_value_tag "address" ${WAZUH_MANAGER_IP}
        fi

        # Options to be modified in ossec.conf
        edit_value_tag "protocol" ${WAZUH_PROTOCOL}
        edit_value_tag "port" ${WAZUH_SERVER_PORT}
        edit_value_tag "notify_time" ${WAZUH_NOTIFY_TIME}
        edit_value_tag "time-reconnect" ${WAZUH_TIME_RECONNECT}
    fi

    if [ ! -s ${DIRECTORY}/etc/client.keys ] && [ ! -z ${WAZUH_AUTHD_SERVER} ]; then
        # Options to be used in register time.
            OPTIONS="-m ${WAZUH_AUTHD_SERVER}"
            OPTIONS=$(add_parameter "${OPTIONS}" "-p" "${WAZUH_AUTHD_PORT}")
            OPTIONS=$(add_parameter "${OPTIONS}" "-P" "${WAZUH_PASSWORD}")
            OPTIONS=$(add_parameter "${OPTIONS}" "-A" "${WAZUH_AGENT_NAME}")
            OPTIONS=$(add_parameter "${OPTIONS}" "-G" "${WAZUH_GROUP}")
            OPTIONS=$(add_parameter "${OPTIONS}" "-v" "${WAZUH_CERTIFICATE}")
            OPTIONS=$(add_parameter "${OPTIONS}" "-k" "${WAZUH_KEY}")
            OPTIONS=$(add_parameter "${OPTIONS}" "-x" "${WAZUH_PEM}")
            ${DIRECTORY}/bin/agent-auth ${OPTIONS} >> ${DIRECTORY}/logs/ossec.log 2>/dev/null
    fi
}

main