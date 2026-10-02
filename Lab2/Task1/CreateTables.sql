CREATE TABLE categories (
    cat_ID integer NOT NULL PRIMARY KEY,
    cat_name text NOT NULL,
    cat_overcat integer
);

CREATE TABLE manufacturers (
    man_ID integer NOT NULL PRIMARY KEY,
    man_name text NOT NULL,
    man_address text NOT NULL
);

CREATE TABLE products (
    prod_ID integer NOT NULL PRIMARY KEY,
    prod_name text NOT NULL,
    prod_price numeric(8, 2) NOT NULL,
    prod_rest integer NOT NULL,
    prod_cat_ID integer NOT NULL,
    prod_man_ID integer NOT NULL,
    FOREIGN KEY (prod_cat_ID) REFERENCES categories (cat_ID) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (prod_man_ID) REFERENCES manufacturers (man_ID) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE customers (
    cust_ID integer NOT NULL PRIMARY KEY,
    cust_name text NOT NULL,
    cust_address text NOT NULL,
    cust_discount integer
);

CREATE TABLE employees (
    emp_ID integer NOT NULL PRIMARY KEY,
    emp_name text NOT NULL,
    emp_position text NOT NULL
);

CREATE TABLE orders (
    ord_ID integer NOT NULL PRIMARY KEY,
    ord_cust_ID integer NOT NULL,
    ord_emp_ID integer NOT NULL,
    ord_date date NOT NULL,
    FOREIGN KEY (ord_cust_ID) REFERENCES customers (cust_ID) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (ord_emp_ID) REFERENCES employees (emp_ID) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE items (
    item_ID integer NOT NULL PRIMARY KEY,
    item_ord_ID integer NOT NULL,
    item_prod_ID integer NOT NULL,
    item_prod_count integer NOT NULL,
    FOREIGN KEY (item_ord_ID) REFERENCES orders (ord_ID) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (item_prod_ID) REFERENCES products (prod_ID) ON DELETE CASCADE ON UPDATE CASCADE
);