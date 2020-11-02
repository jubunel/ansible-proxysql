#!/bin/bash

# Author:: Matteo Dessalvi & Michaël de Groot
#
# Copyright:: 2017
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# 
# This script checks the status of a ProxySQL instance routing traffic to
# a Galera cluster. It checks if there is at least 1 node available to write
# and another node available to read from.
#
# It will return: 
# 
#    "HTTP/1.x 200 OK\r" (if the node status is 'Synced') 
# 
# - OR - 
# 
#    "HTTP/1.x 503 Service Unavailable\r" (for any other status) 
# 
# The return values from this script will be used by HAproxy 
# in order to know the (Galera) status of a node.
#

#
# Node status looks fine, so return an 'HTTP 200' status code.
#
http_ok () {
  /bin/echo -e "HTTP/1.1 200 OK\r\n"
  /bin/echo -e "Content-Type: Content-Type: text/plain\r\n"
  /bin/echo -e "\r\n"
  /bin/echo -e "$1"
  /bin/echo -e "\r\n"
}

#
# Node status reports problems, so return an 'HTTP 503' status code.
#
http_no_access () {
  /bin/echo -e "HTTP/1.1 503 Service Unavailable\r\n"
  /bin/echo -e "Content-Type: Content-Type: text/plain\r\n"
  /bin/echo -e "\r\n"
  /bin/echo -e "$1"
  /bin/echo -e "\r\n"
}

#
# Script is called incorrectly, so HTTP 400 Bad Request status code
#
http_bad_request() {
  /bin/echo -e "HTTP/1.1 400 Bad Request\r\n"
  /bin/echo -e "Content-Type: Content-Type: text/plain\r\n"
  /bin/echo -e "\r\n"
  /bin/echo -e "$1"
  /bin/echo -e "\r\n"
}

if [ $# -lt 2 ]; then
    http_bad_request "Not enough arguments. Usage: $0 <writer hostgroup id> <read hostgroup id>"
    exit 1
fi


#
# Run a SQL query on the local MySQL instance.
# 
status_query () {
  SQL_QUERY=`/usr/bin/mysql --defaults-file=/root/.my.cnf --silent --raw -N -e "$1"`
  RESULT=`echo $SQL_QUERY|/usr/bin/cut -d ' ' -f 2` # just remove the value label
  echo $RESULT
}

#
# Safety check: verify if MySQL is up and running.
#
PROXYSQL_STATUS=`/bin/systemctl is-active proxysql.service`
if [ "$PROXYSQL_STATUS" != 'active' ]; then
    http_no_access "ProxySQL instance is reported $PROXYSQL_STATUS.\r\n"
    exit 1
fi

#
# Check how many writers are online
#
NUM_ONLINE=$(status_query "select count(*) FROM runtime_mysql_servers WHERE status='ONLINE'")

#
if [ -z "$NUM_ONLINE" ] || [ "$NUM_ONLINE" = "0" ]; then
     http_no_access "No nodes online"
else
     http_ok "We have nodes online"
fi
