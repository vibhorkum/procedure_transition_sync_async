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

### Procedure performs following operations:

* Identifies all synchronous standby and check the status of each named synchronous standby in pg_stat_replication
* If named synchronous standby doesn’t exists in pg_stat_replication, then change the synchronous_standby_names parameter in such a way that it doesn’t lose the name of synchronous standbys, however can demote the named synchronous to asynchronous standby. For that its recommended to use following string for synchronous_standby_names parameter:
	2(standby1, standby2…)
* After demoting the synchronous standby to asynchronous, send an e-mail to DBAs group to notify them about demotion and DBAs can take necessary steps. In EDB Postgres, we have a package UTL_SMTP, which can be used for sending e-mails. Following is an example of such procedure:
```sql

CREATE OR REPLACE PROCEDURE send_mail (
    p_sender        VARCHAR2,
    p_recipient     VARCHAR2,
    p_subj          VARCHAR2,
    p_msg           VARCHAR2,
    p_mailhost      VARCHAR2
)
IS
    v_conn          UTL_SMTP.CONNECTION;
    v_crlf          CONSTANT VARCHAR2(2) := CHR(13) || CHR(10);
    v_port          CONSTANT PLS_INTEGER := 25;
BEGIN
    v_conn := UTL_SMTP.OPEN_CONNECTION(p_mailhost,v_port);
    UTL_SMTP.HELO(v_conn,p_mailhost);
    UTL_SMTP.MAIL(v_conn,p_sender);
    UTL_SMTP.RCPT(v_conn,p_recipient);
    UTL_SMTP.DATA(v_conn, SUBSTR(
        'Date: ' || TO_CHAR(SYSDATE,
        'Dy, DD Mon YYYY HH24:MI:SS') || v_crlf
        || 'From: ' || p_sender || v_crlf
        || 'To: ' || p_recipient || v_crlf
        || 'Subject: ' || p_subj || v_crlf
        || p_msg
        , 1, 32767));
    UTL_SMTP.QUIT(v_conn);
END;
```sql

* If none of standbys are available, then maintain the setting of synchronous_standby_names as given below:
synchronous_standby_names = 1(standby1, standby2,)
Above setting will cover the scenario, where write should be stopped or should be in hanging state in case all standbys are down

* If replication slots are getting used, then check the lag for replication slots and reset the replication slots, so that we are not overloading pg_xlog. 


### Manual execution:
```sql
exec Transition_sync_async(allowed_slots_lag in bytes, <sender e-mail id>, <receiver email id>
```sql

### Example:
```sql
exec Transition_sync_async(1073741824, 'abc@gmail.com', 'dbas@gmail.com');
```sql
