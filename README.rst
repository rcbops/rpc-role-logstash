Ansible Logstash Role
######################
:tags: cloud, ansible, logstash
:category: \*nix

Role for the deployment of Logstash within Rackspace Private Cloud.

Default variables in defaults/main.yml
--------------------------------------

- **logstash_apt_repo_url, logstash_apt_repos and logstash_apt_keys**: Used to define repo in apt sources entries
- **logstash_syslog_port**: Logstash input port to listen for rsyslog events(default: 5544)
- **logstash_tcp_port**: Logstash input port listen for tcp/json events(default: 5140)
- **logstash_beats_port**: Logstash input port to listen for filebeat events(default: 5044) 
- **elasticsearch_host**: Logstash output host for local elasticsearch services(default: localhost)
- **elasticsearch_http_port**: Logstash output port for local elasticsearch services(default: 9200)
- **logstash-plugins**: Plugins needed for input/output entries. (logstash-input-beats needed for filbeat input entry)
- **logging_upgrade**: Can set to true when running ansible to enable an upgrade of logstash.

Variables used to push logs to a centralized location from several private cloud environments.

- **log_aggr_enable**: Enables configuring logstash to push logs to a central elasticsearch server.(default: False)
- **log_aggr_central_es_host**: Destination host of central elasticsearch server(Default: SomeCentralElasticSearchVIP)
- **log_aggr_central_es_port**: Destination post of central elasticsearch server(Default: 9200)
- **log_aggr_enable_ssl**: If setting behind an ssl terminated reverse proxy.(Default: True)
- **log_aggr_account_id**: Customer account id. Used to search specific customer's logs.(Default: 000000)
- **log_aggr_filters_path**: Allow for a custom filter path for log aggregation. (Default: "{{ role_path }}/templates/log_aggr")

Variables used in vars/<distro-version>.yml files
--------------------------------------------------

- **logstash_apt_packages**: Defines correct package names for logstash and openjdk for the supported systems


Ansible Variables
-----------------

Used to determine which configs to look for in ./vars.

- **ansible_distribution**
- **ansible_distribution_version**
- **ansible_distribution_major_version** 
- **ansible_os_family**



Usage Example
-------------
.. code-block:: yaml

    - name: Setup Logstash host
      hosts: logstash_all
      user: root
      vars:
        - elasticsearch_host: "{{ hostvars[groups['elasticsearch'][0]]['container_address'] }}"
      roles:
        - role: "rpc-role-logstash"
