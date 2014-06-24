CREATE DATABASE wpdb;
CREATE USER 'wpuser'@'localhost' IDENTIFIED by 'wpuser';
GRANT ALL PRIVILEGES ON wpdb.* TO 'wpuser'@'localhost' WITH GRANT OPTION;
CREATE USER 'wpuser'@'%' IDENTIFIED by 'wpuser';
GRANT ALL PRIVILEGES ON wpdb.* TO 'wpuser'@'%' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON wpdb.* TO 'wpuser'@'frontend1' IDENTIFIED by 'wpuser' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON wpdb.* TO 'wpuser'@'frontend2' IDENTIFIED by 'wpuser' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON wpdb.* TO 'wpuser'@'frontend3' IDENTIFIED by 'wpuser' WITH GRANT OPTION;
COMMIT;


