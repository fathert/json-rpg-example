
-- Create a test JSON row in a temporary file.
declare global temporary table JSON_INVOICES as (
  select cast(J_DATA as clob(10K)) as J_DATA
  from(values(
  '{
  "invoices": [
    {
      "invoiceNumber": 2019001,
      "customer": 1,
      "address": "Somewhere in Wiesbaden, Germany",
      "email": "test@test.com",
      "items": [
        {
          "lineNum": 1,
          "item": "SPARE_PART-1",
          "quantity": 3,
          "price": 9.99,
          "discountCodes": [
            "XX",
            "YY"
          ]
        },
        {
          "lineNum": 2,
          "item": "SPARE_PART-2",
          "quantity": 3,
          "price": 1.23
        }
      ]
    },
    {
      "invoiceNumber": 2019002,
      "customer": 2,
      "address": "Somewhere in Guildford, UK",
      "items": [
        {
          "lineNum": 1,
          "item": "SPARE_PART-3",
          "quantity": 3,
          "price": 23.45
        },
        {
          "lineNum": 2,
          "item": "SPARE_PART-4",
          "quantity": 3,
          "price": 87.43,
          "discountCodes": [
            "AA",
            "YY"
          ]
        }
      ]
    }
  ]
}')) x(J_DATA)
) with data with replace
;;

-- Extract invoice header data.
declare global temporary table INVOICE_HEADER as (
  select J.INVOICE_NUMBER,
         J.CUSTOMER,
         J.ADDRESS,
         J.EMAIL

  from QTEMP.JSON_INVOICES JI

  cross join json_table(
    JI.J_DATA,
    'strict $.invoices[*]' -- Extract all elements of "invoices" array
    columns(
      INVOICE_NUMBER int path 'strict $.invoiceNumber',
      CUSTOMER int path 'strict $.customer',
      ADDRESS varchar(256) path 'strict $.address',
      EMAIL varchar(256) path 'lax $.email' default '' on empty
    )
  ) J
) with data with replace;;

-- Extract invoice line data.
declare global temporary table INVOICE_LINE as (
  select J.INVOICE_NUMBER,
         J.LINE_NUM,
         J.ITEM,
         J.QUANTITY,
         J.PRICE

  from QTEMP.JSON_INVOICES JI

  cross join json_table( 
    JI.J_DATA,
    '$.invoices[*]'
    columns(
      INVOICE_NUMBER integer path '$.invoiceNumber',
      nested path '$.items[*]' -- Extract all "line" for all "invoices"
        columns(
          LINE_NUM integer path '$.lineNum',
          ITEM varchar(50) path '$.item',
          QUANTITY integer path '$.quantity',
          PRICE decimal(10, 2) path '$.price'
        ) 
    )
  ) J
) with data with replace
;;

-- Extract invoice discount code data.
declare global temporary table INVOICE_DISCOUNT as (
  select J.INVOICE_NUMBER,
         J.LINE_NUM,
         J.DISCOUNT_CODE

  from QTEMP.JSON_INVOICES JI

  cross join json_table(
    JI.J_DATA,
    '$.invoices[*]'
    columns(
      INVOICE_NUMBER integer path '$.invoiceNumber',
      nested path '$.items[*]'
        columns(
          LINE_NUM integer path '$.lineNum',
          nested path 'lax $.discountCodes[*]' -- Extract all "discounts" for all "lines" for all "invoices"
            columns(
              DISCOUNT_CODE char(2) path '$'
          ) 
        ) 
    )
  ) J

  where DISCOUNT_CODE is not null
) with data with replace  
;;

-- Join up the files to show the results...
select *

from QTEMP.INVOICE_HEADER H

join QTEMP.INVOICE_LINE L
  on L.INVOICE_NUMBER = H.INVOICE_NUMBER
  
left join QTEMP.INVOICE_DISCOUNT D
  on D.INVOICE_NUMBER = L.INVOICE_NUMBER and
     D.LINE_NUM = L.LINE_NUM
;;
