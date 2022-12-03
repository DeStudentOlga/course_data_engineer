-- Database: de_hrm

CREATE DATABASE de_hrm
    WITH
    OWNER = postgres
    ENCODING = 'UTF8'
    LC_COLLATE = 'C'
    LC_CTYPE = 'C'
    TABLESPACE = pg_default
    CONNECTION LIMIT = -1;

--создаем тип данных для хранения сведений об уровне сотрудника
create type lev as enum('jun','middle','senior','lead');

--создаем таблицу подразделений
create table department (
id_dep serial not null,
name_dep character varying (150),
chief character varying (150),
kolvo_emp integer,
constraint department_pk primary key (id_dep));

-- создаем таблицу сотрудников
create table employee (
id_emp serial not null,
fio character varying (150),
birth date,
start_date date,
pos character varying (150),
catagory lev,
salary integer,
prev boolean,
department integer not null,
constraint employee_pk primary key (id_emp),    
constraint employee_fk foreign key (department) references department(id_dep)
on update cascade 
on delete restrict);

--создаем тип данных для хранения оценок
create type grade as enum('E','D','C','B','A');

-- создаем таблицу оценок сотрудников
create table kpi (
id_k serial not null,
kvartal smallint,
y smallint,
gr grade,
emp integer,
constraint kpi_pk primary key (id_k),    
constraint kpi_fk foreign key (emp) references employee(id_emp)
on update cascade 
on delete restrict);

-- заполним данные о подразделениях
insert into department (name_dep, chief, kolvo_emp)
values ('ИТ-департамент', 'Иванов И.И.', 10), ('Маркетинг', 'Петров П.П.', 5), 
('Производство', 'Сидоров С.С.', 50), ('Логистика', 'Смиронов С.С.', 10), ('Бухгалтерия', 'Федорова С.С.', 3);

-- заполним данные о сотрудниках
insert into employee (fio, birth, start_date, pos, catagory, salary, prev, department)
values ('Иванов И.И.', '1977-07-07', '2020-07-07', 'начальник ИТ-отдела', 'lead', 100000, 'True', 1),
('Петров П.П.', '1980-08-08', '2020-07-09', 'начальник отдела маркетинга', 'lead', 70000, 'True', 2),
('Савельева О.С.', '1970-06-08', '2018-07-09', 'разработчик', 'middle', 50000, 'False', 1),
('Савина А.С.', '1979-05-06', '2020-07-09', 'маркетолог', 'jun', 30000, 'False', 2),
('Сидоров С.C.', '1976-05-06', '2015-05-06', 'начальник производства', 'lead', 120000, 'True', 3),
('Смирнов С.C.', '1972-03-03', '2005-03-03', 'начальник логистики', 'lead', 90000, 'True', 4),
('Зябликов З.З.', '1982-04-03', '1982-04-03', 'водитель', 'senior', 60000, 'True', 4);

-- заполним данные о новом подразделении
insert into department (name_dep, chief, kolvo_emp)
values ('отдел Интеллектуального анализа данных', 'Звонкий С.П.', 3);

select * from department;
-- заполним данные о новых сотрудниках
insert into employee (fio, birth, start_date, pos, catagory, salary, prev, department)
values ('Звонкий С.П.', '1988-04-20', '2022-12-01', 'начальник аналитиков', 'lead', 90000, 'True', 6),
('Михайлова Е.Н.', '1990-02-20', '2022-12-01', 'аналитик', 'middle', 60000, 'True', 6),
('Троицкий Т.Т.', '1992-04-01', '2022-12-01', 'младший аналитик', 'jun', 40000, 'False', 6);

--заполним данные об оценках сотрудников
insert into kpi (kvartal, y, gr, emp)
values (1, 2022, 'A', 1), (2, 2022, 'B', 1),(3, 2022, 'D', 1),
(1, 2022, 'C', 2), (2, 2022, 'B', 2),(3, 2022, 'A', 2),
(1, 2022, 'A', 3), (2, 2022, 'C', 3),(3, 2022, 'D', 3),
(1, 2022, 'E', 4), (2, 2022, 'B', 4),(3, 2022, 'C', 4),
(1, 2022, 'B', 5), (2, 2022, 'B', 5),(3, 2022, 'B', 5),
(1, 2022, 'A', 6), (2, 2022, 'B', 6),(3, 2022, 'D', 6),
(1, 2022, 'C', 7), (2, 2022, 'C', 7),(3, 2022, 'A', 7);

--Уникальный номер сотрудника, его ФИО и стаж работы – для всех сотрудников компании
select id_emp, fio, age(start_date)
from employee;

--Уникальный номер сотрудника, его ФИО и стаж работы – только первых 3-х сотрудников
select id_emp, fio, age(start_date)
from employee
limit 3;

--Уникальный номер сотрудников - водителей
select id_emp
from employee
where pos='водитель';

--Выведите номера сотрудников, которые хотя бы за 1 квартал получили оценку D или E
select fio from employee join kpi on id_emp=emp
where gr in ('D','E');

--Выведите самую высокую зарплату в компании
select max(salary)
from employee

--Выведите название самого крупного отдела
select name_dep from department
where kolvo_emp=(select max(kolvo_emp) from department)

--Выведите номера сотрудников от самых опытных до вновь прибывших
select id_emp
from employee
order by start_date;

--Рассчитайте среднюю зарплату для каждого уровня сотрудников
select catagory, avg(salary)
from employee
group by catagory;

--Добавьте столбец с информацией о коэффициенте годовой премии к основной таблице. 
alter table employee
add column koef numeric (3,1);
/*Коэффициент рассчитывается по такой схеме: базовое значение коэффициента – 1, каждая оценка действует на коэффициент так:
•         Е – минус 20%
•         D – минус 10%
•         С – без изменений
•         B – плюс 10%
•         A – плюс 20%
Соответственно, сотрудник с оценками А, В, С, D – должен получить коэффициент 1.2.
*/
--создадим таблицу для хранения корректирующих коэффициентов
create table kor_koef (
gr grade,
koef integer,
constraint kor_koef_pk primary key (gr));
--заполним ее данными
insert into kor_koef 
values ('E', -20), ('D',-10),('C',0),('B',10),('A',20);

select fio, sum(kor_koef.koef) 
from employee join kpi on id_emp=emp join kor_koef using (gr)
group by fio

update employee as e
set koef=(select 1+coalesce(0.01*sum(kor_koef.koef),0)
from employee left join kpi on id_emp=emp join kor_koef using (gr)
where fio=e.fio)

select fio, koef from employee;