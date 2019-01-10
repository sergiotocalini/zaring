#!/usr/bin/env ksh
IFS_DEFAULT="${IFS}"
PATH=/usr/local/bin:${PATH}

#################################################################################

#################################################################################
#
#  Variable Definition
# ---------------------
#
APP_NAME=$(basename $0)
APP_DIR=$(dirname $0)
APP_VER="0.0.1"
APP_WEB="http://www.sergiotocalini.com.ar/"
INIT_SCRIPT="/etc/init.d/springboot"
TIMESTAMP=`date '+%s'`
CACHE_DIR=${APP_DIR}/tmp
CACHE_TTL=5                                      # IN MINUTES
#
#################################################################################

#################################################################################
#
#  Load Environment
# ------------------
#
[[ -f ${APP_DIR}/${APP_NAME%.*}.conf ]] && . ${APP_DIR}/${APP_NAME%.*}.conf

#
#################################################################################

#################################################################################
#
#  Function Definition
# ---------------------
#
usage() {
    echo "Usage: ${APP_NAME%.*} [Options]"
    echo ""
    echo "Options:"
    echo "  -a            Query arguments."
    echo "  -h            Displays this help message."
    echo "  -j            Jsonify output."
    echo "  -s ARG(str)   Section (default=stat)."
    echo "  -v            Show the script version."
    echo ""
    echo "Please send any bug reports to sergiotocalini@gmail.com"
    exit 1
}

version() {
    echo "${APP_NAME%.*} ${APP_VER}"
    exit 1
}

zabbix_not_support() {
    echo "ZBX_NOTSUPPORTED"
    exit 1
}

refresh_cache() {
    [[ -d ${CACHE_DIR} ]] || mkdir -p ${CACHE_DIR}
    file=${CACHE_DIR}/data.json
    if [[ $(( `stat -c '%Y' "${file}" 2>/dev/null`+60*${CACHE_TTL} )) -le ${TIMESTAMP} ]]; then
	echo "need to refresh"
    fi
    echo "${file}"
}

discovery() {
    IFS="${IFS_DEFAULT}"
    resource=${1}
    json=$(refresh_cache)
    if [[ ${resource} == 'projects' ]]; then
	for configfile in $(get_configfile); do
	    tags=`jq -r ".monitoring.tags[]" ${configfile} 2>/dev/null | sed 's/null//g' | xargs printf '%s:'`
	    jq -r "select(.monitoring.enable==\"yes\")|\"\(.id)|\(.name)|\(.desc)|\(.monitoring.jmx)|\(.version)|${tags%?}|\"" \
	       ${configfile} 2>/dev/null
	done
    fi
    return 0
}

get_configfile() {
    resource=${1:-all}
    if [[ ${resource} != 'all' ]]; then
	res=`sudo ${INIT_SCRIPT} list units ${resource}`
    else
	res=`sudo ${INIT_SCRIPT} list units`
    fi
    echo "${res[@]:-0}"
    return 0
}

get_service() {
    resource=${1}
    property=${2:-listen}

    json=$(get_configfile ${resource})
    [ ${json} == 0 ] && zabbix_not_support
    
    if [[ ${property} == 'listen' ]]; then
        app_port=(`jq -r '.monitoring.port|@sh' ${json} 2>/dev/null`)
	if [ ${#app_port[@]} -gt 0 ]; then
            for index in ${!app_port[*]}; do
		pid=`sudo lsof -Pi :${app_port[${index}]} -sTCP:LISTEN -t 2>/dev/null`
		rcode="${?}"
		if [[ ${rcode} == 0 ]]; then
		    res=1
		else
		    if [[ ${res} != 0 ]]; then 
			res=2
			continue
		    fi
		    res=0
		fi
            done
	else
	    res=1
	fi
    elif [[ ${property} == 'uptime' ]]; then
        app_exec=`jq -r '.exec' ${json} 2>/dev/null`
        pid=`sudo jps -l 2>/dev/null | grep "${app_exec}" | awk '{print $1}'`
	if [[ -n ${pid} ]]; then
	    res=`sudo ps -p ${pid} -o etimes -h 2>/dev/null | awk '{$1=$1};1'`
	fi
    elif [[ ${property} =~ (cksum|modify|size) ]]; then
	exec=`jq -r '.exec' ${json} 2>/dev/null`
	if [[ ${property} == 'cksum' ]]; then
	    res=`cksum ${exec} 2>/dev/null | awk '{print $1}'`
	elif [[ ${property} == 'modify' ]]; then
	    res=`stat -L -c "%Y" ${exec} 2>/dev/null`
	else
	    res=`stat -L -c "%s" ${exec} 2>/dev/null`
	fi
    elif [[ ${property} == 'version' ]]; then
       	res=`jq -r '.version' ${json} 2>/dev/null`
    elif [[ ${property} == 'status' ]]; then
        url=`jq -r '.monitoring.ws.url' ${json} 2>/dev/null`
        if [[ -n ${url/null/} ]]; then
	   rval=`curl --insecure -s ${url} -o /dev/null -w "%{http_code}\n" 2>/dev/null`
           rcode="${?}"
           if [[ ${rcode} == 0 ]]; then
	      valid_codes=`jq -r '.monitoring.ws.codes|@sh' ${json} 2>/dev/null`
              for code in ${valid_codes[@]:-200}; do
                 if [[ ${code} == ${rval} ]]; then
                    res=1
                    break
                 fi
              done
           fi
        else
           app_exec=`jq -r '.exec' ${json} 2>/dev/null`
           pid=`sudo jps -l 2>/dev/null | grep "${app_exec}" | awk '{print $1}'`
	   if [[ -n ${pid} ]]; then
              res=1           
           fi
        fi
    fi
    echo "${res:-0}"
    return 0
}

#
#################################################################################

#################################################################################
while getopts "s::a:s:uphvj:" OPTION; do
    case ${OPTION} in
	h)
	    usage
	    ;;
	s)
	    SECTION="${OPTARG}"
	    ;;
        j)
            JSON=1
            IFS=":" JSON_ATTR=(${OPTARG//p=})
            ;;
	a)
	    ARGS[${#ARGS[*]}]=${OPTARG//p=}
	    ;;
	v)
	    version
	    ;;
         \?)
            exit 1
            ;;
    esac
done

if [[ ${JSON} -eq 1 ]]; then
    rval=$(discovery ${ARGS[*]})
    echo '{'
    echo '   "data":['
    count=1
    while read line; do
	if [[ ${line} != '' ]]; then
            IFS="|" values=(${line})
            output='{ '
            for val_index in ${!values[*]}; do
		output+='"'{#${JSON_ATTR[${val_index}]:-${val_index}}}'":"'${values[${val_index}]}'"'
		if (( ${val_index}+1 < ${#values[*]} )); then
                    output="${output}, "
		fi
            done 
            output+=' }'
            if (( ${count} < `echo ${rval}|wc -l` )); then
		output="${output},"
            fi
            echo "      ${output}"
	fi	
        let "count=count+1"
    done <<< ${rval}
    echo '   ]'
    echo '}'
else
    if [[ ${SECTION} == 'discovery' ]]; then
        rval=$(discovery ${ARGS[*]})
        rcode="${?}"
    elif [[ ${SECTION} == 'service' ]]; then
	rval=$( get_service ${ARGS[*]} )
	rcode="${?}"	
    else
	rval=$( get_stats ${SECTION} ${ARGS[*]} )
	rcode="${?}"
    fi
    echo "${rval:-0}" | sed "s/null/0/g"
fi

exit ${rcode}
