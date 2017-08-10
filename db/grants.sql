CREATE USER 'ovomdbuser'@'localhost' IDENTIFIED BY 'ovomdbpass';
GRANT CREATE, DELETE, INSERT, SELECT, UPDATE ON `ovomdb`.* TO 'ovomdbuser'@'localhost';
flush privileges;
