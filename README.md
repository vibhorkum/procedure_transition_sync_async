# procedure_transition_sync_async
Following procedure can be use to transisiton a synchronous standby to asynchronous standby for EDB Postgres Advanced Server 9.6
## Pre-requisite
Following are the pre-requisite for using procedure:

* Create extension pg_background:
For more dtail please use following link:
https://github.com/vibhorkum/pg_background
* Use synchronous_standby_names parameter as given below:
    num_of_standbys(standby1,standby2,...)
* If you are planning to use replication_slots with synchronous standby, please create replication slot with same name of standby name for example: standby1 replication slot will be used by standby1 named synchronous replication.

Procedure does following:@##

*	Identifies all synchronous standby and check the status of each named synchronous standby in pg_stat_replication
*	If named synchronous standby doesn’t exists in pg_stat_replication, then change the synchronous_standby_names parameter in such a way that it doesn’t lose the name of synchronous standbys, however can demote the named synchronous to asynchronous standby. For that its recommended to use following string for synchronous_standby_names parameter:
	2(standby1, standby2…)
*	After demoting the synchronous standby to asynchronous, send an e-mail to DBAs group to notify them about demotion and DBAs can take necessary steps. In EDB Postgres, we have a package UTL_SMTP, which can be used for sending e-mails. Following is an example of such procedure:


