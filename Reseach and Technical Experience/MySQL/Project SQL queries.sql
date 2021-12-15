/* Query 1 - Customers information that rented out TV show "Dexter" */
create or replace view Customer_Dexter as
select concat(first_name, ' ', last_name) as 'Customer Name', customer_id as 'Customer ID', purchase_date as 'Date rented/purchased', confirmation_num as 'Confirmation Number'
from invoices join rental_info
using (invoice_id)
join customer
using (customer_id)
join tv_movie on rental_info.catalogue_id = tv_movie.catalogue_id
where title = 'Dexter';

/* Query 2 - Average Star Rating by Production Company */
create or replace view Avg_Studio_Rating as 
select studio_name as 'Studio Name', format(avg(avg_star_rating), 2) as 'Average Rating'
from studio join tv_movie
using (studio_id)
group by studio_id;

/*Query 3 - Movies/TV Shows whose price is higher than the average */
create or replace view movie_greater_average as
select catalogue_id, title
from tv_movie
where pricing >  (select avg(pricing) from tv_movie);

/*Query 4 - What is the most common genre among the Movies */
create or replace view most_common_MoviesGenres as
select coalesce(genre_name, 'Total') as 'Genre Name', count(genre_id) as 'Number of Instances'
from categories join genre
using (genre_id)
join tv_movie on categories.catalogue_id = tv_movie.category_id
where episodes is null
group by genre_name with rollup;

/*Query 5 - How much Redbox has made from invoices */
create or replace view RedBox_revenue as
select coalesce(concat(first_name, ' ', last_name), 'Total') as 'Customer Name', sum(invoice_total) as 'Invoice amounts'
from invoices join customer
using (customer_id)
group by concat(first_name, ' ', last_name) with rollup
