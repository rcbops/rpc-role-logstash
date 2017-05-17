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
    if [ $? != 0 ]
    then
        logIt 'ERROR' 'Updating apt-cache failed'
        exit 1   
    fi

    logIt 'INFO' 'Installing Dependancies'
    apt-get install -y ansible > /dev/null 2>&1
    if [ $? != 0 ]
    then
        logIt 'ERROR' 'Install Dependancies Failed'
        exit 1   
    fi
    
}


#########################################
# Prepare ansible config and locations
#########################################
function prepAnsible {

    if [ ! -e "/etc/ansible/roles" ]
    then
        logIt 'INFO' 'Creating /etc/ansible/roles'
        mkdir /etc/ansible/roles
    fi

    if [ ! -e "/etc/ansible/roles/$(basename $(pwd))" ]
    then
        logIt 'INFO' 'Symlinking the role to the default roles_path'
        ln -s $(pwd) /etc/ansible/roles/$(basename $(pwd))
        if [ ! -e "/etc/ansible/roles/$(basename $(pwd))" ]
        then
  
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
  roles:
    - "$(basename $(pwd))"
EOF

    logIt 'INFO' 'Run example.yml role'
    ansible-playbook -i 'localhost' example.yml
}


#######
# Main
#######

installDeps
prepAnsible
runRoleLocally


