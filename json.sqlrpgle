**FREE
ctl-opt copyright('')
  datfmt(*ISO) datedit(*YMD/) timfmt(*ISO)
  debug(*YES) option(*NODEBUGIO: *SRCSTMT)
  main(main);


dcl-ds json_data_t qualified template inz;
  count int(10);
  sea varchar(50);
end-ds;

//**************************************************************************************************************
// Entry point
//**************************************************************************************************************
dcl-proc main;
  dcl-pi *N;
  end-pi;

  dcl-ds json_data likeds(json_data_t);

  OpenJson();

  dow ReadJson(json_data);

    // Do something with the data...
    // json_data.count
    // json_data.sea
    dsply json_data.sea;

  enddo;

  CloseJson();

end-proc;

//**************************************************************************************************************
// Open the SQL cursor for the JSON data.
//**************************************************************************************************************
dcl-proc OpenJson;
  dcl-pi *N;
  end-pi;

  exec sql
    declare JSON_CURSOR cursor for

    select coalesce(DATA_LEN, 0),
           coalesce(SEA, '')

    from json_table(
      '{"wData_length":14,"SeasOceans":["Adriatic Sea","Arctic Ocean"]}',
      'lax $'
      columns(
        DATA_LEN varchar(20) path '$.wData_length',
        nested path '$.SeasOceans[*]'
        columns(
          SEA varchar(50) path '$'
        )
      )
    ) as X;

  exec sql open JSON_CURSOR;
  // Check SQLSTT for errors here!

end-proc;
//**********************************************************************************
// Read a JSON array element from the SQL cursor.
//**********************************************************************************
dcl-proc ReadJson;
  dcl-pi *N like(*IN);
    json_data likeds(json_data_t);
  end-pi;

  exec sql
    fetch JSON_CURSOR into :json_data;

  // Check SQLSTT for errors here!

  return SQLSTT <> '02000';

end-proc;
//**********************************************************************************
// Close the cursor
//**********************************************************************************
dcl-proc CloseJson;

  exec sql close JSON_CURSOR;
  // Check SQLSTT for errors here!

end-proc;
