REVOKE ALL PRIVILEGES, GRANT OPTION FROM 'ovomdbuser'@'localhost';
DROP USER 'ovomdbuser'@'localhost';
flush privileges;
DROP DATABASE ovomdb;
