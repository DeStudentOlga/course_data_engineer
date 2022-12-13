--Попробуйте вывести не просто самую высокую зарплату во всей команде, а вывести именно фамилию сотрудника с самой высокой зарплатой.
select fio from employee 
where salary=(select max(salary) from employee)

--Попробуйте вывести фамилии сотрудников в алфавитном порядке
select fio from employee order by fio

--Рассчитайте средний стаж для каждого уровня сотрудников
select catagory, avg(age(start_date))
from employee
group by catagory

--Выведите фамилию сотрудника и название отдела, в котором он работает
select fio, name_dep
from employee join department on department=id_dep

--Выведите название отдела и фамилию сотрудника с самой высокой зарплатой в данном отделе и саму зарплату также.
select name_dep, fio, salary
from employee join department on department=id_dep
where salary=(select max(salary) from employee where department=id_dep)

--Выведите название отдела, сотрудники которого получат наибольшую премию по итогам года.
with prem as (
select name_dep, sum(salary*koef) as sm from employee join department on department=id_dep
group by name_dep)
select name_dep from prem where sm=(select max(sm) from prem)

/*Проиндексируйте зарплаты сотрудников с учетом коэффициента премии. 
Для сотрудников с коэффициентом премии больше 1.2 – размер индексации составит 20%, 
для сотрудников с коэффициентом премии от 1 до 1.2 размер индексации составит 10%.
Для всех остальных сотрудников индексация не предусмотрена.*/
alter table employee
add column index_salary numeric (2,1);
update employee
set index_salary=(case when koef>1.2 then 1.2
                        when koef<=1.2 and koef>=1 then 1.1 else 1 end)
                        
select fio,salary, salary*index_salary as new_salary, koef from employee;

/*По итогам индексации отдел финансов хочет получить следующий отчет: вам необходимо на уровень каждого отдела вывести следующую информацию:
                                                    i.     Название отдела
                                                  ii.     Фамилию руководителя
                                                iii.     Количество сотрудников
                                                iv.     Средний стаж
                                                  v.     Средний уровень зарплаты
                                                vi.     Количество сотрудников уровня junior
                                              vii.     Количество сотрудников уровня middle
                                            viii.     Количество сотрудников уровня senior
                                                ix.     Количество сотрудников уровня lead
                                                  x.     Общий размер оплаты труда всех сотрудников до индексации
                                                xi.     Общий размер оплаты труда всех сотрудников после индексации
                                              xii.     Общее количество оценок А
                                            xiii.     Общее количество оценок B
                                            xiv.     Общее количество оценок C
                                              xv.     Общее количество оценок D
                                            xvi.     Общее количество оценок Е
                                          xvii.     Средний показатель коэффициента премии
                                        xviii.     Общий размер премии.
                                            xix.     Общую сумму зарплат(+ премии) до индексации
                                              xx.     Общую сумму зарплат(+ премии) после индексации(премии не индексируются)
                                            xxi.     Разницу в % между предыдущими двумя суммами(первая/вторая)

*/
--функция для подсчета оценок
create or replace function marks (d integer, out a bigint, out b bigint, out c bigint, out d bigint, out e bigint) as
$$
select count(id_k) filter (where gr='A') as a, count(id_k) filter (where gr='B') as b, count(id_k) filter (where gr='C') as c, 
count(id_k) filter (where gr='D') as d, count(id_k) filter (where gr='E') as e
from kpi join employee on emp=id_emp join department on department=id_dep
where id_dep=d;
$$
language SQL;
--проверка функции
select a from marks(1);
--запрос для итогового отчета
select distinct name_dep, chief, kolvo_emp, avg(age(start_date)) over w as experience,
round(avg(salary) over w) as avg_salary, 
count(id_emp) filter (where catagory='jun') over w as juns, 
count(id_emp) filter (where catagory='middle') over w as middles, 
count(id_emp) filter (where catagory='senior') over w as seniors, 
count(id_emp) filter (where catagory='lead') over w as leads,
sum(salary) over w as sum_salary,
sum(salary*index_salary) over w as sum_salary_new,
round(avg(koef) over w,2) as avg_koef,
sum(salary*koef) over w as sum_bonus,
(sum(salary) over w)+(sum(salary*koef) over w)  as sum_befor,
(sum(salary*index_salary) over w)+(sum(salary*koef) over w)  as sum_after,
(select a from marks(id_dep)) as a_marks,
(select b from marks(id_dep)) as b_marks,
(select c from marks(id_dep)) as c_marks,
(select d from marks(id_dep)) as d_marks,
(select e from marks(id_dep)) as e_marks,
round(((sum(salary) over w)+(sum(salary*koef) over w))*100.0/((sum(salary*index_salary) over w)+(sum(salary*koef) over w)),1) as difference
from department join employee on id_dep=department
window w as (partition by name_dep);