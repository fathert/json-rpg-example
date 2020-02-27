

-- NOTE: As yet untested with a functioning API key!
declare global temporary table TEST_LONG_LAT as (

  -- Encode the address as a URL query string as required by the API.
  with QUERY_STRING as (
      select 'address=' concat 
          systools.urlencode(CITY, 'UTF-8') concat '+' concat 
          systools.urlencode(POSTCODE, 'UTF-8') concat '+' concat 
          systools.urlencode(COUNTRY, 'UTF-8') concat 
          '&key=[YOUR_API_KEY]' as QUERY_PARMS
      
      from(values
        ('Wiesbaden', '65185', 'Germany'),
        ('Frankfurt', '60311', 'Germany'),
        ('Mainz', '55122', 'Germany')
      ) x(CITY, POSTCODE, COUNTRY)
  ),

  -- Call the API for each address query above.
  LONG_LAT as (
    select systools.httpgetclob(
      varchar('https://maps.googleapis.com/maps/api/geocode/json?' concat QUERY_PARMS),
      clob('<httpHeader></httpHeader>') -- <--- Insert any required HTTP headers here
    ) as API_RESPONSE

    from QUERY_STRING
  )

  -- Extract the error, latitude and longitude fields form the result.
  select json_value(API_RESPONSE, '$.error_message' returning varchar(256)) as ERROR,
          json_value(API_RESPONSE, '$.results.geometry.location.lat' returning varchar(256)) as LATTITUDE,
          json_value(API_RESPONSE, '$.results.geometry.location.lng' returning varchar(256)) as LONGITUDE

  from LONG_LAT

) with data with replace
;;

select * from QTEMP.TEST_LONG_LAT
