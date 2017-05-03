CREATE OR REPLACE PROCEDURE Transition_sync_async(allowed_slots_lag NUMERIC, p_sender TEXT, p_recipient TEXT)
AS
   DECLARE
       standby_names TEXT[];
       sync_names TEXT;
       sync_count BIGINT;
       alter_system_cmd TEXT;
       reload_status BOOLEAN;
       background_result TEXT;
       old_stndby_cnt BIGINT;
       stale_slots RECORD;
       async_standby_names TEXT;
       reset_replication_slots TEXT := '';
       email_msg TEXT := '';
   BEGIN
       /* This procedure parse the synchronous standbys names and
       transition synchronous standby to asynchronous in case its
       no more in pg_stat_replication.application_name.

       Pre-requisite of this procedure is that you have to use
       synchronous_standby_names value as given below:
       synchronos_standby_names= num(standby1,standby2,...)
       For example: 
       synchronous_standby_names = 2(standby1,standby2)

       This procedure also check if old synchronous standby is attached
       and accordingly transition back to synchronous standby.
       */

       /* find the current value of synchronos_standby_names */
       sync_names := pg_catalog.current_setting('synchronous_standby_names');
       DBMS_OUTPUT.PUT_LINE('INFO: synchronos_standby_names => '||sync_names);

       /* convert into comma seperated string */
       sync_names := pg_catalog.replace(pg_catalog.replace(sync_names,
                                   '(',
                                   ','),
                       ')');
       standby_names := pg_catalog.string_to_array(sync_names,
                                               ',');
       SELECT
           pg_catalog.array_agg(trim(names)) INTO standby_names
       FROM
           unnest(standby_names) foo(names);
       DBMS_OUTPUT.PUT_LINE('INFO: standby_name => '|| standby_names::TEXT);

       /* capture old standby count */
       old_stndby_cnt := standby_names[1];
       DBMS_OUTPUT.PUT_LINE('INFO: old standby count => '|| old_stndby_cnt);

       /* verify if we have all standbys */
       SELECT
           count(1) INTO sync_count
       FROM
           pg_catalog.pg_stat_replication r
           JOIN unnest(standby_names) foo (names)
               ON (r.application_name = foo.names)
       WHERE
           r.application_name IS NOT NULL;
       DBMS_OUTPUT.PUT_LINE('INFO: synchronous_standby_count => '|| sync_count);

       /* verify standby_count is same or not and accordingly update
          System catalog */
       IF old_stndby_cnt != sync_count THEN
           /* sync_count should not be zero. If it is then assume 1 
              This is important. Because from durability point, we 
              always recommend to have atlease on synchronous standby */

            /* if none standbys are available then make one, this will result
               in hanging of standby. However from durability point, we need 
               to have atleast one synchronous standby */
            IF sync_count = 0 THEN
                sync_count = 1;
            END IF;

           /* extract synchronous strandbys which are not available */
           SELECT pg_catalog.string_agg(names,',') INTO async_standby_names FROM ( SELECT
                   *
               FROM
                   unnest(standby_names)
               OFFSET 1) foo(names) LEFT OUTER JOIN pg_stat_replication r 
               ON (r.application_name = foo.names) WHERE r.application_name IS NULL;

            DBMS_OUTPUT.PUT_LINE('INFO: asynchronous standby => '|| async_standby_names);

           /* based on available synchronous standby count rebuild settings */
           SELECT
               pg_catalog.string_agg(names,',') INTO sync_names
           FROM (
               SELECT
                   *
               FROM
                   unnest(standby_names)
               OFFSET 1) foo (names);

           sync_names := sync_count || '(' || sync_names || ')';
           DBMS_OUTPUT.PUT_LINE('INFO: synchronous_names => '|| sync_names);

           alter_system_cmd := 'ALTER SYSTEM SET synchronous_standby_names TO ' || quote_literal(sync_names);
           SELECT result INTO background_result FROM pg_background_result(pg_background_launch(alter_system_cmd)) as (result TEXT);
           DBMS_OUTPUT.PUT_LINE('INFO: background result => '|| background_result);

           SELECT
               pg_reload_conf() INTO reload_status;
           DBMS_OUTPUT.PUT_LINE('INFO: reload stations => '||reload_status);

           /* reset the replication slots where lag is greater than 1 GB */
           FOR stale_slots IN   SELECT
                                    slot_name,
                                    pg_catalog.pg_xlog_location_diff(pg_current_xlog_location(),
                                        restart_lsn) AS lag
                                FROM
                                    pg_replication_slots
                                WHERE
                                    active_pid IS NULL
                                    AND slot_type = 'physical'
           LOOP
                IF stale_slots.lag > allowed_slots_lag THEN
                    reset_replication_slots := reset_replication_slots||','||stale_slots.lag;
                    PERFORM pg_catalog.pg_drop_replication_slot(stale_slots.slot_name);
                    PERFORM pg_catalog.pg_create_physical_replication_slot(stale_stlots.slote_name);
                END IF;
          END LOOP;
 
         /* send message mail user using SMTP if mail address is specified */
          IF p_recipient IS NOT NULL AND p_recipient != '' AND p_sender IS NOT NULL AND p_sender != ''
          THEN
               IF async_standby_names IS NOT NULL AND async_standby_names != '' THEN
                  email_msg :=  'Synchronous standby transitioned to Asynchronous: '|| async_standby_names;
               END IF;
               IF reset_replication_slots != '' THEN
                  email_msg := email_msg ||E'\n' ||
                               'Reset replication slots: '|| reset_replication_slots;
               END IF;
               IF email_msg != '' THEN
                  send_mail(p_sender, p_recipient,'Synchronous standby transitioned to Asynchronous',email_msg,'master.host.com');
               END IF;
          END IF;

       END IF;
END;
