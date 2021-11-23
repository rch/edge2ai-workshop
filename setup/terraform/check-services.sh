#!/usr/bin/env bash
set -o errexit
set -o nounset
BASE_DIR=$(cd $(dirname $0); pwd -L)
source $BASE_DIR/common-basics.sh

if [ $# != 1 ]; then
  echo "Syntax: $0 <namespace>"
  show_namespaces
  exit 1
fi
NAMESPACE=$1

source $BASE_DIR/common.sh

CURL=(curl -L -k --connect-timeout 5)

function cleanup() {
  rm -f .curl.*.$$
}

function get_model_status() {
  local ip=$1
  CDSW_API="cdsw.$ip.nip.io/api/v1"
  CDSW_ALTUS_API="cdsw.$ip.nip.io/api/altus-ds-1"
  status=""
  for scheme in http https; do
    token=$("${CURL[@]}" -X POST --cookie-jar .curl.cj-model.$$ --cookie .curl.cj-model.$$ -H "Content-Type: application/json" --data '{"_local":false,"login":"admin","password":"'"${THE_PWD}"'"}' "$scheme://$CDSW_API/authenticate" 2>/dev/null | jq -r '.auth_token // empty' 2> /dev/null)
    [[ ! -n $token ]] && continue
    status=$("${CURL[@]}" -X POST --cookie-jar .curl.cj-model.$$ --cookie .curl.cj-model.$$ -H "Content-Type: application/json" -H "Authorization: Bearer $token" --data '{"projectOwnerName":"admin","latestModelDeployment":true,"latestModelBuild":true}' "$scheme://$CDSW_ALTUS_API/models/list-models" 2>/dev/null | jq -r '.[].latestModelDeployment | select(.model.name == "IoT Prediction Model").status' 2>/dev/null)
    [[ -n $status ]] && break
  done
  echo -n $status
}

function get_viz_status() {
  local ip=$1
  CDSW_API="cdsw.$ip.nip.io/api/v1"
  status=""
  for scheme in http https; do
    token=$("${CURL[@]}" -X POST --cookie-jar .curl.cj-viz.$$ --cookie .curl.cj-viz.$$ -H "Content-Type: application/json" --data '{"_local":false,"login":"admin","password":"'"${THE_PWD}"'"}' "$scheme://$CDSW_API/authenticate" 2>/dev/null | jq -r '.auth_token // empty' 2> /dev/null)
    [[ ! -n $token ]] && continue
    status=$("${CURL[@]}" -X GET --cookie-jar .curl.cj-viz.$$ --cookie .curl.cj-viz.$$ -H "Content-Type: application/json" -H "Authorization: Bearer $token" "$scheme://$CDSW_API/projects/admin/vizapps-workshop/applications" 2>/dev/null | jq -r '.[0].status // empty' 2>/dev/null)
    [[ -n $status ]] && break
  done
  echo -n $status
}

load_env $NAMESPACE

printf "%-30s %-20s %-5s %-5s %-5s %-5s %-5s %-5s %-5s %-5s %-5s %-14s %s\n" "instance" "ip address" "WEB" "CM" "CEM" "NIFI" "NREG" "SREG" "SMM" "HUE" "CDSW" "Model Status" "Viz Status" 
ensure_tf_json_file
if [ -s $TF_JSON_FILE ]; then
  cat $TF_JSON_FILE | \
  jq -r '.values.root_module.resources[] | select(.type == "aws_instance" and .name == "web" or .type == "aws_instance" and .name == "cluster") | "\(.type).\(.name)[\(.index)] \(.values.public_ip)"' | \
  while read instance ip; do
    host="cdp.$ip.nip.io"
    CDSW_API="http://cdsw.$ip.nip.io/api/v1"
    CDSW_ALTUS_API="http://cdsw.$ip.nip.io/api/altus-ds-1"
    ("${CURL[@]}" http://$host/api/ping 2>/dev/null | grep 'Pong!' > /dev/null 2>&1 && echo Ok) > .curl.web.$$ &
    ("${CURL[@]}" http://$host:7180/cmf/login 2>/dev/null | grep "<title>Cloudera Manager</title>" > /dev/null 2>&1 && echo Ok) > .curl.cm.$$ &
    (("${CURL[@]}" http://$host:10088/efm/ui/        || "${CURL[@]}" https://$host:10088/efm/ui/)        2>/dev/null | grep "<title>CEM</title>" > /dev/null 2>&1 && echo Ok) > .curl.cem.$$ &
    (("${CURL[@]}" http://$host:8080/nifi/           || "${CURL[@]}" https://$host:8443/nifi/)           2>/dev/null | grep "<title>NiFi</title>" > /dev/null 2>&1 && echo Ok) > .curl.nifi.$$ &
    (("${CURL[@]}" http://$host:18080/nifi-registry/ || "${CURL[@]}" https://$host:18433/nifi-registry/) 2>/dev/null | grep "<title>NiFi Registry</title>" > /dev/null 2>&1 && echo Ok) > .curl.nifireg.$$ &
    (("${CURL[@]}" http://$host:7788/                || "${CURL[@]}" https://$host:7790/)                2>/dev/null | egrep "<title>Schema Registry</title>|Error 401 Authentication required" > /dev/null 2>&1 && echo Ok) > .curl.schreg.$$ &
    (("${CURL[@]}" http://$host:9991/                || "${CURL[@]}" https://$host:9991/)                2>/dev/null | grep "<title>STREAMS MESSAGING MANAGER</title>" > /dev/null 2>&1 && echo Ok) > .curl.smm.$$ &
    (("${CURL[@]}" http://$host:8888/                ;  "${CURL[@]}" https://$host:8889/)                2>/dev/null | grep "<title>Hue" > /dev/null 2>&1 && echo Ok) > .curl.hue.$$ &
    (("${CURL[@]}" http://cdsw.$ip.nip.io/           || "${CURL[@]}" https://cdsw.$ip.nip.io/)           2>/dev/null | egrep "(Cloudera Machine Learning|Cloudera Data Science Workbench)" > /dev/null 2>&1 && echo Ok) > .curl.cml.$$ &
    (get_model_status $ip) > .curl.model.$$ &
#    ("${CURL[@]}" http://viz.cdsw.$ip.nip.io/arc/adminapi/users 2>/dev/null | grep 'user' > /dev/null 2>&1 && echo running) > .curl.viz.$$ &
    (get_viz_status $ip) > .curl.viz.$$ &
    wait
#    printf "%-30s %-20s %-5s %-5s %-5s %-5s %-5s %-5s %-5s %-5s %-5s %s\n" "$instance" "$ip" "$(cat .curl.web.$$)" "$(cat .curl.cm.$$)" "$(cat .curl.cem.$$)" "$(cat .curl.nifi.$$)" "$(cat .curl.nifireg.$$)" "$(cat .curl.schreg.$$)" "$(cat .curl.smm.$$)" "$(cat .curl.hue.$$)" "$(cat .curl.cml.$$)" "$(cat .curl.model.$$)"
    printf "%-30s %-20s %-5s %-5s %-5s %-5s %-5s %-5s %-5s %-5s %-5s %-14s %s\n" "$instance" "$ip" "$(cat .curl.web.$$)" "$(cat .curl.cm.$$)" "$(cat .curl.cem.$$)" "$(cat .curl.nifi.$$)" "$(cat .curl.nifireg.$$)" "$(cat .curl.schreg.$$)" "$(cat .curl.smm.$$)" "$(cat .curl.hue.$$)" "$(cat .curl.cml.$$)" "$(cat .curl.model.$$)" "$(cat .curl.viz.$$)"
  done | sort -t\[ -k1,1r -k2,2n
fi
