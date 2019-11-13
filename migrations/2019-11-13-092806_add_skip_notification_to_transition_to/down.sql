-- This file should undo anything in `up.sql`
CREATE OR REPLACE FUNCTION payment_service.transition_to(payment payment_service.catalog_payments, status payment_service.payment_status, reason json)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
        declare
            _project project_service.projects;
            _contributors_count integer;
            _contributor community_service.users;
            _project_owner community_service.users;
            _notification_relations json;
        begin
            -- check if to state is same from state
            if $1.status = $2 then
                return false;
            end if;

            -- generate a new payment status transition
            insert into payment_service.payment_status_transitions (catalog_payment_id, from_status, to_status, data)
                values ($1.id, $1.status, $2, ($3)::jsonb);

            -- update the payment status
            update payment_service.catalog_payments
                set status = $2,
                    updated_at = now()
                where id = $1.id;

            -- build notification relations object
            _notification_relations := json_build_object(
                'relations', json_build_object(
                    'catalog_payment_id', $1.id,
                    'subscription_id', $1.subscription_id,
                    'project_id', $1.project_id,
                    'reward_id', $1.reward_id,
                    'user_id', $1.user_id
                )
            );

            case $2
            when 'paid' then
                -- deliver paid subscription payment
                if $1.subscription_id is not null
                    and not exists (
                        select true from notification_service.user_catalog_notifications n
                            where n.user_id = $1.user_id
                            and (n.data -> 'relations' ->> 'catalog_payment_id')::uuid = $1.id
                            and n.label = 'paid_subscription_payment'
                    )
                then
                    perform notification_service.notify('paid_subscription_payment', _notification_relations);
                end if;
            when 'refused' then
                -- deliver refused notification card subscription
                if ($1.data->>'payment_method')::text = 'credit_card'
                    and $1.subscription_id is not null
                    and not exists (
                        select true from notification_service.user_catalog_notifications n
                            where n.user_id = $1.user_id
                            and (n.data -> 'relations' ->> 'catalog_payment_id')::uuid = $1.id
                            and n.label = 'refused_subscription_card_payment'
                    )
                then
                    perform notification_service.notify('refused_subscription_card_payment', _notification_relations);
                end if;
            else
            end case;

            return true;
        end;
    $function$
;
---

CREATE OR REPLACE FUNCTION payment_service.transition_to(subscription payment_service.subscriptions, status payment_service.subscription_status, reason json)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
        declare
            _last_payment payment_service.catalog_payments;
            _project project_service.projects;
            _relations_json json;
        begin
            -- check if to state is same from state or deleted, should return false
            if $1.status = $2 or $1.status = 'deleted' then
                return false;
            end if;

            -- get then subscription project
            select * from project_service.projects p 
                where p.id = $1.project_id 
                and p.platform_id = $1.platform_id
                into _project;


            -- generate a new subscription status transition
            insert into payment_service.subscription_status_transitions (subscription_id, from_status, to_status, data)
                values ($1.id, $1.status, $2, ($3)::jsonb);

            -- update the subscription status
            update payment_service.subscriptions
                set status = $2
                where id = $1.id;

            -- get last payment
            select * from payment_service.catalog_payments
                where subscription_id = $1.id order by created_at desc limit 1
                into _last_payment;

            if _project.status not in ('rejected', 'failed', 'successful') then
                -- build relations json
                _relations_json := json_build_object(
                    'relations', json_build_object(
                        'catalog_payment_id', _last_payment.id,
                        'subscription_id', $1.id,
                        'project_id', $1.project_id,
                        'reward_id', $1.reward_id,
                        'user_id', $1.user_id
                    )
                );

                -- deliver notifications based on status
                case $2
                when 'active' then
                    if not exists (
                        select true from notification_service.user_catalog_notifications n
                            where n.user_id = $1.user_id
                                and (n.data -> 'relations' ->> 'subscription_id')::uuid = $1.id
                                and n.label = 'reward_welcome_message'
                    ) and (select r.data->>'welcome_message_body' <> ''
                            and r.data->>'welcome_message_subject' <> ''
                            from  project_service.rewards r where r.id = $1.reward_id
                    ) then
                        perform notification_service.notify('reward_welcome_message', _relations_json);
                    end if;
                when 'inactive' then
                    -- check if is comming from canceled / canceling subscription
                    if  $1.status not in ('canceling', 'canceled') then
                        -- deliver notifications after status changes to inactive
                        perform notification_service.notify('inactive_subscription', _relations_json);
                    end if;
                when 'canceling' then
                -- deliver notifications after status changes to inactive
                    perform notification_service.notify('canceling_subscription', _relations_json);
                when 'canceled' then
                    perform notification_service.notify('canceled_subscription', _relations_json);
                else
                end case;
            end if;

            return true;
        end;
    $function$;
