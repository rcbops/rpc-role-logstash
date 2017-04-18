# Role Documentation for aggie_build


## General Role Info

Aggie is a project located at https://github.com/rackerlabs/aggie. It pulls local private cloud
elk stack logs, filters out the unwanted logs and pushes them to a central log store that spans
multiple accounts. This role can either build and deploy aggie on an lxc conatiner, or download
the package from the local repo and deploy.  

## Tags

  - **aggie-prepare-host**: Install any dependancies and create the aggie user needed before the aggie deployment.
  - **aggie-create-package**:  Builds aggie on the container, copies the tarball to /opt/downloads. Only ran if *'build_on_destination'* is set to *'yes'*.
  - **aggie-prestage-package**: Unpacks package from /opt/downloads to /opt/aggie-version. Will download the package from local repo if *'build_on_destination'* was set to *'no'*.
  - **aggie-install-package**: Changes symlink of /opt/aggie to /opt/aggie-version so the cron calls the new code on next run.
  - **aggie-config**: Configures the environment for runtime configuration changes in /etc/aggie/config. Requires input variables that are not defaulted.


## Inputs and Variables


### Defaults:

  - **aggie_git_repo**: 'http://github.com/rackerlabs/aggie.git'
  - **aggie_git_branch**: '0.1.0'
  - **aggie_release**: '0.1.0'
  - **source_elasticsearch_port**: '9200'
  - **source_elasticsearch_ip**: "{{ internal_lb_vip_address }}"
  - **dest_elasticsearch_port**: '9200'
  - **build_locally**: "no"
  - **repo_uploads_loc**: "http://{{ internal_lb_vip_address }}:8181/uploads"


## Required with no defaults:

  - **dest_elasticsearch_ip**: "IP of your central elk stack elasticsearch server"
  - **aggie_tenant_id**": "Tenant ID.  This is used to tag log messages. Must be unique per tenant."

### Common Overrides

  - 'build_locally':  If the container has access to the internet and you don't need to go through the repo servers, 
                      You can set this to 'yes'.  When set to 'no' the aggie_build role will need to be run first
                      to build and upload a package to your repo servers.



### Results

The end result will be the following:

  - A version directory under /opt/aggie-version
  - A symlink at /opt/aggie pointing to /opt/aggie-version
  - A cron wrapper under /usr/local/bin/aggie_run.sh
  - A cron config at /etc/cron.d/aggie
  - An 'aggie' user created to run the process under.



## Usage

You will need a playbook to call the role.  This will be ran on the localhost where the
package is build and the logger server it will be setting on.  


```
# cat aggie.yml 
```

```
---
- name: Setup Aggie host
  hosts: 'aggie_all:logger_all'
  roles:
    - "aggie"
  vars:
    is_metal: "{{ properties.is_metal | default(False) }}"
```

```
# openstack-ansible aggie.yml --limit 'aggie_all' -e 'dest_elasticsearch_ip="ip_addr_of_central_elk" aggie_tenant_id=123456 build_on_destination=yes'
```

