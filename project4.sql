--создаем таблицу клиенты
create table clients (
clientid integer not null,
clientname character varying,
type char,
form character varying,
registerdate date,
constraint clients_pk primary key (ClientId));

--копируем данные о клиентах из csv файла
copy clients from '/Users/ovstoyanova/Clients.csv' DELIMITER ';' CSV HEADER;

--проверяем корректность загрузки данных
select * from clients;

--создаем таблицу счетов
create table account(
accountid integer not null,
accountnum character(20),
clientid integer,
dateopen date,
constraint account_pk primary key(accountid),
constraint account_clients_fk foreign key (clientid) references clients(clientid)
on update cascade on delete restrict)

--копируем данные о счетах из csv файла
copy account from '/Users/ovstoyanova/Account.csv' DELIMITER ';' CSV HEADER;

--проверяем корректность загрузки данных
select * from account;

--создаем таблицу операций
create table operation (
   accountdb	  integer,
   accountcr	  integer,
   dateop	  date,
   amount	  character varying (20),
   currency	  character varying (3),
   comment character varying,
constraint operation_acc_fk1 foreign key (accountdb) references account(accountid)
	on update cascade on delete restrict,
constraint operation_acc_fk2 foreign key (accountcr) references account(accountid)
	on update cascade on delete restrict)

--копируем данные об операциях из csv файла
copy operation from '/Users/ovstoyanova/Operation.csv' DELIMITER ';' CSV HEADER;

--проверяем корректность загрузки данных
select * from operation;

--заменяем разделитель десятичных разрядов
update operation
set amount=replace(amount,',','.');

--заменяем тип столбца amount
alter table operation
alter column amount type numeric(10,2) using amount::numeric(10,2);

--создаем таблицу валют
create table rate (
	currency	character varying (3),
	rate	character varying (50),
	ratedate	date
)
--копируем данные в таблицу валют
copy rate from '/Users/ovstoyanova/Rate.csv' DELIMITER ';' CSV HEADER;
--проверяем корректность загрузки данных
select * from rate;
--заменяем разделитель десятичных разрядов
update rate
set rate=replace(rate,',','.');
--заменяем тип столбца amount
alter table rate
alter column rate type numeric(10,2) using rate::numeric(10,2);

--создаем витрины

/* Витрина _corporate_payments_. Строится по каждому уникальному счету (AccountDB  и AccountCR) из таблицы Operation. Ключ партиции CutoffDt
Поле	Описание
AccountId	ИД счета
ClientId	Ид клиента счета
PaymentAmt	Сумма операций по счету, где счет клиента указан в дебете проводки
EnrollementAmt	Сумма операций по счету, где счет клиента указан в  кредите проводки
TaxAmt 	Сумму операций, где счет клиента указан в дебете, и счет кредита 40702
ClearAmt 	Сумма операций, где счет клиента указан в кредите, и счет дебета 40802
CarsAmt 	Сумма операций, где счет клиента указан в дебете проводки и назначение платежа не содержит слов по маскам Списка 1
FoodAmt 	Сумма операций, где счет клиента указан в кредите проводки и назначение платежа содержит слова по Маскам Списка 2
FLAmt 	Сумма операций с физ. лицами. Счет клиента указан в дебете проводки, а клиент в кредите проводки – ФЛ.
CutoffDt 	Дата операции;*/

--создаем вспомогательные представления
--для дебетовых транзакций счета
create or replace view dbt as
(
	select accountid, accountdb, accountcr, amount, currency, dateop
	from operation join account on accountdb=accountid
)
----для кредитовых транзакций счета
create or replace view crt as
(
	select accountid, accountdb, accountcr, amount, currency, dateop
	from operation join account on accountcr=accountid
)
select * from crt;

create or replace function f1(date) returns 
table (accountid integer, clientid integer, "PaymentAmt" numeric, "EnrollementAmt" numeric, "TaxAmt" numeric, "ClearAmt" numeric, dateoff date)
as
$$
(
with dbt_ as (
	select distinct accountid, sum(amount*rate) over (partition by accountdb) as "PaymentAmt", 
	sum(amount*rate) filter (where accountcr in (select accountid from account where accountnum like '40702%')) 
	over(partition by accountdb) as "TaxAmt"
	from dbt join rate using (currency)
	where ratedate=(select max(ratedate) from rate) and dateop=$1
),
crt_ as(
	select distinct accountid, dateop, sum(amount*rate) over (partition by accountcr) as "EnrollementAmt",
	sum(amount*rate) filter (where accountdb in (select accountid from account where accountnum like '40802%')) 
	over(partition by accountcr) as "ClearAmt"
	from crt join rate using (currency)
	where ratedate=(select max(ratedate) from rate) and dateop=$1
)
select accountid as "AccountId", clientid as "ClientId", "PaymentAmt", "EnrollementAmt", "TaxAmt", "ClearAmt", $1 as dateoff
from dbt_ full join crt_ using (accountid) join account using (accountid));
$$
Language SQL;

select * from f1('2020-11-01');

/*Витрина _corporate_account_. Строится по каждому уникальному счету из таблицы Operation на заданную дату расчета. Ключ партиции CutoffDt
Поле	Описание
AccountID 	ИД счета
AccountNum 	Номер счета
DateOpen 	Дата открытия счета
ClientId 	ИД клиента
ClientName 	Наименование клиента
TotalAmt 	Общая сумма оборотов по счету. Считается как сумма PaymentAmt и EnrollementAmt
CutoffDt 	Дата операции
*/

create view v2 as(
select "AccountId", accountnum, dateopen, "ClientId", clientname, 
coalesce("PaymentAmt",0) + coalesce("EnrollementAmt",0) as "TotalAmt" 
from v1 join account on "AccountId"=accountid join clients using(clientid));

select * from v2;

/*Витрина _corporate_info_. Строится по каждому уникальному клиенту из таблицы Operation. Ключ партиции CutoffDt
Поле 	Описание
ClientId 	ИД клиента (PK)
ClientName 	Наименование клиента
Type 	Тип клиента (ФЛ, ЮЛ)
Form 	Организационно-правовая форма (ООО, ИП и т.п.)
RegisterDate 	Дата регистрации клиента
TotalAmt 	Сумма операций по всем счетам клиент. Считается как сумма corporate_account.total_amt по всем счетам.
CutoffDt 	Дата операции
*/

select distinct clientid, clients.clientname, type, form, registerdate, sum("TotalAmt") over (partition by clientid)
from clients join v2 on clientid="ClientId"

