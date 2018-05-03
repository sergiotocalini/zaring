#!/usr/bin/env ksh
SOURCE_DIR=$(dirname $0)
ZABBIX_DIR=/etc/zabbix

mkdir -p ${ZABBIX_DIR}/scripts/agentd/zaring
cp ${SOURCE_DIR}/zaring/zaring.conf.example ${ZABBIX_DIR}/scripts/agentd/zaring/zaring.conf
cp ${SOURCE_DIR}/zaring/zaring.sh ${ZABBIX_DIR}/scripts/agentd/zaring/
cp ${SOURCE_DIR}/zaring/zabbix_agentd.conf ${ZABBIX_DIR}/zabbix_agentd.d/zaring.conf
