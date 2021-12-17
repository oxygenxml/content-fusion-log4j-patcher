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

cd /fusion
JNDI_LOOKUP_CLASS=org/apache/logging/log4j/core/lookup/JndiLookup.class

echo "-- Content Fusion Log4Shell patch --"
echo ""

TMP_DIR=$(mktemp -d /tmp/log4shell.XXXXXX)
echo "Created temp dir: ${TMP_DIR}"

LS_IMAGE_NAME=$(docker images | grep license-servlet | awk '{print $1}')

WA_VERSION=$(docker images | grep oxygenxml/webreviewer-webauthor | awk '{print $2}')
CF_VERSION=$(docker images | grep oxygenxml/webreviewer-api | awk '{print $2}')
LS_VERSION=$(docker images | grep "${LS_IMAGE_NAME}" | awk '{print $2}')

echo "Detected webreviewer-webauthor version: ${WA_VERSION}"
echo "Detected webreviewer-api version: ${CF_VERSION}"
echo "Detected license-servlet version: ${LS_VERSION}"
echo ""

WA_CONTAINER=$(docker-compose ps -q webauthor)
WA_CONTAINER=$(echo "${WA_CONTAINER}" | tr -d '\r')

CF_CONTAINER=$(docker-compose ps -q review-api)
CF_CONTAINER=$(echo "${CF_CONTAINER}" | tr -d '\r')

LS_CONTAINER=$(docker-compose ps -q license-servlet)
LS_CONTAINER=$(echo "${LS_CONTAINER}" | tr -d '\r')

echo "Found container for webauthor: ${WA_CONTAINER}"
echo "Found container for review-api: ${CF_CONTAINER}"
echo "Found container for ${LS_IMAGE_NAME}: ${LS_CONTAINER}"
echo ""


echo "Searching for log4j-core in webauthor"
WA_LOG4JCORE=$(docker-compose exec webauthor find /tomcat/webapps/oxygen-xml-web-author/WEB-INF/lib/ -name log4j-core*jar)
WA_LOG4JCORE=$(echo "${WA_LOG4JCORE}" | tr -d '\r')

if [ "${WA_LOG4JCORE}" == "" ]; then
  echo "log4j-core not present in webauthor, nothing to patch."
else
  echo "Patching ${WA_LOG4JCORE}"
  WA_JAR=${TMP_DIR}/webauthor.jar
  docker cp "${WA_CONTAINER}:${WA_LOG4JCORE}" "${WA_JAR}"
  zip -q -d "${WA_JAR}" "${JNDI_LOOKUP_CLASS}"
  docker cp "${WA_JAR}" "${WA_CONTAINER}:${WA_LOG4JCORE}"
  docker commit "${WA_CONTAINER}" "oxygenxml/webreviewer-webauthor:${WA_VERSION}"
  echo "Done"
fi
echo ""


echo "Searching for log4j-core in review-api"
CF_LOG4JCORE=$(docker-compose exec review-api find /tomcat/webapps/ROOT/WEB-INF/lib/ -name log4j-core*jar)
CF_LOG4JCORE=$(echo "${CF_LOG4JCORE}" | tr -d '\r')

if [ "${CF_LOG4JCORE}" == "" ]; then
  echo "log4j-core not present in review-api, nothing to patch."
else
  echo "Patching ${CF_LOG4JCORE}"
  CF_JAR=${TMP_DIR}/review-api.jar
  docker cp "${CF_CONTAINER}:${CF_LOG4JCORE}" "${CF_JAR}"
  zip -q -d "${CF_JAR}" "${JNDI_LOOKUP_CLASS}"
  docker cp "${CF_JAR}" "${CF_CONTAINER}:${CF_LOG4JCORE}"
  docker commit "${CF_CONTAINER}" "oxygenxml/webreviewer-api:${CF_VERSION}"
  echo "Done"
fi
echo ""


echo "Searching for log4j-core in license-servlet"
LS_LOG4JCORE=$(docker-compose exec license-servlet find /tomcat/webapps/ROOT/WEB-INF/lib/ -name log4j-core*jar)
LS_LOG4JCORE=$(echo "${LS_LOG4JCORE}" | tr -d '\r')

if [ "${LS_LOG4JCORE}" == "" ]; then
  echo "log4j-core not present in license-servlet, nothing to patch."
else
  echo "Patching ${LS_LOG4JCORE}"
  LS_JAR=${TMP_DIR}/license-servlet.jar
  docker cp "${LS_CONTAINER}:${LS_LOG4JCORE}" "${LS_JAR}"
  zip -q -d "${LS_JAR}" "${JNDI_LOOKUP_CLASS}"
  docker cp "${LS_JAR}" "${LS_CONTAINER}:${LS_LOG4JCORE}"
  docker commit "${LS_CONTAINER}" "${LS_IMAGE_NAME}:${LS_VERSION}"
  echo "Done"
fi
echo ""


echo "Restarting Content Fusion"
bash /fusion/admin/stop-content-fusion.sh
bash /fusion/admin/start-content-fusion.sh

echo "Log4Shell patch applied successfully"
