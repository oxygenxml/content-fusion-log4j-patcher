#!/usr/bin/env bash

if [ `id -u` != "0" ]; then
  echo "The Log4Shell patch requires root privileges."
  exit 1
fi

if ! command -v zip &> /dev/null
then
  echo "'zip' is required to apply this patch. Please install it and try again."
  exit 1
fi

set -e

# Move to the directory where this script is located.
SCRIPT_DIR=$(dirname "$0")
cd "${SCRIPT_DIR}"
# Save the current directory for later use.
SCRIPT_DIR=$(pwd)

LIB_DIR=${SCRIPT_DIR}/lib

TMP_DIR=$(mktemp -d /tmp/log4temp.XXXXXX)
function exit_cleanup() {
  rm -rf "${TMP_DIR}"
}
trap exit_cleanup EXIT

#
# @param $1 image_name The name of the image where changes should be commited.
# @param $2 container_id The ID of the docker container to patch.
# @param $3 lib_path Path to the directory where jars are located inside the container.
#
function patch() {
  local image_name=$1
  local container_id=$2
  local lib_path=$3

  declare -a jars=("log4j-1.2-api*jar" "log4j-api*jar" "log4j-core*jar" "log4j-slf4j-impl*jar" "log4j-web*jar")

  local patched_at_least_one_jar=false
  echo "Patching ${image_name}"

  for jar in "${jars[@]}"
  do
    echo -n "  ${jar}... "

    local path_in_container
    path_in_container=$(docker exec "${container_id}" find "${lib_path}" -name "${jar}")
    path_in_container=$(echo "${path_in_container}" | tr -d '\r')

    if [ "${path_in_container}" == "" ] && [ "${jar}" == "log4j-slf4j-impl*jar" ]; then
      echo -n "... "

      # In CF-2/review-api the slf4j-impl jar has a different name
      path_in_container=$(docker exec "${container_id}" find "${lib_path}" -name "slf4j-log4j12-*jar")
      path_in_container=$(echo "${path_in_container}" | tr -d '\r')
    fi

    if [ "${path_in_container}" == "" ]; then
      echo "Ok"
    else
      echo -n "Patching... "

      docker exec "${container_id}" rm "${path_in_container}"
      # shellcheck disable=SC2086
      docker cp "${LIB_DIR}/"${jar} "${container_id}:${lib_path}"

      echo "Ok"
      patched_at_least_one_jar=true
    fi
  done

  local log4j1_in_container
  log4j1_in_container=$(docker exec "${container_id}" find "${lib_path}" -name "log4j-1.2.17.jar" -or -name "oxygen-patched-log4j*jar")
  log4j1_in_container=$(echo "${log4j1_in_container}" | tr -d '\r')

  if [ "${log4j1_in_container}" != "" ]; then
    # CF-1500
    echo -n "  log4j1... "

    local log4j1_jar=${TMP_DIR}/log4j1.jar
    docker cp "${container_id}:${log4j1_in_container}" "${log4j1_jar}"

    set +e
    zip -q -d "${log4j1_jar}" "org/apache/log4j/net/JMSAppender.class" &> /dev/null
    set -e

    docker cp "${log4j1_jar}" "${container_id}:${log4j1_in_container}"

    echo "Ok"
    patched_at_least_one_jar=true
  fi

  if [[ "${patched_at_least_one_jar}" == "true" ]]; then
    echo -n "  Committing changes... "
    docker commit "${container_id}" "${image_name}"
  fi

  echo "Done"
  echo ""
}

echo "-- Content Fusion patch --"
echo ""

echo "Searching for containers to patch"
echo ""

pushd /fusion 1> /dev/null
  WA_IMAGE_NAME=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep webreviewer-webauthor)
  # review-api might have two tags for the same image created by patch_CF_1233
  CF_IMAGE_NAME=$(grep "oxygenxml/webreviewer-api" < /fusion/docker-compose.yml | awk '{print $2}')
  LS_IMAGE_NAME=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep license-servlet)

  WA_CONTAINER=$(docker-compose ps -q webauthor)
  WA_CONTAINER=$(echo "${WA_CONTAINER}" | tr -d '\r')

  CF_CONTAINER=$(docker-compose ps -q review-api)
  CF_CONTAINER=$(echo "${CF_CONTAINER}" | tr -d '\r')

  LS_CONTAINER=$(docker-compose ps -q license-servlet)
  LS_CONTAINER=$(echo "${LS_CONTAINER}" | tr -d '\r')
popd 1> /dev/null

echo "Found container for ${WA_IMAGE_NAME}: ${WA_CONTAINER}"
echo "Found container for ${CF_IMAGE_NAME}: ${CF_CONTAINER}"
echo "Found container for ${LS_IMAGE_NAME}: ${LS_CONTAINER}"
echo ""

patch "${WA_IMAGE_NAME}" "${WA_CONTAINER}" "/tomcat/webapps/oxygen-xml-web-author/WEB-INF/lib/"
patch "${CF_IMAGE_NAME}" "${CF_CONTAINER}" "/tomcat/webapps/ROOT/WEB-INF/lib/"
patch "${LS_IMAGE_NAME}" "${LS_CONTAINER}" "/tomcat/webapps/ROOT/WEB-INF/lib/"

echo "Restarting Content Fusion"
echo ""

bash /fusion/admin/stop-content-fusion.sh
echo ""
bash /fusion/admin/start-content-fusion.sh
echo ""

echo "Patch applied successfully"
