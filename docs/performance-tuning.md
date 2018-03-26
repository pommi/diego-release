# Performance Tuning Recommendations

This document describes recommendations for performance tuning of the Diego Data Store.


### Table of Contents

1. [MySQL Performance Tuning](#mysql-performance-tuning)
1. [BBS and Locket Tuning](#bbs-locket-tuning)


### <a name="mysql-performance-tuning"></a> MySQL Performance Tuning

Operators can set the following values in the case of a high traffic deployment:

* Set the `innodb_flush_log_at_trx_commit` to `0` so that the log buffer is written to the log file approximately every second. For more details check the [MySQL manual](https://dev.mysql.com/doc/refman/5.7/en/innodb-parameters.html#sysvar_innodb_flush_log_at_trx_commit)

* If you are using [CF Mysql Release](https://github.com/cloudfoundry/cf-mysql-release), then set the `cf_mysql.mysql.innodb_flush_log_at_trx_commit` in the deployment mainfest to `0`.

The following operation files are used to benchmark the BBS at scale, via [time-rotor](https://diego.ci.cf-app.com/teams/main/pipelines/main?groups=time-rotor).  This assumes that you are using [cf-deployment](https://github.com/cloudfoundry/cf-deployment/).

* [mysql.yml](operations/time-rotor-gcp/mysql.yml)
* [postgres.yml](operations/time-rotor-gcp/postgres.yml)
* [overrides.yml](operations/time-rotor-gcp/overrides.yml)

### <a name="bbs-locket-tuning"></a> BBS and Locket Tuning

#### BBS and Locket VM instance types:

Avoid VM instance types with shared or bursty CPU for the BBS and Locket vms.  These include the fi-micro and g1-small instance types on GCP and the `t2.*` instance types on AWS EC2.

#### Calculating worst-case database connection usage:

????????????????????

### NEED THE FOLLOWING ###

* recommended tuning for cf-mysql nodes, including tuning we use in CI environments at scale and disabling audit logging
* explaining how to calculate worst-case database connection usage from BBS and Locket based on their max-DB-connections configuration and the number of deployed instances
* recommending against shared-CPU VM types for BBS and Locket to reduce CPU contention and starvation

<!-- Random Notes -->

* time-rotor uses n1-standard-16 for the diego-api instance - this is pretty beefy, whats the general recomendation here?

* moved the following ops files from deployments-diego/time-rotor-gcp to diego-release/operations/time-rotor-gcp:
* mysql.yml
* overrides.yml
* postgres.yml
