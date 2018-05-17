#!/bin/bash


########################################
# Simple function to centralize logging
########################################
function logIt {

    LEVEL=$1
    MESSAGE=$2

    echo "[${LEVEL}]: ${MESSAGE}"
}


#################################################
# Install any dependancies needed for the tests
#################################################
function installDeps {

    logIt 'INFO' 'Updating apt cache'
    apt-get update > /dev/null 2>&1
    if [ $? != 0 ] ; then
        logIt 'ERROR' 'Updating apt-cache failed'
        exit 1
    fi

    # Check if already installed
    INST_LIST=""
    for DEP in ansible curl netcat-openbsd python-pip python-dev build-essential; do
        dpkg -s $DEP > /dev/null 2>&1
        if [ $? != 0 ] ; then
        INST_LIST="${INST_LIST}$DEP "
        fi
    done

    # Install only if needed
    if [ "$INST_LIST" != "" ] ; then
        logIt 'INFO' 'Installing Dependancies'
        apt-get install -y $INST_LIST > /dev/null 2>&1
    fi

    # Install the lastest ansible via pip
    if [ "$DISTRIB_CODENAME" == "trusty" ] ; then
        pip install ansible==1.9.3 > /dev/null 2>&1
    fi

}


#########################################
# Prepare ansible config and locations
#########################################
function prepAnsible {

    if [ ! -e "/etc/ansible/roles" ] ; then
        logIt 'INFO' 'Creating /etc/ansible/roles'
        mkdir /etc/ansible/roles
    fi

    if [ ! -e "/etc/ansible/roles/$(basename $(pwd))" ] ; then
        logIt 'INFO' 'Symlinking the role to the default roles_path'
        ln -s $(pwd) /etc/ansible/roles/$(basename $(pwd))
        if [ ! -e "/etc/ansible/roles/$(basename $(pwd))" ] ; then
            logIt 'ERROR' 'Failed creating role symlink'
            exit 1
        fi
    fi
}


#############################################
# Run the logstash role with temp playbook
#############################################
function runRoleLocally {
    logIt 'INFO' 'Creating temp playbook under ./example.yml'
    cat <<EOF > ./example.yml
- name: Setup Logstash host
  hosts: localhost
  vars:
    - log_aggr_enable: True
    - log_aggr_central_es_host: localhost
    - log_aggr_enable_ssl: False
    - log_aggr_account_id: 123456
  roles:
    - "$(basename $(pwd))"
EOF

    logIt 'INFO' 'Run example.yml role'
    if [ "$DISTRIB_CODENAME" == "trusty" ] ; then
        /usr/local/bin/ansible-playbook -e 'ansible_connection=local' -i 'localhost,' example.yml
    else
        ansible-playbook -e 'ansible_connection=local' -i 'localhost,' example.yml
    fi
}


########################################################
# Install elasticsearch and set up locally for testing
########################################################
function installElasticSearch {

    # Install java 8 for testing on trusty(xenial has this by default)
    if [ "$DISTRIB_CODENAME" == "trusty" ] ; then
        dpkg -s oracle-java8-installer > /dev/null 2>&1
        if [ $? != 0 ] ; then
            logIt 'INFO' 'Installing openjdk 8 for ES'
            add-apt-repository -y ppa:webupd8team/java > /dev/null 2>&1
            apt-get update > /dev/null 2>&1
            echo debconf shared/accepted-oracle-license-v1-1 select true | debconf-set-selections
            echo debconf shared/accepted-oracle-license-v1-1 seen true | debconf-set-selections
            apt-get install -y oracle-java8-installer > /dev/null 2>&1
        fi
    fi

    # Install elasticsearch package
    dpkg -s elasticsearch > /dev/null 2>&1
    if [ $? != 0 ] ; then
        logIt 'INFO' 'Installing elasticsearch'
        apt-get install -y elasticsearch > /dev/null 2>&1
    fi


    # Enable if not
    if [ "$DISTRIB_CODENAME" == "xenial" ] ; then
        systemctl status elasticsearch > /dev/null 2>&1
    else
        service elasticsearch status > /dev/null 2>&1
    fi

    if [ $? != 0 ] ; then
        logIt 'INFO' 'Starting ElasticSearch'
        if [ "$DISTRIB_CODENAME" == "trusty" ] ; then
            service elasticsearch start > /dev/null 2>&1
            service elasticsearch status > /dev/null 2>&1
        else
            systemctl start elasticsearch > /dev/null 2>&1
            systemctl status  elasticsearch > /dev/null 2>&1
        fi
        if [ $? != 0 ] ; then
            logIt 'ERROR' 'Elasticsearch failed to start'
            exit 1
        fi
    fi


    # Wait for a bit for the app to initalize
    WAIT_SEC=30
    logIt 'INFO' "Waiting for ${WAIT_SEC} seconds for elasticsearch to initalize"
    sleep ${WAIT_SEC}

    # Set up a pipeline to do some simple taging to test aggregation.
    cat <<EOF > /tmp/pipeline.json
{
  "description" : "Pipeline to update fields if account in maintenance",
  "processors" : [
    {
      "set": {
        "field": "from_pipeline",
        "value": "yes"
      }
    }
  ]
}
EOF
    curl -s http://localhost:9200/_ingest/pipeline/log-aggr-pipeline -XGET 2>/dev/null | grep 'from_pipeline' > /dev/null 2>&1
    if [ $? != 0 ] ; then

        logIt 'INFO' 'Setting up ElasticSearch Pipeline for testing'
        curl http://localhost:9200/_ingest/pipeline/log-aggr-pipeline -H 'Content-Type: application/json' -XPUT -d @/tmp/pipeline.json > /dev/null 2>&1

        curl -s http://localhost:9200/_ingest/pipeline/log-aggr-pipeline -XGET 2>/dev/null | grep 'from_pipeline' > /dev/null 2>&1
        if [ $? != 0 ] ; then
            logIt 'ERROR' 'ElasticSearch pipeline creation failed'
            exit 1
        fi
    fi

}



########################################################
# Install filebeat and set up locally for testing
########################################################
function installFilebeat {

    # Install filebeat package
    dpkg -s filebeat > /dev/null 2>&1
    if [ $? != 0 ] ; then
        logIt 'INFO' 'Installing filebeat'
        apt-get install -y filebeat > /dev/null 2>&1
    fi


    # Enable if not
    if [ "$DISTRIB_CODENAME" == "xenial" ] ; then
        systemctl status filebeat > /dev/null 2>&1
    else
        service filebeat status > /dev/null 2>&1
    fi

    if [ $? != 0 ] ; then
        logIt 'INFO' 'Starting Filebeat'
        if [ "$DISTRIB_CODENAME" != "xenial" ] ; then
            service filebeat start > /dev/null 2>&1
            service filebeat status > /dev/null 2>&1
        else
            systemctl start filebeat > /dev/null 2>&1
            systemctl status  filebeat > /dev/null 2>&1
        fi
        if [ $? != 0 ] ; then
            logIt 'ERROR' 'Filebeat failed to start'
            exit 1
        fi
    fi

    # Set up a test log
    if [ ! -e "/var/log/logstashtest.log" ] ; then
        logIt 'INFO' 'Creating test log /var/log/logstashtest.log'
        touch /var/log/logstashtest.log
    fi

    # Configure filebeat for test log and local logstash
    grep '/var/log/logstashtest.log' /etc/filebeat/filebeat.yml > /dev/null 2>&1
    if [ $? != 0 ] ; then

        cat <<EOF > /etc/filebeat/filebeat.yml
filebeat.prospectors:

- input_type: log

  paths:
    - /var/log/logstashtest.log

output.logstash:
  hosts: ["localhost:5044"]

EOF

        # Restart the service
        logIt 'INFO' 'Restarting Filebeat'
        if [ "$DISTRIB_CODENAME" != "xenial" ] ; then
            service filebeat restart > /dev/null 2>&1
            service filebeat status > /dev/null 2>&1
        else
            systemctl restart filebeat > /dev/null 2>&1
            systemctl status  filebeat > /dev/null 2>&1
        fi
        if [ $? != 0 ] ; then
            logIt 'ERROR' 'Filebeat failed to restart'
            exit 1
        fi

    fi

}


######################################
# Input functions to push to logstash
######################################
function sendTCPLog {
    logIt 'INFO' 'Sending test logstash log via TCP'
    echo '{ "message": "'$@'"}' | nc localhost 5140
}
function sendSyslogLog {
    logIt 'INFO' 'Sending test logstash log via syslog'
    if [ "$DISTRIB_CODENAME" == "xenial" ] ; then
        logger -n localhost -P 5544 "$@"
    else
        # Trusty's logger only supports udp
        echo "$@" | nc localhost 5544
    fi
}
function sendFilebeatLog {
    logIt 'INFO' 'Sending test logstash log via filebeat'
    echo "$@" >> /var/log/logstashtest.log
}

####################################
# Basic test for inputs and outputs
####################################
function testInputsAndOutputs {


    # Clean out the logs
    curl -s http://localhost:9200/logstash* -XDELETE 2>/dev/null | grep 'from_pipeline' > /dev/null 2>&1
    curl -s http://localhost:9200/filebeat* -XDELETE 2>/dev/null | grep 'from_pipeline' > /dev/null 2>&1
    sleep 2

    TESTLOG="This log is being used to test the logstash inputs and outputs"

    # Send test logs
    sendTCPLog $TESTLOG
    sendSyslogLog $TESTLOG
    sendFilebeatLog $TESTLOG

    # Wait for ES to catch up
    WAIT_SEC=30
    logIt 'INFO' "Waiting for ${WAIT_SEC} seconds for filebeat/logstash/elasticsearch to process things"
    sleep $WAIT_SEC

    # Check elasticsearch for test logs
    curl -s "localhost:9200/_search?default_operator=AND&q=from_pipeline:yes%20tags:logstash-input-syslog" | grep '"hits":{"total":1' > /dev/null 2>&1
    if [ $? == 0 ] ; then
        logIt 'SUCCESS' 'Syslog input with log aggregation output succeded'
    else
        logIt 'FAIL' 'Syslog input with log aggregation output failed'
        exit 1
    fi

    curl -s "localhost:9200/_search?default_operator=AND&q=from_pipeline:yes%20tags:logstash-input-tcp" | grep '"hits":{"total":1' > /dev/null 2>&1
    if [ $? == 0 ] ; then
        logIt 'SUCCESS' 'TCP input with log aggregation output succeded'
    else
        logIt 'FAIL' 'TCP input with log aggregation output failed'
        exit 1
    fi

    curl -s "localhost:9200/_search?default_operator=AND&q=from_pipeline:yes%20source:\/var\/log\/logstashtest.log" | grep '"hits":{"total":1' > /dev/null 2>&1
    if [ $? == 0 ] ; then
        logIt 'SUCCESS' 'Filebeat input with log aggregation output succeded'
    else
        logIt 'FAIL' 'Filebeat input with log aggregation output failed'
        exit 1
    fi

    curl -s "localhost:9200/_search?default_operator=AND&q=NOT%20from_pipeline:yes%20tags:logstash-input-syslog" | grep '"hits":{"total":1' > /dev/null 2>&1
    if [ $? == 0 ] ; then
        logIt 'SUCCESS' 'Syslog input with local elasticsearch output succeded'
    else
        logIt 'FAIL' 'Syslog input with local elasticsearch output failed'
        exit 1
    fi

    curl -s "localhost:9200/_search?default_operator=AND&q=NOT%20from_pipeline:yes%20tags:logstash-input-tcp" | grep '"hits":{"total":1' > /dev/null 2>&1
    if [ $? == 0 ] ; then
        logIt 'SUCCESS' 'TCP input with local elasticsearch output succeded'
    else
        logIt 'FAIL' 'TCP input with local elasticsearch output failed'
        exit 1
    fi

    curl -s "localhost:9200/_search?default_operator=AND&q=NOT%20from_pipeline:yes%20source:\/var\/log\/logstashtest.log" | grep '"hits":{"total":1' > /dev/null 2>&1
    if [ $? == 0 ] ; then
        logIt 'SUCCESS' 'Filebeat input with local elasticsearch output succeded'
    else
        logIt 'FAIL' 'Filebeat input with local elasticsearch output failed'
        exit 1
    fi

    # Clean out the logs
    curl -s http://localhost:9200/logstash* -XDELETE 2>/dev/null | grep 'from_pipeline' > /dev/null 2>&1
    curl -s http://localhost:9200/filebeat* -XDELETE 2>/dev/null | grep 'from_pipeline' > /dev/null 2>&1
}

######################
# Run all the things
######################
function runTests {

    JAVA_WAIT=60
    logIt 'INFO' "Lets give java ${JAVA_WAIT} seconds to initialize before starting tests"
    sleep $JAVA_WAIT

    logIt 'INFO' 'Running rpc-role-logstash tests'

    # Test Logstash Inputs and Outputs
    testInputsAndOutputs

    # Might want to through specific filter tests during an eval for grokparsefailures
    # testFilters

}

######################
# Artifact Workaround
######################
function artifactWorkaround {

    logIt 'INFO' 'Removing ansible on trusty as it causes issues with post scripts'
    if [ "$DISTRIB_CODENAME" == "trusty" ] ; then
        pip uninstall -y ansible > /dev/null 2>&1
        apt-get remove -y ansible --purge > /dev/null 2>&1
    fi
}


#######
# Main
#######

# Source the release file
. /etc/lsb-release

# Install dependancies
installDeps

# Prepare ansible for the logstash run
prepAnsible

# Run the rpc-role-logstash role
runRoleLocally

# Install elasticsearch using java and elasticsearch repo should already be set up
installElasticSearch

# Install filebeat for input testing
installFilebeat

# Run all the tests
runTests

# Artifact run workaround
artifactWorkaround

# If we make it this far, exit with a success
exit 0
