CREATE OR REPLACE FUNCTION payment_service._serialize_subscription_basic_data(json, with_default json)
  RETURNS json
  LANGUAGE plpgsql
  IMMUTABLE
AS $function$
        declare
            _result json;
            _is_international boolean default false;
        begin
            -- check if is foreign payment
            _is_international := coalesce(coalesce(nullif(($1->>'is_international'), '')::boolean, nullif(($2->>'is_international'), '')::boolean)::boolean, false);

            select json_build_object(
                'current_ip', coalesce(($1->>'current_ip')::text,($2->>'current_ip')),
                'anonymous', coalesce(coalesce(
                    ($1->>'anonymous')::boolean,
                    ($2->>'anonymous')::boolean
                ), false),
                'is_international', coalesce(coalesce(
                    ($1->>'is_international')::boolean,
                    ($2->>'is_international')::boolean
                ), false),
                'amount', core_validator.raise_when_empty(
                    coalesce(
                        (($1->>'amount')::integer)::text,
                        (($2->>'amount')::integer)::text
                    ),
                    'amount'
                ),
                'payment_method', core_validator.raise_when_empty(
                    lower(coalesce(
                        ($1->>'payment_method')::text,
                        ($2->>'payment_method')::text
                    )),
                    'payment_method'
                ),
                'credit_card_owner_document', (
                    lower(coalesce(
                        ($1->>'credit_card_owner_document')::text,
                        ($2->>'credit_card_owner_document')::text
                    ))
                ),
                'customer', json_build_object(
                    'name', core_validator.raise_when_empty(
                        coalesce(
                            ($1->'customer'->>'name')::text,
                            ($2->'customer'->>'name')::text
                        ),
                        'name'
                    ),
                    'document_number', (
                        case _is_international
                        when false then
                            core_validator.raise_when_empty(
                                coalesce(
                                    ($1->'customer'->>'document_number')::text,
                                    ($2->'customer'->>'document_number')::text
                                ),
                                'document number')
                        else
                            coalesce(
                                ($1->'customer'->>'document_number')::text,
                                ($2->'customer'->>'document_number')::text
                            )
                        end),
                    'address', json_build_object(
                        'street', core_validator.raise_when_empty(
                            coalesce(
                                ($1->'customer'->'address'->>'street')::text,
                                ($2->'customer'->'address'->>'street')::text
                            ),
                            'street'
                        ),
                        'street_number', (
                            case _is_international
                            when false then
                                core_validator.raise_when_empty(
                                    coalesce(
                                        ($1->'customer'->'address'->>'street_number')::text,
                                        ($2->'customer'->'address'->>'street_number')::text
                                    ),
                                    'street_number')
                            else
                                coalesce(
                                    ($1->'customer'->'address'->>'street_number')::text,
                                    ($2->'customer'->'address'->>'street_number')::text
                                )
                            end
                        ),
                        'neighborhood', (
                            case _is_international
                            when false then
                                core_validator.raise_when_empty(
                                    coalesce(
                                        ($1->'customer'->'address'->>'neighborhood')::text,
                                        ($2->'customer'->'address'->>'neighborhood')::text
                                    ),
                                    'neighborhood')
                            else
                                coalesce(
                                    ($1->'customer'->'address'->>'neighborhood')::text,
                                    ($2->'customer'->'address'->>'neighborhood')::text
                                )
                            end
                        ),
                        'zipcode', core_validator.raise_when_empty(
                            coalesce(
                                ($1->'customer'->'address'->>'zipcode')::text,
                                ($2->'customer'->'address'->>'zipcode')::text
                            ),
                            'zipcode'
                        ),
                        'country', core_validator.raise_when_empty(
                            coalesce(
                                ($1->'customer'->'address'->>'country')::text,
                                ($2->'customer'->'address'->>'country')::text
                            ),
                            'country'
                        ),
                        'country_en', core_validator.raise_when_empty(
                            coalesce(
                                ($1->'customer'->'address'->>'country_en')::text,
                                ($2->'customer'->'address'->>'country_en')::text
                            ),
                            'country_en'
                        ),
                        'state', core_validator.raise_when_empty(
                            coalesce(
                                ($1->'customer'->'address'->>'state')::text,
                                ($2->'customer'->'address'->>'state')::text
                            ),
                            'state'
                        ),
                        'city', core_validator.raise_when_empty(
                            coalesce(
                                ($1->'customer'->'address'->>'city')::text,
                                ($2->'customer'->'address'->>'city')::text
                            ),
                            'city'
                        ),
                        'complementary', coalesce(
                            ($1->'customer'->'address'->>'complementary')::text,
                            ($2->'customer'->'address'->>'complementary')::text
                        )
                    ),
                    'phone', json_build_object(
                        'ddi', (
                            case _is_international
                            when false then
                                core_validator.raise_when_empty(
                                    coalesce(
                                        ($1->'customer'->'phone'->>'ddi')::text,
                                        ($2->'customer'->'phone'->>'ddi')::text
                                    ),
                                    'phone_ddi')
                            else
                                coalesce(
                                    ($1->'customer'->'phone'->>'ddi')::text,
                                    ($2->'customer'->'phone'->>'ddi')::text
                                )
                            end
                        ),
                        'ddd', (
                            case _is_international
                            when false then
                                core_validator.raise_when_empty(
                                    coalesce(
                                        ($1->'customer'->'phone'->>'ddd')::text,
                                        ($2->'customer'->'phone'->>'ddd')::text
                                    ),
                                    'phone_ddd')
                            else
                                coalesce(
                                    ($1->'customer'->'phone'->>'ddd')::text,
                                    ($2->'customer'->'phone'->>'ddd')::text
                                )
                            end
                        ),
                        'number', (
                            case _is_international
                            when false then
                                core_validator.raise_when_empty(
                                    regexp_replace(coalesce(
                                            ($1->'customer'->'phone'->>'number')::text,
                                            ($2->'customer'->'phone'->>'number')::text
                                    ), '[^\d]+', ''),
                                'phone_number')
                            else
                                regexp_replace(coalesce(
                                    ($1->'customer'->'phone'->>'number')::text,
                                    ($2->'customer'->'phone'->>'number')::text
                                ), '[^\d]+', '')
                            end
                        )
                    )
                )
            ) into _result;

            return _result;
        end;
    $function$
;
