**FREE
//**************************************************************************************************************
// Basic example of calling a JSON webservice using embedded RPG.
//  The example API is from OpenWeather and can be found here https://openweathermap.org/current#severalid
//**************************************************************************************************************
ctl-opt copyright('')
  datfmt(*ISO) datedit(*YMD/) timfmt(*ISO)
  debug(*YES) option(*NODEBUGIO: *SRCSTMT)
  main(main);

dcl-c SQL_NOT_EOF *OFF;
dcl-c SQL_EOF     *ON;

dcl-c HOST     'https://samples.openweathermap.org';
dcl-c ENDPOINT '/data/2.5/group?id=&CITY_IDS&units=metric&appid=&APPID';

// Reference fields for use where using SQLTYPE is not legal.
dcl-ds ref_t template qualified inz;
  xmlLocator SQLTYPE(XML_LOCATOR);
end-ds;

// Extracted weather data.
dcl-ds json_data_t qualified template inz;
  city varchar(128);
  id int(10);
  main varchar(128);
  desc varchar(1024);
end-ds;

//**************************************************************************************************************
// Entry point
//**************************************************************************************************************
dcl-proc main;
  dcl-pi *N;
  end-pi;

  dcl-ds json_data likeds(json_data_t);
  dcl-s message varchar(1000);

  // The sample OpenWeather API always returns the same response regardless of the input.
  // I.e Moscow, Kiev and London.
  OpenWeatherApi('524901,703448,2643743');

  dow ReadWeatherApi(json_data);

    // Do something with the data...
    // json_data.city
    // json_data.main

    message = 'The weather in ' + json_data.city + ' is ' + json_data.main + '!';

  enddo;

  CloseWeatherApi();

end-proc;
//**************************************************************************************************************
// Call the OpenWeather API and open the JSON response for reading.
//**************************************************************************************************************
dcl-proc OpenWeatherApi;
  dcl-pi *N;
    cities varchar(100) options(*varsize) const;  // List of city ids
  end-pi;

  dcl-c APPID 'b6907d289e10d714a6e88b30761fae22'; // API key, usually provided by the API owner
  dcl-s response SQLTYPE(CLOB_LOCATOR);
  dcl-s requestHeaders SQLTYPE(XML_LOCATOR);

  // Create the XML representation of the HTTP request headers.
  requestHeaders = CreateHttpRequestHeaders();

  // Execute the webservice call.
  exec sql
    set :response = systools.httpgetclob(
      concat(:HOST, replace(replace(:ENDPOINT, '&CITY_IDS', :cities), '&APPID', :APPID)),
      :requestHeaders
    );
  CheckSqlState(SQLSTT);

  // Create and open a cursor to parse the JSON repsonse.
  exec sql
    declare JSON_CURSOR cursor for

    select coalesce(CITY, ''),
           coalesce(WEATHER_ID, 0),
           coalesce(MAIN, ''),
           coalesce(DESC, '')

    from json_table(
      :response,
      'lax $.list[*]'   -- Occurs once per city
      columns(
        CITY varchar(50) path '$.name',
        nested path 'lax $.weather[*]' -- Occurs 1 or more times for each city
        columns(
          WEATHER_ID integer path '$.id',
          MAIN varchar(50) path '$.main',
          DESC varchar(50) path '$.description'
        )
      )
    ) as X;

  exec sql open JSON_CURSOR;
  CheckSqlState(SQLSTT);

end-proc;
//**********************************************************************************
// Read a JSON array element from the SQL cursor.
//**********************************************************************************
dcl-proc ReadWeatherApi;
  dcl-pi *N like(*IN);
    json_data likeds(json_data_t);
  end-pi;

  exec sql fetch JSON_CURSOR into :json_data;

  return CheckSqlState(SQLSTT) <> SQL_EOF;

end-proc;
//**********************************************************************************
// Close the cursor
//**********************************************************************************
dcl-proc CloseWeatherApi;

  exec sql close JSON_CURSOR;
  CheckSqlState(SQLSTT);

end-proc;
//**********************************************************************************
// Check SQL state (DUMMY!)
//  This would be replaced by a proper SQL exception testing procedure
//**********************************************************************************
dcl-proc CheckSqlState;
  dcl-pi *N like(*IN);
    sqlState like(SQLSTT) const;
  end-pi;

  dcl-s x int(5);

  select;
    when sqlState = '02000';
      return SQL_EOF;

    when sqlState = '00000';
      return SQL_NOT_EOF;

    other;
      dsply 'Error!';
      // Force a stupid error in lieu of sending an proper exception...
      x = x / x;
      return SQL_EOF;

  endsl;

end-proc;
//**************************************************************************************************************
// Create HTTP request headers.
//  Returns an <httpHeader>...</httpHeader> element as required by the SQL webservice APIs
//  We must accept a JSON response, so set "Accept" header accordingly.
//**************************************************************************************************************
dcl-proc CreateHttpRequestHeaders;
  dcl-pi *N like(ref_t.xmlLocator);
  end-pi;

  dcl-s headers like(ref_t.xmlLocator);

  exec sql
    set :headers = xmlelement(
      name "httpHeader",
      xmlattributes(10000 as "connectTimeout", 'true' as "followRedirects"),
      xmlelement(
        name "header",
        xmlattributes('application/json' as "Accept")
      )
    );

  return headers;

end-proc;
//**************************************************************************************************************
